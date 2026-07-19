# GrokDesk

<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="GrokDesk icon">
</p>

<p align="center">
  A native, open-source macOS desktop client for <a href="https://github.com/xai-org/grok-build">Grok Build</a>.
</p>

> [!IMPORTANT]
> GrokDesk is an independent community project. It is not affiliated with or endorsed by xAI. Grok and Grok Build are trademarks of their respective owner.

[中文](#中文) · [English](#english)

## 中文

GrokDesk 将本机 Grok Build Runtime 的 ACP/JSON-RPC 能力呈现为现代化的原生 SwiftUI 桌面界面。它不是内嵌终端，也不会重新实现 Grok Agent；文件、Shell、Git、MCP、Skills、Plugins、Hooks、Memory、Subagent 等能力仍由本机 Grok Build 执行。

### 功能

- 原生 macOS 会话界面，支持 Markdown、代码块、表格、链接和附件预览。
- 按真实执行顺序展示思考、文件与搜索、命令、Skills、Hooks、计划、权限和 Runtime 事件；相邻同类事件可折叠，原始详情可查看。
- 直接读取并恢复本机 Grok Session，按工作文件夹组织对话，支持归档、搜索和删除。
- 选择工作目录、模型、推理强度和权限模式，并支持停止、追加提示和自动上下文压缩。
- Skills 浏览、启停、详情查看和斜杠触发；保留未知 ACP / `x.ai/*` 扩展事件，避免新能力被旧 UI 静默丢弃。
- 图片和文件选择、拖放、复制粘贴以及详情预览。
- 多账号登录、改名、启停和拖拽排序；支持智能额度优先、顺序、轮询和固定账号路由。
- 周/月额度、本轮账号、Context Window 和 Runtime 状态可视化。
- 浅色、深色和跟随系统外观；简体中文与 English。

### 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon 或 Intel Mac
- 可用的 Grok Build 账号

GrokDesk **不包含 Grok Build 源码或二进制**。首次启动时会检查设置路径、`~/.grok/bin/grok`、Homebrew 常见目录和 `PATH`。若未安装，App 会先征求确认，再按照 [Grok Build 官方仓库](https://github.com/xai-org/grok-build#installing-the-released-binary) 的说明调用 xAI 官方安装器获取最新版；不会静默下载安装。

也可以手动安装：

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
grok --version
```

### 从源码构建

```bash
git clone https://github.com/KAMIENDER/GrokDesk.git
cd GrokDesk
./script/build_and_run.sh --verify
```

或只构建 Swift Package：

```bash
swift build -c release --product GrokDesk
```

生成的应用位于 `dist/GrokDesk.app`。当前使用临时签名，首次打开时可能需要在“系统设置 → 隐私与安全性”中确认。

### 本地数据与隐私

GrokDesk 的 UI 状态和附加数据保存在：

```text
~/Library/Application Support/GrokDesk/
```

Grok Build 的默认数据仍位于 `~/.grok/`。多账号凭据保存在 GrokDesk 为每个账号建立的独立 `GROK_HOME` 中；Session 历史保持本机共享，不绑定某个账号，因此健康账号可以继续同一个 Session。GrokDesk 不会将 Token、Session、Memory 或工作区文件上传到本项目仓库。

## English

GrokDesk presents the ACP/JSON-RPC capabilities of a local Grok Build runtime through a modern native SwiftUI interface. It does not embed a terminal or reimplement the agent. File operations, shell commands, Git, MCP, Skills, Plugins, Hooks, Memory, and subagents continue to run through Grok Build.

### Highlights

- Native conversations with Markdown, code blocks, tables, links, and attachment previews.
- Chronological, expandable activity for reasoning, files, commands, Skills, Hooks, plans, permissions, and runtime events.
- Local Grok Session discovery and resume, grouped by workspace, with archive and search.
- Workspace, model, reasoning effort, permission controls, stop/interject, and automatic context compaction.
- Skill management and slash invocation, plus lossless retention of unknown ACP and `x.ai/*` extension events.
- File and image selection, drag and drop, clipboard paste, and full previews.
- Isolated multi-account authentication with smart-usage, sequential, round-robin, and fixed-account routing.
- Weekly/monthly usage, active account, context-window, and runtime status visibility.
- System, light, and dark appearance with Simplified Chinese and English.

### Requirements and runtime setup

GrokDesk requires macOS 14 or later and a Grok Build account. The repository does **not** vendor Grok Build source or binaries.

At launch, GrokDesk checks the configured path, `~/.grok/bin/grok`, common Homebrew locations, and `PATH`. If the runtime is missing, it asks before using the official xAI installer documented by the [Grok Build repository](https://github.com/xai-org/grok-build#installing-the-released-binary). No installation is performed without confirmation.

### Build from source

```bash
git clone https://github.com/KAMIENDER/GrokDesk.git
cd GrokDesk
./script/build_and_run.sh --verify
```

The packaged app is written to `dist/GrokDesk.app`.

## Architecture

```text
GrokDesk (SwiftUI)
  ├─ AppModel / local state
  ├─ ACPBridge (grok agent stdio)
  ├─ local Session and Skill indexes
  └─ isolated account GROK_HOME environments
       └─ local Grok Build runtime
```

The ACP event name and raw payload remain authoritative. UI adapters add presentation for known event types without discarding unknown events from newer runtime versions.

## Contributing

Issues and pull requests are welcome. Please keep credentials, local Session data, generated app bundles, and Grok Build source out of commits.

## License

[MIT](LICENSE)
