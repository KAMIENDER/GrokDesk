import Foundation

struct MarkdownImageReference: Equatable {
    let altText: String
    let destination: String

    static func parseStandalone(_ line: String) -> MarkdownImageReference? {
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("!["), value.hasSuffix(")"),
              let separator = value.range(of: "](") else { return nil }

        let altStart = value.index(value.startIndex, offsetBy: 2)
        let alt = String(value[altStart..<separator.lowerBound])
        var destination = String(value[separator.upperBound..<value.index(before: value.endIndex)])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if destination.hasPrefix("<"), destination.hasSuffix(">") {
            destination = String(destination.dropFirst().dropLast())
        }
        guard !destination.isEmpty else { return nil }
        return MarkdownImageReference(altText: alt, destination: destination)
    }

    func resolvedURL(relativeTo baseDirectory: String?) -> URL? {
        if destination.hasPrefix("file://") {
            if let url = URL(string: destination), url.isFileURL { return url.standardizedFileURL }
            let path = String(destination.dropFirst("file://".count)).removingPercentEncoding
                ?? String(destination.dropFirst("file://".count))
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        if let url = URL(string: destination), ["https", "http"].contains(url.scheme?.lowercased()) {
            return url
        }

        let decoded = destination.removingPercentEncoding ?? destination
        if decoded.hasPrefix("/") { return URL(fileURLWithPath: decoded).standardizedFileURL }
        guard let baseDirectory, !baseDirectory.isEmpty else { return nil }
        return URL(fileURLWithPath: baseDirectory, isDirectory: true)
            .appendingPathComponent(decoded).standardizedFileURL
    }
}
