# Agent Instructions (Repository Root)

本仓库是 **GuGuTalk** 的 monorepo，包含 macOS 和 Windows 两个原生实现，由多个 AI 编码工具共同维护。

**先读这一份。** 如果只改一个平台的代码，再去读对应目录的 `AGENTS.md`。

## 仓库结构

```
DesktopVoiceInput/                     ← 仓库根目录
├── README.md                          ← 项目总览（中英文）
├── PRODUCT.md                         ← 产品定义（共享，两个平台都遵循）
├── DESIGN.md / DESIGN.json            ← 设计系统（共享，两个平台保持品牌一致）
├── BUGS.md                            ← 已知问题（混合两个平台）
├── CONTRIBUTING.md                    ← 贡献指南（共享）
├── AGENTS.md                          ← 本文件
├── macos/                             ← macOS 版（Swift 6 + SwiftUI）
│   ├── AGENTS.md                      ← Mac 专用规范
│   ├── HANDOFF.md                     ← Mac 开发交接状态
│   ├── MEMORY.md                      ← Mac 项目记忆
│   ├── Package.swift
│   ├── DesktopVoiceInput.xcodeproj/
│   ├── Sources/                       ← Swift 源码
│   ├── Tests/
│   ├── Config/                        ← Info.plist + entitlements
│   ├── scripts/                       ← package-dmg.sh 等
│   └── dist/dmg/                      ← DMG 产物（gitignored）
└── windows/                           ← Windows 版（C# + WPF + .NET 8）
    ├── AGENTS.md                      ← Windows 专用规范
    ├── README.md                      ← Windows 构建/打包说明
    ├── GuGuTalk.sln
    ├── Directory.Build.props          ← 全局 MSBuild 配置
    ├── Directory.Packages.props       ← 中央包版本管理
    ├── src/
    │   ├── GuGuTalk.Core/             ← 业务逻辑（无 UI）
    │   ├── GuGuTalk.App/              ← WPF 应用
    │   └── GuGuTalk.LocalAsr/         ← sherpa-onnx 封装
    ├── tests/
    └── installer/                     ← WiX 5 MSI
```

## 开发模式

**单分支 (main)**。两个平台都在 main 分支上开发，各改各的目录。

- 改 Mac 版 → 编辑 `macos/`、commit、push
- 改 Windows 版 → 编辑 `windows/`、commit、push
- 共享的产品/设计文档变更要确认两边都不会受影响

如果你的改动很大（重构、跨平台协议改动），开功能分支再合并。

## 改动边界（重要）

**不要跨目录改文件。**

| 你在做什么 | 应该改 |
|------|------|
| 修 macOS bug | 只改 `macos/` |
| 修 Windows bug | 只改 `windows/` |
| 改产品文案 | `README.md` / `PRODUCT.md`（如适用，两边都要核对） |
| 改设计 token（颜色、间距等） | `DESIGN.md` + `DESIGN.json`，然后**两边都要同步** |
| 改云端协议（豆包/千问帧格式） | `macos/Sources/.../Providers/` + `windows/src/GuGuTalk.Core/Providers/` **必须同步** |

⚠️ **协议同步**是最容易出错的地方。豆包二进制帧格式、千问 OpenAI Realtime 事件类型，两边都有自己的实现。如果你改了一边，**主动检查另一边是否需要同步**。

## Commit 信息约定

```
<scope>: <短描述>

<可选的更长说明>
```

scope 用以下之一：

- `macos:` — 只改 macOS 代码
- `windows:` — 只改 Windows 代码
- `docs:` — 只改文档
- `design:` — 改 DESIGN.md / DESIGN.json
- `protocol:` — 改两端的云端协议代码（必须同时改两端）
- `repo:` — 仓库结构、CI、根目录配置等

例：
```
windows: 修复剪贴板恢复延迟
macos: 加固微信文字插入
protocol: 豆包帧 messageType 增加 0x0C 处理
docs: 更新 PRODUCT.md 用户场景
```

## 构建与验证

每个平台有自己的构建命令，详见对应 `AGENTS.md`：

- macOS: `cd macos && xcodebuild ...`（详见 `macos/AGENTS.md`）
- Windows: `cd windows && dotnet build ...`（详见 `windows/AGENTS.md`）

**不要 `cd` 到对方平台尝试构建**，会失败且没有意义。

## 常见误区

- ❌ 在 macOS 机器上 `dotnet build windows/`：因为 Windows 项目目标 framework 是 `net8.0-windows`，macOS 不支持
- ❌ 在 Windows 机器上 `xcodebuild macos/`：Xcode 只在 macOS 上有
- ❌ 直接编辑 `windows/src/GuGuTalk.LocalAsr/bundled-models/` 的内容：那是构建时下载的产物，被 gitignored
- ❌ 把 macOS 的 `dist/dmg/` 或 Windows 的 `installer/*.msi` 提交到 git：构建产物，被 gitignored
- ❌ 把 API key、签名证书提交到 git：本地配置，永远不要进仓库

## 不在仓库的临时区

`.claude/`、`.agents/`、`.codex/` 是 AI 工具的临时区，被 gitignored，不要在里面放需要长期保留的东西。worktrees 同样是临时的。

## 共享 vs 平台特定的判定

不确定一个改动该放哪？问自己：

- **改这个会让另一个平台的用户体验不同吗？** → 共享（DESIGN.md / PRODUCT.md）
- **改这个只影响一个平台的实现？** → 平台目录
- **改这个改的是数据格式（如设置文件 schema、协议字段）？** → 协议改动，两端都要改

## 当你不确定时

不要猜。读对应平台的 `AGENTS.md`、`HANDOFF.md`（如有）、`MEMORY.md`（如有），还不清楚就向用户确认。这个仓库是双平台同步演进的，错放一个文件会污染另一个平台的构建。
