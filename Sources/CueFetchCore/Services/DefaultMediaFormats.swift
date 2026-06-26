import Foundation

public enum DefaultMediaFormats {
    public static let all: [MediaFormat] = [
        MediaFormat(
            quality: "2160p (4K)",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC 128 kbps",
            estimatedSize: "~ 1.45 GB",
            subtitles: true,
            compatibility: "Compatible with QuickTime",
            ytDLPFormat: "bv*[height<=2160][ext=mp4]+ba[ext=m4a]/b[height<=2160][ext=mp4]/b"
        ),
        MediaFormat(
            quality: "1080p (Full HD)",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC 128 kbps",
            estimatedSize: "~ 720 MB",
            subtitles: true,
            compatibility: "Compatible with QuickTime",
            ytDLPFormat: "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]/b"
        ),
        MediaFormat(
            quality: "720p (HD)",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC 128 kbps",
            estimatedSize: "~ 420 MB",
            subtitles: true,
            compatibility: "Compatible with QuickTime",
            ytDLPFormat: "bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/b"
        ),
        MediaFormat(
            quality: "480p",
            container: "MP4",
            videoCodec: "H.264",
            audio: "AAC 128 kbps",
            estimatedSize: "~ 240 MB",
            subtitles: false,
            compatibility: "Compatible with QuickTime",
            ytDLPFormat: "bv*[height<=480][ext=mp4]+ba[ext=m4a]/b[height<=480][ext=mp4]/b"
        ),
        MediaFormat(
            quality: "Audio Only",
            container: "M4A",
            videoCodec: "-",
            audio: "M4A 128 kbps",
            estimatedSize: "~ 32 MB",
            subtitles: true,
            compatibility: "Compatible with Music",
            ytDLPFormat: "ba[ext=m4a]/ba"
        )
    ]
}
