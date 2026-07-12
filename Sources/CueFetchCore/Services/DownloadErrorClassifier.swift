import Foundation

public enum DownloadErrorKind: Equatable, Sendable {
    case missingYTDLP
    case safariCookiePermissionDenied
    case cookiesRequired
    case drmProtected
    case unsupported
    case timeoutOrNetwork
    case general
}

public enum DownloadErrorClassifier {
    public static func kind(for error: String, ytdlpMissing: Bool = false) -> DownloadErrorKind {
        let lowered = error.lowercased()

        if ytdlpMissing || lowered.contains("yt-dlp not found") {
            return .missingYTDLP
        }

        if isSafariCookiePermissionDenied(lowered) {
            return .safariCookiePermissionDenied
        }

        if lowered.contains("drm") {
            return .drmProtected
        }

        if lowered.contains("cookie") || lowered.contains("sign in") || lowered.contains("login") {
            return .cookiesRequired
        }

        if lowered.contains("unsupported") || lowered.contains("not supported") {
            return .unsupported
        }

        if lowered.contains("timed out") || lowered.contains("timeout") || lowered.contains("network") {
            return .timeoutOrNetwork
        }

        return .general
    }

    public static func accessState(from error: String) -> AccessState {
        switch kind(for: error) {
        case .cookiesRequired:
            return .cookiesRequired
        case .drmProtected:
            return .drmProtected
        case .missingYTDLP, .safariCookiePermissionDenied, .unsupported, .timeoutOrNetwork, .general:
            return .unsupported
        }
    }

    public static func analysisStatusMessage(for error: String) -> String {
        switch kind(for: error) {
        case .cookiesRequired:
            return "Safari cookies may be required"
        case .safariCookiePermissionDenied:
            return "Safari cookie access blocked"
        case .drmProtected:
            return "DRM protected media"
        case .missingYTDLP, .unsupported, .timeoutOrNetwork, .general:
            return "Could not analyze link"
        }
    }

    private static func isSafariCookiePermissionDenied(_ lowered: String) -> Bool {
        let mentionsSafariCookies = lowered.contains("cookies.binarycookies")
            || (lowered.contains("safari") && lowered.contains("cookie"))
        let mentionsPermission = lowered.contains("operation not permitted")
            || lowered.contains("permission denied")
            || lowered.contains("not authorized")
            || lowered.contains("access denied")

        return mentionsSafariCookies && mentionsPermission
    }
}
