import Foundation

public enum ToolLocator {
    private static let commonSearchDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    private static let allowedEnvironmentKeys = [
        "HOME",
        "TMPDIR",
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
        "SSL_CERT_FILE",
        "SSL_CERT_DIR",
        "CURL_CA_BUNDLE",
        "REQUESTS_CA_BUNDLE",
        "XDG_CACHE_HOME"
    ]

    public static func status() -> ToolStatus {
        let ytdlp = locate("yt-dlp")
        let ffmpeg = locate("ffmpeg")
        let detectedVersion: String?
        if let ytdlp {
            detectedVersion = version(forExecutableAt: ytdlp)
        } else {
            detectedVersion = nil
        }
        return ToolStatus(ytdlpPath: ytdlp, ytdlpVersion: detectedVersion, ffmpegPath: ffmpeg)
    }

    public static func locate(_ executable: String) -> String? {
        for directory in commonSearchDirectories {
            let candidate = "\(directory)/\(executable)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", executable]
        process.environment = processEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return output.isEmpty ? nil : output
    }

    private static func version(forExecutableAt path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.environment = processEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return output.isEmpty ? nil : output
    }

    public static func processEnvironment(
        from inherited: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = allowedEnvironmentKeys.reduce(into: [String: String]()) { result, key in
            if let value = inherited[key], !value.isEmpty {
                result[key] = value
            }
        }

        let existingPath = inherited["PATH"] ?? ""
        let pathParts = commonSearchDirectories + existingPath
            .split(separator: ":")
            .map(String.init)
        environment["PATH"] = pathParts.reduce(into: [String]()) { result, item in
            if !result.contains(item) {
                result.append(item)
            }
        }
        .joined(separator: ":")
        return environment
    }
}
