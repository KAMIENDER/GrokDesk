import SwiftUI

extension AppSettings {
    var effectiveLanguage: String { language == "en" ? "en" : "zh-Hans" }
    var effectiveAppearance: String {
        ["system", "light", "dark"].contains(appearance ?? "") ? appearance! : "system"
    }
    var appLocale: Locale { Locale(identifier: effectiveLanguage) }
    var preferredColorScheme: ColorScheme? {
        switch effectiveAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

/// Localizes strings that travel through model or helper APIs as `String`.
/// SwiftUI literals use Localizable.strings automatically; this helper covers
/// dynamic labels where `LocalizedStringKey` would otherwise be lost.
enum L10n {
    static func text(_ key: String, language: String) -> String {
        guard language == "en" else { return key }
        return english[key] ?? key
    }

    private static let english: [String: String] = [
        "新对话": "New chat", "项目": "Projects", "设置": "Settings",
        "账号与额度": "Accounts & usage", "刷新额度": "Refresh usage",
        "添加 Grok 账号": "Add Grok account", "尚未配置": "Not configured",
        "额度待刷新": "Usage pending", "选择项目": "Choose project",
        "运行详情": "Run details", "过程": "Process", "思考过程": "Reasoning",
        "Skills 与扩展": "Skills & extensions", "文件与搜索": "Files & search",
        "上下文与记忆": "Context & memory",
        "命令与任务": "Commands & tasks", "执行计划": "Plan",
        "权限与交互": "Permissions & interactions", "运行与系统": "Runtime & system",
        "其他操作": "Other activity", "输入": "Input", "内容": "Content", "结果": "Result",
        "完成": "Completed", "失败": "Failed", "等待": "Pending", "运行中": "Running",
        "通用": "General", "Agent 能力": "Agent capabilities", "兼容性": "Compatibility",
        "账号与用量": "Accounts & usage", "已归档对话": "Archived chats",
        "选择 Grok 工作文件夹": "Choose a Grok workspace",
        "Grok 将在这个文件夹中读取文件、修改代码并运行工具。": "Grok will read files, modify code, and run tools in this folder.",
        "选择文件夹": "Choose folder", "本机 Grok CLI": "Local Grok CLI",
        "就绪": "Ready", "正在连接 Grok Agent": "Connecting to Grok Agent",
        "Agent 已连接": "Agent connected", "Grok 正在处理": "Grok is processing",
        "已追加到当前运行": "Added to current run", "额度已刷新": "Usage refreshed",
        "正在自动压缩上下文": "Auto-compacting context", "上下文已自动压缩": "Context auto-compacted",
        "自动压缩失败": "Auto-compaction failed", "工具调用": "Tool call",
        "正在准备安装最新版 Grok Build…": "Preparing to install the latest Grok Build…",
        "Grok Build 已安装": "Grok Build installed", "Grok Build 安装失败": "Grok Build installation failed",
        "Grok 请求补充信息": "Grok requests more information", "Grok 请求确认计划": "Grok requests plan approval",
        "Grok 请求执行操作": "Grok requests an action", "任务已转入后台": "Task moved to background",
        "后台任务完成": "Background task completed", "Runtime 正在重试": "Runtime is retrying",
        "正在写入 Memory": "Writing Memory", "Memory 写入完成": "Memory written",
        "本轮执行完成": "Turn completed", "Session 回顾": "Session recap"
    ]
}
