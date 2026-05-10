# 严重 Bug 记录

## 2026-05-07 问题清单

### 2026-05-07 Codex 修复记录

**状态：已做代码修复并通过 Release 编译，相关修复已进入当前打包流程。后续用户测试没有再确认同类权限阻塞；本文件保留为历史问题和回归测试记录。下方部分“需要修复”是当时的原始排查记录，不代表当前仍未修。**

已处理：
- 语音识别权限申请现在显式从主线程发起，并在主线程恢复结果，降低 `SFSpeechRecognizer.requestAuthorization` 回调导致崩溃的风险。
- 启动时只做静默权限检查，不再无条件启动全局热键监听；只有输入监控权限可用时才启动 / 重载 hotkey event tap。
- 菜单栏的“处理”改为打开设置窗口，不再一次性申请所有缺失权限。
- 启动发现缺权限时，自动打开设置窗口，让用户先看到权限说明，再手动点击对应权限操作。
- “刷新检查”统一走 AppModel 刷新入口，刷新权限状态的同时同步热键监听状态。
- Release 构建已改用本地稳定签名 `GuGuTalk Local Code Signing`，避免每次 Debug 临时包身份变化导致 TCC 权限记录不稳定。
- 已添加 `Config/DesktopVoiceInput.entitlements`，包含 `com.apple.security.device.audio-input`，让 Hardened Runtime 下的应用能正确请求并出现在麦克风权限列表中。

### 2026-05-07 22:02 二次崩溃根因

**已定位到真实原因：** 不是权限配置缺失，而是 `SFSpeechRecognizer.requestAuthorization` 的系统回调运行在后台队列；因为回调闭包写在 `@MainActor PermissionCoordinator` 的方法里，Swift 认为该闭包仍带有 MainActor 隔离。系统在后台队列调用这个闭包时触发 `_swift_task_checkIsolatedSwift` 运行时断言，导致 `EXC_BREAKPOINT / SIGTRAP` 崩溃。

**修复方式：**
- 将语音识别授权请求封装到 `nonisolated static requestSpeechRecognitionAuthorization()`。
- 传给 `SFSpeechRecognizer.requestAuthorization` 的闭包不再捕获 MainActor 隔离上下文。
- `refreshSpeechRecognition(prompt:)` 只在 await 返回后回到 MainActor 更新 `@Published` 状态。

**验证：**
- Debug 编译通过。
- 启动新版后进程保持运行。
- 最新崩溃日志仍停留在 `DesktopVoiceInput-2026-05-07-220223.ips`，启动新版后未新增崩溃日志。

待验证：
- 点击”语音识别”的”立即申请”是否不再闪退。
- 首次启动是否不会直接弹出辅助功能系统弹窗。
- 在系统设置授权后，回到 App 点击”刷新检查”是否能正确变成”已授权”。

### 2026-05-07 23:xx 麦克风权限问题

**现象**：用户报告已授予麦克风权限，但应用显示”待请求”；系统设置的”麦克风”列表里没有 GuGuTalk。

**实际根因**：
- Release/Debug app 启用了 Hardened Runtime。
- 应用签名 entitlements 里缺少 `com.apple.security.device.audio-input`。
- macOS 因此没有把 GuGuTalk 作为可申请麦克风的应用登记到 TCC，导致应用内一直看到 `.notDetermined`，系统设置列表里也不出现 GuGuTalk。

**验证方法**：
```bash
codesign -d --entitlements :- /Applications/GuGuTalk.app 2>/dev/null | plutil -p -
```

**解决方案**：
- 新增 `Config/DesktopVoiceInput.entitlements`。
- 在 Xcode project 的 Debug/Release build settings 中设置 `CODE_SIGN_ENTITLEMENTS = Config/DesktopVoiceInput.entitlements`。
- 使用本地稳定证书 `GuGuTalk Local Code Signing` 重新签名 Release app。
- 重新安装到 `/Applications/GuGuTalk.app` 后，执行：
```bash
tccutil reset Microphone com.end.DesktopVoiceInput
tccutil reset SpeechRecognition com.end.DesktopVoiceInput
```
- 启动新版后，用户重新点击麦克风授权按钮，应出现系统麦克风弹窗并在系统设置列表中显示 GuGuTalk。

**验证状态**：
- `xcodebuild -configuration Release` 构建通过。
- `/Applications/GuGuTalk.app` 的 entitlements 已确认包含 `com.apple.security.device.audio-input => true`。
- 已启动 `/Applications/GuGuTalk.app/Contents/MacOS/DesktopVoiceInput`。
- 后续用户测试基本恢复；仍建议在新机器或新 DMG 上回归麦克风授权流程。

### 1. 申请语音识别权限导致应用闪退
**现象**：点击"语音识别"的"立即申请"按钮后，应用直接崩溃闪退

**可能原因**：
- `SFSpeechRecognizer.requestAuthorization` 调用方式有问题
- 权限请求回调处理不当
- 线程问题（在非主线程更新 UI）

**需要修复**：
- 检查 `PermissionCoordinator.refreshSpeechRecognition(prompt: true)` 的实现
- 确保权限请求回调在主线程执行
- 添加错误处理和崩溃保护

### 2. 应用启动时自动弹出辅助功能权限请求
**现象**：打开应用后，不是进入设置界面，而是直接弹出系统的辅助功能权限请求对话框

**期望行为**：
- 应用启动后应该直接打开设置窗口
- 用户在设置窗口中看到权限引导
- 用户主动点击按钮后才请求权限

**实际行为**：
- 应用启动时自动调用了 `AXIsProcessTrustedWithOptions` 并传入了 `prompt: true`
- 导致系统弹出权限请求对话框

**需要修复**：
- 检查 `VoiceInputAppModel.init()` 中的 `refreshAll(promptForSystemDialogs: false)` 是否正确传递参数
- 确保启动时的权限检查不会触发系统弹窗
- 实现自动打开设置窗口的逻辑（之前添加过但被移除了）

### 3. 权限检测不准确（已部分修复）
**现象**：用户在系统设置中授予权限后，应用仍然显示"未授权"

**已尝试的修复**：
- 启用 Hardened Runtime
- 启用代码签名（ad-hoc）
- 添加"刷新检查"按钮

**仍需验证**：
- 权限检测 API 是否在启用 Hardened Runtime 后正常工作
- 是否需要重启应用才能检测到权限变化

## 根本问题

1. **权限请求流程混乱**：
   - 启动时不应该自动请求权限
   - 应该先显示设置界面，让用户了解需要哪些权限
   - 用户主动点击后才请求

2. **错误处理缺失**：
   - 权限请求可能失败或崩溃，但没有错误处理
   - 应该添加 try-catch 和崩溃保护

3. **UI 流程不清晰**：
   - 用户不知道应用启动后应该做什么
   - 应该有明确的引导流程

## 下一步行动

1. 修复语音识别权限请求崩溃（最高优先级）
2. 修复启动时自动弹窗问题
3. 实现正确的首次启动流程：启动 → 自动打开设置窗口 → 显示权限引导
4. 添加完善的错误处理和日志
