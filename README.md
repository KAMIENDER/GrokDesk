# GrokDesk

<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="GrokDesk icon">
</p>

<p align="center">
  A native, open-source macOS desktop client for <a href="https://github.com/xai-org/grok-build">Grok Build</a>.
</p>

<p align="center">
  English · <a href="README.zh-CN.md">简体中文</a>
</p>

> [!IMPORTANT]
> GrokDesk is an independent community project. It is not affiliated with or endorsed by xAI. Grok and Grok Build are trademarks of their respective owner.

GrokDesk presents the ACP/JSON-RPC capabilities of a local Grok Build runtime through a modern native SwiftUI interface. It does not embed a terminal or reimplement the agent. File operations, shell commands, Git, MCP, Skills, Plugins, Hooks, Memory, and subagents continue to run through Grok Build.

## Highlights

- Native macOS conversations with Markdown, code blocks, tables, links, and attachment previews.
- Chronological, expandable activity for reasoning, files, searches, commands, Skills, Hooks, plans, permissions, interactions, and runtime events.
- Local Grok Session discovery and resume, grouped by workspace, with archive, search, and deletion controls.
- Workspace, model, reasoning effort, permission controls, stop/interject, context-window visibility, and automatic context compaction.
- Skill management and slash invocation, plus lossless retention of unknown ACP and `x.ai/*` extension events.
- File and image selection, drag and drop, clipboard paste, and full previews.
- Isolated multi-account authentication with renaming, ordering, health controls, and smart-usage, sequential, round-robin, or fixed-account routing.
- Weekly/monthly usage, active account, context-window, and runtime status visibility.
- System, light, and dark appearance with English and Simplified Chinese interfaces.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- A valid Grok Build account

GrokDesk does **not** vendor Grok Build source or binaries. At launch, it checks the configured runtime path, `~/.grok/bin/grok`, common Homebrew locations, and `PATH`. If Grok Build is unavailable, GrokDesk asks for confirmation before running the official xAI installer documented by the [Grok Build repository](https://github.com/xai-org/grok-build#installing-the-released-binary). It never installs the runtime silently.

You can also install Grok Build manually:

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
grok --version
```

## Build from source

```bash
git clone https://github.com/KAMIENDER/GrokDesk.git
cd GrokDesk
./script/build_and_run.sh --verify
```

To build only the Swift package:

```bash
swift build -c release --product GrokDesk
```

The packaged application is written to `dist/GrokDesk.app`. Development builds use ad-hoc signing, so macOS may ask you to confirm the first launch in **System Settings → Privacy & Security**.

## Architecture

```text
GrokDesk (SwiftUI)
  ├─ AppModel and local presentation state
  ├─ ACPBridge (Grok Build agent over stdio)
  ├─ local Session and Skill indexes
  └─ isolated per-account GROK_HOME environments
       └─ local Grok Build runtime
```

ACP event names and raw payloads remain authoritative. UI adapters provide richer presentation for known event types without discarding unknown events introduced by newer runtime versions.

## Local data and privacy

GrokDesk stores its UI state and supplemental data in:

```text
~/Library/Application Support/GrokDesk/
```

Grok Build keeps its default data under `~/.grok/`. Multi-account credentials live in isolated `GROK_HOME` directories managed by GrokDesk. Session history remains local and shared rather than being bound to one account, so another healthy account can continue the same Session. GrokDesk does not upload tokens, Sessions, Memory, or workspace files to this repository.

## Contributing

Issues and pull requests are welcome. Please keep credentials, local Session data, generated application bundles, and Grok Build source out of commits.

## License

[MIT](LICENSE)
