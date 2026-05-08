# Handoff

This file is the first-stop handoff note for switching between Codex, Claude Code, Xcode, and other development tools.

## ⚠️ CRITICAL ISSUES - 2026-05-07

**权限流程曾导致应用处于不可用状态。Codex 已做一轮修复并通过 Release 编译，已安装到 `/Applications/GuGuTalk.app`，仍需用户本机人工验证。**

1. **申请语音识别权限导致闪退**
   - 点击"语音识别"的"立即申请"按钮后应用崩溃
   - 位置：`PermissionCoordinator.refreshSpeechRecognition(prompt: true)`
   - 已处理：权限请求显式在主线程发起，并在主线程恢复结果

2. **启动时自动弹出权限请求对话框**
   - 应用启动后直接弹出系统辅助功能权限请求
   - 期望：应该先打开设置窗口，让用户主动点击后才请求
   - 已处理：启动只做静默权限检查；全局热键监听仅在输入监控已授权时启动；缺权限时自动打开设置窗口

3. **权限检测不准确**
   - 用户在系统设置中授予权限后，应用仍显示"未授权"
   - 已定位：麦克风权限缺失的真实原因是 Hardened Runtime 下应用缺少 `com.apple.security.device.audio-input` entitlement，导致系统麦克风权限列表不出现 GuGuTalk
   - 已处理：Release 构建使用本地稳定签名 `GuGuTalk Local Code Signing`；新增 `Config/DesktopVoiceInput.entitlements`；刷新检查统一走 AppModel，刷新权限后同步热键监听状态
   - 需要验证修复是否有效

**详细问题记录见 `BUGS.md`**

## Current Stable Point

- Stable tag: `stable-2026-05-01`
- Stable commit: `960f2b3`
- GitHub repository: `https://github.com/HawkkZhang/GuGuSpeak`
- Local branch at time of writing: `codex/archive-current-state`
- Remote branch: `origin/main`

If local work gets messy, use the stable tag as the known-good restore point.

## Product Snapshot

This is a macOS-only desktop voice input app. It is not a system IME. The product shape is:

- menu bar app
- global hotkeys
- small floating recognition preview
- final text insertion into the currently focused app
- local Apple Speech, Qwen realtime, and Doubao realtime providers

Default user experience:

1. User triggers recording with a configured shortcut.
2. The overlay shows recording state and streaming transcript.
3. On stop, final text is post-processed.
4. The app inserts final text into the active input target.

## Source Of Truth Files

Read these before starting work:

- `PRODUCT.md`: product purpose, users, personality, anti-references.
- `DESIGN.md`: visual language, layout rules, component rules, recording overlay rules.
- `MEMORY.md`: current status, unfinished functionality, risk areas.
- `README.md`: high-level implementation and run instructions.
- `HANDOFF.md`: current operational handoff.

When switching tools, update `HANDOFF.md` if the next step, risk, or known-good state changes.

## Recent State

The app currently has:

- a SwiftUI/AppKit menu bar shell
- settings window with tabs for common settings, cloud services, and permissions
- first-launch settings guidance: first run opens Settings automatically, using the Permissions tab when required permissions are missing
- two shortcut modes:
  - hold-to-talk
  - press-once-to-start, press-again-to-stop
- local Apple Speech provider
- Qwen realtime provider
- Doubao realtime provider
- floating preview overlay
- post-processing and insertion pipeline
- design documentation and project memory
- local Release install at `/Applications/GuGuTalk.app`, signed with `GuGuTalk Local Code Signing`

The most recent UI direction is:

- native macOS feel
- calm and restrained
- system font
- system light/dark appearance support
- no flashy AI styling
- no web-admin or game-panel feeling
- compact overlay with waveform only before text, then waveform embedded quietly behind transcript text
- newest transcript content should remain visible, with a single leading ellipsis when older text is omitted

## Known Risks

- The locally signed `/Applications/GuGuTalk.app` is for development testing. It may still be blocked by Gatekeeper when double-clicked because the certificate is self-signed; launching via `/Applications/GuGuTalk.app/Contents/MacOS/DesktopVoiceInput` is currently the most reliable local test path.
- Do not assume hotkeys are fully stable. Dual hotkey mode still needs testing and polish.
- Do not let shortcut recording trigger live voice input.
- Do not let recognized text insert into the app's own settings or internal UI.
- Treat text insertion compatibility as a top-priority product risk. Browser and web rich-text editors can expose placeholder / hint text through Accessibility APIs, so direct AX read-modify-write can accidentally merge hint text into the dictated result. Prefer paste-style insertion for browsers / web editors, keep Accessibility insertion for safe native controls, and build toward per-app strategy memory plus full pasteboard restoration.
- Cloud provider credentials live in local user defaults and are not committed.
- macOS permissions are per-machine and are not committed.
- Xcode signing/distribution is not production-ready.
- GitHub sync stores source code, not installable app artifacts.

## Next Recommended Work

1. Stabilize hotkey state transitions.
2. Harden the text insertion pipeline for browsers, rich-text editors, Electron apps, and native text fields.
3. Add self-protection so settings/internal windows cannot receive dictated text.
4. Improve provider configuration validation before a recording session starts.
5. Improve provider visibility in the menu bar console and errors.
6. Add automated tests for hotkeys, insertion guards, and provider selection.
7. Eventually set up signing, packaging, and release artifacts.

## Suggested Prompt For Another AI Tool

Use this when opening Claude Code or another coding agent:

```text
Please first read PRODUCT.md, DESIGN.md, MEMORY.md, HANDOFF.md, README.md, and the latest git log.
This is a macOS SwiftUI/AppKit voice input app named GuGuSpeak / DesktopVoiceInput.
Continue from the current repository state without overwriting uncommitted changes.
Respect the native macOS design direction and the known risks in HANDOFF.md.
Before editing, inspect the relevant files and summarize the intended change.
After a stable change, build with xcodebuild, commit, and push.
```

## Useful Commands

Build:

```bash
xcodebuild -project DesktopVoiceInput.xcodeproj -scheme DesktopVoiceInput -configuration Debug -derivedDataPath /tmp/DesktopVoiceInputDerivedData build
```

Run the debug app:

```bash
open /tmp/DesktopVoiceInputDerivedData/Build/Products/Debug/DesktopVoiceInput.app
```

Check status:

```bash
git status --short --branch
git log --oneline -5 --decorate
```

Return to current stable checkpoint only if intentionally discarding local work:

```bash
git switch -C restore-stable stable-2026-05-01
```

Do not run destructive reset commands unless the user explicitly approves discarding local changes.
