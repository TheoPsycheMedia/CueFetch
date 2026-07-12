import Testing
@testable import CueFetchCore

struct URLIntakeAnalyzerTests {
    @Test func singleURLDoesNotRequireConfirmation() {
        let result = URLIntakeAnalyzer.analyze("https://youtu.be/abc123")

        #expect(result.kind == .single)
        #expect(!result.requiresConfirmation)
        #expect(result.primaryURL == "https://youtu.be/abc123")
    }

    @Test func multipleURLsRequireConfirmationAndKeepFirstURL() {
        let result = URLIntakeAnalyzer.analyze(
            """
            https://youtu.be/first
            https://vimeo.com/second
            """
        )

        #expect(result.kind == .multipleLinks)
        #expect(result.requiresConfirmation)
        #expect(result.urlCount == 2)
        #expect(result.primaryURL == "https://youtu.be/first")
    }

    @Test func playlistURLRequiresConfirmationAndCanStripToVideoURL() {
        let result = URLIntakeAnalyzer.analyze("https://www.youtube.com/watch?v=abc123&list=PL123&index=4")

        #expect(result.kind == .playlist)
        #expect(result.requiresConfirmation)
        #expect(result.canAnalyzeSingleVideo)
        #expect(result.primaryURL == "https://www.youtube.com/watch?v=abc123")
    }

    @Test func purePlaylistCannotStripToSingleVideo() {
        let result = URLIntakeAnalyzer.analyze("https://www.youtube.com/playlist?list=PL123")

        #expect(result.kind == .playlist)
        #expect(result.requiresConfirmation)
        #expect(!result.canAnalyzeSingleVideo)
        #expect(result.primaryURL == "https://www.youtube.com/playlist?list=PL123")
    }

    @Test func arbitraryTextIsInvalidAndCannotBeAnalyzed() {
        let result = URLIntakeAnalyzer.analyze("--version")

        #expect(result.kind == .invalid)
        #expect(result.validationError == .invalidFormat)
        #expect(result.validatedURL == nil)
        #expect(!result.canAnalyzeSingleVideo)
    }

    @Test func unsupportedSchemesAreInvalid() {
        let result = URLIntakeAnalyzer.analyze("file:///tmp/private.mov")

        #expect(result.kind == .invalid)
        #expect(result.validationError == .unsupportedScheme)
        #expect(!result.canAnalyzeSingleVideo)
    }

    @Test func oversizedInputIsRejectedBeforeURLDetection() {
        let input = "https://example.com/" + String(repeating: "a", count: ValidatedMediaURL.maximumInputLength)
        let result = URLIntakeAnalyzer.analyze(input)

        #expect(result.kind == .invalid)
        #expect(result.validationError == .tooLong(maximum: ValidatedMediaURL.maximumInputLength))
        #expect(result.originalInput.isEmpty)
    }
}
