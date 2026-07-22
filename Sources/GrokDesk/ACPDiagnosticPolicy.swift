import Foundation

/// Decides which JSON-RPC failures represent a broken conversation and may
/// replace the global header status. Grok Build extensions are versioned
/// independently from standard ACP; an unsupported optional extension must
/// fall back at its call site instead of looking like a session failure.
enum ACPDiagnosticPolicy {
    static func shouldPublish(method: String, errorCode: Int?) -> Bool {
        !(method.hasPrefix("x.ai/") && errorCode == -32601)
    }

    static func integerCode(from value: Any?) -> Int? {
        switch value {
        case let value as Int: return value
        case let value as NSNumber: return value.intValue
        case let value as String: return Int(value)
        default: return nil
        }
    }
}
