import Testing
@testable import CueFetchCore

struct YTDLPCommandBuilderTests {
    @Test func fullHDPresetBuildsStrictQuickTimeArgumentsAndIgnoresSelected4KFormat() throws {
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/watch/123"),
            destination: "/tmp/CueFetch",
            preset: .mp4FullHD,
            selectedFormat: DefaultMediaFormats.all[0],
            includeSubtitles: true,
            useBrowserCookies: true
        )

        let arguments = YTDLPCommandBuilder.downloadArguments(for: plan)
        let formatSelector = try argument(after: "--format", in: arguments)

        #expect(formatSelector.contains("[height<=1080]"))
        #expect(!formatSelector.contains("2160"))
        #expect(formatSelector.contains("[vcodec^=avc1]"))
        #expect(formatSelector.contains("[acodec^=mp4a.40.]"))
        #expect(!formatSelector.contains("+ba[ext=m4a]/"))
        #expect(arguments.contains("--write-subs"))
        #expect(arguments.contains("--cookies-from-browser"))
    }

    @Test func selectedBestVideoUsesItsExactTypedSelection() throws {
        let selectedFormat = MediaFormat(
            quality: "1080p (Full HD)",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC",
            estimatedSize: "~ 44 MB",
            subtitles: false,
            compatibilityKind: .quickTime,
            selection: .video(
                formatSelector: "137+ba[ext=m4a][acodec^=mp4a.40.]",
                mergeOutputFormat: "mp4"
            )
        )
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/watch/123"),
            destination: "/tmp/CueFetch",
            preset: .bestVideo,
            selectedFormat: selectedFormat,
            includeSubtitles: false,
            useBrowserCookies: false
        )

        let arguments = YTDLPCommandBuilder.downloadArguments(for: plan)

        #expect(try argument(after: "--format", in: arguments) == "137+ba[ext=m4a][acodec^=mp4a.40.]")
        #expect(try argument(after: "--merge-output-format", in: arguments) == "mp4")
    }

    @Test func audioOnlyPresetUsesExplicitBestAudioTranscode() throws {
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/audio"),
            destination: "/tmp/CueFetch",
            preset: .audioOnly,
            selectedFormat: DefaultMediaFormats.all[0],
            includeSubtitles: false,
            useBrowserCookies: false
        )

        let arguments = YTDLPCommandBuilder.downloadArguments(for: plan)

        #expect(try argument(after: "--format", in: arguments) == "bestaudio")
        #expect(arguments.contains("--extract-audio"))
        #expect(try argument(after: "--audio-format", in: arguments) == "m4a")
        #expect(!arguments.contains("--write-subs"))
    }

    @Test func downloadArgumentsUseDeterministicSingleItemBoundaryAndFinalPathMarker() throws {
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/watch?v=123&list=PL456"),
            destination: "/tmp/CueFetch",
            preset: .mp4FullHD,
            includeSubtitles: false,
            useBrowserCookies: false
        )

        let arguments = YTDLPCommandBuilder.downloadArguments(for: plan)
        let terminatorIndex = try #require(arguments.lastIndex(of: "--"))

        #expect(arguments.first == "--ignore-config")
        #expect(arguments.contains("--no-playlist"))
        #expect(try argument(after: "--print", in: arguments) == "after_move:__CUEFETCH_FINAL_PATH__:%(filepath)s")
        #expect(terminatorIndex == arguments.count - 2)
        #expect(arguments[arguments.index(after: terminatorIndex)] == plan.url.string)
        #expect(arguments.last == plan.url.string)
    }

    @Test func subtitleLanguagesUseSelectedLanguageList() throws {
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/watch/123"),
            destination: "/tmp/CueFetch",
            preset: .mp4FullHD,
            includeSubtitles: true,
            subtitleLanguages: "en,es",
            useBrowserCookies: false
        )

        let arguments = YTDLPCommandBuilder.downloadArguments(for: plan)

        #expect(try argument(after: "--sub-langs", in: arguments) == "en,es")
    }

    @Test func analyzeArgumentsAreReadOnlyDeterministicAndSingleItem() throws {
        let url = try ValidatedMediaURL("https://example.com/video")
        let arguments = YTDLPCommandBuilder.analyzeArguments(for: url)
        let terminatorIndex = try #require(arguments.lastIndex(of: "--"))

        #expect(arguments.first == "--ignore-config")
        #expect(arguments.contains("--dump-single-json"))
        #expect(arguments.contains("--skip-download"))
        #expect(arguments.contains("--no-playlist"))
        #expect(!arguments.contains("--cookies-from-browser"))
        #expect(arguments[arguments.index(after: terminatorIndex)] == url.string)
        #expect(arguments.last == url.string)
    }

    @Test func analyzeArgumentsCanUseSafariCookiesBeforeTheOptionTerminator() throws {
        let url = try ValidatedMediaURL("https://example.com/private-video")
        let arguments = YTDLPCommandBuilder.analyzeArguments(for: url, useBrowserCookies: true)
        let cookieIndex = try #require(arguments.firstIndex(of: "--cookies-from-browser"))
        let terminatorIndex = try #require(arguments.lastIndex(of: "--"))

        #expect(arguments[arguments.index(after: cookieIndex)] == "safari")
        #expect(cookieIndex < terminatorIndex)
    }

    private func argument(after flag: String, in arguments: [String]) throws -> String {
        let index = try #require(arguments.firstIndex(of: flag))
        return arguments[arguments.index(after: index)]
    }
}
