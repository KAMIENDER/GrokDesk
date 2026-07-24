# 录制隐私安全的 GrokDesk 演示

GrokDesk 提供了一个录制辅助脚本。它会使用全新的隔离演示档案启动 App，
不会导入正常 GrokDesk Session；演示项目选择器也只展示安全的示例名称，
不会显示本机用户名和绝对路径。

## 快速开始

如尚未打包 App，先运行：

```bash
./scripts/package-app.sh
```

从全新的语言选择页开始，并由 macOS 选择要录制的窗口、区域或显示器：

```bash
./scripts/record-demo.sh --gif
```

如果 GrokDesk 已放在第二块显示器上，也可以直接录制该显示器 45 秒：

```bash
./scripts/record-demo.sh --display 2 --duration 45 --gif
```

原始视频及可选 GIF 会输出到 `dist/demo-recordings/`。生成 GIF 需要
`ffmpeg`，只录制 `.mov` 则不需要。

## 建议的 35–45 秒演示流程

1. 在全新的语言页选择 **English** 或 **简体中文**。
2. 点击 **新对话**，选择一个安全的演示项目。
3. 展示模型与推理强度切换。
4. 输入不含隐私信息的示例任务，例如：

   > 检查这个示例 SwiftUI 工作区，总结架构，并提出一个小型无障碍改进。

5. 展开 **过程**，展示 Grok Build 的思考、文件、命令、Skill、Hook 和
   Runtime 事件。
6. 展示 Context Window 指示器或右侧运行详情。
7. 从 macOS 菜单栏停止录制。

## 隐私与清理

- 每次运行都会创建独立的
  `/Users/Shared/GrokDesk-Recording-<时间戳>` 状态目录。
- `GROKDESK_SKIP_SESSION_IMPORT=1` 会阻止导入已有 CLI Session。
- 演示工作区使用模拟名称和模拟展示路径。
- 脚本不会自动删除正常数据或演示数据。
- 对外发布前请完整检查视频；录制单个窗口通常比录制整块显示器更安全。

脚本结束后会打印本次隔离档案的准确路径。不再需要时，只手动删除该次
演示对应的目录即可。

运行 `./scripts/record-demo.sh --help` 可以查看所有参数。
