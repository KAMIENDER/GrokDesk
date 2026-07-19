import Foundation

enum SkillIndex {
    static func discover(cwd: String?) -> [GrokSkill] {
        let fm = FileManager.default
        var roots: [(URL, String)] = [
            (fm.homeDirectoryForCurrentUser.appendingPathComponent(".grok/skills"), "user"),
            (fm.homeDirectoryForCurrentUser.appendingPathComponent(".grok/server-skills"), "server")
        ]
        if let cwd {
            var cursor = URL(fileURLWithPath: cwd, isDirectory: true).standardizedFileURL
            var first = true
            while cursor.path != "/" {
                roots.append((cursor.appendingPathComponent(".grok/skills"), first ? "local" : "repo"))
                first = false
                cursor.deleteLastPathComponent()
            }
        }

        var result: [GrokSkill] = []
        var seen = Set<String>()
        for (root, scope) in roots where fm.fileExists(atPath: root.path) {
            guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
            for directory in children {
                let file = directory.appendingPathComponent("SKILL.md")
                guard fm.fileExists(atPath: file.path),
                      let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let fallbackName = directory.lastPathComponent
                let fields = frontmatter(content)
                let name = fields["name"] ?? fallbackName
                // Grok resolves higher-priority scopes first. Preserve only the
                // winning bare slash command in the pre-session local index.
                guard seen.insert(name).inserted else { continue }
                let description = fields["description"] ?? firstParagraph(content) ?? "Grok Skill"
                result.append(GrokSkill(name: name, displayName: fields["display_name"],
                                        description: description, shortDescription: fields["short_description"],
                                        path: file.path, scope: scope, enabled: true,
                                        userInvocable: fields["user_invocable"]?.lowercased() != "false",
                                        whenToUse: fields["when_to_use"], argumentHint: fields["argument_hint"],
                                        author: fields["author"], compatibility: fields["compatibility"], content: content))
            }
        }
        return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func frontmatter(_ content: String) -> [String: String] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [:] }
        var values: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            guard let split = line.firstIndex(of: ":") else { continue }
            let key = line[..<split].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: split)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, (value.first == "\"" && value.last == "\"") || (value.first == "'" && value.last == "'") {
                value.removeFirst(); value.removeLast()
            }
            if !key.isEmpty, !value.isEmpty { values[key] = value }
        }
        return values
    }

    private static func firstParagraph(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var inFrontmatter = lines.first?.trimmingCharacters(in: .whitespaces) == "---"
        for (index, line) in lines.enumerated() {
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if inFrontmatter {
                if index > 0, value == "---" { inFrontmatter = false }
                continue
            }
            if !value.isEmpty, !value.hasPrefix("#") { return value }
        }
        return nil
    }
}
