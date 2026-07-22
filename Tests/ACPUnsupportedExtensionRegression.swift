import Foundation

@main
enum ACPUnsupportedExtensionRegression {
    static func main() {
        precondition(
            !ACPDiagnosticPolicy.shouldPublish(method: "x.ai/commands/list", errorCode: -32601),
            "unsupported x.ai capability probes must not overwrite the global session status"
        )
        precondition(
            !ACPDiagnosticPolicy.shouldPublish(method: "x.ai/skills/list", errorCode: -32601),
            "unsupported skills discovery must quietly fall back to the local index"
        )
        precondition(
            ACPDiagnosticPolicy.shouldPublish(method: "session/prompt", errorCode: -32601),
            "missing standard ACP methods are real session failures and must remain visible"
        )
        precondition(
            ACPDiagnosticPolicy.shouldPublish(method: "x.ai/skills/toggle", errorCode: -32602),
            "extension failures other than method-not-found must remain diagnosable"
        )

        print("ACP unsupported extension regression passed")
    }
}
