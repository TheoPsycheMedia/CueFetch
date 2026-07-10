import AppKit
import CueFetchCore
import Testing
@testable import CueFetch

@Suite("UI state contracts", .serialized)
struct UIStateContractTests {
    @Test("Main window has one minimum-size contract")
    func minimumWindowSize() {
        let minimum = CueFetchWindowMetrics.minimumContentSize

        #expect(minimum.width == 960)
        #expect(minimum.height == 660)
        #expect(CueFetchWindowMetrics.preferredContentSize.width >= minimum.width)
        #expect(CueFetchWindowMetrics.preferredContentSize.height >= minimum.height)
    }

    @Test("Minimum-size check rejects either undersized dimension")
    func minimumWindowBoundary() {
        #expect(!CueFetchWindowMetrics.isBelowMinimum(NSSize(width: 960, height: 660)))
        #expect(CueFetchWindowMetrics.isBelowMinimum(NSSize(width: 959, height: 660)))
        #expect(CueFetchWindowMetrics.isBelowMinimum(NSSize(width: 960, height: 659)))
    }

    @Test("Active download locks link intake controls")
    func downloadLocksLinkIntake() {
        let state = DownloadInputControlState(
            hasAnalyzableInput: true,
            isAnalyzing: false,
            isDownloading: true
        )

        #expect(!state.isURLInputEnabled)
        #expect(!state.isAnalyzeEnabled)
        #expect(!state.isRecentSelectionEnabled)
    }

    @Test("Analyze requires nonempty idle input")
    func analyzeAvailability() {
        let ready = DownloadInputControlState(
            hasAnalyzableInput: true,
            isAnalyzing: false,
            isDownloading: false
        )
        let analyzing = DownloadInputControlState(
            hasAnalyzableInput: true,
            isAnalyzing: true,
            isDownloading: false
        )
        let empty = DownloadInputControlState(
            hasAnalyzableInput: false,
            isAnalyzing: false,
            isDownloading: false
        )

        #expect(ready.isURLInputEnabled)
        #expect(ready.isAnalyzeEnabled)
        #expect(!analyzing.isAnalyzeEnabled)
        #expect(!empty.isAnalyzeEnabled)
    }

    @Test("Missing yt-dlp leaves analysis in a truthful blocked state")
    @MainActor
    func missingYTDLPBlocksAnalysis() {
        let store = DownloadStore(
            analysisRunner: FixedAnalysisRunner(data: Data()),
            toolStatusProvider: {
                ToolStatus(ytdlpPath: nil, ytdlpVersion: nil, ffmpegPath: nil)
            }
        )

        store.setInputURL("https://example.com/video")
        store.analyzeLink()

        #expect(!store.isAnalyzing)
        #expect(store.candidate == nil)
        #expect(store.statusMessage == "yt-dlp not found")
        #expect(store.lastErrorMessage.contains("Install yt-dlp"))
    }

    @Test("Metadata without formats cannot enter a downloadable state")
    @MainActor
    func metadataWithoutFormatsStaysBlocked() async {
        let metadata = Data(
            #"{"title":"Unavailable item","webpage_url":"https://example.com/video","formats":[]}"#.utf8
        )
        let store = DownloadStore(
            analysisRunner: FixedAnalysisRunner(data: metadata),
            toolStatusProvider: {
                ToolStatus(
                    ytdlpPath: "/test/yt-dlp",
                    ytdlpVersion: "test",
                    ffmpegPath: "/test/ffmpeg"
                )
            }
        )

        store.setInputURL("https://example.com/video")
        store.analyzeLink()
        for _ in 0..<100 where store.isAnalyzing {
            await Task.yield()
        }

        #expect(store.candidate?.formats.isEmpty == true)
        #expect(store.currentPlan == nil)
        #expect(!store.canDownload)
        #expect(store.statusMessage == "No downloadable formats found")
    }

    @Test("Tool readiness follows the effective operation")
    @MainActor
    func toolReadinessMatchesPlan() {
        let direct = MediaFormat(
            quality: "360p",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC",
            estimatedSize: "-",
            subtitles: false,
            compatibilityKind: .quickTime,
            selection: .video(formatSelector: "18", mergeOutputFormat: nil),
            pixelWidth: 640,
            pixelHeight: 360
        )
        let candidate = DownloadCandidate(
            title: "Progressive clip",
            url: "https://example.com/progressive",
            domain: "example.com",
            duration: "1:00",
            published: "Today",
            thumbnailName: "",
            site: .generic,
            accessState: .available,
            formats: [direct]
        )
        let store = DownloadStore(
            analysisRunner: FixedAnalysisRunner(data: Data()),
            toolStatusProvider: {
                ToolStatus(
                    ytdlpPath: "/test/yt-dlp",
                    ytdlpVersion: "test",
                    ffmpegPath: nil
                )
            }
        )

        store.applyAnalysisResult(candidate)
        store.selectFormat(id: direct.id)
        #expect(store.canDownload)
        #expect(store.statusMessage == "Ready to download")

        store.selectPreset(.mp4FullHD)
        #expect(!store.canDownload)
        #expect(store.statusMessage == "FFmpeg required for this preset")
    }

    @Test("Cookie-required media is blocked until the user opts in for the job")
    @MainActor
    func cookieRequiredMediaNeedsJobScopedOptIn() {
        let format = MediaFormat(
            quality: "360p",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC",
            estimatedSize: "-",
            subtitles: false,
            compatibilityKind: .quickTime,
            selection: .video(formatSelector: "18", mergeOutputFormat: nil)
        )
        let candidate = DownloadCandidate(
            title: "Private clip",
            url: "https://example.com/private",
            domain: "example.com",
            duration: "1:00",
            published: "Today",
            thumbnailName: "",
            site: .generic,
            accessState: .cookiesRequired,
            formats: [format]
        )
        let store = DownloadStore(
            analysisRunner: FixedAnalysisRunner(data: Data()),
            toolStatusProvider: {
                ToolStatus(
                    ytdlpPath: "/test/yt-dlp",
                    ytdlpVersion: "test",
                    ffmpegPath: nil
                )
            }
        )

        store.applyAnalysisResult(candidate)
        store.selectFormat(id: format.id)
        #expect(!store.canDownload)
        #expect(store.statusMessage == "Safari cookies required for this link")

        store.setUseBrowserCookies(true)
        #expect(store.canDownload)
        #expect(store.statusMessage == "Ready to download")
    }
}

private struct FixedAnalysisRunner: AnalysisRunner {
    let data: Data

    func capture(_ request: AnalysisExecutionRequest) async throws -> Data {
        data
    }
}
