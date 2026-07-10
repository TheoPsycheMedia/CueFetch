import Testing
@testable import CueFetchCore

struct ValidatedMediaURLTests {
    @Test func acceptsHTTPAndHTTPSURLsWithHosts() throws {
        let https = try ValidatedMediaURL("  https://example.com/watch?v=abc  ")
        let http = try ValidatedMediaURL("http://localhost:8080/video")

        #expect(https.string == "https://example.com/watch?v=abc")
        #expect(http.string == "http://localhost:8080/video")
    }

    @Test(arguments: [
        "--version",
        "not a URL",
        "https:///missing-host",
        "https://example.com/video\n--config-location=/tmp/config"
    ])
    func rejectsMalformedOrHostlessInput(_ input: String) {
        let error = validationError(for: input)

        #expect(error == .invalidFormat || error == .missingHost)
    }

    @Test func rejectsUnsupportedSchemes() {
        #expect(validationError(for: "ftp://example.com/video") == .unsupportedScheme)
        #expect(validationError(for: "file:///tmp/video.mov") == .unsupportedScheme)
    }

    @Test func rejectsUserInfoAndFragments() {
        #expect(validationError(for: "https://user:secret@example.com/video") == .userInfoNotAllowed)
        #expect(validationError(for: "https://example.com/video#private-token") == .fragmentNotAllowed)
    }

    @Test func rejectsInputsBeyondTheBoundedLimit() {
        let oversized = "https://example.com/" + String(repeating: "a", count: ValidatedMediaURL.maximumInputLength)

        #expect(validationError(for: oversized) == .tooLong(maximum: ValidatedMediaURL.maximumInputLength))
    }

    private func validationError(for input: String) -> MediaURLValidationError? {
        do {
            _ = try ValidatedMediaURL(input)
            return nil
        } catch let error as MediaURLValidationError {
            return error
        } catch {
            return .invalidFormat
        }
    }
}
