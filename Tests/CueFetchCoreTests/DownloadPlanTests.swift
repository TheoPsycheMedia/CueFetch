import Testing
@testable import CueFetchCore

struct DownloadPlanTests {
    @Test func fixedPresetsExposeTheirEffectiveSelectionInsteadOfPretendingToUseTheRow() throws {
        let selected4K = DefaultMediaFormats.all[0]
        let url = try ValidatedMediaURL("https://example.com/video")

        let fullHD = try DownloadPlan(
            url: url,
            destination: "/tmp/CueFetch",
            preset: .mp4FullHD,
            selectedFormat: selected4K,
            includeSubtitles: false,
            useBrowserCookies: false
        )
        let audio = try DownloadPlan(
            url: url,
            destination: "/tmp/CueFetch",
            preset: .audioOnly,
            selectedFormat: selected4K,
            includeSubtitles: false,
            useBrowserCookies: false
        )

        #expect(fullHD.effectiveSelection == .fixedQuickTimeMP4(maximumHeight: 1080))
        #expect(fullHD.compatibility == .quickTime)
        #expect(audio.effectiveSelection == .fixedM4A)
        #expect(audio.compatibility == .music)
    }

    @Test func selectedPresetsExposeTheSelectedFormatsTypedCommandSelection() throws {
        let selected = DefaultMediaFormats.all[2]
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/video"),
            destination: "/tmp/CueFetch",
            preset: .bestVideo,
            selectedFormat: selected,
            includeSubtitles: false,
            useBrowserCookies: false
        )

        #expect(plan.effectiveSelection == .selectedFormat(selected.selection))
        #expect(plan.compatibility == selected.compatibilityKind)
    }

    @Test func selectedPresetRequiresASelectedVideoFormat() throws {
        let url = try ValidatedMediaURL("https://example.com/video")

        #expect(planError(url: url, selectedFormat: nil) == .missingSelectedFormat)
        #expect(planError(url: url, selectedFormat: DefaultMediaFormats.all.last) == .selectedVideoFormatRequired)
    }

    @Test func customPlanCarriesTypedConversionWarningWithoutReadingDisplayText() throws {
        let format = MediaFormat(
            quality: "1440p",
            container: "WEBM",
            videoCodec: "VP9",
            audio: "Opus",
            estimatedSize: "-",
            subtitles: false,
            compatibilityKind: .requiresConversion,
            selection: .video(
                formatSelector: "248+251",
                mergeOutputFormat: "webm"
            )
        )
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/video"),
            destination: "/tmp/CueFetch",
            preset: .custom,
            selectedFormat: format,
            includeSubtitles: false,
            useBrowserCookies: false
        )

        #expect(plan.compatibility == .requiresConversion)
        #expect(plan.effectiveSelection == .selectedFormat(format.selection))
    }

    @Test func plansReportMissingFFmpegWhenTheirEffectiveOperationRequiresIt() throws {
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/video"),
            destination: "/tmp/CueFetch",
            preset: .mp4FullHD,
            includeSubtitles: false,
            useBrowserCookies: false
        )
        let status = ToolStatus(
            ytdlpPath: "/opt/homebrew/bin/yt-dlp",
            ytdlpVersion: "2026.07.01",
            ffmpegPath: nil
        )

        #expect(plan.requiredTools == [.ytDLP, .ffmpeg])
        #expect(plan.missingTools(in: status) == [.ffmpeg])
        #expect(toolValidationError(for: plan, status: status) == .missingTools([.ffmpeg]))
        #expect(status.isYTDLPInstalled)
        #expect(!status.isFFmpegInstalled)
    }

    @Test func directProgressivePlanDoesNotRequireMissingFFmpeg() throws {
        let format = MediaFormat(
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
        let plan = try DownloadPlan(
            url: ValidatedMediaURL("https://example.com/video"),
            destination: "/tmp/CueFetch",
            preset: .custom,
            selectedFormat: format,
            includeSubtitles: false,
            useBrowserCookies: false
        )
        let status = ToolStatus(
            ytdlpPath: "/opt/homebrew/bin/yt-dlp",
            ytdlpVersion: "test",
            ffmpegPath: nil
        )

        #expect(plan.requiredTools == [.ytDLP])
        #expect(plan.missingTools(in: status).isEmpty)
    }

    private func planError(url: ValidatedMediaURL, selectedFormat: MediaFormat?) -> DownloadPlanError? {
        do {
            _ = try DownloadPlan(
                url: url,
                destination: "/tmp/CueFetch",
                preset: .bestVideo,
                selectedFormat: selectedFormat,
                includeSubtitles: false,
                useBrowserCookies: false
            )
            return nil
        } catch let error as DownloadPlanError {
            return error
        } catch {
            return nil
        }
    }

    private func toolValidationError(for plan: DownloadPlan, status: ToolStatus) -> DownloadPlanError? {
        do {
            try plan.validateTools(against: status)
            return nil
        } catch let error as DownloadPlanError {
            return error
        } catch {
            return nil
        }
    }
}
