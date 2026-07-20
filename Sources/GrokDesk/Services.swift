import AppKit
import Foundation

enum AppPaths {
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("GrokDesk", isDirectory: true)
    }()
    static let accounts = root.appendingPathComponent("accounts", isDirectory: true)
    static let pastedAttachments = root.appendingPathComponent("Pasted Attachments", isDirectory: true)
    static let state = root.appendingPathComponent("state.json")

    static func prepare() throws {
        try FileManager.default.createDirectory(at: accounts, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pastedAttachments, withIntermediateDirectories: true)
    }
}

enum AccountEnvironment {
    /// Credentials stay private per account. Session history is machine-local state and is
    /// intentionally shared so any healthy token can resume the same Grok conversation.
    static func prepare(home: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: home, withIntermediateDirectories: true)
        let defaultHome = fm.homeDirectoryForCurrentUser.appendingPathComponent(".grok", isDirectory: true)
        try? fm.createDirectory(at: defaultHome.appendingPathComponent("sessions", isDirectory: true), withIntermediateDirectories: true)
        let shared = ["sessions", "bin", "skills", "plugins", "hooks", "agents", "commands", "marketplaces", "config.toml", "managed_config.toml"]
        for name in shared {
            let source = defaultHome.appendingPathComponent(name)
            let target = home.appendingPathComponent(name)
            guard fm.fileExists(atPath: source.path), !fm.fileExists(atPath: target.path) else { continue }
            try? fm.createSymbolicLink(at: target, withDestinationURL: source)
        }
    }
}

final class GrokRuntimeInstaller {
    static let sourceRepository = URL(string: "https://github.com/xai-org/grok-build")!
    static let installerURL = URL(string: "https://x.ai/cli/install.sh")!

    private var process: Process?
    private var temporaryDirectory: URL?

    /// Finder-launched apps inherit a restricted PATH, so probe both the saved
    /// path and the locations used by the official installer and Homebrew.
    static func resolveBinary(configuredPath: String) -> String? {
        let fm = FileManager.default
        var candidates = [configuredPath]
        let home = fm.homeDirectoryForCurrentUser
        candidates += [
            home.appendingPathComponent(".grok/bin/grok").path,
            "/opt/homebrew/bin/grok",
            "/usr/local/bin/grok"
        ]
        for directory in (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":") {
            candidates.append(URL(fileURLWithPath: String(directory)).appendingPathComponent("grok").path)
        }
        return candidates.first { !$0.isEmpty && fm.isExecutableFile(atPath: $0) }
    }

    func installLatest(onLine: @escaping (String) -> Void,
                       completion: @escaping (Result<String, Error>) -> Void) {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("GrokDesk-Installer-\(UUID().uuidString)", isDirectory: true)
        let script = directory.appendingPathComponent("install.sh")
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            temporaryDirectory = directory
        } catch {
            completion(.failure(error)); return
        }

        onLine("Downloading the official xAI installer…")
        run(executable: "/usr/bin/curl", arguments: [
            "--fail", "--silent", "--show-error", "--location",
            Self.installerURL.absoluteString, "--output", script.path
        ], onLine: onLine) { [weak self] downloadResult in
            guard let self else { return }
            switch downloadResult {
            case .failure(let error):
                self.finish(.failure(error), completion: completion)
            case .success:
                onLine("Running the official installer…")
                self.run(executable: "/bin/bash", arguments: [script.path], onLine: onLine) { installResult in
                    switch installResult {
                    case .failure(let error):
                        self.finish(.failure(error), completion: completion)
                    case .success:
                        guard let binary = Self.resolveBinary(configuredPath: "") else {
                            let error = NSError(domain: "GrokDesk.RuntimeInstaller", code: 2, userInfo: [
                                NSLocalizedDescriptionKey: "安装程序已结束，但没有找到 grok 可执行文件。"
                            ])
                            self.finish(.failure(error), completion: completion)
                            return
                        }
                        self.finish(.success(binary), completion: completion)
                    }
                }
            }
        }
    }

    private func run(executable: String, arguments: [String], onLine: @escaping (String) -> Void,
                     completion: @escaping (Result<Void, Error>) -> Void) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        var environment = ProcessInfo.processInfo.environment
        let commonPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = commonPaths + ":" + (environment["PATH"] ?? "")
        process.environment = environment
        self.process = process

        let reader = LineReader(onLine: onLine)
        output.fileHandleForReading.readabilityHandler = { reader.consume($0.availableData) }
        process.terminationHandler = { process in
            output.fileHandleForReading.readabilityHandler = nil
            reader.finish()
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    completion(.success(()))
                } else {
                    completion(.failure(NSError(domain: "GrokDesk.RuntimeInstaller",
                                                 code: Int(process.terminationStatus), userInfo: [
                        NSLocalizedDescriptionKey: "安装命令退出码 \(process.terminationStatus)"
                    ])))
                }
            }
        }
        do { try process.run() }
        catch { DispatchQueue.main.async { completion(.failure(error)) } }
    }

    private func finish(_ result: Result<String, Error>,
                        completion: @escaping (Result<String, Error>) -> Void) {
        process = nil
        if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
        temporaryDirectory = nil
        completion(result)
    }
}

enum LocalSessionIndex {
    private static var sessionsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".grok/sessions", isDirectory: true)
    }

    static func summaries() -> [Conversation] {
        guard let enumerator = FileManager.default.enumerator(at: sessionsRoot, includingPropertiesForKeys: nil) else { return [] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var result: [Conversation] = []
        for case let url as URL in enumerator where url.lastPathComponent == "summary.json" {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let info = json["info"] as? [String: Any],
                  let sessionID = info["id"] as? String,
                  let cwd = info["cwd"] as? String,
                  json["hidden"] as? Bool != true else { continue }
            let kind = json["session_kind"] as? String
            if kind?.contains("subagent") == true { continue }
            let title = (json["generated_title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (json["session_summary"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? "Grok Session"
            let created = (json["created_at"] as? String).flatMap(formatter.date) ?? .distantPast
            let updated = (json["last_active_at"] as? String).flatMap(formatter.date)
                ?? (json["updated_at"] as? String).flatMap(formatter.date) ?? created
            result.append(Conversation(id: UUID(uuidString: sessionID) ?? UUID(), title: title, cwd: cwd,
                                       accountID: nil, grokSessionID: sessionID, messages: [],
                                       createdAt: created, updatedAt: updated))
            enumerator.skipDescendants()
        }
        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func messages(sessionID: String) -> [ChatMessage] {
        guard let enumerator = FileManager.default.enumerator(at: sessionsRoot, includingPropertiesForKeys: nil) else { return [] }
        var historyURL: URL?
        for case let url as URL in enumerator where url.lastPathComponent == sessionID {
            let candidate = url.appendingPathComponent("chat_history.jsonl")
            if FileManager.default.fileExists(atPath: candidate.path) { historyURL = candidate; break }
        }
        guard let historyURL, let text = try? String(contentsOf: historyURL, encoding: .utf8) else { return [] }
        var result: [ChatMessage] = []
        for line in text.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { continue }
            if type == "user", json["prompt_index"] != nil,
               let blocks = json["content"] as? [[String: Any]] {
                let raw = blocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
                let value = extractUserQuery(raw)
                if !value.isEmpty { result.append(ChatMessage(role: .user, text: value)) }
            } else if type == "assistant", let value = json["content"] as? String, !value.isEmpty {
                result.append(ChatMessage(role: .assistant, text: value))
            }
        }
        return result
    }

    /// Merges turns written by the native Grok CLI into GrokDesk's richer
    /// local transcript. The last common user turn is the anchor: only content
    /// after that point may change, so older tool timelines and message IDs are
    /// preserved while externally continued turns become visible.
    static func reconcile(local: [ChatMessage], external: [ChatMessage]) -> [ChatMessage] {
        guard !external.isEmpty else { return local }
        guard !local.isEmpty else { return external }

        for localUserIndex in local.indices.reversed() where local[localUserIndex].role == .user {
            let query = normalized(local[localUserIndex].text)
            guard let externalUserIndex = external.lastIndex(where: {
                $0.role == .user && normalized($0.text) == query
            }) else { continue }

            let localTail = Array(local.dropFirst(localUserIndex + 1))
            let externalTail = Array(external.dropFirst(externalUserIndex + 1))
            guard hasExternalProgress(localTail: localTail, externalTail: externalTail) else { return local }

            var merged = Array(local.prefix(localUserIndex + 1))
            var externalStart = 0
            if let localAssistant = localTail.first(where: { $0.role == .assistant }),
               let firstExternalAssistantIndex = externalTail.firstIndex(where: { $0.role == .assistant }) {
                var assistant = localAssistant
                assistant.text = externalTail[firstExternalAssistantIndex].text
                assistant.isStreaming = false
                merged.append(assistant)
                externalStart = firstExternalAssistantIndex + 1
            }
            merged.append(contentsOf: externalTail.dropFirst(externalStart))
            return merged
        }
        return local
    }

    private static func hasExternalProgress(localTail: [ChatMessage], externalTail: [ChatMessage]) -> Bool {
        if externalTail.contains(where: { $0.role == .user }) { return true }
        guard let externalAssistant = externalTail.first(where: { $0.role == .assistant }) else { return false }
        let localAssistantText = localTail.first(where: { $0.role == .assistant })?.text ?? ""
        return externalAssistant.text.count > localAssistantText.count
            && externalAssistant.text.hasPrefix(localAssistantText)
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func contextUsage(sessionID: String, fallbackTotal: Int) -> ContextUsage? {
        guard let enumerator = FileManager.default.enumerator(at: sessionsRoot, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent == sessionID {
            let signals = url.appendingPathComponent("signals.json")
            guard let data = try? Data(contentsOf: signals),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let used = (json["contextTokensUsed"] as? NSNumber)?.intValue ?? 0
            let total = (json["contextWindowTokens"] as? NSNumber)?.intValue ?? fallbackTotal
            let count = (json["compactionCount"] as? NSNumber)?.intValue ?? 0
            return ContextUsage(usedTokens: used, totalTokens: total > 0 ? total : fallbackTotal,
                                compactionCount: count)
        }
        return nil
    }

    /// Permanent deletion remains recoverable through the macOS Trash.
    @discardableResult
    static func moveToTrash(sessionID: String) throws -> Bool {
        guard let enumerator = FileManager.default.enumerator(at: sessionsRoot, includingPropertiesForKeys: nil) else { return false }
        for case let url as URL in enumerator where url.lastPathComponent == sessionID {
            var destination: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &destination)
            return true
        }
        return false
    }

    private static func extractUserQuery(_ text: String) -> String {
        guard let start = text.range(of: "<user_query>"), let end = text.range(of: "</user_query>", range: start.upperBound..<text.endIndex) else {
            // Grok persists runtime context alongside real prompts. It is input to
            // the agent, not something the user typed, so never surface it as chat.
            if text.contains("<system-reminder>") || text.contains("<user_info>") { return "" }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum StateStore {
    static func load() -> PersistedState {
        guard let data = try? Data(contentsOf: AppPaths.state),
              let state = try? decoder.decode(PersistedState.self, from: data) else {
            return PersistedState()
        }
        return state
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func save(_ state: PersistedState) throws {
        try AppPaths.prepare()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: AppPaths.state, options: [.atomic])
    }
}

enum ShellWords {
    /// Small shell-like tokenizer for the advanced argument field. It never invokes a shell.
    static func parse(_ input: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false
        for char in input {
            if escaped { current.append(char); escaped = false; continue }
            if char == "\\" { escaped = true; continue }
            if let activeQuote = quote {
                if char == activeQuote { quote = nil }
                else { current.append(char) }
            } else if char == "\"" || char == "'" {
                quote = char
            } else if char.isWhitespace {
                if !current.isEmpty { result.append(current); current = "" }
            } else { current.append(char) }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

}

final class CLIProcessService {
    private(set) var process: Process?

    func cancel() {
        guard let process, process.isRunning else { return }
        process.interrupt()
    }

    func runChat(
        binary: String,
        account: GrokAccount,
        conversation: Conversation,
        prompt: String,
        settings: AppSettings,
        onText: @escaping (String) -> Void,
        onThought: @escaping (String) -> Void,
        onDiagnostic: @escaping (String) -> Void,
        completion: @escaping (Result<CLIEndEvent, Error>) -> Void
    ) {
        var args = ["-p", prompt, "--cwd", conversation.cwd, "--output-format", "streaming-json"]
        if let session = conversation.grokSessionID { args += ["--resume", session] }
        if !settings.model.isEmpty { args += ["--model", settings.model] }
        if !settings.reasoningEffort.isEmpty { args += ["--reasoning-effort", settings.reasoningEffort] }
        args += ["--permission-mode", settings.permissionMode, "--max-turns", String(settings.maxTurns)]
        if settings.enableMemory { args.append("--experimental-memory") } else { args.append("--no-memory") }
        if !settings.enableWebSearch { args.append("--disable-web-search") }
        if !settings.enableSubagents { args.append("--no-subagents") }
        args += ShellWords.parse(settings.extraArguments)

        run(binary: binary, arguments: args, grokHome: account.homePath, cwd: conversation.cwd,
            onStdoutLine: { line in
                guard let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = object["type"] as? String else {
                    if !line.isEmpty { onDiagnostic(line) }
                    return
                }
                switch type {
                case "text": onText(object["data"] as? String ?? "")
                case "thought": onThought(object["data"] as? String ?? "")
                case "error": onDiagnostic(object["message"] as? String ?? "Grok 返回未知错误")
                case "end":
                    let usage = object["usage"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                        .flatMap { String(data: $0, encoding: .utf8) }
                    completion(.success(CLIEndEvent(
                        sessionID: object["sessionId"] as? String,
                        stopReason: object["stopReason"] as? String,
                        usageDescription: usage
                    )))
                default: break
                }
            }, onStderrLine: onDiagnostic) { [weak self] result in
                self?.process = nil
                if case .failure = result { completion(result.map { _ in CLIEndEvent() }) }
            }
    }

    func runLogin(binary: String, account: GrokAccount, onLine: @escaping (String) -> Void,
                  completion: @escaping (Result<Void, Error>) -> Void) {
        run(binary: binary, arguments: ["login", "--oauth"], grokHome: account.homePath,
            cwd: FileManager.default.homeDirectoryForCurrentUser.path,
            onStdoutLine: onLine, onStderrLine: onLine, completion: completion)
    }

    func listModels(binary: String, account: GrokAccount,
                    completion: @escaping (Result<[String], Error>) -> Void) {
        var models: [String] = []
        let consume: (String) -> Void = { line in
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.hasPrefix("* ") || value.hasPrefix("- ") else { return }
            let id = value.dropFirst(2).split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            if !id.isEmpty, !models.contains(id) { models.append(id) }
        }
        run(binary: binary, arguments: ["models"], grokHome: account.homePath,
            cwd: FileManager.default.homeDirectoryForCurrentUser.path,
            onStdoutLine: consume, onStderrLine: { _ in }) { result in
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success: completion(.success(models))
                }
            }
    }

    private func run(
        binary: String, arguments: [String], grokHome: String, cwd: String,
        onStdoutLine: @escaping (String) -> Void,
        onStderrLine: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let process = Process()
        let stdout = Pipe(), stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        var environment = ProcessInfo.processInfo.environment
        environment["GROK_HOME"] = grokHome
        environment["PATH"] = URL(fileURLWithPath: binary).deletingLastPathComponent().path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        process.environment = environment
        process.standardOutput = stdout
        process.standardError = stderr
        self.process = process

        let stdoutReader = LineReader(onLine: onStdoutLine)
        let stderrReader = LineReader(onLine: onStderrLine)
        stdout.fileHandleForReading.readabilityHandler = { stdoutReader.consume($0.availableData) }
        stderr.fileHandleForReading.readabilityHandler = { stderrReader.consume($0.availableData) }
        process.terminationHandler = { process in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            stdoutReader.finish(); stderrReader.finish()
            DispatchQueue.main.async {
                if process.terminationStatus == 0 { completion(.success(())) }
                else { completion(.failure(NSError(domain: "GrokDesk.CLI", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Grok CLI 退出码 \(process.terminationStatus)"]))) }
            }
        }
        do { try process.run() }
        catch { DispatchQueue.main.async { completion(.failure(error)) } }
    }
}

private final class LineReader: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()
    private let onLine: (String) -> Void
    init(onLine: @escaping (String) -> Void) { self.onLine = onLine }

    func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock(); buffer.append(data)
        while let range = buffer.range(of: Data([0x0A])) {
            let line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex...range.lowerBound)
            if let string = String(data: line, encoding: .utf8) { DispatchQueue.main.async { self.onLine(string) } }
        }
        lock.unlock()
    }
    func finish() {
        lock.lock(); let rest = buffer; buffer.removeAll(); lock.unlock()
        if !rest.isEmpty, let string = String(data: rest, encoding: .utf8) { DispatchQueue.main.async { self.onLine(string) } }
    }
}

enum QuotaService {
    static func fetch(account: GrokAccount, clientVersion: String = "0.2.101") async -> QuotaSnapshot {
        do {
            let token = try readToken(from: account.authPath)
            async let weeklyData = request(token: token, query: "format=credits", clientVersion: clientVersion)
            async let monthlyData = request(token: token, query: nil, clientVersion: clientVersion)
            let (weekly, monthly) = try await (weeklyData, monthlyData)
            return parse(weekly: weekly, monthly: monthly)
        } catch {
            return QuotaSnapshot(checkedAt: Date(), error: error.localizedDescription)
        }
    }

    private static func readToken(from path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let json = try JSONSerialization.jsonObject(with: data)
        if let token = findString(keys: ["key", "access_token", "accessToken"], in: json) { return token }
        throw NSError(domain: "GrokDesk.Auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "auth.json 中没有可用登录令牌"])
    }

    private static func findString(keys: Set<String>, in value: Any) -> String? {
        if let dict = value as? [String: Any] {
            for key in keys { if let value = dict[key] as? String, !value.isEmpty { return value } }
            for child in dict.values { if let found = findString(keys: keys, in: child) { return found } }
        } else if let array = value as? [Any] {
            for child in array { if let found = findString(keys: keys, in: child) { return found } }
        }
        return nil
    }

    private static func request(token: String, query: String?, clientVersion: String) async throws -> Any {
        var components = URLComponents(string: "https://cli-chat-proxy.grok.com/v1/billing")!
        if let query { components.query = query }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientVersion, forHTTPHeaderField: "x-grok-client-version")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "GrokDesk.Billing", code: code, userInfo: [NSLocalizedDescriptionKey: "额度接口 HTTP \(code)，可先重新登录或发起一次对话刷新令牌"])
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func parse(weekly: Any, monthly: Any) -> QuotaSnapshot {
        let weeklyUsed = findNumber(keys: ["creditUsagePercent"], in: weekly)
        let limit = findNumber(keys: ["monthlyLimit", "monthly_limit"], in: monthly)
        let used = findNumber(keys: ["used", "monthlyUsed", "monthly_used"], in: monthly)
        let remaining = findNumber(keys: ["remaining", "monthlyRemaining", "monthly_remaining"], in: monthly)
            ?? ((limit != nil && used != nil) ? max(0, limit! - used!) : nil)
        let periodEnd = findString(keys: ["end", "billingPeriodEnd", "billing_period_end"], in: weekly)
            ?? findString(keys: ["billingPeriodEnd", "billing_period_end"], in: monthly)
        return QuotaSnapshot(
            weeklyUsedPercent: weeklyUsed,
            weeklyRemainingPercent: weeklyUsed.map { max(0, 100 - $0) },
            monthlyLimit: limit, monthlyUsed: used, monthlyRemaining: remaining,
            periodEnd: periodEnd, checkedAt: Date(), error: nil
        )
    }

    private static func findNumber(keys: Set<String>, in value: Any) -> Double? {
        if let dict = value as? [String: Any] {
            for key in keys {
                if let number = dict[key] as? NSNumber { return number.doubleValue }
                if let string = dict[key] as? String, let number = Double(string) { return number }
            }
            for child in dict.values { if let found = findNumber(keys: keys, in: child) { return found } }
        } else if let array = value as? [Any] {
            for child in array { if let found = findNumber(keys: keys, in: child) { return found } }
        }
        return nil
    }
}
