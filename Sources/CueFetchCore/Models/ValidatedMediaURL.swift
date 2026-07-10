import Foundation

public enum MediaURLValidationError: Error, Equatable, Sendable {
    case empty
    case tooLong(maximum: Int)
    case invalidFormat
    case unsupportedScheme
    case missingHost
    case userInfoNotAllowed
    case fragmentNotAllowed
}

public struct ValidatedMediaURL: Equatable, Hashable, Sendable, CustomStringConvertible {
    public static let maximumInputLength = 4_096

    public let string: String

    public var description: String { string }

    public init(_ input: String) throws {
        guard input.utf8.count <= Self.maximumInputLength else {
            throw MediaURLValidationError.tooLong(maximum: Self.maximumInputLength)
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MediaURLValidationError.empty
        }

        let forbiddenCharacters = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard trimmed.rangeOfCharacter(from: forbiddenCharacters) == nil,
              let components = URLComponents(string: trimmed),
              components.url != nil,
              let rawScheme = components.scheme
        else {
            throw MediaURLValidationError.invalidFormat
        }

        let scheme = rawScheme.lowercased()
        guard scheme == "http" || scheme == "https" else {
            throw MediaURLValidationError.unsupportedScheme
        }

        guard let host = components.host, !host.isEmpty else {
            throw MediaURLValidationError.missingHost
        }

        guard components.user == nil, components.password == nil else {
            throw MediaURLValidationError.userInfoNotAllowed
        }

        guard components.fragment == nil else {
            throw MediaURLValidationError.fragmentNotAllowed
        }

        self.string = trimmed
    }
}
