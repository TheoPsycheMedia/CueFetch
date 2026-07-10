import Testing
@testable import CueFetchCore

struct ToolLocatorTests {
    @Test func processEnvironmentCopiesOnlyTheExplicitAllowlist() {
        let inherited = [
            "PATH": "/custom/bin:/usr/bin",
            "HOME": "/Users/tester",
            "TMPDIR": "/private/tmp/session",
            "LANG": "en_US.UTF-8",
            "LC_CTYPE": "UTF-8",
            "SSL_CERT_FILE": "/etc/ssl/cert.pem",
            "CURL_CA_BUNDLE": "/etc/ssl/curl.pem",
            "XDG_CACHE_HOME": "/Users/tester/.cache",
            "DYLD_LIBRARY_PATH": "/tmp/injected",
            "PYTHONPATH": "/tmp/injected-python",
            "OPENAI_API_KEY": "must-not-leak"
        ]

        let environment = ToolLocator.processEnvironment(from: inherited)

        #expect(environment["HOME"] == "/Users/tester")
        #expect(environment["TMPDIR"] == "/private/tmp/session")
        #expect(environment["LANG"] == "en_US.UTF-8")
        #expect(environment["LC_CTYPE"] == "UTF-8")
        #expect(environment["SSL_CERT_FILE"] == "/etc/ssl/cert.pem")
        #expect(environment["CURL_CA_BUNDLE"] == "/etc/ssl/curl.pem")
        #expect(environment["XDG_CACHE_HOME"] == "/Users/tester/.cache")
        #expect(environment["DYLD_LIBRARY_PATH"] == nil)
        #expect(environment["PYTHONPATH"] == nil)
        #expect(environment["OPENAI_API_KEY"] == nil)
    }

    @Test func processEnvironmentUsesKnownDirectoriesBeforeInheritedPathWithoutDuplicates() throws {
        let environment = ToolLocator.processEnvironment(
            from: ["PATH": "/custom/bin:/usr/bin:/custom/bin"]
        )
        let path = try #require(environment["PATH"])
        let components = path.split(separator: ":").map(String.init)

        #expect(components.first == "/opt/homebrew/bin")
        #expect(components.contains("/custom/bin"))
        #expect(components.filter { $0 == "/usr/bin" }.count == 1)
        #expect(components.filter { $0 == "/custom/bin" }.count == 1)
    }
}
