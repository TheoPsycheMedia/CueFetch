import Foundation

public enum YTDLPMetadataMapper {
    public static func candidate(from metadata: YTDLPMetadata, fallbackURL: String) -> DownloadCandidate {
        let url = metadata.webpageURL ?? metadata.originalURL ?? fallbackURL
        let domain = domainName(for: url)
        let site = SiteKind(domain: domain.isEmpty ? (metadata.extractorKey ?? metadata.extractor ?? "") : domain)
        let hasSubtitles = !(metadata.subtitles ?? [:]).isEmpty || !(metadata.automaticCaptions ?? [:]).isEmpty
        let subtitleLanguages = subtitleLanguages(from: metadata)
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
            formats: formats,
            subtitleLanguages: subtitleLanguages
        )
    }

    public static func mediaFormats(from formats: [YTDLPFormat], hasSubtitles: Bool) -> [MediaFormat] {
        var rows = representativeVideoFormats(from: formats).compactMap { format -> MediaFormat? in
            guard let height = format.height,
                  let formatID = format.formatID,
                  !formatID.isEmpty
            else {
                return nil
            }

            let ext = (format.ext ?? "mp4").uppercased()
            let codec = simplifiedCodec(format.vcodec)
            let audio = format.acodec == "none" ? "Separate audio" : simplifiedAudio(format.acodec, abr: format.abr)
            let estimated = format.filesize ?? format.filesizeApprox
            let compatibility = compatibility(for: format)

            return MediaFormat(
                quality: qualityLabel(width: format.width, height: height),
                container: ext,
                videoCodec: codec,
                audio: audio,
                estimatedSize: byteString(estimated),
                subtitles: hasSubtitles,
                compatibilityKind: compatibility,
                selection: selection(for: format, formatID: formatID, compatibility: compatibility),
                pixelWidth: format.width,
                pixelHeight: height
            )
        }

        if let audio = bestAudioFormat(in: formats) {
            guard let formatID = audio.formatID, !formatID.isEmpty else {
                return rows
            }
            rows.append(
                MediaFormat(
                    quality: "Audio Only",
                    container: (audio.ext ?? "m4a").uppercased(),
                    videoCodec: "-",
                    audio: simplifiedAudio(audio.acodec, abr: audio.abr),
                    estimatedSize: byteString(audio.filesize ?? audio.filesizeApprox),
                    subtitles: hasSubtitles,
                    compatibilityKind: .music,
                    selection: .audio(formatSelector: formatID)
                )
            )
        }

        return rows
    }

    private struct VideoKey: Hashable {
        let width: Int
        let height: Int
        let codec: String
    }

    private static func representativeVideoFormats(from formats: [YTDLPFormat]) -> [YTDLPFormat] {
        let videos = formats.filter { format in
            guard format.formatID?.isEmpty == false,
                  let height = format.height,
                  height > 0,
                  let codec = format.vcodec?.lowercased()
            else {
                return false
            }
            return codec != "none"
        }

        let representatives = videos.reduce(into: [VideoKey: YTDLPFormat]()) { result, format in
            let key = VideoKey(
                width: format.width ?? 0,
                height: format.height ?? 0,
                codec: simplifiedCodec(format.vcodec)
            )
            guard let current = result[key] else {
                result[key] = format
                return
            }
            if representativeScore(format) > representativeScore(current) {
                result[key] = format
            }
        }

        return representatives.values.sorted { lhs, rhs in
            let lhsPixels = (lhs.width ?? 0) * (lhs.height ?? 0)
            let rhsPixels = (rhs.width ?? 0) * (rhs.height ?? 0)
            if lhsPixels != rhsPixels { return lhsPixels > rhsPixels }
            if lhs.height != rhs.height { return (lhs.height ?? 0) > (rhs.height ?? 0) }

            let lhsCompatibility = compatibility(for: lhs) == .quickTime ? 0 : 1
            let rhsCompatibility = compatibility(for: rhs) == .quickTime ? 0 : 1
            if lhsCompatibility != rhsCompatibility { return lhsCompatibility < rhsCompatibility }
            return simplifiedCodec(lhs.vcodec) < simplifiedCodec(rhs.vcodec)
        }
    }

    private static func representativeScore(_ format: YTDLPFormat) -> Double {
        let quickTimeScore = compatibility(for: format) == .quickTime ? 1_000_000.0 : 0
        let embeddedAudioScore = hasUsableAudio(format) ? 100_000.0 : 0
        let mp4Score = format.ext?.lowercased() == "mp4" ? 10_000.0 : 0
        return quickTimeScore + embeddedAudioScore + mp4Score + (format.tbr ?? 0)
    }

    private static func bestAudioFormat(in formats: [YTDLPFormat]) -> YTDLPFormat? {
        formats
            .filter { format in
                format.formatID?.isEmpty == false
                    && format.vcodec == "none"
                    && format.ext?.lowercased() == "m4a"
                    && isAAC(format.acodec)
            }
            .sorted { lhs, rhs in
                (lhs.abr ?? lhs.tbr ?? 0) > (rhs.abr ?? rhs.tbr ?? 0)
            }
            .first
    }

    private static func compatibility(for format: YTDLPFormat) -> MediaCompatibility {
        isQuickTimeFriendlyVideo(format) ? .quickTime : .requiresConversion
    }

    private static func selection(
        for format: YTDLPFormat,
        formatID: String,
        compatibility: MediaCompatibility
    ) -> MediaFormatSelection {
        if compatibility == .quickTime {
            if isAAC(format.acodec) {
                return .video(
                    formatSelector: formatID,
                    mergeOutputFormat: nil
                )
            }
            return .video(
                formatSelector: DefaultMediaFormats.quickTimeMP4Selector(videoFormatID: formatID),
                mergeOutputFormat: "mp4"
            )
        }

        if hasUsableAudio(format) {
            return .video(
                formatSelector: formatID,
                mergeOutputFormat: nil
            )
        }

        return .video(
            formatSelector: "\(formatID)+bestaudio",
            mergeOutputFormat: format.ext?.lowercased()
        )
    }

    private static func isQuickTimeFriendlyVideo(_ format: YTDLPFormat) -> Bool {
        guard format.ext?.lowercased() == "mp4" else { return false }
        let codec = format.vcodec?.lowercased() ?? ""
        guard codec.hasPrefix("avc1") || codec.contains("h264") else { return false }

        guard hasUsableAudio(format) else { return true }
        return isAAC(format.acodec)
    }

    private static func hasUsableAudio(_ format: YTDLPFormat) -> Bool {
        guard let acodec = format.acodec?.lowercased(), acodec != "none" else {
            return false
        }
        return true
    }

    private static func isAAC(_ codec: String?) -> Bool {
        codec?.lowercased().hasPrefix("mp4a.40.") == true
    }

    private static func qualityLabel(width: Int?, height: Int) -> String {
        if let width, width > 0, width < height {
            return "\(width)×\(height) (Vertical)"
        }
        if height >= 2160 { return "\(height)p (4K)" }
        if height == 1080 { return "\(height)p (Full HD)" }
        if height == 720 { return "\(height)p (HD)" }
        return "\(height)p"
    }

    private static func subtitleLanguages(from metadata: YTDLPMetadata) -> [String] {
        var languages = Set<String>()
        languages.formUnion((metadata.subtitles ?? [:]).keys)
        languages.formUnion((metadata.automaticCaptions ?? [:]).keys)
        return languages
            .filter { !$0.isEmpty && $0 != "live_chat" }
            .sorted { lhs, rhs in
                if lhs == "en" { return true }
                if rhs == "en" { return false }
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
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
