# Project Memory

## Current Status

- DesktopVoiceInput is a macOS menu bar voice input app prototype.
- Local Apple Speech, Qwen realtime, and Doubao realtime integrations have all been implemented.
- The current stable checkpoint is tag `stable-2026-05-01`, commit `960f2b3`.
- GitHub repository: `https://github.com/HawkkZhang/GuGuSpeak`.
- Local development branch is currently `codex/archive-current-state`, tracking `origin/main`.
- Product name under consideration: `GuGuSpeak`.

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

1. ~~Stabilize the hotkey system.~~ (done: event tap auto-recovery, reload protection, debounce)
2. ~~Harden text insertion compatibility across browsers, rich-text editors, Electron apps, and native macOS fields.~~ (done: clipboard paste as default, full pasteboard save/restore, changeCount check)
3. ~~Finish self-protection around settings and internal windows.~~ (done: bundleID check)
4. Add clearer validation and error handling for Doubao / Qwen configuration.
5. Improve provider visibility and fallback messaging.
6. Expand tests around hotkeys, insertion, and provider switching.
7. Implement Agent 对话 for smart post-processing configuration.
8. Implement per-app post-processing rules.
