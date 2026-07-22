import Foundation

@main
enum MarkdownImageSupportRegression {
    static func main() {
        let markdown = "![turn-118](file:///Users/bytedance/Claude/Projects/galgame/%E7%8C%AB%E8%80%B3%E8%BD%AC%E5%AD%A6/turns/images/turn-118.png)"
        guard let reference = MarkdownImageReference.parseStandalone(markdown) else {
            fatalError("standalone Markdown image was not parsed")
        }
        precondition(reference.altText == "turn-118")
        precondition(reference.resolvedURL(relativeTo: nil)?.path == "/Users/bytedance/Claude/Projects/galgame/猫耳转学/turns/images/turn-118.png")

        let relative = MarkdownImageReference.parseStandalone("![preview](turns/images/turn-118.png)")
        precondition(relative?.resolvedURL(relativeTo: "/tmp/project")?.path == "/tmp/project/turns/images/turn-118.png")

        let remote = MarkdownImageReference.parseStandalone("![remote](https://example.com/render.png)")
        precondition(remote?.resolvedURL(relativeTo: nil)?.absoluteString == "https://example.com/render.png")

        precondition(MarkdownImageReference.parseStandalone("See [docs](https://example.com)") == nil)
        print("Markdown image regression passed")
    }
}
