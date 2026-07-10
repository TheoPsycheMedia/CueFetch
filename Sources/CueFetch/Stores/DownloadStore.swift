import AppKit
import CueFetchCore
import Foundation

@MainActor
final class DownloadStore: ObservableObject {
    private enum Defaults {
        static let destination = "destination"
        static let includeSubtitles = "includeSubtitles"
        static let recentLinks = "recentLinks"
        static let selectedProfileID = "selectedProfileID"
        static let selectedPreset = "selectedPreset"
        static let selectedSubtitleLanguages = "selectedSubtitleLanguages"
    }

    @Published private(set) var inputURL = "" {
        didSet {
            guard inputURL != oldValue else { return }
            clearIntakeScopedState()
        }
    }
    @Published private(set) var candidate: DownloadCandidate?
    @Published private(set) var selectedFormatID: UUID?
    @Published private(set) var selectedPreset: OutputPreset = DownloadStore.loadSelectedPreset() {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: Defaults.selectedPreset)
            synchronizeProfileSelection()
        }
    }
    @Published private(set) var selectedProfileID = "custom"
    @Published private(set) var selectedSubtitleLanguages = UserDefaults.standard.string(forKey: Defaults.selectedSubtitleLanguages) ?? "all,-live_chat" {
        didSet {
            UserDefaults.standard.set(selectedSubtitleLanguages, forKey: Defaults.selectedSubtitleLanguages)
            synchronizeProfileSelection()
        }
    }
    @Published private(set) var includeSubtitles = UserDefaults.standard.object(forKey: Defaults.includeSubtitles) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(includeSubtitles, forKey: Defaults.includeSubtitles)
            synchronizeProfileSelection()
        }
    }
    @Published private(set) var useBrowserCookies = false
    @Published private(set) var destination = UserDefaults.standard.string(forKey: Defaults.destination) ?? "~/Downloads/CueFetch" {
        didSet {
            UserDefaults.standard.set(destination, forKey: Defaults.destination)
            synchronizeProfileSelection()
        }
    }
    @Published private(set) var recentLinks: [RecentLink] = DownloadStore.loadRecentLinks()
    @Published private(set) var toolStatus: ToolStatus
    @Published var isShowingSettings = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var downloadProgress = 0.0
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var lastCommandPreview = ""
    @Published private(set) var lastErrorMessage = ""
    @Published private(set) var pendingIntakeWarning: URLIntakeResult?
    @Published private(set) var runState: DownloadRunState = .idle

    private let runner: any DownloadRunner
    private let analysisRunner: any AnalysisRunner
    private let now: () -> Date
    private let toolStatusProvider: () -> ToolStatus
    private let downloadedFileExists: @Sendable (String) -> Bool
    private var downloadTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var activeAnalysisID: UUID?

    init(
        runner: any DownloadRunner = ProcessDownloadRunner(),
        analysisRunner: any AnalysisRunner = ProcessAnalysisRunner(),
        now: @escaping () -> Date = Date.init,
        toolStatusProvider: @escaping () -> ToolStatus = ToolLocator.status,
        downloadedFileExists: @escaping @Sendable (String) -> Bool = { path in
            var isDirectory = ObjCBool(false)
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
        }
    ) {
        self.runner = runner
        self.analysisRunner = analysisRunner
        self.now = now
        self.toolStatusProvider = toolStatusProvider
        self.downloadedFileExists = downloadedFileExists
        self.toolStatus = toolStatusProvider()

        // Browser cookies and private link history are intentionally job/session scoped.
        UserDefaults.standard.removeObject(forKey: "useBrowserCookies")
        UserDefaults.standard.removeObject(forKey: Defaults.recentLinks)
        recentLinks = []
        synchronizeProfileSelection()
    }

    var selectedFormat: MediaFormat? {
        guard let candidate, let selectedFormatID else { return nil }
        return candidate.formats.first { $0.id == selectedFormatID }
    }

    var selectedProfile: DownloadProfile {
        DownloadProfile.profile(id: selectedProfileID) ?? DownloadProfile(
            id: "custom",
            name: "Custom settings",
            summary: "Current settings differ from a saved workflow",
            destination: destination,
            preset: selectedPreset,
            includeSubtitles: includeSubtitles,
            subtitleLanguages: selectedSubtitleLanguages
        )
    }

    var currentPlan: DownloadPlan? {
        if case let .running(run) = runState {
            return run.plan
        }

        guard let candidate, !candidate.formats.isEmpty else { return nil }
        if selectedPreset == .mp4FullHD,
           !candidate.formats.contains(where: { $0.kind == .video }) {
            return nil
        }
        return try? makeDownloadPlan(candidate: candidate, selectedFormat: selectedFormat)
    }

    var isDownloading: Bool {
        runState.isRunning
    }

    var lastDownloadedPath: String {
        runState.completedDownload?.filePath ?? ""
    }

    var canAnalyze: Bool {
        !inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isAnalyzing
            && !runState.isRunning
    }

    var canDownload: Bool {
        guard
            let candidate,
            !isDownloading,
            candidate.accessState == .available
                || (candidate.accessState == .cookiesRequired && useBrowserCookies),
            let plan = currentPlan
        else {
            return false
        }
        return plan.missingTools(in: toolStatus).isEmpty
    }

    var canCopyReceipt: Bool {
        runState.completedDownload != nil
    }

    func setInputURL(_ value: String) {
        guard !runState.isRunning else { return }
        inputURL = value
    }

    func setIncludeSubtitles(_ value: Bool) {
        guard !runState.isRunning else { return }
        includeSubtitles = value
        updateCommandPreview()
    }

    func setSubtitleLanguages(_ value: String) {
        guard !runState.isRunning else { return }
        selectedSubtitleLanguages = value
        updateCommandPreview()
    }

    func setUseBrowserCookies(_ value: Bool) {
        guard !runState.isRunning else { return }
        useBrowserCookies = value
        updateCommandPreview()
        if candidate != nil {
            statusMessage = analysisReadinessStatus()
        }
    }

    func setDestination(_ value: String) {
        guard !runState.isRunning else { return }
        destination = value
        updateCommandPreview()
    }

    func refreshToolStatus() {
        guard !runState.isRunning else { return }
        toolStatus = toolStatusProvider()
        statusMessage = candidate == nil
            ? (toolStatus.isYTDLPInstalled ? "Using yt-dlp \(toolStatus.ytdlpVersion ?? "")" : "yt-dlp not found")
            : analysisReadinessStatus()
    }

    func selectRecent(_ link: RecentLink) {
        guard !runState.isRunning else { return }
        inputURL = link.url
        candidate = nil
        selectedFormatID = nil
        selectedSubtitleLanguages = "all,-live_chat"
        pendingIntakeWarning = nil
        lastErrorMessage = ""
        runState = .idle
        downloadProgress = 0
        statusMessage = "Link restored. Analyze to refresh details."
        updateCommandPreview()
    }

    func clearRecentLinks() {
        guard !runState.isRunning else { return }
        recentLinks.removeAll()
        UserDefaults.standard.removeObject(forKey: Defaults.recentLinks)
        statusMessage = "History cleared"
    }

    func applyProfile(_ profile: DownloadProfile) {
        guard !runState.isRunning else { return }
        destination = profile.destination
        selectPreset(profile.preset)
        includeSubtitles = profile.includeSubtitles
        selectedSubtitleLanguages = profile.subtitleLanguages
        selectedProfileID = profile.id
        UserDefaults.standard.set(profile.id, forKey: Defaults.selectedProfileID)
        updateCommandPreview()
        statusMessage = candidate == nil
            ? "Applied \(profile.name) profile"
            : analysisReadinessStatus()
    }

    func selectPreset(_ preset: OutputPreset) {
        guard !runState.isRunning else { return }
        selectedPreset = preset
        selectedFormatID = Self.defaultFormatID(for: candidate?.formats ?? [], preset: preset)
        updateCommandPreview()
        if candidate != nil {
            statusMessage = analysisReadinessStatus()
        }
    }

    func selectFormat(id: UUID) {
        guard !runState.isRunning else { return }
        guard candidate?.formats.contains(where: { $0.id == id }) == true else {
            return
        }
        selectedFormatID = id
        selectedPreset = .custom
        updateCommandPreview()
        statusMessage = analysisReadinessStatus()
    }

    func analyzeLink() {
        analyzeLink(confirmedURL: nil)
    }

    func analyzePrimaryIntakeURL() {
        guard !runState.isRunning else { return }
        guard let warning = pendingIntakeWarning else {
            analyzeLink()
            return
        }

        inputURL = warning.primaryURL
        analyzeLink(confirmedURL: warning.primaryURL)
    }

    func clearIntakeWarning() {
        guard !runState.isRunning else { return }
        pendingIntakeWarning = nil
        statusMessage = "Ready"
    }

    private func analyzeLink(confirmedURL: String?) {
        guard !runState.isRunning else { return }
        guard canAnalyze else {
            statusMessage = "Paste a link to analyze"
            return
        }

        let intake = URLIntakeAnalyzer.analyze(inputURL)
        if confirmedURL == nil, intake.requiresConfirmation {
            pendingIntakeWarning = intake
            statusMessage = intake.kind == .multipleLinks ? "Multiple links detected" : "Playlist detected"
            return
        }

        let rawURL = confirmedURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? intake.primaryURL
        guard let validatedURL = try? ValidatedMediaURL(rawURL) else {
            pendingIntakeWarning = nil
            candidate = nil
            selectedFormatID = nil
            statusMessage = "Enter a valid HTTP or HTTPS media link"
            lastErrorMessage = "CueFetch accepts one HTTP or HTTPS media URL at a time."
            updateCommandPreview()
            return
        }

        refreshToolStatus()
        guard let ytdlpPath = toolStatus.ytdlpPath else {
            statusMessage = "yt-dlp not found"
            lastErrorMessage = "Install yt-dlp with Homebrew or add it to PATH."
            return
        }

        analysisTask?.cancel()
        isAnalyzing = true
        let analysisID = UUID()
        activeAnalysisID = analysisID
        pendingIntakeWarning = nil
        lastErrorMessage = ""
        runState = .idle
        downloadProgress = 0
        statusMessage = "Analyzing link..."

        let arguments = YTDLPCommandBuilder.analyzeArguments(
            for: validatedURL,
            useBrowserCookies: useBrowserCookies
        )

        let request = AnalysisExecutionRequest(
            executablePath: ytdlpPath,
            arguments: arguments,
            environment: ToolLocator.processEnvironment(),
            timeout: 60
        )
        let analysisRunner = analysisRunner
        analysisTask = Task {
            do {
                let data = try await analysisRunner.capture(request)
                let metadata = try YTDLPMetadataParser.parse(data)
                let mapped = YTDLPMetadataMapper.candidate(from: metadata, fallbackURL: validatedURL.string)

                guard activeAnalysisID == analysisID else { return }
                activeAnalysisID = nil
                analysisTask = nil
                applyAnalysisResult(mapped)
                isAnalyzing = false
                updateCommandPreview()
            } catch {
                guard activeAnalysisID == analysisID else { return }
                activeAnalysisID = nil
                analysisTask = nil
                isAnalyzing = false
                candidate = nil
                selectedFormatID = nil
                pendingIntakeWarning = nil
                let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                statusMessage = Self.statusMessage(forAnalysisError: message)
                lastErrorMessage = message
                updateCommandPreview()
            }
        }
    }

    func retryAnalysis() {
        analyzeLink()
    }

    func retryAnalysisWithCookies() {
        guard !runState.isRunning else { return }
        useBrowserCookies = true
        statusMessage = "Retrying with Safari cookies..."
        analyzeLink()
    }

    func addCookies() {
        guard !runState.isRunning else { return }
        useBrowserCookies = true
        candidate?.accessState = .available
        statusMessage = "Safari cookies enabled for this download"
        updateCommandPreview()
    }

    func applyAnalysisResult(_ result: DownloadCandidate) {
        guard !runState.isRunning else { return }
        candidate = result
        selectedFormatID = Self.defaultFormatID(for: result.formats, preset: selectedPreset)
        prependRecent(from: result)
        runState = .idle
        downloadProgress = 0
        lastErrorMessage = ""
        statusMessage = analysisReadinessStatus()
    }

    func startDownload() {
        guard !isDownloading else { return }
        refreshToolStatus()
        guard canDownload else {
            statusMessage = candidate == nil
                ? "Analyze a link before downloading"
                : analysisReadinessStatus()
            return
        }

        guard let candidate else {
            statusMessage = "Analyze a link before downloading"
            return
        }
        guard let ytdlpPath = toolStatus.ytdlpPath else {
            statusMessage = "yt-dlp not found"
            lastErrorMessage = "Install yt-dlp with Homebrew or add it to PATH."
            return
        }

        runState = .idle
        downloadProgress = 0
        lastErrorMessage = ""

        do {
            let plan = try makeDownloadPlan(candidate: candidate, selectedFormat: selectedFormat)
            try plan.validateTools(against: toolStatus)
            var arguments = YTDLPCommandBuilder.downloadArguments(for: plan)
            arguments = YTDLPOutputContract.argumentsReportingFinalPath(arguments)
            let run = DownloadRunSnapshot(
                id: UUID(),
                candidate: candidate,
                plan: plan,
                executablePath: ytdlpPath,
                arguments: arguments,
                ytdlpVersion: toolStatus.ytdlpVersion,
                startedAt: now()
            )

            runState = .running(run)
            downloadProgress = 0
            lastErrorMessage = ""
            statusMessage = "Preparing download..."
            lastCommandPreview = ShellCommandRenderer.render(
                executable: ytdlpPath,
                arguments: arguments
            )

            try FileManager.default.createDirectory(
                atPath: plan.destination,
                withIntermediateDirectories: true
            )

            execute(run)
        } catch {
            if case let .running(run) = runState {
                runState = .failed(FailedDownload(
                    run: run,
                    message: error.localizedDescription,
                    exitCode: nil,
                    failedAt: now()
                ))
            }
            statusMessage = "Could not prepare download"
            lastErrorMessage = error.localizedDescription
            resetBrowserCookiesAndPreview()
        }
    }

    func cancelDownload() {
        guard case let .running(run) = runState else { return }
        runState = .cancelled(CancelledDownload(run: run, cancelledAt: now()))
        downloadTask?.cancel()
        downloadTask = nil
        resetBrowserCookiesAndPreview()
        statusMessage = "Download cancelled"
    }

    func chooseDestination() {
        guard !runState.isRunning else { return }
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
        guard let completed = runState.completedDownload else {
            openDestinationFolder()
            return
        }

        guard FileManager.default.fileExists(atPath: completed.filePath) else {
            statusMessage = "Downloaded file is no longer at the recorded path"
            lastErrorMessage = "CueFetch recorded \(completed.filePath), but that file could not be found."
            openDestinationFolder()
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: completed.filePath)])
    }

    func copyDownloadReceipt() {
        guard let completed = runState.completedDownload else {
            statusMessage = "No completed download receipt is available"
            return
        }
        let receipt = DownloadReceiptRenderer.render(
            completed
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(receipt, forType: .string)
        statusMessage = "Download receipt copied"
    }

    func updateCommandPreview() {
        guard candidate != nil else {
            lastCommandPreview = "Analyze a link to preview the yt-dlp command."
            return
        }

        guard let plan = currentPlan else {
            lastCommandPreview = "Choose an available format or preset to preview the command."
            return
        }

        let arguments = YTDLPCommandBuilder.downloadArguments(for: plan)
        lastCommandPreview = ShellCommandRenderer.render(
            executable: toolStatus.ytdlpPath ?? "yt-dlp",
            arguments: arguments
        )
    }

    private var expandedDestination: String {
        (destination as NSString).expandingTildeInPath
    }

    private func makeDownloadPlan(
        candidate: DownloadCandidate,
        selectedFormat: MediaFormat?
    ) throws -> DownloadPlan {
        try DownloadPlan(
            url: ValidatedMediaURL(candidate.url),
            destination: expandedDestination,
            preset: selectedPreset,
            selectedFormat: selectedFormat,
            includeSubtitles: includeSubtitles,
            subtitleLanguages: selectedSubtitleLanguages,
            useBrowserCookies: useBrowserCookies
        )
    }

    private func execute(_ run: DownloadRunSnapshot) {
        let request = DownloadExecutionRequest(
            runID: run.id,
            executablePath: run.executablePath,
            arguments: run.arguments,
            environment: ToolLocator.processEnvironment()
        )
        let runner = runner
        let accumulator = DownloadOutputAccumulator()

        statusMessage = "Download started"
        downloadTask = Task { [weak self] in
            let result = await runner.run(request) { [weak self] event in
                let snapshot = accumulator.consume(event)
                Task { @MainActor [weak self] in
                    self?.handleOutputSnapshot(snapshot, runID: run.id)
                }
            }

            guard let self else { return }
            finishExecution(run: run, result: result, output: accumulator.finish())
        }
    }

    private func handleOutputSnapshot(_ snapshot: DownloadOutputSnapshot, runID: UUID) {
        guard case let .running(run) = runState, run.id == runID else {
            return
        }

        if let progress = snapshot.progress {
            downloadProgress = progress
            statusMessage = "Downloading \(Int(progress * 100))%"
        }
        if let latestError = snapshot.latestError {
            lastErrorMessage = latestError
        }
    }

    private func finishExecution(
        run: DownloadRunSnapshot,
        result: DownloadRunnerResult,
        output: DownloadOutputSnapshot
    ) {
        guard case let .running(activeRun) = runState, activeRun.id == run.id else {
            return
        }

        downloadTask = nil
        switch result {
        case let .exited(code) where code == 0:
            guard let finalPath = output.finalPath else {
                fail(
                    run,
                    message: "yt-dlp exited successfully but did not report the final file path.",
                    exitCode: code
                )
                return
            }
            guard downloadedFileExists(finalPath) else {
                fail(
                    run,
                    message: "yt-dlp reported success, but the downloaded file was not found at the final path.",
                    exitCode: code
                )
                return
            }

            let completed = CompletedDownload(
                run: run,
                filePath: finalPath,
                completedAt: now()
            )
            runState = .succeeded(completed)
            downloadProgress = 1
            lastErrorMessage = ""
            statusMessage = "Download completed"
            resetBrowserCookiesAndPreview()
        case let .exited(code):
            fail(
                run,
                message: output.latestError ?? "yt-dlp exited with status \(code).",
                exitCode: code
            )
        case .cancelled:
            runState = .cancelled(CancelledDownload(run: run, cancelledAt: now()))
            statusMessage = "Download cancelled"
            resetBrowserCookiesAndPreview()
        case let .launchFailed(message):
            fail(run, message: message, exitCode: nil)
        }
    }

    private func fail(_ run: DownloadRunSnapshot, message: String, exitCode: Int32?) {
        runState = .failed(FailedDownload(
            run: run,
            message: message,
            exitCode: exitCode,
            failedAt: now()
        ))
        lastErrorMessage = message
        statusMessage = "Download failed"
        resetBrowserCookiesAndPreview()
    }

    private func clearIntakeScopedState() {
        analysisTask?.cancel()
        analysisTask = nil
        activeAnalysisID = nil
        isAnalyzing = false
        useBrowserCookies = false
        candidate = nil
        selectedFormatID = nil
        pendingIntakeWarning = nil
        lastErrorMessage = ""
        runState = .idle
        downloadProgress = 0
        statusMessage = "Ready to analyze"
        lastCommandPreview = "Analyze a link to preview the yt-dlp command."
    }

    private func synchronizeProfileSelection() {
        let currentDestination = expandedDestination
        let matchingProfile = DownloadProfile.all.first { profile in
            (profile.destination as NSString).expandingTildeInPath == currentDestination
                && profile.preset == selectedPreset
                && profile.includeSubtitles == includeSubtitles
                && profile.subtitleLanguages == selectedSubtitleLanguages
        }

        selectedProfileID = matchingProfile?.id ?? "custom"
        if let matchingProfile {
            UserDefaults.standard.set(matchingProfile.id, forKey: Defaults.selectedProfileID)
        } else {
            UserDefaults.standard.removeObject(forKey: Defaults.selectedProfileID)
        }
    }

    func openBundledLegalDocument(named name: String) {
        let resourceNames = [
            "LICENSE": "LICENSE",
            "NOTICE": "NOTICE",
            "THIRD_PARTY_NOTICES": "THIRD_PARTY_NOTICES.md",
            "THIRD_PARTY_NOTICES.md": "THIRD_PARTY_NOTICES.md"
        ]
        guard let resourceName = resourceNames[name] else {
            statusMessage = "Unknown legal document"
            return
        }

        let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("Legal", isDirectory: true)
            .appendingPathComponent(resourceName)
        guard let resourceURL, FileManager.default.fileExists(atPath: resourceURL.path) else {
            statusMessage = "\(name) is not included in this build"
            return
        }

        NSWorkspace.shared.open(resourceURL)
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
        persistRecentLinks()
    }

    private static func loadRecentLinks() -> [RecentLink] {
        []
    }

    private static func loadSelectedPreset() -> OutputPreset {
        guard let rawValue = UserDefaults.standard.string(forKey: Defaults.selectedPreset),
              let preset = OutputPreset(rawValue: rawValue)
        else {
            let profileID = UserDefaults.standard.string(forKey: Defaults.selectedProfileID)
            return profileID.flatMap(DownloadProfile.profile(id:))?.preset ?? DownloadProfile.all[0].preset
        }
        return preset
    }

    private static func defaultFormatID(for formats: [MediaFormat], preset: OutputPreset) -> UUID? {
        switch preset {
        case .mp4FullHD, .audioOnly:
            return nil
        case .custom:
            return formats.first?.id
        case .bestVideo:
            return formats
                .filter { $0.kind == .video }
                .max { lhs, rhs in
                    if lhs.pixelCount != rhs.pixelCount {
                        return lhs.pixelCount < rhs.pixelCount
                    }
                    if lhs.compatibilityKind != rhs.compatibilityKind {
                        return lhs.compatibilityKind == .requiresConversion
                    }
                    return lhs.quality.localizedStandardCompare(rhs.quality) == .orderedAscending
                }?
                .id
        }
    }

    private func resetBrowserCookiesAndPreview() {
        useBrowserCookies = false
        updateCommandPreview()
    }

    private func analysisReadinessStatus() -> String {
        guard let candidate else { return "Ready" }
        switch candidate.accessState {
        case .available:
            break
        case .cookiesRequired where useBrowserCookies:
            break
        case .cookiesRequired:
            return "Safari cookies required for this link"
        case .unsupported:
            return "This link is not supported"
        case .drmProtected:
            return "DRM-protected media cannot be downloaded"
        }
        guard !candidate.formats.isEmpty else {
            return "No downloadable formats found"
        }
        guard let plan = currentPlan else {
            return "Choose an available format or preset"
        }

        let missing = plan.missingTools(in: toolStatus)
        if missing.contains(.ytDLP) {
            return "yt-dlp not found"
        }
        if missing.contains(.ffmpeg) {
            return "FFmpeg required for this preset"
        }
        return "Ready to download"
    }

    private func persistRecentLinks() {
        UserDefaults.standard.removeObject(forKey: Defaults.recentLinks)
    }

    private static func statusMessage(forAnalysisError error: String) -> String {
        DownloadErrorClassifier.analysisStatusMessage(for: error)
    }

}
