import Foundation

public enum YTDLPCommandBuilder {
    public static func analyzeArguments(for url: String) -> [String] {
        [
            "--dump-single-json",
            "--no-warnings",
            "--skip-download",
            url
        ]
    }

    public static func downloadArguments(for options: DownloadOptions) -> [String] {
        var arguments: [String] = [
            "--newline",
            "--progress",
            "--restrict-filenames",
            "--paths", options.destination,
            "--output", "%(title)s [%(id)s].%(ext)s"
        ]

        switch options.preset {
        case .bestVideo:
            arguments += [
                "--format", options.format.ytDLPFormat,
                "--merge-output-format", "mp4"
            ]
        case .mp4FullHD:
            arguments += [
                "--format", "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]/b",
                "--merge-output-format", "mp4"
            ]
        case .audioOnly:
            arguments += [
                "--extract-audio",
                "--audio-format", "m4a",
                "--audio-quality", "0"
            ]
        case .custom:
            arguments += ["--format", options.format.ytDLPFormat]
        }

        if options.includeSubtitles {
            arguments += [
                "--write-subs",
                "--write-auto-subs",
                "--sub-langs", "all,-live_chat"
            ]
        }

        if options.useBrowserCookies {
            arguments += [
                "--cookies-from-browser",
                "safari"
            ]
        }

        arguments.append(options.url)
        return arguments
    }
}
