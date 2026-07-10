import Foundation

public enum ShellCommandRenderer {
    public static func render(executable: String, arguments: [String]) -> String {
        ([executable] + arguments)
            .map(singleQuoted)
            .joined(separator: " ")
    }

    private static func singleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
