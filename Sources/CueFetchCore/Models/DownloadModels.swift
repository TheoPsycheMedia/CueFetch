import Foundation

public enum SiteKind: String, CaseIterable, Identifiable, Codable, Sendable {
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
        case .bestVideo: "Highest resolution"
        case .mp4FullHD: "H.264 + AAC"
        case .audioOnly: "M4A audio"
        case .custom: "Choose a format"
        }
    }
}

public struct DownloadProfile: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var summary: String
    public var destination: String
    public var preset: OutputPreset
    public var includeSubtitles: Bool
    public var subtitleLanguages: String

    public init(
        id: String,
        name: String,
        summary: String,
        destination: String,
        preset: OutputPreset,
        includeSubtitles: Bool,
        subtitleLanguages: String = "all,-live_chat"
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.destination = destination
        self.preset = preset
        self.includeSubtitles = includeSubtitles
        self.subtitleLanguages = subtitleLanguages
    }

    public static let all: [DownloadProfile] = [
        DownloadProfile(
            id: "editing",
            name: "Editing",
            summary: "1080p MP4 with captions",
            destination: "~/Downloads/CueFetch/Editing",
            preset: .mp4FullHD,
            includeSubtitles: true
        ),
        DownloadProfile(
            id: "audio",
            name: "Audio",
            summary: "M4A extraction",
            destination: "~/Downloads/CueFetch/Audio",
            preset: .audioOnly,
            includeSubtitles: false
        ),
        DownloadProfile(
            id: "archive",
            name: "Archive",
            summary: "Best available media",
            destination: "~/Downloads/CueFetch/Archive",
            preset: .bestVideo,
            includeSubtitles: true
        ),
        DownloadProfile(
            id: "short-clips",
            name: "Short Clips",
            summary: "1080p MP4 for short-form edits",
            destination: "~/Downloads/CueFetch/Short Clips",
            preset: .mp4FullHD,
            includeSubtitles: true
        )
    ]

    public static func profile(id: String) -> DownloadProfile? {
        let migratedID = id == "sermon-clips" ? "short-clips" : id
        return all.first { $0.id == migratedID }
    }
}

public enum DownloadTool: String, CaseIterable, Hashable, Sendable {
    case ytDLP = "yt-dlp"
    case ffmpeg
}

public enum MediaKind: Equatable, Sendable {
    case video
    case audio
}

public enum MediaCompatibility: Equatable, Sendable {
    case quickTime
    case music
    case requiresConversion

    public var label: String {
        switch self {
        case .quickTime: "Compatible with QuickTime"
        case .music: "Compatible with Music"
        case .requiresConversion: "May require conversion"
        }
    }
}

public enum MediaFormatSelection: Equatable, Sendable {
    case video(
        formatSelector: String,
        mergeOutputFormat: String?
    )
    case audio(formatSelector: String)

    public var kind: MediaKind {
        switch self {
        case .video: .video
        case .audio: .audio
        }
    }

    public var formatSelector: String {
        switch self {
        case let .video(formatSelector, _), let .audio(formatSelector):
            formatSelector
        }
    }

    public var mergeOutputFormat: String? {
        guard case let .video(_, mergeOutputFormat) = self else { return nil }
        return mergeOutputFormat
    }

    public var requiredTools: Set<DownloadTool> {
        switch self {
        case let .video(formatSelector, mergeOutputFormat):
            formatSelector.contains("+") || mergeOutputFormat != nil
                ? [.ytDLP, .ffmpeg]
                : [.ytDLP]
        case .audio: [.ytDLP]
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
    public var compatibilityKind: MediaCompatibility
    public var selection: MediaFormatSelection
    public var pixelWidth: Int?
    public var pixelHeight: Int?

    public var kind: MediaKind { selection.kind }
    public var compatibility: String { compatibilityKind.label }
    public var ytDLPFormat: String { selection.formatSelector }
    public var isAudioOnly: Bool { kind == .audio }

    public init(
        id: UUID = UUID(),
        quality: String,
        container: String,
        videoCodec: String,
        audio: String,
        estimatedSize: String,
        subtitles: Bool,
        compatibilityKind: MediaCompatibility,
        selection: MediaFormatSelection,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil
    ) {
        self.id = id
        self.quality = quality
        self.container = container
        self.videoCodec = videoCodec
        self.audio = audio
        self.estimatedSize = estimatedSize
        self.subtitles = subtitles
        self.compatibilityKind = compatibilityKind
        self.selection = selection
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    public var pixelCount: Int {
        let height = max(pixelHeight ?? 0, 0)
        let width = max(pixelWidth ?? height, 0)
        return width * height
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
    public var subtitleLanguages: [String]

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
        formats: [MediaFormat],
        subtitleLanguages: [String] = []
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
        self.subtitleLanguages = subtitleLanguages
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

    public var isYTDLPInstalled: Bool { ytdlpPath != nil }
    public var isFFmpegInstalled: Bool { ffmpegPath != nil }

    public func missingTools(required: Set<DownloadTool>) -> Set<DownloadTool> {
        required.filter { tool in
            switch tool {
            case .ytDLP: !isYTDLPInstalled
            case .ffmpeg: !isFFmpegInstalled
            }
        }
    }
}

public enum EffectiveDownloadSelection: Equatable, Sendable {
    case selectedFormat(MediaFormatSelection)
    case fixedQuickTimeMP4(maximumHeight: Int)
    case fixedM4A
}

public enum DownloadPlanError: Error, Equatable, Sendable {
    case missingSelectedFormat
    case selectedVideoFormatRequired
    case missingTools(Set<DownloadTool>)
}

public struct DownloadPlan: Equatable, Sendable {
    public let url: ValidatedMediaURL
    public let destination: String
    public let preset: OutputPreset
    public let selectedFormat: MediaFormat?
    public let effectiveSelection: EffectiveDownloadSelection
    public let includeSubtitles: Bool
    public let subtitleLanguages: String
    public let useBrowserCookies: Bool
    public let compatibility: MediaCompatibility
    public let requiredTools: Set<DownloadTool>

    public init(
        url: ValidatedMediaURL,
        destination: String,
        preset: OutputPreset,
        selectedFormat: MediaFormat? = nil,
        includeSubtitles: Bool,
        subtitleLanguages: String = "all,-live_chat",
        useBrowserCookies: Bool
    ) throws {
        let effectiveSelection: EffectiveDownloadSelection
        let compatibility: MediaCompatibility
        let requiredTools: Set<DownloadTool>

        switch preset {
        case .bestVideo:
            guard let selectedFormat else {
                throw DownloadPlanError.missingSelectedFormat
            }
            guard selectedFormat.kind == .video else {
                throw DownloadPlanError.selectedVideoFormatRequired
            }
            effectiveSelection = .selectedFormat(selectedFormat.selection)
            compatibility = selectedFormat.compatibilityKind
            requiredTools = selectedFormat.selection.requiredTools
        case .mp4FullHD:
            effectiveSelection = .fixedQuickTimeMP4(maximumHeight: 1080)
            compatibility = .quickTime
            requiredTools = [.ytDLP, .ffmpeg]
        case .audioOnly:
            effectiveSelection = .fixedM4A
            compatibility = .music
            requiredTools = [.ytDLP, .ffmpeg]
        case .custom:
            guard let selectedFormat else {
                throw DownloadPlanError.missingSelectedFormat
            }
            effectiveSelection = .selectedFormat(selectedFormat.selection)
            compatibility = selectedFormat.compatibilityKind
            requiredTools = selectedFormat.selection.requiredTools
        }

        self.url = url
        self.destination = destination
        self.preset = preset
        self.selectedFormat = selectedFormat
        self.effectiveSelection = effectiveSelection
        self.includeSubtitles = includeSubtitles
        self.subtitleLanguages = subtitleLanguages
        self.useBrowserCookies = useBrowserCookies
        self.compatibility = compatibility
        self.requiredTools = requiredTools
    }

    public func missingTools(in status: ToolStatus) -> Set<DownloadTool> {
        status.missingTools(required: requiredTools)
    }

    public func validateTools(against status: ToolStatus) throws {
        let missing = missingTools(in: status)
        guard missing.isEmpty else {
            throw DownloadPlanError.missingTools(missing)
        }
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
