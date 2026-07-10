import Foundation
import Testing
@testable import CueFetchCore

struct YTDLPMetadataMapperTests {
    @Test func mapsYouTubeMetadataIntoDownloadCandidate() throws {
        let json = """
        {
          "id": "o3B5k0q1QUw",
          "title": "Aleluya | Video Oficial Con Letras | Elevation Español y Unified Sound",
          "webpage_url": "https://www.youtube.com/watch?v=o3B5k0q1QUw",
          "duration_string": "4:08",
          "upload_date": "20240315",
          "thumbnail": "https://i.ytimg.com/vi/o3B5k0q1QUw/maxresdefault.jpg",
          "subtitles": {"es": [{"ext": "vtt", "url": "https://example.com/subs-es.vtt"}]},
          "automatic_captions": {
            "en": [{"ext": "vtt", "url": "https://example.com/subs.vtt"}],
            "live_chat": [{"ext": "json", "url": "https://example.com/live-chat.json"}]
          },
          "formats": [
            {"format_id": "18", "format_note": "360p", "ext": "mp4", "height": 360, "vcodec": "avc1.42001E", "acodec": "mp4a.40.2", "filesize": 5909717},
            {"format_id": "135", "format_note": "480p", "ext": "mp4", "height": 480, "vcodec": "avc1.4d401e", "acodec": "none", "filesize": 7816678},
            {"format_id": "137", "format_note": "1080p", "ext": "mp4", "height": 1080, "vcodec": "avc1.640028", "acodec": "none", "filesize": 44427794},
            {"format_id": "140", "format_note": "medium", "ext": "m4a", "vcodec": "none", "acodec": "mp4a.40.2", "abr": 129.5, "filesize": 4009319}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let metadata = try YTDLPMetadataParser.parse(data)
        let candidate = YTDLPMetadataMapper.candidate(from: metadata, fallbackURL: "https://youtu.be/o3B5k0q1QUw")

        #expect(candidate.title.contains("Aleluya"))
        #expect(candidate.domain == "youtube.com")
        #expect(candidate.duration == "4:08")
        #expect(candidate.site == .youtube)
        #expect(candidate.thumbnailURL?.contains("maxresdefault") == true)
        #expect(candidate.subtitleLanguages == ["en", "es"])
        #expect(candidate.formats.contains { $0.quality.contains("1080p") })
        #expect(candidate.formats.contains { $0.isAudioOnly })
    }

    @Test func sortsHighestResolutionFirstAndPreservesRealCodecTradeoffs() throws {
        let json = """
        {
          "id": "sample",
          "title": "Codec Stress Test",
          "webpage_url": "https://www.youtube.com/watch?v=sample",
          "duration_string": "2:00",
          "formats": [
            {"format_id": "400", "format_note": "1440p", "ext": "mp4", "height": 1440, "vcodec": "av01.0.12M.08", "acodec": "none", "tbr": 1048.0},
            {"format_id": "137", "format_note": "1080p", "ext": "mp4", "height": 1080, "vcodec": "avc1.640028", "acodec": "none", "tbr": 2461.0},
            {"format_id": "251", "format_note": "medium", "ext": "webm", "vcodec": "none", "acodec": "opus", "abr": 128.0},
            {"format_id": "140", "format_note": "medium", "ext": "m4a", "vcodec": "none", "acodec": "mp4a.40.2", "abr": 129.5}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let metadata = try YTDLPMetadataParser.parse(data)
        let candidate = YTDLPMetadataMapper.candidate(from: metadata, fallbackURL: "https://youtu.be/sample")
        let firstVideo = try #require(candidate.formats.first { !$0.isAudioOnly })

        #expect(firstVideo.quality == "1440p")
        #expect(firstVideo.container == "MP4")
        #expect(firstVideo.videoCodec == "AV1")
        #expect(firstVideo.compatibilityKind == .requiresConversion)
        #expect(firstVideo.selection.formatSelector == "400+bestaudio")
        #expect(firstVideo.selection.requiredTools == [.ytDLP, .ffmpeg])
        #expect(candidate.formats.contains { $0.videoCodec == "H.264" && $0.compatibilityKind == .quickTime })
    }

    @Test func mapsActualNonWhitelistedLandscapeAndVerticalDimensions() throws {
        let json = """
        {
          "id": "dimensions",
          "title": "Dimensions",
          "webpage_url": "https://example.com/dimensions",
          "formats": [
            {"format_id": "360", "ext": "mp4", "width": 640, "height": 360, "vcodec": "avc1.42001E", "acodec": "none"},
            {"format_id": "540", "ext": "mp4", "width": 960, "height": 540, "vcodec": "avc1.4d401f", "acodec": "none"},
            {"format_id": "vertical", "ext": "mp4", "width": 1080, "height": 1920, "vcodec": "avc1.64002a", "acodec": "none"},
            {"format_id": "140", "ext": "m4a", "vcodec": "none", "acodec": "mp4a.40.2"}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let metadata = try YTDLPMetadataParser.parse(data)
        let formats = YTDLPMetadataMapper.candidate(from: metadata, fallbackURL: "https://example.com/dimensions").formats

        #expect(formats.contains { $0.quality == "360p" })
        #expect(formats.contains { $0.quality == "540p" })
        #expect(formats.contains { $0.quality == "1080×1920 (Vertical)" })
    }

    @Test func analysisWithNoRealFormatsDoesNotFabricatePresetRows() throws {
        let json = """
        {
          "id": "empty",
          "title": "No formats",
          "webpage_url": "https://example.com/empty",
          "formats": []
        }
        """
        let data = try #require(json.data(using: .utf8))
        let metadata = try YTDLPMetadataParser.parse(data)
        let candidate = YTDLPMetadataMapper.candidate(from: metadata, fallbackURL: "https://example.com/empty")

        #expect(candidate.formats.isEmpty)
    }

    @Test func quickTimeRowsNeverFallBackToNonAACAudio() throws {
        let json = """
        {
          "id": "strict-audio",
          "title": "Strict audio",
          "webpage_url": "https://example.com/strict",
          "formats": [
            {"format_id": "137", "ext": "mp4", "width": 1920, "height": 1080, "vcodec": "avc1.640028", "acodec": "none"},
            {"format_id": "251", "ext": "webm", "vcodec": "none", "acodec": "opus"}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let metadata = try YTDLPMetadataParser.parse(data)
        let candidate = YTDLPMetadataMapper.candidate(from: metadata, fallbackURL: "https://example.com/strict")
        let video = try #require(candidate.formats.first { $0.kind == .video })

        #expect(video.compatibilityKind == .quickTime)
        #expect(video.selection.formatSelector == "137+ba[ext=m4a][acodec^=mp4a.40.]")
        #expect(!video.selection.formatSelector.contains("/"))
        #expect(!candidate.formats.contains { $0.kind == .audio })
    }

    @Test func embeddedNonAACAudioIsTypedAsRequiringConversion() throws {
        let json = """
        {
          "id": "opus-mp4",
          "title": "Opus in MP4",
          "webpage_url": "https://example.com/opus",
          "formats": [
            {"format_id": "bad", "ext": "mp4", "width": 1920, "height": 1080, "vcodec": "avc1.640028", "acodec": "opus"}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let metadata = try YTDLPMetadataParser.parse(data)
        let video = try #require(
            YTDLPMetadataMapper.candidate(from: metadata, fallbackURL: "https://example.com/opus").formats.first
        )

        #expect(video.compatibilityKind == .requiresConversion)
    }

    @Test func progressiveQuickTimeFormatDoesNotRequireFFmpeg() throws {
        let json = """
        {
          "id": "progressive",
          "title": "Progressive MP4",
          "webpage_url": "https://example.com/progressive",
          "formats": [
            {"format_id": "18", "ext": "mp4", "width": 640, "height": 360, "vcodec": "avc1.42001E", "acodec": "mp4a.40.2"}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let metadata = try YTDLPMetadataParser.parse(data)
        let video = try #require(
            YTDLPMetadataMapper.candidate(
                from: metadata,
                fallbackURL: "https://example.com/progressive"
            ).formats.first
        )

        #expect(video.selection.formatSelector == "18")
        #expect(video.selection.mergeOutputFormat == nil)
        #expect(video.selection.requiredTools == [.ytDLP])
    }
}
