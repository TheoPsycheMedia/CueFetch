import Foundation

public enum YTDLPCommandBuilder {
    public static let finalPathMarker = "__CUEFETCH_FINAL_PATH__:"

    public static func analyzeArguments(
        for url: ValidatedMediaURL,
        useBrowserCookies: Bool = false
    ) -> [String] {
        var arguments = [
            "--ignore-config",
            "--dump-single-json",
            "--no-warnings",
            "--skip-download",
            "--no-playlist"
        ]

        appendCookieArguments(to: &arguments, useBrowserCookies: useBrowserCookies)
        arguments += ["--", url.string]
        return arguments
    }

    public static func downloadArguments(for plan: DownloadPlan) -> [String] {
        var arguments: [String] = [
            "--ignore-config",
            "--newline",
            "--progress",
            "--no-playlist",
            "--restrict-filenames",
            "--paths", plan.destination,
            "--output", "%(title)s [%(id)s].%(ext)s",
            "--print", "after_move:\(finalPathMarker)%(filepath)s"
        ]

        switch plan.effectiveSelection {
        case let .selectedFormat(selection):
            arguments += ["--format", selection.formatSelector]
            if let mergeOutputFormat = selection.mergeOutputFormat {
                arguments += ["--merge-output-format", mergeOutputFormat]
            }
        case let .fixedQuickTimeMP4(maximumHeight):
            arguments += [
                "--format", DefaultMediaFormats.quickTimeMP4Selector(maxHeight: maximumHeight),
                "--merge-output-format", "mp4"
            ]
        case .fixedM4A:
            arguments += [
                "--format", "bestaudio",
                "--extract-audio",
                "--audio-format", "m4a",
                "--audio-quality", "0"
            ]
        }

        if plan.includeSubtitles {
            arguments += [
                "--write-subs",
                "--write-auto-subs",
                "--sub-langs", plan.subtitleLanguages
            ]
        }

        appendCookieArguments(to: &arguments, useBrowserCookies: plan.useBrowserCookies)
        arguments += ["--", plan.url.string]
        return arguments
    }

    private static func appendCookieArguments(
        to arguments: inout [String],
        useBrowserCookies: Bool
    ) {
        guard useBrowserCookies else { return }
        arguments += ["--cookies-from-browser", "safari"]
    }
}
