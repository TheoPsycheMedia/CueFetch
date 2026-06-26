import Foundation

public enum SiteKind: String, CaseIterable, Identifiable, Sendable {
    case youtube = "YouTube"
    case vimeo = "Vimeo"
    case tiktok = "TikTok"
    case x = "X"
    case generic = "Web"

    public var id: String { rawValue }

    public init(domain: String) {
        let value = domain.lowercased()
        if value.contains("youtube") || value.contains("youtu.be") {
            self = .youtube
        } else if value.contains("vimeo") {
            self = .vimeo
        } else if value.contains("tiktok") {
            self = .tiktok
        } else if value.contains("x.com") || value.contains("twitter") {
            self = .x
        } else {
            self = .generic
        }
    }
}

public enum AccessState: String, CaseIterable, Identifiable, Sendable {
    case available = "Ready"
    case cookiesRequired = "Cookies required"
    case unsupported = "Unsupported"
    case drmProtected = "DRM protected"

    public var id: String { rawValue }
}

public enum OutputPreset: String, CaseIterable, Identifiable, Sendable {
    case bestVideo = "Best Video"
    case mp4FullHD = "1080p MP4"
    case audioOnly = "Audio Only"
    case custom = "Custom"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .bestVideo: "Highest quality"
        case .mp4FullHD: "High quality"
        case .audioOnly: "MP3 / M4A"
        case .custom: "Choose formats"
        }
    }
}

public struct MediaFormat: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var quality: String
    public var container: String
    public var videoCodec: String
    public var audio: String
    public var estimatedSize: String
    public var subtitles: Bool
    public var compatibility: String
    public var ytDLPFormat: String
    public var isAudioOnly: Bool

    public init(
        id: UUID = UUID(),
        quality: String,
        container: String,
        videoCodec: String,
        audio: String,
        estimatedSize: String,
        subtitles: Bool,
        compatibility: String,
        ytDLPFormat: String,
        isAudioOnly: Bool = false
    ) {
        self.id = id
        self.quality = quality
        self.container = container
        self.videoCodec = videoCodec
        self.audio = audio
        self.estimatedSize = estimatedSize
        self.subtitles = subtitles
        self.compatibility = compatibility
        self.ytDLPFormat = ytDLPFormat
        self.isAudioOnly = isAudioOnly
    }
}

public struct DownloadCandidate: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var url: String
    public var domain: String
    public var duration: String
    public var published: String
    public var thumbnailName: String
    public var thumbnailURL: String?
    public var site: SiteKind
    public var accessState: AccessState
    public var formats: [MediaFormat]

    public init(
        id: UUID = UUID(),
        title: String,
        url: String,
        domain: String,
        duration: String,
        published: String,
        thumbnailName: String,
        thumbnailURL: String? = nil,
        site: SiteKind,
        accessState: AccessState,
        formats: [MediaFormat]
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.domain = domain
        self.duration = duration
        self.published = published
        self.thumbnailName = thumbnailName
        self.thumbnailURL = thumbnailURL
        self.site = site
        self.accessState = accessState
        self.formats = formats
    }
}

public struct RecentLink: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var domain: String
    public var dateLabel: String
    public var thumbnailName: String
    public var site: SiteKind
    public var url: String

    public init(
        id: UUID = UUID(),
        title: String,
        domain: String,
        dateLabel: String,
        thumbnailName: String,
        site: SiteKind,
        url: String
    ) {
        self.id = id
        self.title = title
        self.domain = domain
        self.dateLabel = dateLabel
        self.thumbnailName = thumbnailName
        self.site = site
        self.url = url
    }
}

public struct ToolStatus: Equatable, Sendable {
    public var ytdlpPath: String?
    public var ytdlpVersion: String?
    public var ffmpegPath: String?

    public init(ytdlpPath: String?, ytdlpVersion: String?, ffmpegPath: String?) {
        self.ytdlpPath = ytdlpPath
        self.ytdlpVersion = ytdlpVersion
        self.ffmpegPath = ffmpegPath
    }

    public var isReady: Bool {
        ytdlpPath != nil
    }
}

public struct DownloadOptions: Equatable, Sendable {
    public var url: String
    public var destination: String
    public var preset: OutputPreset
    public var format: MediaFormat
    public var includeSubtitles: Bool
    public var useBrowserCookies: Bool

    public init(
        url: String,
        destination: String,
        preset: OutputPreset,
        format: MediaFormat,
        includeSubtitles: Bool,
        useBrowserCookies: Bool
    ) {
        self.url = url
        self.destination = destination
        self.preset = preset
        self.format = format
        self.includeSubtitles = includeSubtitles
        self.useBrowserCookies = useBrowserCookies
    }
}

public struct YTDLPMetadata: Decodable, Equatable, Sendable {
    public var id: String?
    public var title: String?
    public var webpageURL: String?
    public var originalURL: String?
    public var extractorKey: String?
    public var extractor: String?
    public var duration: Double?
    public var durationString: String?
    public var uploadDate: String?
    public var timestamp: Double?
    public var thumbnail: String?
    public var subtitles: [String: [SubtitleEntry]]?
    public var automaticCaptions: [String: [SubtitleEntry]]?
    public var formats: [YTDLPFormat]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case webpageURL = "webpage_url"
        case originalURL = "original_url"
        case extractorKey = "extractor_key"
        case extractor
        case duration
        case durationString = "duration_string"
        case uploadDate = "upload_date"
        case timestamp
        case thumbnail
        case subtitles
        case automaticCaptions = "automatic_captions"
        case formats
    }
}

public struct SubtitleEntry: Decodable, Equatable, Sendable {
    public var ext: String?
    public var url: String?
}

public struct YTDLPFormat: Decodable, Equatable, Sendable {
    public var formatID: String?
    public var formatNote: String?
    public var ext: String?
    public var height: Int?
    public var width: Int?
    public var vcodec: String?
    public var acodec: String?
    public var filesize: Int?
    public var filesizeApprox: Int?
    public var tbr: Double?
    public var abr: Double?

    enum CodingKeys: String, CodingKey {
        case formatID = "format_id"
        case formatNote = "format_note"
        case ext
        case height
        case width
        case vcodec
        case acodec
        case filesize
        case filesizeApprox = "filesize_approx"
        case tbr
        case abr
    }
}
