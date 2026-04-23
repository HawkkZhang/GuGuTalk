# Desktop Voice Input

一个面向 macOS 的桌面语音输入工具原型：

- 菜单栏常驻
- 全局按住快捷键说话
- 流式预览 partial 文本
- 松开后插入 final 文本
- 支持本地识别、豆包、千问三种模式

## 当前实现

- `SwiftUI + AppKit` 菜单栏应用入口
- `HotkeyManager` 监听全局按住说话
- `PermissionCoordinator` 管理麦克风、语音识别、辅助功能、输入监控权限
- `AudioCaptureEngine` 采集并转换为 `16k PCM16 mono`
- `RecognitionOrchestrator` 管理录音、识别、预览、最终插入
- `LocalSpeechProvider` 基于 Apple Speech 框架
- `DoubaoSpeechProvider` 基于豆包 WebSocket 协议
- `QwenSpeechProvider` 基于 DashScope Realtime WebSocket 协议
- `TextInsertionService` 按“辅助功能 -> 模拟键盘 -> 剪贴板粘贴”降级写回文本

## 运行

### 用 Xcode 直接运行

1. 打开 `DesktopVoiceInput.xcodeproj`
2. 左上角选择 `DesktopVoiceInput` scheme
3. 点击运行按钮
4. 第一次运行后，到系统设置里授予麦克风、辅助功能、输入监控权限

这个工程已经带了正式的 `Info.plist`，会以菜单栏应用的形式启动。

### 用命令行运行

```bash
swift build
swift run
```

首次使用需要在系统设置中授予：

- 麦克风
- 辅助功能
- 输入监控
- 语音识别（仅本地识别需要）

## 已知限制

- 当前仓库同时保留了 `Swift Package Manager` 骨架和正式的 Xcode App 工程，便于一边快速迭代、一边直接在 Xcode 里运行。
- Xcode 工程目前关闭了签名要求，适合本机开发运行；如果后续要分发给别人使用，还需要补签名、归档和发布配置。
- 云端 provider 需要在设置页填写真实凭证后才能工作。
