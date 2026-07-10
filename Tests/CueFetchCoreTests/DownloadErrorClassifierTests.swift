import Testing
@testable import CueFetchCore

struct DownloadErrorClassifierTests {
    @Test func safariCookiePermissionErrorsHaveDedicatedRecoveryKind() {
        let error = "ERROR: [Errno 1] Operation not permitted: '/Users/example/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies'"

        #expect(DownloadErrorClassifier.kind(for: error) == .safariCookiePermissionDenied)
        #expect(DownloadErrorClassifier.accessState(from: error) == .unsupported)
        #expect(DownloadErrorClassifier.analysisStatusMessage(for: error) == "Safari cookie access blocked")
    }

    @Test func signInErrorsStillAskForCookies() {
        let error = "Sign in to confirm you are not a bot. Use cookies from your browser."

        #expect(DownloadErrorClassifier.kind(for: error) == .cookiesRequired)
        #expect(DownloadErrorClassifier.accessState(from: error) == .cookiesRequired)
        #expect(DownloadErrorClassifier.analysisStatusMessage(for: error) == "Safari cookies may be required")
    }
}
