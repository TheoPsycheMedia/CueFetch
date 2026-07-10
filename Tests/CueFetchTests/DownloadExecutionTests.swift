import Foundation
import Testing
@testable import CueFetch
import CueFetchCore

@Suite(.serialized)
struct DownloadExecutionTests {
    @Test func processAnalysisRunnerCapturesStandardOutput() async throws {
        let runner = ProcessAnalysisRunner()
        let request = AnalysisExecutionRequest(
            executablePath: "/usr/bin/printf",
            arguments: ["{\"title\":\"captured\"}"],
            environment: [:],
            timeout: 1
        )

        let data = try await runner.capture(request)

        #expect(String(decoding: data, as: UTF8.self) == "{\"title\":\"captured\"}")
    }

    @Test func processAnalysisRunnerTerminatesAtTheTimeout() async {
        let runner = ProcessAnalysisRunner()
        let request = AnalysisExecutionRequest(
            executablePath: "/bin/sleep",
            arguments: ["1"],
            environment: [:],
            timeout: 0.02
        )

        do {
            _ = try await runner.capture(request)
            Issue.record("Expected the analysis process to time out")
        } catch let error as AnalysisRunnerError {
            #expect(error == .timedOut)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func cancellingAnalysisTerminatesTheRunningProcess() async throws {
        let runner = ProcessAnalysisRunner()
        let request = AnalysisExecutionRequest(
            executablePath: "/bin/sleep",
            arguments: ["5"],
            environment: [:],
            timeout: 60
        )
        let task = Task {
            try await runner.capture(request)
        }

        try await Task.sleep(for: .milliseconds(75))
        let cancellationStarted = ContinuousClock.now
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation to terminate analysis")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Unexpected cancellation error: \(error)")
        }

        #expect(cancellationStarted.duration(to: .now) < .seconds(1))
    }

    @Test func scriptedAnalysisRunnerRecordsTheExactRequest() async throws {
        let expected = Data("metadata".utf8)
        let runner = ScriptedAnalysisRunner(outcome: .success(expected))
        let request = AnalysisExecutionRequest(
            executablePath: "/test/yt-dlp",
            arguments: ["--dump-single-json", "--", "https://example.com/video"],
            environment: ["PATH": "/test"],
            timeout: 60
        )

        let data = try await runner.capture(request)

        #expect(data == expected)
        #expect(await runner.receivedRequests() == [request])
    }

    @Test @MainActor func storeIgnoresAnAnalysisResultAfterTheInputChanges() async {
        let analysisRunner = ScriptedAnalysisRunner(outcome: .suspendedSuccess(Self.metadataData))
        let downloadRunner = ScriptedDownloadRunner(
            script: .init(events: [], result: .exited(code: 0))
        )
        let store = DownloadStore(
            runner: downloadRunner,
            analysisRunner: analysisRunner,
            toolStatusProvider: {
                ToolStatus(ytdlpPath: "/test/yt-dlp", ytdlpVersion: "test", ffmpegPath: "/test/ffmpeg")
            }
        )

        store.setInputURL("https://example.com/first")
        store.analyzeLink()
        for _ in 0..<100 where await analysisRunner.receivedRequests().isEmpty {
            await Task.yield()
        }
        #expect(store.isAnalyzing)

        store.setInputURL("https://example.com/second")
        #expect(!store.isAnalyzing)
        #expect(store.candidate == nil)
        #expect(store.statusMessage == "Ready to analyze")

        await analysisRunner.resumeSuspendedCaptures()
        for _ in 0..<20 {
            await Task.yield()
        }

        #expect(store.candidate == nil)
        #expect(store.statusMessage == "Ready to analyze")
    }

    @Test @MainActor func storeCompletesOnlyFromTheExactFinalPathMarker() async {
        let expectedPath = "/tmp/CueFetchTests/Exact Final.mp4"
        let runner = ScriptedDownloadRunner(script: .init(
            events: [
                .standardOutput("[download] Destination: /tmp/CueFetchTests/wrong.mp4\n"),
                .standardOutput("__CUEFETCH_FINAL_PATH__:\(expectedPath)\n")
            ],
            result: .exited(code: 0)
        ))
        let store = makeStore(downloadRunner: runner)
        store.setDestination("/tmp/CueFetchTests")
        store.applyAnalysisResult(makeVideoCandidate())
        store.selectPreset(.mp4FullHD)

        store.startDownload()
        await waitForDownloadToFinish(store)

        #expect(store.lastDownloadedPath == expectedPath)
        guard case let .succeeded(completed) = store.runState else {
            Issue.record("Expected a succeeded run state")
            return
        }
        #expect(completed.filePath == expectedPath)
        #expect(completed.run.id == store.runState.runID)

        store.setInputURL("https://example.com/new-intake")
        #expect(store.runState == .idle)
        #expect(store.lastDownloadedPath.isEmpty)
        #expect(!store.canCopyReceipt)
    }

    @Test @MainActor func zeroExitWithoutFinalPathMarkerIsAFailedRun() async {
        let runner = ScriptedDownloadRunner(script: .init(
            events: [.standardOutput("[download] 100%\n")],
            result: .exited(code: 0)
        ))
        let store = makeStore(downloadRunner: runner)
        store.setDestination("/tmp/CueFetchTests")
        store.applyAnalysisResult(makeVideoCandidate())
        store.selectPreset(.mp4FullHD)

        store.startDownload()
        await waitForDownloadToFinish(store)

        guard case let .failed(failure) = store.runState else {
            Issue.record("Expected a failed run state")
            return
        }
        #expect(failure.message.contains("did not report the final file path"))
        #expect(store.lastDownloadedPath.isEmpty)
        #expect(!store.canCopyReceipt)
    }

    @Test @MainActor func zeroExitWithMissingReportedFileIsAFailedRun() async {
        let missingPath = "/tmp/CueFetchTests/missing.mp4"
        let runner = ScriptedDownloadRunner(script: .init(
            events: [.standardOutput("__CUEFETCH_FINAL_PATH__:\(missingPath)\n")],
            result: .exited(code: 0)
        ))
        let store = makeStore(downloadRunner: runner, downloadedFileExists: false)
        store.setDestination("/tmp/CueFetchTests")
        store.applyAnalysisResult(makeVideoCandidate())
        store.selectPreset(.mp4FullHD)

        store.startDownload()
        await waitForDownloadToFinish(store)

        guard case let .failed(failure) = store.runState else {
            Issue.record("Expected a missing output file to fail the run")
            return
        }
        #expect(failure.message.contains("file was not found"))
        #expect(store.lastDownloadedPath.isEmpty)
        #expect(!store.canCopyReceipt)
    }

    @Test @MainActor func cancellationIsTerminalAndCannotBecomeAFalseSuccess() async {
        let runner = ScriptedDownloadRunner(script: .init(
            events: [.standardOutput("[download] 25%\n")],
            result: .exited(code: 0),
            suspendUntilCancelled: true
        ))
        let store = makeStore(downloadRunner: runner)
        store.setDestination("/tmp/CueFetchTests")
        store.applyAnalysisResult(makeVideoCandidate())
        store.selectPreset(.mp4FullHD)
        store.setUseBrowserCookies(true)
        store.startDownload()
        for _ in 0..<100 where await runner.receivedRequests().isEmpty {
            await Task.yield()
        }

        let runningID = store.runState.runID
        store.cancelDownload()

        guard case let .cancelled(cancelled) = store.runState else {
            Issue.record("Expected a cancelled run state")
            return
        }
        #expect(cancelled.run.id == runningID)
        #expect(!store.isDownloading)
        #expect(store.lastDownloadedPath.isEmpty)
        #expect(!store.canCopyReceipt)
        #expect(!store.useBrowserCookies)
        #expect(!store.lastCommandPreview.contains("--cookies-from-browser"))

        for _ in 0..<20 {
            await Task.yield()
        }
        #expect(store.runState.runID == runningID)
        #expect(store.statusMessage == "Download cancelled")
    }

    @Test @MainActor func activeRunFreezesEveryPlanAffectingStoreControl() async {
        let runner = ScriptedDownloadRunner(script: .init(
            events: [.standardOutput("[download] 10%\n")],
            result: .exited(code: 0),
            suspendUntilCancelled: true
        ))
        let store = makeStore(downloadRunner: runner)
        store.setInputURL("https://example.com/original")
        store.setDestination("/tmp/CueFetchTests/original")
        store.applyAnalysisResult(makeVideoCandidate())
        store.selectPreset(.bestVideo)
        store.setIncludeSubtitles(true)
        store.setSubtitleLanguages("en")
        store.setUseBrowserCookies(true)
        store.startDownload()
        for _ in 0..<100 where await runner.receivedRequests().isEmpty {
            await Task.yield()
        }

        guard case let .running(activeRun) = store.runState else {
            Issue.record("Expected an active run")
            return
        }
        let selectedFormatID = store.selectedFormatID

        store.setInputURL("https://example.com/replacement")
        store.setDestination("/tmp/CueFetchTests/replacement")
        store.setIncludeSubtitles(false)
        store.setSubtitleLanguages("es")
        store.setUseBrowserCookies(false)
        store.selectPreset(.audioOnly)
        if let selectedFormatID {
            store.selectFormat(id: selectedFormatID)
        }
        store.applyProfile(DownloadProfile.all[1])
        store.selectRecent(RecentLink(
            title: "Replacement",
            domain: "example.com",
            dateLabel: "Now",
            thumbnailName: "",
            site: .generic,
            url: "https://example.com/recent"
        ))
        store.analyzeLink()

        #expect(store.inputURL == "https://example.com/original")
        #expect(store.destination == "/tmp/CueFetchTests/original")
        #expect(store.includeSubtitles)
        #expect(store.selectedSubtitleLanguages == "en")
        #expect(store.useBrowserCookies)
        #expect(store.selectedPreset == .bestVideo)
        #expect(store.selectedFormatID == selectedFormatID)
        #expect(store.currentPlan == activeRun.plan)
        #expect(store.runState == .running(activeRun))
        #expect((await runner.receivedRequests()).count == 1)

        store.cancelDownload()
    }

    @Test @MainActor func fixedPresetsDoNotHighlightIgnoredDetectedRows() {
        let store = makeStore(downloadRunner: ScriptedDownloadRunner(
            script: .init(events: [], result: .exited(code: 0))
        ))
        store.applyAnalysisResult(makeVideoCandidate())

        store.selectPreset(.mp4FullHD)
        #expect(store.selectedFormatID == nil)
        #expect(store.currentPlan?.effectiveSelection == .fixedQuickTimeMP4(maximumHeight: 1080))
        #expect(store.lastCommandPreview.contains("height<=1080"))

        store.selectPreset(.audioOnly)
        #expect(store.selectedFormatID == nil)
        #expect(store.currentPlan?.effectiveSelection == .fixedM4A)
        #expect(store.lastCommandPreview.contains("--extract-audio"))
    }

    @Test @MainActor func bestVideoSelectsTheHighestResolutionEvenWhenItNeedsConversion() {
        let h264 = MediaFormat(
            quality: "1080p (Full HD)",
            container: "MP4",
            videoCodec: "H.264",
            audio: "Separate audio",
            estimatedSize: "-",
            subtitles: false,
            compatibilityKind: .quickTime,
            selection: .video(
                formatSelector: "137+140",
                mergeOutputFormat: "mp4"
            ),
            pixelWidth: 1920,
            pixelHeight: 1080
        )
        let av1 = MediaFormat(
            quality: "2160p (4K)",
            container: "MP4",
            videoCodec: "AV1",
            audio: "Separate audio",
            estimatedSize: "-",
            subtitles: false,
            compatibilityKind: .requiresConversion,
            selection: .video(
                formatSelector: "401+bestaudio",
                mergeOutputFormat: "mp4"
            ),
            pixelWidth: 3840,
            pixelHeight: 2160
        )
        var candidate = makeVideoCandidate()
        candidate.formats = [h264, av1]
        let store = makeStore(downloadRunner: ScriptedDownloadRunner(
            script: .init(events: [], result: .exited(code: 0))
        ))

        store.applyAnalysisResult(candidate)
        store.selectPreset(.bestVideo)

        #expect(store.selectedFormatID == av1.id)
        #expect(store.currentPlan?.selectedFormat?.id == av1.id)
    }

    @Test func finalPathParserRequiresMachineReadableMarkerAndBuffersSplitChunks() {
        var parser = YTDLPOutputParser()

        parser.consumeStandardOutput(
            "[download] Destination: /tmp/__CUEFETCH_FINAL_PATH__:wrong.mp4\n__CUEFETCH_FINAL_"
        )
        #expect(parser.finalPath == nil)

        parser.consumeStandardOutput("PATH__:/tmp/Final Clip.mp4\n")

        #expect(parser.finalPath == "/tmp/Final Clip.mp4")
    }

    @Test func finalPathReportingArgumentsAreInsertedBeforeOptionTerminator() {
        let original = ["--ignore-config", "--", "https://example.com/watch?v=private"]

        let arguments = YTDLPOutputContract.argumentsReportingFinalPath(original)

        #expect(arguments == [
            "--ignore-config",
            "--print",
            "after_move:__CUEFETCH_FINAL_PATH__:%(filepath)s",
            "--",
            "https://example.com/watch?v=private"
        ])
    }

    @Test func receiptUsesOnlyCompletedRunSnapshotAndRedactsPrivateValues() throws {
        let runID = UUID(uuidString: "A1A1A1A1-A1A1-A1A1-A1A1-A1A1A1A1A1A1")!
        let format = MediaFormat(
            id: UUID(uuidString: "B2B2B2B2-B2B2-B2B2-B2B2-B2B2B2B2B2B2")!,
            quality: "1080p",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC",
            estimatedSize: "20 MB",
            subtitles: true,
            compatibilityKind: .quickTime,
            selection: .video(
                formatSelector: "137+140",
                mergeOutputFormat: "mp4"
            )
        )
        let candidate = DownloadCandidate(
            title: "Snapshot title",
            url: "https://example.com/watch?id=abc&token=super-secret",
            domain: "example.com",
            duration: "1:00",
            published: "Today",
            thumbnailName: "",
            site: .generic,
            accessState: .available,
            formats: [format]
        )
        let plan = try DownloadPlan(
            url: ValidatedMediaURL(candidate.url),
            destination: "/Users/tester/Downloads/CueFetch",
            preset: .custom,
            selectedFormat: format,
            includeSubtitles: true,
            subtitleLanguages: "en",
            useBrowserCookies: true
        )
        let run = DownloadRunSnapshot(
            id: runID,
            candidate: candidate,
            plan: plan,
            executablePath: "/opt/homebrew/bin/yt-dlp",
            arguments: [
                "--paths", "/Users/tester/Downloads/CueFetch",
                "--", candidate.url
            ],
            ytdlpVersion: "2026.07.10",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let completed = CompletedDownload(
            run: run,
            filePath: "/Users/tester/Downloads/CueFetch/Clip.mp4",
            completedAt: Date(timeIntervalSince1970: 1_700_000_060)
        )

        let receipt = DownloadReceiptRenderer.render(
            completed,
            homeDirectory: "/Users/tester"
        )

        #expect(receipt.contains("Run: \(runID.uuidString)"))
        #expect(receipt.contains("Title: Snapshot title"))
        #expect(receipt.contains("URL: https://example.com/watch?id=REDACTED&token=REDACTED"))
        #expect(receipt.contains("Downloaded file: ~/Downloads/CueFetch/Clip.mp4"))
        #expect(receipt.contains("yt-dlp executable: yt-dlp"))
        #expect(receipt.contains("yt-dlp: 2026.07.10"))
        #expect(!receipt.contains("super-secret"))
        #expect(!receipt.contains("/Users/tester"))
        #expect(!receipt.contains("/opt/homebrew/bin/yt-dlp"))
    }

    @Test func receiptDescribesFixed1080pPlanInsteadOfTheSelected4KRow() throws {
        let selected4K = DefaultMediaFormats.all[0]
        let candidate = DownloadCandidate(
            title: "Fixed preset",
            url: "https://example.com/video",
            domain: "example.com",
            duration: "1:00",
            published: "Today",
            thumbnailName: "",
            site: .generic,
            accessState: .available,
            formats: [selected4K]
        )
        let plan = try DownloadPlan(
            url: ValidatedMediaURL(candidate.url),
            destination: "/tmp/CueFetch",
            preset: .mp4FullHD,
            selectedFormat: selected4K,
            includeSubtitles: false,
            useBrowserCookies: false
        )
        let run = DownloadRunSnapshot(
            id: UUID(),
            candidate: candidate,
            plan: plan,
            executablePath: "/opt/homebrew/bin/yt-dlp",
            arguments: YTDLPCommandBuilder.downloadArguments(for: plan),
            ytdlpVersion: nil,
            startedAt: Date(timeIntervalSince1970: 10)
        )
        let completed = CompletedDownload(
            run: run,
            filePath: "/tmp/CueFetch/video.mp4",
            completedAt: Date(timeIntervalSince1970: 20)
        )

        let receipt = DownloadReceiptRenderer.render(completed)

        #expect(receipt.contains("Format: Up to 1080p MP4 - H.264 - AAC (fixed preset)"))
        #expect(!receipt.contains(selected4K.quality))
    }

    @Test func terminalStateCarriesTheSameImmutableRunID() throws {
        let run = try makeRun()
        let completed = CompletedDownload(
            run: run,
            filePath: "/tmp/final.mp4",
            completedAt: Date(timeIntervalSince1970: 20)
        )

        let state = DownloadRunState.succeeded(completed)

        #expect(state.runID == run.id)
        #expect(state.completedDownload == completed)
        #expect(!state.isRunning)
    }

    @Test func scriptedRunnerProducesDeterministicEventsAndRecordsRequest() async {
        let script = ScriptedDownloadRunner.Script(
            events: [
                .standardOutput("[download] 50%\n"),
                .standardOutput("__CUEFETCH_FINAL_PATH__:/tmp/final.mp4\n")
            ],
            result: .exited(code: 0)
        )
        let runner = ScriptedDownloadRunner(script: script)
        let request = DownloadExecutionRequest(
            runID: UUID(),
            executablePath: "/usr/bin/true",
            arguments: ["--version"],
            environment: [:]
        )
        let events = EventCollector()

        let result = await runner.run(request) { event in
            events.append(event)
        }

        #expect(result == .exited(code: 0))
        #expect(events.values == script.events)
        #expect(await runner.receivedRequests() == [request])
    }

    private func makeRun() throws -> DownloadRunSnapshot {
        let format = MediaFormat(
            quality: "Audio",
            container: "M4A",
            videoCodec: "None",
            audio: "AAC",
            estimatedSize: "5 MB",
            subtitles: false,
            compatibilityKind: .music,
            selection: .audio(formatSelector: "140")
        )
        let candidate = DownloadCandidate(
            title: "Clip",
            url: "https://example.com/clip",
            domain: "example.com",
            duration: "1:00",
            published: "Today",
            thumbnailName: "",
            site: .generic,
            accessState: .available,
            formats: [format]
        )
        let plan = try DownloadPlan(
            url: ValidatedMediaURL(candidate.url),
            destination: "/tmp",
            preset: .audioOnly,
            selectedFormat: format,
            includeSubtitles: false,
            useBrowserCookies: false
        )
        return DownloadRunSnapshot(
            id: UUID(),
            candidate: candidate,
            plan: plan,
            executablePath: "/usr/bin/true",
            arguments: ["--", candidate.url],
            ytdlpVersion: "test",
            startedAt: Date(timeIntervalSince1970: 10)
        )
    }

    @MainActor
    private func makeStore(
        downloadRunner: ScriptedDownloadRunner,
        downloadedFileExists: Bool = true
    ) -> DownloadStore {
        DownloadStore(
            runner: downloadRunner,
            analysisRunner: ScriptedAnalysisRunner(outcome: .failure(.timedOut)),
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            toolStatusProvider: {
                ToolStatus(
                    ytdlpPath: "/test/yt-dlp",
                    ytdlpVersion: "test",
                    ffmpegPath: "/test/ffmpeg"
                )
            },
            downloadedFileExists: { _ in downloadedFileExists }
        )
    }

    private func makeVideoCandidate() -> DownloadCandidate {
        let format = MediaFormat(
            quality: "1080p",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC",
            estimatedSize: "20 MB",
            subtitles: false,
            compatibilityKind: .quickTime,
            selection: .video(
                formatSelector: "137+140",
                mergeOutputFormat: "mp4"
            )
        )
        return DownloadCandidate(
            title: "Run-bound candidate",
            url: "https://example.com/video?id=private",
            domain: "example.com",
            duration: "1:00",
            published: "Today",
            thumbnailName: "",
            site: .generic,
            accessState: .available,
            formats: [format]
        )
    }

    @MainActor
    private func waitForDownloadToFinish(_ store: DownloadStore) async {
        for _ in 0..<100 {
            if !store.isDownloading { return }
            await Task.yield()
        }
        Issue.record("Download runner did not reach a terminal state")
    }

    private static let metadataData = Data(
        #"{"title":"Stale clip","webpage_url":"https://example.com/first","formats":[{"format_id":"137","ext":"mp4","height":1080,"width":1920,"vcodec":"avc1.640028","acodec":"none"}]}"#.utf8
    )
}

private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [DownloadRunnerEvent] = []

    var values: [DownloadRunnerEvent] {
        lock.withLock { storage }
    }

    func append(_ event: DownloadRunnerEvent) {
        lock.withLock {
            storage.append(event)
        }
    }
}
