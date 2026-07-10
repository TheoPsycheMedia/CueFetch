import Foundation

public enum URLIntakeKind: Equatable, Sendable {
    case empty
    case invalid
    case single
    case playlist
    case multipleLinks
}

public struct URLIntakeResult: Equatable, Sendable {
    public var kind: URLIntakeKind
    public var originalInput: String
    public var primaryURL: String
    public var urlCount: Int
    public var canAnalyzeSingleVideo: Bool
    public var validatedURL: ValidatedMediaURL?
    public var validationError: MediaURLValidationError?

    public var requiresConfirmation: Bool {
        kind == .playlist || kind == .multipleLinks
    }
}

public enum URLIntakeAnalyzer {
    public static func analyze(_ input: String) -> URLIntakeResult {
        guard input.utf8.count <= ValidatedMediaURL.maximumInputLength else {
            return invalidResult(
                originalInput: "",
                error: .tooLong(maximum: ValidatedMediaURL.maximumInputLength)
            )
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return URLIntakeResult(
                kind: .empty,
                originalInput: "",
                primaryURL: "",
                urlCount: 0,
                canAnalyzeSingleVideo: false,
                validatedURL: nil,
                validationError: .empty
            )
        }

        let urls = detectedURLs(in: trimmed)
        guard urls.count <= 1 else {
            let validatedURL = try? ValidatedMediaURL(urls[0])
            return URLIntakeResult(
                kind: .multipleLinks,
                originalInput: trimmed,
                primaryURL: urls[0],
                urlCount: urls.count,
                canAnalyzeSingleVideo: validatedURL != nil,
                validatedURL: validatedURL,
                validationError: nil
            )
        }

        if let detectedURL = urls.first, detectedURL != trimmed {
            return invalidResult(originalInput: trimmed, error: .invalidFormat)
        }

        let url = urls.first ?? trimmed
        let validatedURL: ValidatedMediaURL
        do {
            validatedURL = try ValidatedMediaURL(url)
        } catch let error as MediaURLValidationError {
            return invalidResult(originalInput: trimmed, error: error)
        } catch {
            return invalidResult(originalInput: trimmed, error: .invalidFormat)
        }

        let singleVideoURL = videoOnlyURL(from: url)
        if isPlaylistURL(url) {
            let primaryURL = singleVideoURL ?? url
            let primaryValidatedURL = try? ValidatedMediaURL(primaryURL)
            return URLIntakeResult(
                kind: .playlist,
                originalInput: trimmed,
                primaryURL: primaryURL,
                urlCount: 1,
                canAnalyzeSingleVideo: singleVideoURL != nil && primaryValidatedURL != nil,
                validatedURL: primaryValidatedURL,
                validationError: nil
            )
        }

        return URLIntakeResult(
            kind: .single,
            originalInput: trimmed,
            primaryURL: url,
            urlCount: 1,
            canAnalyzeSingleVideo: true,
            validatedURL: validatedURL,
            validationError: nil
        )
    }

    private static func detectedURLs(in input: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s]+"#) else {
            return []
        }

        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.matches(in: input, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: input) else {
                return nil
            }
            return cleanedURL(String(input[matchRange]))
        }
    }

    private static func cleanedURL(_ url: String) -> String {
        var cleaned = url
        while let last = cleaned.last, [".", ",", ";", ")", "]"].contains(last) {
            cleaned.removeLast()
        }
        return cleaned
    }

    private static func isPlaylistURL(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString) else {
            return false
        }

        if components.path.localizedCaseInsensitiveContains("playlist") {
            return true
        }

        return (components.queryItems ?? []).contains { item in
            item.name == "list" && !(item.value ?? "").isEmpty
        }
    }

    private static func videoOnlyURL(from urlString: String) -> String? {
        guard var components = URLComponents(string: urlString),
              let queryItems = components.queryItems,
              queryItems.contains(where: { $0.name == "v" })
        else {
            return nil
        }

        components.queryItems = queryItems.filter { item in
            !["list", "index", "start_radio"].contains(item.name)
        }

        return components.string
    }

    private static func invalidResult(
        originalInput: String,
        error: MediaURLValidationError
    ) -> URLIntakeResult {
        URLIntakeResult(
            kind: .invalid,
            originalInput: originalInput,
            primaryURL: "",
            urlCount: 0,
            canAnalyzeSingleVideo: false,
            validatedURL: nil,
            validationError: error
        )
    }
}
