import AppKit
import CueFetchCore
import Foundation

@MainActor
final class DownloadStore: ObservableObject {
    private enum Defaults {
        static let destination = "destination"
        static let includeSubtitles = "includeSubtitles"
        static let useBrowserCookies = "useBrowserCookies"
    }

    @Published var inputURL = ""
    @Published var candidate: DownloadCandidate?
    @Published var selectedFormatID: UUID?
    @Published var selectedPreset: OutputPreset = .bestVideo
    @Published var includeSubtitles = UserDefaults.standard.object(forKey: Defaults.includeSubtitles) as? Bool ?? true {
        didSet { UserDefaults.standard.set(includeSubtitles, forKey: Defaults.includeSubtitles) }
    }
    @Published var useBrowserCookies = UserDefaults.standard.object(forKey: Defaults.useBrowserCookies) as? Bool ?? false {
        didSet { UserDefaults.standard.set(useBrowserCookies, forKey: Defaults.useBrowserCookies) }
    }
    @Published var destination = UserDefaults.standard.string(forKey: Defaults.destination) ?? "~/Downloads/CueFetch" {
        didSet { UserDefaults.standard.set(destination, forKey: Defaults.destination) }
    }
    @Published var recentLinks: [RecentLink] = []
    @Published var toolStatus = ToolLocator.status()
    @Published var isShowingSettings = false
    @Published var isAnalyzing = false
    @Published var isDownloading = false
    @Published var downloadProgress = 0.0
    @Published var statusMessage = "Ready"
    @Published var lastCommandPreview = ""
    @Published var lastDownloadedPath = ""
    @Published var lastErrorMessage = ""

    private var activeProcess: Process?
    private var downloadStartedAt: Date?

    var selectedFormat: MediaFormat? {
        guard let candidate else { return nil }
        return candidate.formats.first { $0.id == selectedFormatID } ?? candidate.formats.first
    }

    var canAnalyze: Bool {
        !inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canDownload: Bool {
        guard let candidate, selectedFormat != nil else { return false }
        return !isDownloading && candidate.accessState != .drmProtected && candidate.accessState != .unsupported
    }

    func refreshToolStatus() {
        toolStatus = ToolLocator.status()
        statusMessage = toolStatus.isReady ? "Using yt-dlp \(toolStatus.ytdlpVersion ?? "")" : "yt-dlp not found"
    }

    func selectRecent(_ link: RecentLink) {
        inputURL = link.url
        candidate = nil
        selectedFormatID = nil
        lastErrorMessage = ""
        statusMessage = "Link restored. Analyze to refresh details."
        updateCommandPreview()
    }

    func clearRecentLinks() {
        recentLinks.removeAll()
        statusMessage = "History cleared"
    }

    func analyzeLink() {
        guard canAnalyze else {
            statusMessage = "Paste a link to analyze"
            return
        }

        refreshToolStatus()
        guard let ytdlpPath = toolStatus.ytdlpPath else {
            statusMessage = "yt-dlp not found"
            lastErrorMessage = "Install yt-dlp with Homebrew or add it to PATH."
            return
        }

        isAnalyzing = true
        lastErrorMessage = ""
        statusMessage = "Analyzing link..."

        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let arguments = YTDLPCommandBuilder.analyzeArguments(for: trimmed)

        Task {
            do {
                let data = try await Self.runAndCapture(executable: ytdlpPath, arguments: arguments)
                let metadata = try YTDLPMetadataParser.parse(data)
                let mapped = YTDLPMetadataMapper.candidate(from: metadata, fallbackURL: trimmed)

                candidate = mapped
                selectedFormatID = mapped.formats.first?.id
                prependRecent(from: mapped)
                isAnalyzing = false
                statusMessage = "Ready to download"
                updateCommandPreview()
            } catch {
                isAnalyzing = false
                candidate = nil
                selectedFormatID = nil
                statusMessage = "Could not analyze link"
                lastErrorMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                updateCommandPreview()
            }
        }
    }

    func addCookies() {
        useBrowserCookies = true
        candidate?.accessState = .available
        statusMessage = "Safari cookies enabled for this download"
        updateCommandPreview()
    }

    func startDownload() {
        guard canDownload else {
            statusMessage = "This link cannot be downloaded"
            return
        }

        refreshToolStatus()
        guard let candidate, let selectedFormat else {
            statusMessage = "Analyze a link before downloading"
            return
        }
        guard let ytdlpPath = toolStatus.ytdlpPath else {
            statusMessage = "yt-dlp not found"
            lastErrorMessage = "Install yt-dlp with Homebrew or add it to PATH."
            return
        }

        isDownloading = true
        downloadProgress = 0
        lastErrorMessage = ""
        lastDownloadedPath = ""
        downloadStartedAt = Date()
        statusMessage = "Preparing download..."
        updateCommandPreview()

        let destinationPath = expandedDestination
        do {
            try FileManager.default.createDirectory(
                atPath: destinationPath,
                withIntermediateDirectories: true
            )
        } catch {
            isDownloading = false
            statusMessage = "Could not create destination"
            lastErrorMessage = error.localizedDescription
            return
        }

        let options = DownloadOptions(
            url: candidate.url,
            destination: destinationPath,
            preset: selectedPreset,
            format: selectedFormat,
            includeSubtitles: includeSubtitles,
            useBrowserCookies: useBrowserCookies
        )
        runDownload(executable: ytdlpPath, arguments: YTDLPCommandBuilder.downloadArguments(for: options))
    }

    func cancelDownload() {
        activeProcess?.terminate()
        activeProcess = nil
        isDownloading = false
        statusMessage = "Download cancelled"
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: expandedDestination)

        if panel.runModal() == .OK, let url = panel.url {
            destination = url.path
            updateCommandPreview()
            statusMessage = "Destination updated"
        }
    }

    func openDestinationFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: expandedDestination))
    }

    func revealLastDownload() {
        guard let resolvedPath = resolvedLastDownloadPath() else {
            openDestinationFolder()
            return
        }

        lastDownloadedPath = resolvedPath
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: resolvedPath)])
    }

    func updateCommandPreview() {
        guard let candidate, let selectedFormat else {
            lastCommandPreview = "Analyze a link to preview the yt-dlp command."
            return
        }

        let options = DownloadOptions(
            url: candidate.url,
            destination: expandedDestination,
            preset: selectedPreset,
            format: selectedFormat,
            includeSubtitles: includeSubtitles,
            useBrowserCookies: useBrowserCookies
        )
        lastCommandPreview = "yt-dlp " + YTDLPCommandBuilder.downloadArguments(for: options)
            .map { $0.contains(" ") ? "\"\($0)\"" : $0 }
            .joined(separator: " ")
    }

    private var expandedDestination: String {
        (destination as NSString).expandingTildeInPath
    }

    private func resolvedLastDownloadPath() -> String? {
        if !lastDownloadedPath.isEmpty, FileManager.default.fileExists(atPath: lastDownloadedPath) {
            return lastDownloadedPath
        }

        guard let downloadStartedAt else {
            return nil
        }

        return newestDownloadPath(since: downloadStartedAt.addingTimeInterval(-10))
    }

    private func newestDownloadPath(since startDate: Date) -> String? {
        let destinationURL = URL(fileURLWithPath: expandedDestination, isDirectory: true)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: destinationURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls.compactMap { url -> (url: URL, modified: Date)? in
            guard
                let values = try? url.resourceValues(forKeys: Set(keys)),
                values.isRegularFile == true,
                let modified = values.contentModificationDate,
                modified >= startDate
            else {
                return nil
            }
            return (url, modified)
        }
        .sorted { $0.modified > $1.modified }
        .first?
        .url
        .path
    }

    private func runDownload(executable: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ToolLocator.processEnvironment()

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let outputHandler: @Sendable (FileHandle) -> Void = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            Task { @MainActor in
                self?.handleProcessOutput(text)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = outputHandler
        errorPipe.fileHandleForReading.readabilityHandler = outputHandler

        process.terminationHandler = { [weak self] process in
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            Task { @MainActor in
                guard let self else { return }
                self.activeProcess = nil
                self.isDownloading = false
                if process.terminationStatus == 0 {
                    if let resolvedPath = self.resolvedLastDownloadPath() {
                        self.lastDownloadedPath = resolvedPath
                    }
                    self.downloadProgress = 1
                    self.statusMessage = "Download completed"
                } else {
                    self.statusMessage = "Download failed"
                    if self.lastErrorMessage.isEmpty {
                        self.lastErrorMessage = "yt-dlp exited with status \(process.terminationStatus)."
                    }
                }
            }
        }

        do {
            activeProcess = process
            try process.run()
            statusMessage = "Download started"
        } catch {
            activeProcess = nil
            isDownloading = false
            statusMessage = "Could not start download"
            lastErrorMessage = error.localizedDescription
        }
    }

    private func handleProcessOutput(_ text: String) {
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if let path = destinationPath(from: line) {
                lastDownloadedPath = path
            }
            if let percent = progressPercent(from: line) {
                downloadProgress = percent / 100
                statusMessage = "Downloading \(Int(percent))%"
            }
            if line.localizedCaseInsensitiveContains("error") {
                lastErrorMessage = line
            }
        }
    }

    private func destinationPath(from line: String) -> String? {
        guard let range = line.range(of: "Destination: ") else {
            return mergerDestinationPath(from: line)
        }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mergerDestinationPath(from line: String) -> String? {
        guard let range = line.range(of: #"into "(.+)""#, options: .regularExpression) else {
            return nil
        }

        let match = String(line[range])
        guard let firstQuote = match.firstIndex(of: "\""), let lastQuote = match.lastIndex(of: "\""), firstQuote != lastQuote else {
            return nil
        }

        return String(match[match.index(after: firstQuote)..<lastQuote])
    }

    private func progressPercent(from line: String) -> Double? {
        guard let range = line.range(of: #"(\d+(?:\.\d+)?)%"#, options: .regularExpression) else {
            return nil
        }
        return Double(line[range].replacingOccurrences(of: "%", with: ""))
    }

    private func prependRecent(from candidate: DownloadCandidate) {
        let recent = RecentLink(
            title: candidate.title,
            domain: candidate.domain,
            dateLabel: "Just now",
            thumbnailName: candidate.thumbnailName,
            site: candidate.site,
            url: candidate.url
        )
        recentLinks.removeAll { $0.url == recent.url }
        recentLinks.insert(recent, at: 0)
        if recentLinks.count > 8 {
            recentLinks.removeLast(recentLinks.count - 8)
        }
    }

    private static func accessState(from error: String) -> AccessState {
        let lowered = error.lowercased()
        if lowered.contains("drm") {
            return .drmProtected
        }
        if lowered.contains("cookie") || lowered.contains("sign in") || lowered.contains("login") {
            return .cookiesRequired
        }
        return .unsupported
    }

    private static func runAndCapture(executable: String, arguments: [String]) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let outputURL = fileManager.temporaryDirectory.appendingPathComponent("cuefetch-analyze-\(UUID().uuidString).json")
            let errorURL = fileManager.temporaryDirectory.appendingPathComponent("cuefetch-analyze-\(UUID().uuidString).log")

            fileManager.createFile(atPath: outputURL.path, contents: nil)
            fileManager.createFile(atPath: errorURL.path, contents: nil)

            let outputHandle = try FileHandle(forWritingTo: outputURL)
            let errorHandle = try FileHandle(forWritingTo: errorURL)

            defer {
                try? outputHandle.close()
                try? errorHandle.close()
                try? fileManager.removeItem(at: outputURL)
                try? fileManager.removeItem(at: errorURL)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = ToolLocator.processEnvironment()
            process.standardOutput = outputHandle
            process.standardError = errorHandle

            try process.run()

            let deadline = Date().addingTimeInterval(60)
            while process.isRunning && Date() < deadline {
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
                throw NSError(
                    domain: "CueFetch.ytdlp",
                    code: 124,
                    userInfo: [NSLocalizedDescriptionKey: "Timed out while analyzing link. Check the site connection and try again."]
                )
            }

            process.waitUntilExit()

            try outputHandle.synchronize()
            try errorHandle.synchronize()

            let output = try Data(contentsOf: outputURL)
            let error = try Data(contentsOf: errorURL)

            guard process.terminationStatus == 0 else {
                let message = String(data: error, encoding: .utf8)
                    ?? "yt-dlp exited with status \(process.terminationStatus)."
                throw NSError(
                    domain: "CueFetch.ytdlp",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }

            return output
        }.value
    }
}
