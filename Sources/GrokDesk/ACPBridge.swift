import Foundation
import UniformTypeIdentifiers

/// Version-tolerant ACP JSON-RPC bridge. Standard ACP and every `x.ai/*` payload
/// are preserved as JSON, so unknown/new Grok extensions are observable instead of dropped.
final class ACPBridge {
    typealias JSONObject = [String: Any]
    var onUpdate: ((String, JSONObject) -> Void)?
    var onInteraction: ((String, String, JSONObject) -> Void)?
    var onDiagnostic: ((String) -> Void)?
    var onModelState: ((JSONObject) -> Void)?

    private let binary: String
    private let account: GrokAccount
    private let settings: AppSettings
    private let cwd: String
    private var process: Process?
    private var input: FileHandle?
    private var nextID = 1
    private struct PendingRequest {
        let method: String
        let completion: (Result<JSONObject, Error>) -> Void
    }
    private var callbacks: [String: PendingRequest] = [:]
    private var reader: ACPLineReader?
    private var permissionRequests: [String: Any] = [:]
    private var suppressReplayUpdates = false
    private(set) var sessionID: String?
    var accountID: UUID { account.id }

    init(binary: String, account: GrokAccount, settings: AppSettings, cwd: String) {
        self.binary = binary; self.account = account; self.settings = settings; self.cwd = cwd
    }

    func start(existingSessionID: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        suppressReplayUpdates = existingSessionID != nil
        let process = Process(), stdout = Pipe(), stderr = Pipe(), stdin = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        var args = ["agent"]
        if !settings.model.isEmpty { args += ["--model", settings.model] }
        args.append("stdio")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        var env = ProcessInfo.processInfo.environment
        env["GROK_HOME"] = account.homePath
        env["GROK_MEMORY"] = settings.enableMemory ? "1" : "0"
        // Grok Build reads these before creating the sampler and its native
        // auto-compaction policy. Keeping them process-scoped avoids rewriting
        // the user's shared ~/.grok/config.toml for a GrokDesk preference.
        env["GROK_DEBUG_CONTEXT_WINDOW"] = String(settings.effectiveContextWindowTokens)
        env["GROK_AUTO_COMPACT_THRESHOLD_PERCENT"] = String(settings.effectiveAutoCompactThresholdPercent)
        if !settings.enableWebSearch { env["GROK_WEB_FETCH"] = "0" }
        env["PATH"] = URL(fileURLWithPath: binary).deletingLastPathComponent().path + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        process.environment = env
        process.standardInput = stdin; process.standardOutput = stdout; process.standardError = stderr
        self.process = process; input = stdin.fileHandleForWriting

        let reader = ACPLineReader { [weak self] line in self?.receive(line) }
        self.reader = reader
        stdout.fileHandleForReading.readabilityHandler = { reader.consume($0.availableData) }
        let errReader = ACPLineReader { [weak self] line in DispatchQueue.main.async { self?.onDiagnostic?(line) } }
        stderr.fileHandleForReading.readabilityHandler = { errReader.consume($0.availableData) }
        process.terminationHandler = { [weak self] p in
            DispatchQueue.main.async { self?.onDiagnostic?("Grok Agent 已退出（\(p.terminationStatus)）") }
        }
        do { try process.run() } catch { completion(.failure(error)); return }

        let capabilities: JSONObject = [
            "fs": ["readTextFile": false, "writeTextFile": false],
            "terminal": false,
            "_meta": ["x.ai/incrementalBashOutput": true, "x.ai/hunkTracker": ["mode": "full"],
                      "x.ai/gitHeadChanged": true]
        ]
        request("initialize", params: ["protocolVersion": 1, "clientCapabilities": capabilities,
            "_meta": ["clientType": "grokdesk-macos", "clientVersion": "0.1.0"]]) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let initResult):
                self.authenticateIfNeeded(initResult) { authResult in
                    switch authResult {
                    case .failure(let error): completion(.failure(error))
                    case .success:
                        let method = existingSessionID == nil ? "session/new" : "session/load"
                        var params: JSONObject = ["cwd": self.cwd, "mcpServers": []]
                        if let existingSessionID { params["sessionId"] = existingSessionID }
                        var meta: JSONObject = [
                            "yoloMode": self.settings.permissionMode == "bypassPermissions",
                            "autoMode": self.settings.permissionMode == "auto"
                        ]
                        if self.settings.permissionMode == "plan" {
                            meta["agentProfile"] = self.settings.enableSubagents ? "grok-build-plan" : "grok-build-plan-no-subagents"
                        }
                        if !self.settings.reasoningEffort.isEmpty { meta["reasoningEffort"] = self.settings.reasoningEffort }
                        params["_meta"] = meta
                        self.request(method, params: params) { sessionResult in
                            switch sessionResult {
                            case .failure(let error): completion(.failure(error))
                            case .success(let value):
                                guard let session = value["sessionId"] as? String ?? existingSessionID else {
                                    completion(.failure(Self.error("ACP 没有返回 sessionId"))); return
                                }
                                self.sessionID = session
                                if let models = value["models"] as? JSONObject { self.onModelState?(models) }
                                self.suppressReplayUpdates = false
                                completion(.success(session))
                            }
                        }
                    }
                }
            }
        }
    }

    func prompt(_ text: String, attachments: [URL] = [], completion: @escaping (Result<JSONObject, Error>) -> Void) {
        guard let sessionID else { completion(.failure(Self.error("ACP Session 尚未就绪"))); return }
        var blocks: [JSONObject] = [["type": "text", "text": text]]
        for url in attachments {
            let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType) ?? .data
            if type.conforms(to: .image), let data = try? Data(contentsOf: url), data.count <= 25_000_000 {
                blocks.append(["type": "image", "data": data.base64EncodedString(), "mimeType": type.preferredMIMEType ?? "application/octet-stream"])
            } else if type.conforms(to: .audio), let data = try? Data(contentsOf: url), data.count <= 25_000_000 {
                blocks.append(["type": "audio", "data": data.base64EncodedString(), "mimeType": type.preferredMIMEType ?? "application/octet-stream"])
            } else {
                blocks.append(["type": "resource_link", "name": url.lastPathComponent, "uri": url.absoluteString,
                               "mimeType": type.preferredMIMEType ?? "application/octet-stream"])
            }
        }
        request("session/prompt", params: ["sessionId": sessionID,
            "prompt": blocks], completion: completion)
    }

    func cancel() {
        guard let sessionID else { return }
        notify("session/cancel", params: ["sessionId": sessionID, "reason": "user"])
    }

    /// Steer the currently running turn through Grok Build's native mid-turn
    /// interjection channel. This is not a second concurrent session/prompt.
    func interject(_ text: String) {
        guard let sessionID else { return }
        notify("x.ai/interject", params: [
            "sessionId": sessionID,
            "text": text,
            "interjectionId": UUID().uuidString
        ])
    }

    /// Grok exposes reasoning effort through the ACP model switch request meta.
    /// Re-selecting the current model applies the new effort without replacing the session.
    func setModel(_ modelID: String, reasoningEffort: String,
                  completion: @escaping (Result<JSONObject, Error>) -> Void) {
        guard let sessionID else { completion(.failure(Self.error("ACP Session 尚未就绪"))); return }
        request("session/setModel", params: [
            "sessionId": sessionID,
            "modelId": modelID,
            "_meta": ["reasoningEffort": reasoningEffort]
        ], completion: completion)
    }

    func callExtension(_ method: String, params: JSONObject = [:], completion: @escaping (Result<JSONObject, Error>) -> Void) {
        var value = params
        if value["sessionId"] == nil, let sessionID { value["sessionId"] = sessionID }
        request(method, params: value, completion: completion)
    }

    func sendExtensionNotification(_ method: String, params: JSONObject = [:]) {
        var value = params
        if value["sessionId"] == nil, let sessionID { value["sessionId"] = sessionID }
        notify(method, params: value)
    }

    func answerPermission(requestID: String, optionID: String?) {
        let result: JSONObject
        if let optionID { result = ["outcome": ["outcome": "selected", "optionId": optionID]] }
        else { result = ["outcome": ["outcome": "cancelled"]] }
        answerInteraction(requestID: requestID, result: result)
    }

    func answerInteraction(requestID: String, result: JSONObject) {
        send(["jsonrpc": "2.0", "id": permissionRequests.removeValue(forKey: requestID) ?? requestID, "result": result])
    }

    func stop() { process?.terminate(); process = nil }

    private func authenticateIfNeeded(_ result: JSONObject, completion: @escaping (Result<Void, Error>) -> Void) {
        let meta = result["_meta"] as? JSONObject
        let defaultID = meta?["defaultAuthMethodId"] as? String
        let methods = result["authMethods"] as? [JSONObject] ?? []
        guard let methodID = defaultID ?? methods.first?["id"] as? String else { completion(.success(())); return }
        request("authenticate", params: ["methodId": methodID, "_meta": ["headless": true]]) {
            completion($0.map { _ in () })
        }
    }

    private func request(_ method: String, params: JSONObject, completion: @escaping (Result<JSONObject, Error>) -> Void) {
        let id = String(nextID); nextID += 1
        callbacks[id] = PendingRequest(method: method, completion: completion)
        send(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
    }
    private func notify(_ method: String, params: JSONObject) { send(["jsonrpc": "2.0", "method": method, "params": params]) }

    private func send(_ object: JSONObject) {
        guard JSONSerialization.isValidJSONObject(object), let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        var line = data; line.append(0x0A)
        do { try input?.write(contentsOf: line) } catch { onDiagnostic?(error.localizedDescription) }
    }

    private func receive(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? JSONObject else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let idValue = json["id"], json["method"] == nil {
                let id = String(describing: idValue)
                guard let pending = self.callbacks.removeValue(forKey: id) else { return }
                if let error = json["error"] as? JSONObject {
                    let message = error["message"] as? String ?? "ACP 请求失败"
                    let numericCode = ACPDiagnosticPolicy.integerCode(from: error["code"])
                    let code = error["code"].map { String(describing: $0) }
                    let data = error["data"].map { String(describing: $0) }
                    let diagnostic = [code.map { "code=\($0)" }, data.map { "data=\($0)" }]
                        .compactMap { $0 }.joined(separator: ", ")
                    if !diagnostic.isEmpty,
                       ACPDiagnosticPolicy.shouldPublish(method: pending.method, errorCode: numericCode) {
                        self.onDiagnostic?("ACP 错误：\(message)（\(diagnostic)）")
                    }
                    pending.completion(.failure(Self.error(message)))
                } else if let object = json["result"] as? JSONObject { pending.completion(.success(object)) }
                else { pending.completion(.success(["_value": json["result"] ?? NSNull()])) }
                return
            }
            var method = json["method"] as? String ?? "unknown"
            var params = json["params"] as? JSONObject ?? [:]
            // Leader mode may wrap extension reverse-requests as `_x.ai/*`.
            if method.hasPrefix("_x.ai/"), let innerMethod = params["method"] as? String,
               let innerParams = params["params"] as? JSONObject { method = innerMethod; params = innerParams }
            if json["id"] != nil && (method == "session/request_permission" || method == "x.ai/ask_user_question" || method == "x.ai/exit_plan_mode") {
                let requestID = String(describing: json["id"]!)
                self.permissionRequests[requestID] = json["id"]!
                self.onInteraction?(method, requestID, params)
            } else if !self.suppressReplayUpdates { self.onUpdate?(method, params) }
        }
    }

    private static func error(_ message: String) -> Error {
        NSError(domain: "GrokDesk.ACP", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private final class ACPLineReader: @unchecked Sendable {
    private var data = Data(); private let lock = NSLock(); private let handler: (String) -> Void
    init(handler: @escaping (String) -> Void) { self.handler = handler }
    func consume(_ next: Data) {
        guard !next.isEmpty else { return }; lock.lock(); data.append(next)
        while let newline = data.firstIndex(of: 0x0A) {
            let line = data.prefix(upTo: newline); data.removeSubrange(...newline)
            if let string = String(data: line, encoding: .utf8) { handler(string) }
        }
        lock.unlock()
    }
}
