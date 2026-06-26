import Foundation

public enum YTDLPMetadataMapper {
    public static func candidate(from metadata: YTDLPMetadata, fallbackURL: String) -> DownloadCandidate {
        let url = metadata.webpageURL ?? metadata.originalURL ?? fallbackURL
        let domain = domainName(for: url)
        let site = SiteKind(domain: domain.isEmpty ? (metadata.extractorKey ?? metadata.extractor ?? "") : domain)
        let hasSubtitles = !(metadata.subtitles ?? [:]).isEmpty || !(metadata.automaticCaptions ?? [:]).isEmpty
        let formats = mediaFormats(from: metadata.formats ?? [], hasSubtitles: hasSubtitles)

        return DownloadCandidate(
            title: metadata.title ?? "Detected Video",
            url: url,
            domain: domain.isEmpty ? (metadata.extractorKey ?? "supported site") : domain,
            duration: metadata.durationString ?? durationString(from: metadata.duration),
            published: publishedString(uploadDate: metadata.uploadDate, timestamp: metadata.timestamp),
            thumbnailName: "",
            thumbnailURL: metadata.thumbnail,
            site: site,
            accessState: .available,
            formats: formats.isEmpty ? DefaultMediaFormats.all : formats
        )
    }

    public static func mediaFormats(from formats: [YTDLPFormat], hasSubtitles: Bool) -> [MediaFormat] {
        let preferredHeights = [2160, 1440, 1080, 720, 480]
        var rows: [MediaFormat] = []

        for height in preferredHeights {
            guard let format = bestVideoFormat(for: height, in: formats) else {
                continue
            }

            let ext = (format.ext ?? "mp4").uppercased()
            let codec = simplifiedCodec(format.vcodec)
            let audio = format.acodec == "none" ? "Best audio" : simplifiedAudio(format.acodec, abr: format.abr)
            let estimated = format.filesize ?? format.filesizeApprox
            let formatID = format.formatID ?? "bestvideo"

            rows.append(
                MediaFormat(
                    quality: height >= 2160 ? "\(height)p (4K)" : "\(height)p" + (height == 1080 ? " (Full HD)" : height == 720 ? " (HD)" : ""),
                    container: ext,
                    videoCodec: codec,
                    audio: audio,
                    estimatedSize: byteString(estimated),
                    subtitles: hasSubtitles,
                    compatibility: ext == "MP4" ? "Compatible with QuickTime" : "May require conversion",
                    ytDLPFormat: "\(formatID)+bestaudio/best[height<=\(height)]/best",
                    isAudioOnly: false
                )
            )
        }

        if let audio = bestAudioFormat(in: formats) {
            rows.append(
                MediaFormat(
                    quality: "Audio Only",
                    container: (audio.ext ?? "m4a").uppercased(),
                    videoCodec: "-",
                    audio: simplifiedAudio(audio.acodec, abr: audio.abr),
                    estimatedSize: byteString(audio.filesize ?? audio.filesizeApprox),
                    subtitles: hasSubtitles,
                    compatibility: "Compatible with Music",
                    ytDLPFormat: audio.formatID ?? "bestaudio",
                    isAudioOnly: true
                )
            )
        }

        return rows
    }

    private static func bestVideoFormat(for maxHeight: Int, in formats: [YTDLPFormat]) -> YTDLPFormat? {
        formats
            .filter { format in
                guard let height = format.height, height <= maxHeight else { return false }
                guard format.vcodec != nil, format.vcodec != "none" else { return false }
                return true
            }
            .sorted { lhs, rhs in
                let lhsMP4 = lhs.ext == "mp4" ? 1 : 0
                let rhsMP4 = rhs.ext == "mp4" ? 1 : 0
                if lhs.height != rhs.height { return (lhs.height ?? 0) > (rhs.height ?? 0) }
                if lhsMP4 != rhsMP4 { return lhsMP4 > rhsMP4 }
                return (lhs.tbr ?? 0) > (rhs.tbr ?? 0)
            }
            .first
    }

    private static func bestAudioFormat(in formats: [YTDLPFormat]) -> YTDLPFormat? {
        formats
            .filter { ($0.vcodec == "none") && ($0.acodec != nil && $0.acodec != "none") }
            .sorted { lhs, rhs in
                let lhsM4A = lhs.ext == "m4a" ? 1 : 0
                let rhsM4A = rhs.ext == "m4a" ? 1 : 0
                if lhsM4A != rhsM4A { return lhsM4A > rhsM4A }
                return (lhs.abr ?? lhs.tbr ?? 0) > (rhs.abr ?? rhs.tbr ?? 0)
            }
            .first
    }

    private static func domainName(for urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return ""
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private static func durationString(from duration: Double?) -> String {
        guard let duration else { return "-" }
        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func publishedString(uploadDate: String?, timestamp: Double?) -> String {
        if let uploadDate, uploadDate.count == 8 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            if let date = formatter.date(from: uploadDate) {
                return date.formatted(.dateTime.month(.abbreviated).day().year())
            }
        }

        if let timestamp {
            let date = Date(timeIntervalSince1970: timestamp)
            return date.formatted(.dateTime.month(.abbreviated).day().year())
        }

        return "Detected just now"
    }

    private static func simplifiedCodec(_ codec: String?) -> String {
        guard let codec, codec != "none" else { return "-" }
        if codec.lowercased().contains("avc") { return "H.264" }
        if codec.lowercased().contains("av01") { return "AV1" }
        if codec.lowercased().contains("vp9") { return "VP9" }
        if codec.lowercased().contains("hvc") || codec.lowercased().contains("hevc") { return "HEVC" }
        return codec
    }

    private static func simplifiedAudio(_ codec: String?, abr: Double?) -> String {
        let bitrate = abr.map { "\(Int($0.rounded())) kbps" } ?? "Best"
        guard let codec, codec != "none" else { return bitrate }
        if codec.lowercased().contains("mp4a") { return "AAC \(bitrate)" }
        if codec.lowercased().contains("opus") { return "Opus \(bitrate)" }
        return "\(codec) \(bitrate)"
    }

    private static func byteString(_ bytes: Int?) -> String {
        guard let bytes, bytes > 0 else { return "-" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = bytes > 1_000_000_000 ? [.useGB] : [.useMB]
        return "~ " + formatter.string(fromByteCount: Int64(bytes))
    }
}
