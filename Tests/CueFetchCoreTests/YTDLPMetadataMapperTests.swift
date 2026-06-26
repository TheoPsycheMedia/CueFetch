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
          "automatic_captions": {"en": [{"ext": "vtt", "url": "https://example.com/subs.vtt"}]},
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
        #expect(candidate.formats.contains { $0.quality.contains("1080p") })
        #expect(candidate.formats.contains { $0.isAudioOnly })
    }
}
