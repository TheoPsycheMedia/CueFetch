import Testing
@testable import CueFetchCore

struct ShellCommandRendererTests {
    @Test func quotesEveryArgumentAndEscapesEmbeddedApostrophes() {
        let rendered = ShellCommandRenderer.render(
            executable: "/opt/homebrew/bin/yt-dlp",
            arguments: [
                "--paths",
                "/tmp/Creator's Clips",
                "https://example.com/watch?v=one&list=two"
            ]
        )

        #expect(
            rendered
                == "'/opt/homebrew/bin/yt-dlp' '--paths' '/tmp/Creator'\"'\"'s Clips' 'https://example.com/watch?v=one&list=two'"
        )
    }

    @Test func rendersEmptyArgumentsAsSafeEmptySingleQuotedValues() {
        let rendered = ShellCommandRenderer.render(executable: "yt-dlp", arguments: [""])

        #expect(rendered == "'yt-dlp' ''")
    }
}
