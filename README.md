# GuGuTalk

一款跨平台语音输入工具，支持本地识别和云端识别，让语音输入更高效。

## 平台

| 平台 | 技术栈 | 目录 | 状态 |
|------|--------|------|------|
| macOS | Swift 6 + SwiftUI | [`macos/`](macos/) | 已发布 |
| Windows | C# + WPF (.NET 8) | [`windows/`](windows/) | 开发中 |

## 功能

- 多种识别引擎：本地离线 / 豆包 / 千问
- 灵活热键：按住说话 + 切换模式
- 智能文字插入：自动适配目标应用
- 后处理：热词替换 + LLM 优化 + 标点控制
- 系统常驻：菜单栏 (macOS) / 系统托盘 (Windows)

## 快速开始

### macOS

```bash
cd macos
xcodebuild -project DesktopVoiceInput.xcodeproj -scheme DesktopVoiceInput build
```

### Windows

```powershell
cd windows
dotnet build GuGuTalk.sln -c Release
dotnet run --project src/GuGuTalk.App
```

详细说明见各平台目录下的 README。

## 设计

- [PRODUCT.md](PRODUCT.md) — 产品定义
- [DESIGN.md](DESIGN.md) — 设计系统

## 开源协议

MIT License
