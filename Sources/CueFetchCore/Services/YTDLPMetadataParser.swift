import Foundation

public enum YTDLPMetadataParser {
    public static func parse(_ data: Data) throws -> YTDLPMetadata {
        try JSONDecoder().decode(YTDLPMetadata.self, from: data)
    }
}
