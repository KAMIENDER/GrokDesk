# GrokDesk

<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="GrokDesk icon">
</p>

<p align="center">
  <strong>Grok Build, beyond the terminal.</strong>
</p>

<p align="center">
  A native, open-source macOS workspace built directly on the <a href="https://github.com/xai-org/grok-build">Grok Build</a> runtime—with full agent visibility, shared CLI sessions, and quota-aware multi-account routing.
</p>

<p align="center">
  English · <a href="README.zh-CN.md">简体中文</a>
</p>

> [!IMPORTANT]
> GrokDesk is an independent community project. It is not affiliated with or endorsed by xAI. Grok and Grok Build are trademarks of their respective owner.

GrokDesk is the native macOS experience layer for Grok Build, not a separate general-purpose agent harness. It presents the ACP/JSON-RPC capabilities of the local runtime through a modern SwiftUI interface while preserving Grok Build's Sessions, tools, and extension semantics. It does not embed a terminal or reimplement the agent. File operations, shell commands, Git, MCP, Skills, Plugins, Hooks, Memory, and subagents continue to run through Grok Build.

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
- Apple Silicon for the current prebuilt release
- Intel Macs can build GrokDesk from source
- A valid Grok Build account

GrokDesk does **not** vendor Grok Build source or binaries. At launch, it checks the configured runtime path, `~/.grok/bin/grok`, common Homebrew locations, and `PATH`. If Grok Build is unavailable, GrokDesk asks for confirmation before running the official xAI installer documented by the [Grok Build repository](https://github.com/xai-org/grok-build#installing-the-released-binary). It never installs the runtime silently.

You can also install Grok Build manually:

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
grok --version
```

## Download and install

Download the Apple Silicon DMG from [GitHub Releases](https://github.com/KAMIENDER/GrokDesk/releases), open it, and drag `GrokDesk.app` onto the `Applications` shortcut. The ZIP archive remains available as a portable alternative.

After the first installation, GrokDesk checks GitHub Releases through Sparkle. You can check manually from **GrokDesk → Check for Updates…**, or configure automatic checks and background downloads in **Settings → General → Software updates**. Update archives are authenticated with a dedicated Sparkle EdDSA signature before installation.

The current community build is ad-hoc signed and has not been notarized by Apple. On first launch, Control-click `GrokDesk.app`, choose **Open**, and confirm the macOS prompt. A notarized, warning-free distribution requires an Apple Developer ID certificate, which is not currently available to this project.

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

To create the drag-to-install DMG:

```bash
./scripts/package-dmg.sh
```

Maintainers can create the DMG, Sparkle ZIP, and signed `appcast.xml` together with:

```bash
./scripts/package-release.sh
```

Pushing a version tag such as `v0.1.3` runs the release workflow. The repository must contain a `SPARKLE_PRIVATE_KEY` Actions secret exported from Sparkle's `generate_keys` tool; the private key must never be committed.

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
