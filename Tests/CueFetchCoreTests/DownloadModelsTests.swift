import Foundation
import Testing
@testable import CueFetchCore

struct DownloadModelsTests {
    @Test func outputPresetSubtitlesDescribeTheEffectiveOperation() {
        #expect(OutputPreset.bestVideo.subtitle == "Highest resolution")
        #expect(OutputPreset.mp4FullHD.subtitle == "H.264 + AAC")
        #expect(OutputPreset.audioOnly.subtitle == "M4A audio")
        #expect(OutputPreset.custom.subtitle == "Choose a format")
    }

    @Test func builtInDownloadProfilesCoverCoreWorkflows() {
        let profiles = DownloadProfile.all

        #expect(profiles.map(\.id) == ["editing", "audio", "archive", "short-clips"])
        #expect(profiles.contains { $0.preset == .audioOnly && !$0.includeSubtitles })
        #expect(profiles.contains { $0.preset == .bestVideo && $0.includeSubtitles })
        #expect(profiles.allSatisfy { $0.destination.hasPrefix("~/Downloads/CueFetch") })
        #expect(DownloadProfile.profile(id: "sermon-clips")?.id == "short-clips")
    }

    @Test func defaultQuickTimeSelectorsContainNoPermissiveAudioFallback() {
        let bounded = DefaultMediaFormats.quickTimeMP4Selector(maxHeight: 1080)
        let exact = DefaultMediaFormats.quickTimeMP4Selector(videoFormatID: "137")
        let audio = DefaultMediaFormats.all.first { $0.kind == .audio }

        #expect(bounded == "bv*[height<=1080][ext=mp4][vcodec^=avc1]+ba[ext=m4a][acodec^=mp4a.40.]/b[height<=1080][ext=mp4][vcodec^=avc1][acodec^=mp4a.40.]")
        #expect(exact == "137+ba[ext=m4a][acodec^=mp4a.40.]")
        #expect(audio?.selection.formatSelector == "ba[ext=m4a][acodec^=mp4a.40.]")
    }
}
