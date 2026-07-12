import CueFetchCore
import Foundation

struct DownloadExecutionRequest: Equatable, Sendable {
    let runID: UUID
    let executablePath: String
    let arguments: [String]
    let environment: [String: String]
}

enum DownloadRunnerEvent: Equatable, Sendable {
    case standardOutput(String)
    case standardError(String)
}

enum DownloadRunnerResult: Equatable, Sendable {
    case exited(code: Int32)
    case cancelled
    case launchFailed(message: String)
}

protocol DownloadRunner: Sendable {
    func run(
        _ request: DownloadExecutionRequest,
        onEvent: @escaping @Sendable (DownloadRunnerEvent) -> Void
    ) async -> DownloadRunnerResult

    func cancel(runID: UUID) async
}

struct AnalysisExecutionRequest: Equatable, Sendable {
    let executablePath: String
    let arguments: [String]
    let environment: [String: String]
    let timeout: TimeInterval
}

enum AnalysisRunnerError: Error, Equatable, Sendable, LocalizedError {
    case timedOut
    case exited(code: Int32, message: String)
    case launchFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .timedOut:
            "Timed out while analyzing link. Check the site connection and try again."
        case let .exited(_, message), let .launchFailed(message):
            message
        }
    }
}

protocol AnalysisRunner: Sendable {
    func capture(_ request: AnalysisExecutionRequest) async throws -> Data
}

struct ProcessAnalysisRunner: AnalysisRunner {
    func capture(_ request: AnalysisExecutionRequest) async throws -> Data {
        let process = Process()

        return try await withTaskCancellationHandler {
            let fileManager = FileManager.default
            let outputURL = fileManager.temporaryDirectory
                .appendingPathComponent("cuefetch-analyze-\(UUID().uuidString).json")
            let errorURL = fileManager.temporaryDirectory
                .appendingPathComponent("cuefetch-analyze-\(UUID().uuidString).log")

            _ = fileManager.createFile(atPath: outputURL.path, contents: nil)
            _ = fileManager.createFile(atPath: errorURL.path, contents: nil)

            let outputHandle = try FileHandle(forWritingTo: outputURL)
            let errorHandle = try FileHandle(forWritingTo: errorURL)

            defer {
                if process.isRunning {
                    process.terminate()
                    process.waitUntilExit()
                }
                try? outputHandle.close()
                try? errorHandle.close()
                try? fileManager.removeItem(at: outputURL)
                try? fileManager.removeItem(at: errorURL)
            }

            process.executableURL = URL(fileURLWithPath: request.executablePath)
            process.arguments = request.arguments
            process.environment = request.environment
            process.standardOutput = outputHandle
            process.standardError = errorHandle

            do {
                try process.run()
            } catch {
                throw AnalysisRunnerError.launchFailed(message: error.localizedDescription)
            }

            try Task.checkCancellation()

            let deadline = Date().addingTimeInterval(request.timeout)
            while process.isRunning && Date() < deadline {
                try await Task.sleep(for: .milliseconds(50))
            }

            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
                throw AnalysisRunnerError.timedOut
            }

            process.waitUntilExit()
            try outputHandle.synchronize()
            try errorHandle.synchronize()

            let output = try Data(contentsOf: outputURL)
            let errorData = try Data(contentsOf: errorURL)
            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedMessage: String
                if let message, !message.isEmpty {
                    resolvedMessage = message
                } else {
                    resolvedMessage = "yt-dlp exited with status \(process.terminationStatus)."
                }
                throw AnalysisRunnerError.exited(
                    code: process.terminationStatus,
                    message: resolvedMessage
                )
            }

            return output
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

actor ProcessDownloadRunner: DownloadRunner {
    private final class ExecutionContext: @unchecked Sendable {
        let request: DownloadExecutionRequest
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let onEvent: @Sendable (DownloadRunnerEvent) -> Void
        let outputLock = NSLock()
        var continuation: CheckedContinuation<DownloadRunnerResult, Never>?
        var cancellationRequested = false

        init(
            request: DownloadExecutionRequest,
            onEvent: @escaping @Sendable (DownloadRunnerEvent) -> Void
        ) {
            self.request = request
            self.onEvent = onEvent
        }
    }

    private var executions: [UUID: ExecutionContext] = [:]

    func run(
        _ request: DownloadExecutionRequest,
        onEvent: @escaping @Sendable (DownloadRunnerEvent) -> Void
    ) async -> DownloadRunnerResult {
        if Task.isCancelled {
            return .cancelled
        }

        let context = ExecutionContext(request: request, onEvent: onEvent)
        configure(context)

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                context.continuation = continuation
                executions[request.runID] = context
                do {
                    try context.process.run()
                } catch {
                    finish(
                        runID: request.runID,
                        proposedResult: .launchFailed(message: error.localizedDescription),
                        drainOutput: false
                    )
                }
            }
        } onCancel: {
            Task {
                await self.cancel(runID: request.runID)
            }
        }
    }

    func cancel(runID: UUID) {
        guard let context = executions[runID] else {
            return
        }

        context.cancellationRequested = true
        if context.process.isRunning {
            context.process.terminate()
        } else {
            finish(runID: runID, proposedResult: .cancelled, drainOutput: true)
        }
    }

    private func configure(_ context: ExecutionContext) {
        context.process.executableURL = URL(fileURLWithPath: context.request.executablePath)
        context.process.arguments = context.request.arguments
        context.process.environment = context.request.environment
        context.process.standardOutput = context.outputPipe
        context.process.standardError = context.errorPipe

        context.outputPipe.fileHandleForReading.readabilityHandler = { [weak context] handle in
            guard let context else { return }
            context.outputLock.withLock {
                Self.deliverAvailableData(from: handle) { text in
                    context.onEvent(.standardOutput(text))
                }
            }
        }
        context.errorPipe.fileHandleForReading.readabilityHandler = { [weak context] handle in
            guard let context else { return }
            context.outputLock.withLock {
                Self.deliverAvailableData(from: handle) { text in
                    context.onEvent(.standardError(text))
                }
            }
        }

        let runID = context.request.runID
        context.process.terminationHandler = { [weak self] process in
            Task {
                await self?.finish(
                    runID: runID,
                    proposedResult: .exited(code: process.terminationStatus),
                    drainOutput: true
                )
            }
        }
    }

    private func finish(
        runID: UUID,
        proposedResult: DownloadRunnerResult,
        drainOutput: Bool
    ) {
        guard let context = executions.removeValue(forKey: runID) else {
            return
        }

        context.outputPipe.fileHandleForReading.readabilityHandler = nil
        context.errorPipe.fileHandleForReading.readabilityHandler = nil

        context.outputLock.withLock {
            if drainOutput && !context.cancellationRequested {
                Self.deliverRemainingData(from: context.outputPipe.fileHandleForReading) { text in
                    context.onEvent(.standardOutput(text))
                }
                Self.deliverRemainingData(from: context.errorPipe.fileHandleForReading) { text in
                    context.onEvent(.standardError(text))
                }
            }
        }

        let result = context.cancellationRequested ? .cancelled : proposedResult
        context.continuation?.resume(returning: result)
        context.continuation = nil
    }

    private nonisolated static func deliverAvailableData(
        from handle: FileHandle,
        deliver: (String) -> Void
    ) {
        let data = handle.availableData
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
            return
        }
        deliver(text)
    }

    private nonisolated static func deliverRemainingData(
        from handle: FileHandle,
        deliver: (String) -> Void
    ) {
        guard
            let data = try? handle.readToEnd(),
            !data.isEmpty,
            let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        deliver(text)
    }
}

enum YTDLPOutputContract {
    static let finalPathPrefix = YTDLPCommandBuilder.finalPathMarker
    static let finalPathPrintTemplate = "after_move:\(finalPathPrefix)%(filepath)s"

    static func argumentsReportingFinalPath(_ arguments: [String]) -> [String] {
        guard !arguments.contains(where: { $0.contains(finalPathPrefix) }) else {
            return arguments
        }

        var updated = arguments
        let insertionIndex: Int
        if let optionTerminatorIndex = updated.firstIndex(of: "--") {
            insertionIndex = optionTerminatorIndex
        } else if updated.isEmpty {
            insertionIndex = 0
        } else {
            insertionIndex = updated.index(before: updated.endIndex)
        }

        updated.insert(contentsOf: ["--print", finalPathPrintTemplate], at: insertionIndex)
        return updated
    }
}

struct YTDLPOutputParser: Equatable, Sendable {
    private var standardOutputBuffer = ""
    private(set) var finalPath: String?

    mutating func consumeStandardOutput(_ chunk: String) {
        standardOutputBuffer += chunk
        consumeCompleteLines()
    }

    mutating func finish() {
        guard !standardOutputBuffer.isEmpty else { return }
        consume(line: standardOutputBuffer)
        standardOutputBuffer = ""
    }

    private mutating func consumeCompleteLines() {
        while let newlineIndex = standardOutputBuffer.firstIndex(where: \.isNewline) {
            let line = String(standardOutputBuffer[..<newlineIndex])
            let nextIndex = standardOutputBuffer.index(after: newlineIndex)
            standardOutputBuffer.removeSubrange(..<nextIndex)
            consume(line: line)
        }
    }

    private mutating func consume(line: String) {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.hasPrefix(YTDLPOutputContract.finalPathPrefix) else {
            return
        }

        let path = trimmedLine.dropFirst(YTDLPOutputContract.finalPathPrefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
            finalPath = path
        }
    }

    static func progressPercent(from text: String) -> Double? {
        guard let range = text.range(of: #"(\d+(?:\.\d+)?)%"#, options: .regularExpression) else {
            return nil
        }
        return Double(text[range].replacingOccurrences(of: "%", with: ""))
    }
}

struct DownloadRunSnapshot: Equatable, Sendable {
    let id: UUID
    let candidate: DownloadCandidate
    let plan: DownloadPlan
    let executablePath: String
    let arguments: [String]
    let ytdlpVersion: String?
    let startedAt: Date
}

struct CompletedDownload: Equatable, Sendable {
    let run: DownloadRunSnapshot
    let filePath: String
    let completedAt: Date
}

struct FailedDownload: Equatable, Sendable {
    let run: DownloadRunSnapshot
    let message: String
    let exitCode: Int32?
    let failedAt: Date
}

struct CancelledDownload: Equatable, Sendable {
    let run: DownloadRunSnapshot
    let cancelledAt: Date
}

enum DownloadRunState: Equatable, Sendable {
    case idle
    case running(DownloadRunSnapshot)
    case succeeded(CompletedDownload)
    case failed(FailedDownload)
    case cancelled(CancelledDownload)

    var isRunning: Bool {
        if case .running = self { true } else { false }
    }

    var runID: UUID? {
        switch self {
        case .idle:
            nil
        case let .running(run):
            run.id
        case let .succeeded(download):
            download.run.id
        case let .failed(download):
            download.run.id
        case let .cancelled(download):
            download.run.id
        }
    }

    var completedDownload: CompletedDownload? {
        guard case let .succeeded(download) = self else { return nil }
        return download
    }
}

enum DownloadReceiptRenderer {
    static func render(
        _ completed: CompletedDownload,
        homeDirectory: String = NSHomeDirectory()
    ) -> String {
        let run = completed.run
        let plan = run.plan
        let formatDescription = effectiveFormatDescription(for: plan)
        let commandArguments = run.arguments.map {
            ReceiptPrivacy.safeCommandArgument($0, homeDirectory: homeDirectory)
        }
        let command = ([URL(fileURLWithPath: run.executablePath).lastPathComponent] + commandArguments)
            .map(ReceiptPrivacy.shellQuoted)
            .joined(separator: " ")

        return [
            "CueFetch Download Receipt",
            "Run: \(run.id.uuidString)",
            "Started: \(ReceiptPrivacy.timestamp(run.startedAt))",
            "Completed: \(ReceiptPrivacy.timestamp(completed.completedAt))",
            "Title: \(ReceiptPrivacy.singleLine(run.candidate.title))",
            "URL: \(ReceiptPrivacy.redactedURL(plan.url.string))",
            "Downloaded file: \(ReceiptPrivacy.abbreviatedPath(completed.filePath, homeDirectory: homeDirectory))",
            "Destination: \(ReceiptPrivacy.abbreviatedPath(plan.destination, homeDirectory: homeDirectory))",
            "Preset: \(plan.preset.rawValue)",
            "Format: \(formatDescription)",
            "Subtitles: \(plan.includeSubtitles ? "Included if available" : "Skipped")",
            "Subtitle languages: \(plan.includeSubtitles ? plan.subtitleLanguages : "-")",
            "Safari cookies: \(plan.useBrowserCookies ? "Enabled for this run" : "Disabled")",
            "yt-dlp: \(run.ytdlpVersion ?? "unknown")",
            "yt-dlp executable: \(URL(fileURLWithPath: run.executablePath).lastPathComponent)",
            "Command: \(command)"
        ].joined(separator: "\n")
    }

    private static func effectiveFormatDescription(for plan: DownloadPlan) -> String {
        switch plan.effectiveSelection {
        case .selectedFormat:
            guard let format = plan.selectedFormat else {
                return "Selected format"
            }
            return "\(format.quality) - \(format.container) - \(format.videoCodec) - \(format.audio)"
        case let .fixedQuickTimeMP4(maximumHeight):
            return "Up to \(maximumHeight)p MP4 - H.264 - AAC (fixed preset)"
        case .fixedM4A:
            return "M4A - AAC audio (fixed preset)"
        }
    }
}

struct DownloadOutputSnapshot: Equatable, Sendable {
    let finalPath: String?
    let progress: Double?
    let latestError: String?
}

final class DownloadOutputAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var parser = YTDLPOutputParser()
    private var progress: Double?
    private var latestError: String?

    @discardableResult
    func consume(_ event: DownloadRunnerEvent) -> DownloadOutputSnapshot {
        lock.withLock {
            switch event {
            case let .standardOutput(text):
                parser.consumeStandardOutput(text)
                updateProgress(from: text)
            case let .standardError(text):
                updateProgress(from: text)
                updateError(from: text)
            }
            return currentSnapshot()
        }
    }

    func finish() -> DownloadOutputSnapshot {
        lock.withLock {
            parser.finish()
            return currentSnapshot()
        }
    }

    private func updateProgress(from text: String) {
        guard let percent = YTDLPOutputParser.progressPercent(from: text) else { return }
        progress = percent / 100
    }

    private func updateError(from text: String) {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        if let errorLine = lines.last(where: { $0.localizedCaseInsensitiveContains("error") }) {
            latestError = errorLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func currentSnapshot() -> DownloadOutputSnapshot {
        DownloadOutputSnapshot(
            finalPath: parser.finalPath,
            progress: progress,
            latestError: latestError
        )
    }
}

private enum ReceiptPrivacy {
    static func redactedURL(_ value: String) -> String {
        guard
            var components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return "[redacted URL]"
        }

        components.user = nil
        components.password = nil
        components.fragment = nil
        if let queryItems = components.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems.map { item in
                URLQueryItem(name: item.name, value: item.value == nil ? nil : "REDACTED")
            }
        }
        return components.string ?? "[redacted URL]"
    }

    static func abbreviatedPath(_ path: String, homeDirectory: String) -> String {
        let normalizedHome = homeDirectory.hasSuffix("/")
            ? String(homeDirectory.dropLast())
            : homeDirectory
        if path == normalizedHome {
            return "~"
        }
        if path.hasPrefix(normalizedHome + "/") {
            return "~" + path.dropFirst(normalizedHome.count)
        }
        return path
    }

    static func safeCommandArgument(_ argument: String, homeDirectory: String) -> String {
        if let scheme = URLComponents(string: argument)?.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return redactedURL(argument)
        }
        return abbreviatedPath(argument, homeDirectory: homeDirectory)
    }

    static func shellQuoted(_ argument: String) -> String {
        guard !argument.isEmpty else { return "''" }
        let safeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~/:=%+,@"))
        if argument.unicodeScalars.allSatisfy(safeCharacters.contains) {
            return argument
        }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
