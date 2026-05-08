# Project Memory

## ⚠️ CRITICAL STATUS - 2026-05-07

**权限流程曾导致应用不可用。Codex 已做一轮修复并通过 Release 编译，已安装到 `/Applications/GuGuTalk.app`，仍需用户本机人工验证权限弹窗与授权刷新。**

### 严重问题

1. **语音识别权限申请导致闪退**
   - 症状：点击"立即申请"按钮后应用崩溃
   - 影响：无法完成权限配置流程
   - 位置：`PermissionCoordinator.refreshSpeechRecognition(prompt: true)`
   - 当前处理：权限请求显式在主线程发起，并在主线程恢复结果

2. **启动时错误弹出权限请求**
   - 症状：应用启动后立即弹出系统辅助功能权限对话框
   - 期望：应该先显示设置窗口，用户主动点击后才请求
   - 影响：用户体验混乱，不知道应该做什么
   - 当前处理：启动只做静默检查；全局热键监听仅在输入监控已授权时启动；缺权限时自动打开设置窗口

3. **权限检测不准确**
   - 症状：系统设置中已授权，应用仍显示"未授权"
   - 已定位：辅助功能/输入监控需要稳定签名和正确跳转；麦克风在 Hardened Runtime 下还必须具备 `com.apple.security.device.audio-input` entitlement
   - 当前处理：Release 构建使用本地稳定签名 `GuGuTalk Local Code Signing`；新增 `Config/DesktopVoiceInput.entitlements`；刷新检查统一走 AppModel，刷新权限后同步热键状态
   - 状态：需要用户验证修复是否有效

### 最近的修改（2026-05-07）

**打包和品牌**：
- 应用名改为 GuGuTalk
- 创建 DMG 安装包
- 添加应用图标和菜单栏图标
- 移除 `LSUIElement`，应用出现在 Launchpad

**权限系统修改**：
- 启用 Hardened Runtime（尝试修复权限检测）
- 启用代码签名（现为本地稳定证书 `GuGuTalk Local Code Signing`，不再依赖 ad-hoc）
- 添加 `Config/DesktopVoiceInput.entitlements`，包含麦克风音频输入 entitlement
- 首次启动会自动打开设置窗口；缺权限时直接进入“权限”页，避免新用户误以为菜单栏应用消失
- 移除自动打开设置窗口逻辑（导致问题 2）
- 添加"刷新检查"按钮
- 曾添加"我已授权，继续使用"按钮（已移除）

**已知问题根源**：
- 权限请求流程混乱
- 错误处理缺失
- UI 流程不清晰

详细问题记录见 `BUGS.md`

## Current Status

- DesktopVoiceInput is a macOS menu bar voice input app prototype.
- Local Apple Speech, Qwen realtime, and Doubao realtime integrations have all been implemented.
- The current stable checkpoint is tag `stable-2026-05-01`, commit `960f2b3`.
- The latest pushed checkpoint on `main` is `5521384 记录豆包流式修复和启动入口方案`.
- GitHub repository: `https://github.com/HawkkZhang/GuGuSpeak`.
- Local development branch is currently `main`, tracking `origin/main`.
- Product name in the installed app is currently `GuGuTalk`; repository/project names still include `GuGuSpeak` / `DesktopVoiceInput`.

## Latest Synced State - 2026-05-08

These changes have been pushed to GitHub on `main` at commit `5521384`:

- Doubao streaming result handling now parses `utterances` explicitly.
- `definite=true` utterances are committed, while `definite=false` utterances remain as the active preview segment.
- This is intended to fix extra duplicated words caused by treating the whole `result.text` as final whenever any utterance was marked definite.
- Doubao `enable_ddc` should remain off for this issue. It is a semantic smoothing feature for real spoken filler/repetition, not a fix for client-side streaming result assembly.
- A temporary SwiftUI Settings-opening bridge was attempted so app launch/reopen can request the settings window.
- The preferred next architecture is a dedicated native GuGuTalk settings/onboarding window, not relying on SwiftUI `Settings {}` as the app's primary entry window.
- After app launch or reopen from Finder/Launchpad, expected UX is:
  - missing required permissions -> open Permissions page
  - permissions ready -> open General/Home page

## Not Yet Fully Implemented

### Hotkeys

- The new dual-hotkey system still needs stabilization.
- There are now two trigger modes:
  - hold-to-talk
  - press-once-to-start, press-again-to-stop
- Hotkey recording should never trigger live voice input while recording.
- Single-key hotkeys are allowed, but conflict handling still needs more polish.
- System-level reserved shortcuts cannot be fully intercepted.
- App-level shortcut conflicts can often be intercepted, but detection and user guidance are still incomplete.

### Safety / Anti-Footgun

- Prevent the app from inserting recognized text into its own settings window or other internal UI.
- Add stronger guards so recording / settings editing / text insertion do not interfere with one another.
- Validate cloud provider settings earlier, before runtime, to reduce handshake-time failures.

### Recognition UX

- Make it clearer which provider is actually being used right now:
  - local
  - Doubao
  - Qwen
- Make fallback reasons and provider switching reasons visible to the user.
- Improve failure messages so they are easier for non-technical users to understand.
- Continue validating Doubao streaming assembly against official `utterances[].definite` semantics; do not solve client-side partial/final duplication by turning on semantic smoothing.

### Text Quality

- `TranscriptPostProcessor` is still minimal.
- It currently only does:
  - whitespace cleanup
  - limited Chinese punctuation cleanup
  - terminal punctuation append
- Still missing:
  - better Chinese punctuation restoration
  - number formatting
  - mixed Chinese / English formatting
  - smarter sentence segmentation

### Stability / Compatibility

- Settings/onboarding entry is currently a product architecture priority. The app should not feel like it disappears into the menu bar when launched from Finder or Launchpad.
- Use one dedicated settings/onboarding window for app launch, menu bar Settings, and permission guidance.
- More compatibility testing is needed across common macOS apps and input fields.
- Text insertion compatibility is a top-priority product risk. The app must not merely "insert text"; it needs reliable per-target insertion behavior across native text fields, browser editors, rich text editors, Electron apps, and unusual web inputs.
- Browser / web rich-text editors such as Gemini, ChatGPT, Notion, Google Docs, Feishu, and Slack should generally prefer paste-style insertion because Accessibility `AXValue` can expose placeholder / hint / hidden editor text as if it were real content.
- Native macOS text fields may still use Accessibility insertion when safe, but the app should detect placeholder / hint values and fall back before merging them into dictated text.
- Future insertion architecture should support per-app strategy memory, full pasteboard preservation, insertion diagnostics, and a user-facing compatibility mode.
- Need more verification for:
  - repeated sessions
  - permission revocation mid-use
  - settings window interactions
  - self-focus / self-insertion edge cases

### Testing

- Test coverage is still very light.
- Current tests mostly cover transcript post-processing only.
- Missing automated tests for:
  - hotkey state transitions
  - provider fallback flow
  - text insertion safeguards
  - settings validation

### Release Readiness

- App signing is not set up yet.
- Packaging / distribution / install flow is not set up yet.
- Update mechanism is not implemented.

### 智能后处理（Phase 2 & 3 未完成）

已完成：
- 标点处理独立设置（规则层，不依赖 LLM）
- LLM 后处理基础能力（纠错、正式化、列表预设）
- 用户可编辑每个预设的 Prompt
- LLM 客户端支持 OpenAI 兼容 + Anthropic 双协议
- BYOK 配置（endpoint / API key / model）

未完成：
- Per-app 差异化规则（根据目标应用选择不同处理管线）
- Agent 对话功能：用户用自然语言描述后处理需求，Agent 自动判断用规则层还是 LLM 层，输出结构化配置变更
- Agent 对话 UI（独立聊天窗口）
- Agent 对话历史持久化
- 自定义 Prompt 模板管理（用户自建模板，不限于预设）

设计文档：`.claude/plans/jolly-spinning-whistle.md`

## Immediate Priorities

1. Replace SwiftUI `Settings {}` as the primary entry UI with a dedicated native settings/onboarding window.
2. Verify Doubao streaming duplicate fix with real usage and logs.
3. Add clearer validation and error handling for Doubao / Qwen configuration.
4. Improve provider visibility and fallback messaging.
5. Expand tests around hotkeys, insertion, and provider switching.
6. Implement Agent 对话 for smart post-processing configuration.
7. Implement per-app post-processing rules.
