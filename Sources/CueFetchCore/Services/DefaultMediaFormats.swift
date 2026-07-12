import Foundation

public enum DefaultMediaFormats {
    public static func quickTimeMP4Selector(maxHeight: Int) -> String {
        let video = "bv*[height<=\(maxHeight)][ext=mp4][vcodec^=avc1]"
        let audio = "ba[ext=m4a][acodec^=mp4a.40.]"
        let progressive = "b[height<=\(maxHeight)][ext=mp4][vcodec^=avc1][acodec^=mp4a.40.]"

        return "\(video)+\(audio)/\(progressive)"
    }

    public static func quickTimeMP4Selector(videoFormatID: String) -> String {
        "\(videoFormatID)+ba[ext=m4a][acodec^=mp4a.40.]"
    }

    public static let all: [MediaFormat] = [
        MediaFormat(
            quality: "2160p (4K)",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC 128 kbps",
            estimatedSize: "~ 1.45 GB",
            subtitles: true,
            compatibilityKind: .quickTime,
            selection: .video(
                formatSelector: quickTimeMP4Selector(maxHeight: 2160),
                mergeOutputFormat: "mp4"
            ),
            pixelWidth: 3840,
            pixelHeight: 2160
        ),
        MediaFormat(
            quality: "1080p (Full HD)",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC 128 kbps",
            estimatedSize: "~ 720 MB",
            subtitles: true,
            compatibilityKind: .quickTime,
            selection: .video(
                formatSelector: quickTimeMP4Selector(maxHeight: 1080),
                mergeOutputFormat: "mp4"
            ),
            pixelWidth: 1920,
            pixelHeight: 1080
        ),
        MediaFormat(
            quality: "720p (HD)",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC 128 kbps",
            estimatedSize: "~ 420 MB",
            subtitles: true,
            compatibilityKind: .quickTime,
            selection: .video(
                formatSelector: quickTimeMP4Selector(maxHeight: 720),
                mergeOutputFormat: "mp4"
            ),
            pixelWidth: 1280,
            pixelHeight: 720
        ),
        MediaFormat(
            quality: "480p",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC 128 kbps",
            estimatedSize: "~ 240 MB",
            subtitles: false,
            compatibilityKind: .quickTime,
            selection: .video(
                formatSelector: quickTimeMP4Selector(maxHeight: 480),
                mergeOutputFormat: "mp4"
            ),
            pixelWidth: 854,
            pixelHeight: 480
        ),
        MediaFormat(
            quality: "Audio Only",
            container: "M4A",
            videoCodec: "-",
            audio: "M4A 128 kbps",
            estimatedSize: "~ 32 MB",
            subtitles: true,
            compatibilityKind: .music,
            selection: .audio(formatSelector: "ba[ext=m4a][acodec^=mp4a.40.]")
        )
    ]
}
