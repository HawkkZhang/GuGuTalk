# GuGuTalk Windows

macOS 原生语音输入工具 GuGuTalk 的 Windows 版本。

## 技术栈

- C# / .NET 8
- WPF (UI)
- NAudio (WASAPI 音频采集)
- sherpa-onnx (本地语音识别)
- FlaUI (UIAutomation 文字插入)
- WiX 5 (MSI 安装包)

## 构建

```powershell
dotnet build GuGuTalk.sln -c Release
```

**首次构建会自动从 GitHub 下载 sherpa-onnx 中文模型 (~30MB)**，缓存在 `.modelcache/`。
之后构建走缓存。

## 运行（开发）

```powershell
dotnet run --project src/GuGuTalk.App
```

## 打包安装包

```powershell
dotnet publish src/GuGuTalk.App -c Release -r win-x64 --self-contained false
dotnet build installer/GuGuTalk.Installer.wixproj -c Release
```

生成的 `.msi` 中已包含识别模型，**用户安装后无需联网即可使用本地识别**。

## 测试

```powershell
dotnet test
```

## 功能

- 多种识别引擎：本地 (sherpa-onnx，内置) / 豆包 / 千问
- 灵活热键：按住说话 (Ctrl+`) + 切换模式 (Alt+Space)，可在设置中重新录制
- 三层文字插入：剪贴板 → UIAutomation → SendInput
- 智能后处理：热词替换 + LLM 优化（OpenAI / Anthropic）
- 系统托盘常驻 + 录音状态浮窗 + 波形动画

## 系统要求

- Windows 10 1903+ (x64)
- .NET 8 Runtime
- 麦克风

## 模型管理

- **构建时下载**：默认 `sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23`（中文，30MB）
- **路径搜索顺序**：用户目录 (`%LOCALAPPDATA%\GuGuTalk\models\`) 优先，然后是安装目录 (`<exe>\models\`)
- **替换模型**：把其他 sherpa-onnx 兼容的流式模型放到用户目录即可（包含 `tokens.txt` + `encoder*.onnx` + `decoder*.onnx` [+ `joiner*.onnx`]）
