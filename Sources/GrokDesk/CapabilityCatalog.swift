import Foundation

struct CapabilityDescriptor: Identifiable, Hashable {
    var id: String { method }
    var category: String
    var method: String
    var template: String
}

/// Callable Grok ACP extension catalog derived from the checked-in Grok Build router.
/// The free-form method field remains authoritative, so a newer runtime is usable before
/// this convenience catalog is updated.
enum GrokCapabilityCatalog {
    static let all: [CapabilityDescriptor] = {
        let groups: [(String, [String])] = [
            ("Session", ["x.ai/session/info", "x.ai/session/list", "x.ai/sessions/list", "x.ai/session/search", "x.ai/session/load_history", "x.ai/session/fork", "x.ai/session/rename", "x.ai/session/delete", "x.ai/session/repair", "x.ai/session/rehydrate", "x.ai/session/close", "x.ai/session/updates", "x.ai/session/update_mcp_servers", "x.ai/prompt_history", "x.ai/commands/list", "x.ai/compact_conversation", "x.ai/rewind/points", "x.ai/rewind/execute", "x.ai/restore_code", "x.ai/recap", "x.ai/share_session", "x.ai/workspaces/list"]),
            ("Files", ["x.ai/fs/list", "x.ai/fs/exists", "x.ai/fs/read_file", "x.ai/fs/write_file", "x.ai/fs/delete_file"]),
            ("Search & Code", ["x.ai/search/content", "x.ai/search/fuzzy/open", "x.ai/search/fuzzy/change", "x.ai/search/fuzzy/close", "x.ai/code/status", "x.ai/code/find-definitions", "x.ai/code/find-references", "x.ai/code/goto-definition", "x.ai/code/goto-references"]),
            ("Git", ["x.ai/git/info", "x.ai/git/status", "x.ai/git/diffs", "x.ai/git/files", "x.ai/git/branches", "x.ai/git/current_commit", "x.ai/git/stage", "x.ai/git/stage/content", "x.ai/git/unstage", "x.ai/git/discard", "x.ai/git/commit", "x.ai/git/stash", "x.ai/git/checkout", "x.ai/git/checkout_commit", "x.ai/git/checkout_session_head", "x.ai/git/serialize_changes"]),
            ("Worktree", ["x.ai/git/worktree/list", "x.ai/git/worktree/show", "x.ai/git/worktree/status", "x.ai/git/worktree/create", "x.ai/git/worktree/create_from_worktree", "x.ai/git/worktree/apply", "x.ai/git/worktree/remove", "x.ai/git/worktree/gc", "x.ai/git/worktree/resume_session", "x.ai/git/worktree/db/path", "x.ai/git/worktree/db/stats", "x.ai/git/worktree/db/rebuild"]),
            ("Terminal", ["x.ai/terminal/list", "x.ai/terminal/create", "x.ai/terminal/output", "x.ai/terminal/background", "x.ai/terminal/wait_for_exit", "x.ai/terminal/kill", "x.ai/terminal/release", "x.ai/terminal/pty/create", "x.ai/terminal/pty/load", "x.ai/terminal/pty/input", "x.ai/terminal/pty/resize"]),
            ("Tasks & Queue", ["x.ai/task/list", "x.ai/task/kill", "x.ai/queue/clear", "x.ai/queue/edit", "x.ai/queue/remove", "x.ai/queue/reorder", "x.ai/queue/interject", "x.ai/interject", "x.ai/scheduler/delete"]),
            ("MCP", ["x.ai/mcp/list", "x.ai/mcp/call", "x.ai/mcp/read_resource", "x.ai/mcp/auth_status", "x.ai/mcp/auth_trigger", "x.ai/mcp/setup", "x.ai/mcp/toggle", "x.ai/mcp/toggle_tool", "x.ai/mcp/upsert", "x.ai/mcp/delete"]),
            ("Skills", ["x.ai/skills/list", "x.ai/skills/config", "x.ai/skills/add", "x.ai/skills/remove", "x.ai/skills/toggle", "x.ai/skills/reset", "x.ai/skills/refresh-baseline"]),
            ("Plugins & Hooks", ["x.ai/plugins/list", "x.ai/plugins/action", "x.ai/plugins/reload", "x.ai/marketplace/list", "x.ai/marketplace/action", "x.ai/hooks/list", "x.ai/hooks/action", "x.ai/hooks/run"]),
            ("Memory & Subagents", ["x.ai/memory/flush", "x.ai/memory/rewrite", "x.ai/subagent/list_running", "x.ai/subagent/get", "x.ai/subagent/cancel", "x.ai/toggle_plan_mode", "x.ai/permissions/reset"]),
            ("Review & Changes", ["x.ai/hunk-tracker/get-summary", "x.ai/hunk-tracker/get-files", "x.ai/hunk-tracker/get-hunks", "x.ai/hunk-tracker/get-all-file-contents", "x.ai/hunk-tracker/hunk-action", "x.ai/hunk-tracker/file-action", "x.ai/hunk-tracker/turn-action", "x.ai/hunk-tracker/all-action", "x.ai/review", "x.ai/review/comment", "x.ai/review/comment/delete", "x.ai/pr/status"]),
            ("Account & Billing", ["x.ai/auth/info", "x.ai/auth/get_url", "x.ai/auth/submit_code", "x.ai/auth/cancel", "x.ai/auth/logout", "x.ai/auth/check_subscription", "x.ai/billing", "x.ai/auto-topup-rule", "x.ai/privacy/setCodingDataRetention"]),
            ("Cloud & Bundle", ["x.ai/cloud/env/list", "x.ai/cloud/env/create", "x.ai/cloud/env/update", "x.ai/cloud/env/delete", "x.ai/cloud/terminate", "x.ai/bundle/status", "x.ai/bundle/sync", "x.ai/bundle/entry/get"]),
            ("Settings & Feedback", ["x.ai/settings/update", "x.ai/models/update", "x.ai/folder_trust/request", "x.ai/feedback", "x.ai/feedback/dismiss", "x.ai/follow_ups", "x.ai/suggest", "x.ai/btw"])
        ]
        return groups.flatMap { category, methods in methods.map { CapabilityDescriptor(category: category, method: $0, template: template(for: $0)) } }
    }()

    private static func template(for method: String) -> String {
        switch method {
        case "x.ai/fs/list": return #"{"path":".","depth":2,"limit":500}"#
        case "x.ai/fs/read_file": return #"{"path":"README.md"}"#
        case "x.ai/fs/write_file": return #"{"path":"path/to/file","content":""}"#
        case "x.ai/fs/delete_file": return #"{"path":"path/to/file"}"#
        case "x.ai/git/status": return #"{"includeUntracked":true,"includeStats":true}"#
        case "x.ai/git/diffs": return #"{"from":"HEAD","to":"working","includePatch":true,"includeContent":true}"#
        case "x.ai/terminal/create": return #"{"command":"/bin/zsh","args":["-lc","pwd"],"cwd":null}"#
        case "x.ai/terminal/output", "x.ai/terminal/kill", "x.ai/terminal/release": return #"{"terminalId":""}"#
        case "x.ai/skills/list": return #"{"cwd":"."}"#
        case "x.ai/skills/toggle": return #"{"name":"","enabled":true,"cwd":"."}"#
        case "x.ai/mcp/list": return #"{"cache":true}"#
        case "x.ai/session/search": return #"{"query":"","limit":50}"#
        default: return "{}"
        }
    }
}
