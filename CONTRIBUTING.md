# 开发指南

## 项目结构

```
DesktopVoiceInput/
├── Sources/DesktopVoiceInput/
│   ├── App/                      # 应用入口
│   ├── Models/                   # 数据模型
│   │   ├── AppSettings.swift    # 应用设置
│   │   ├── PreviewState.swift   # 气泡状态
│   │   ├── HotwordStore.swift   # 热词管理
│   │   └── ...
│   ├── Services/                 # 核心服务
│   │   ├── RecognitionOrchestrator.swift  # 识别协调器
│   │   ├── AudioCaptureEngine.swift       # 音频采集
│   │   ├── TextInsertionService.swift     # 文本插入
│   │   ├── HotkeyManager.swift            # 热键管理
│   │   ├── Providers/                     # 识别引擎
│   │   │   ├── LocalSpeechProvider.swift  # 本地识别
│   │   │   ├── DoubaoSpeechProvider.swift # 豆包识别
│   │   │   └── QwenSpeechProvider.swift   # 千问识别
│   │   └── ...
│   └── Views/                    # UI 界面
│       └── SettingsView.swift   # 设置界面
```

## 技术栈

- **语言**：Swift 6
- **框架**：SwiftUI, AppKit
- **语音识别**：
  - Apple Speech Framework（本地）
  - WebSocket（豆包、千问）
- **音频采集**：AVFoundation
- **热键**：CGEvent tap

## 构建项目

### 环境要求

- 支持 Swift 6 的 Xcode
- macOS 14.0+ target / SDK

### 构建步骤

```bash
# 克隆仓库
git clone https://github.com/HawkkZhang/GuGuTalk.git
cd GuGuTalk

# 用 Xcode 打开
open DesktopVoiceInput.xcodeproj

# 或使用命令行构建
xcodebuild -project DesktopVoiceInput.xcodeproj \
           -scheme DesktopVoiceInput \
           -configuration Debug \
           -derivedDataPath /tmp/DesktopVoiceInputDerivedData \
           build
```

## 架构说明

### 识别流程

```
用户按下热键
    ↓
HotkeyManager 触发
    ↓
RecognitionOrchestrator.beginCapture()
    ↓
AudioCaptureEngine 开始录音
    ↓
SpeechProvider 处理音频
    ↓
流式返回识别结果
    ↓
TranscriptPostProcessor 后处理
    ↓
SmartPostProcessor (可选 LLM 优化)
    ↓
TextInsertionService 插入文本
    ↓
用户松开热键
    ↓
RecognitionOrchestrator.endCapture()
```

### 核心组件

#### RecognitionOrchestrator
识别协调器，管理整个识别流程：
- 协调音频采集和识别引擎
- 处理识别事件流
- 管理气泡状态
- 超时保护

#### SpeechProvider
识别引擎接口，三种实现：
- `LocalSpeechProvider`：Apple Speech Framework
- `DoubaoSpeechProvider`：豆包 WebSocket API
- `QwenSpeechProvider`：千问 WebSocket API

#### TextInsertionService
文本插入服务，支持多种方式：
- Pasteboard 粘贴
- Accessibility API
- CGEvent 模拟键盘输入

## 添加新的识别引擎

1. 创建新的 Provider 实现 `SpeechProvider` 协议：

```swift
final class NewSpeechProvider: SpeechProvider {
    let mode: RecognitionMode = .custom
    let events: AsyncStream<TranscriptEvent>
    
    func startSession(config: RecognitionConfig) async throws {
        // 初始化连接
    }
    
    func sendAudio(_ chunk: AudioChunk) async throws {
        // 发送音频数据
    }
    
    func finishAudio() async throws {
        // 结束识别
    }
    
    func cancel() async {
        // 取消识别
    }
}
```

2. 在 `RecognitionMode` 中添加新模式
3. 在 `RecognitionOrchestrator` 中注册 Provider
4. 在设置界面添加配置选项

## 调试技巧

### 查看日志

使用 Console.app 查看日志：
```
subsystem: com.desktopvoiceinput
category: LocalSpeech / Doubao / Qwen / Orchestrator
```

### 常见问题

**识别结果重复**：
- 检查 Provider 的 `hasEmittedFinalResult` 标志
- 查看 `session.finished` 和 `completed` 事件处理

**文本插入失败**：
- 确认辅助功能权限已授予
- 检查 `TextInsertionService` 的插入方式选择

**音频采集问题**：
- 确认麦克风权限
- 检查 `AudioCaptureEngine` 的采样率和格式

## 测试

当前已有基础单元测试，主要覆盖文本后处理、豆包结果解析和终帧前缀保护：

```bash
swift test
```

仍建议继续做以下手动测试：

1. **本地识别**：说多个句子，检查是否累积正确
2. **云端识别**：测试流式更新和最终结果
3. **热键**：测试按住/切换模式
4. **文本插入**：在不同应用中测试（TextEdit、Chrome、VS Code）
5. **气泡 UI**：测试不同长度文本的显示效果

## 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 使用 Swift 标准命名规范
- 添加必要的注释（特别是复杂逻辑）
- 保持函数简洁（单一职责）
- 使用 `// MARK:` 组织代码

## 路线图

- [ ] 扩展自动化测试
- [ ] 改进本地识别（添加标点）
- [ ] 支持更多识别引擎
- [ ] 改进 provider 配置校验和错误提示
- [ ] 优化性能和内存使用
- [ ] 添加使用统计和分析

## 许可证

MIT License - 详见 LICENSE 文件
