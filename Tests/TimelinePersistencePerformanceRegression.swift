import Foundation

@main
enum TimelinePersistencePerformanceRegression {
    static func main() throws {
        let commandPayload = String(repeating: "command metadata ", count: 4_000)
        let imagePayload = """
        [{"type":"content","content":{"type":"image","data":"\(String(repeating: "A", count: 400_000))","mimeType":"image/png"}}]
        """
        let events = (0..<600).map {
            ChatTimelineEvent(id: "commands-\($0)", kind: "extension", title: "available commands update",
                              status: nil, input: nil, output: commandPayload)
        } + [
            ChatTimelineEvent(id: "delta", kind: "extension", title: "tool call delta chunk",
                              status: nil, input: nil, output: commandPayload),
            ChatTimelineEvent(id: "image", kind: "read", title: "Read `/tmp/reference.png`",
                              status: "completed", input: nil, output: imagePayload),
            ChatTimelineEvent(id: "file", kind: "read", title: "Read `/tmp/notes.md`",
                              status: "completed", input: nil, output: "important text result")
        ]

        let started = Date()
        let prepared = TimelinePersistencePolicy.prepare(events)
        let elapsed = Date().timeIntervalSince(started)

        require(prepared.count == 2, "runtime protocol noise must not survive in the conversation timeline")
        require(prepared.contains(where: { $0.id == "file" && $0.output == "important text result" }),
                "meaningful tool text must remain available")
        let image = try requireValue(prepared.first(where: { $0.id == "image" }))
        require((image.output ?? "").contains("binary image data omitted"),
                "embedded image bytes must be replaced by a readable placeholder")
        require((image.output ?? "").count < 2_000, "binary payload compaction must materially reduce persisted state")
        require(elapsed < 0.5, "timeline preparation must remain bounded for noisy long sessions")

        print("Timeline persistence performance regression passed in \(String(format: "%.3f", elapsed))s")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }

    private static func requireValue<T>(_ value: T?) throws -> T {
        guard let value else { throw NSError(domain: "TimelinePersistencePerformanceRegression", code: 1) }
        return value
    }
}
