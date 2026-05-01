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

## Immediate Priorities

1. Stabilize the hotkey system.
2. Finish self-protection around settings and internal windows.
3. Add clearer validation and error handling for Doubao / Qwen configuration.
4. Improve provider visibility and fallback messaging.
5. Expand tests around hotkeys, insertion, and provider switching.
