import Testing
@testable import CueFetchCore

struct YTDLPCommandBuilderTests {
    @Test func fullHDPresetBuildsQuickTimeFriendlyMP4Arguments() {
        let options = DownloadOptions(
            url: "https://example.com/watch/123",
            destination: "/tmp/CueFetch",
            preset: .mp4FullHD,
            format: DefaultMediaFormats.all[1],
            includeSubtitles: true,
            useBrowserCookies: true
        )

        let arguments = YTDLPCommandBuilder.downloadArguments(for: options)

        #expect(arguments.contains("--merge-output-format"))
        #expect(arguments.contains("mp4"))
        #expect(arguments.contains("--write-subs"))
        #expect(arguments.contains("--cookies-from-browser"))
        #expect(arguments.last == "https://example.com/watch/123")
    }

    @Test func audioOnlyPresetUsesExtractAudio() {
        let options = DownloadOptions(
            url: "https://example.com/audio",
            destination: "/tmp/CueFetch",
            preset: .audioOnly,
            format: DefaultMediaFormats.all[4],
            includeSubtitles: false,
            useBrowserCookies: false
        )

        let arguments = YTDLPCommandBuilder.downloadArguments(for: options)

        #expect(arguments.contains("--extract-audio"))
        #expect(arguments.contains("--audio-format"))
        #expect(!arguments.contains("--write-subs"))
        #expect(!arguments.contains("--cookies-from-browser"))
    }

    @Test func analyzeArgumentsStayReadOnly() {
        let arguments = YTDLPCommandBuilder.analyzeArguments(for: "https://example.com/video")

        #expect(arguments.contains("--dump-single-json"))
        #expect(arguments.contains("--skip-download"))
        #expect(arguments.last == "https://example.com/video")
    }
}
