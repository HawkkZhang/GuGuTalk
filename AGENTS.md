# Agent Instructions

This repository is frequently edited by multiple AI coding tools. Treat these files as shared project context.

## Start Here

Before making changes, read:

- `PRODUCT.md`
- `DESIGN.md`
- `MEMORY.md`
- `HANDOFF.md`
- `README.md`

Then inspect the relevant source files before proposing or editing code.

## Collaboration Rules

- Preserve user work. Never revert or overwrite uncommitted changes without explicit approval.
- Prefer small, understandable changes over sweeping rewrites.
- Keep the app native to macOS. Use Swift, SwiftUI, and AppKit patterns already present in the repo.
- Use system font and native macOS controls unless there is a clear reason not to.
- Keep UI calm, compact, and restrained. Avoid flashy AI aesthetics, web dashboard styling, game-like panels, and decorative gradients.
- Update `HANDOFF.md` when the current state, next step, or known risks change.
- Update `MEMORY.md` when a durable project fact changes.

## Build And Verification

For code changes, build with:

```bash
xcodebuild -project DesktopVoiceInput.xcodeproj -scheme DesktopVoiceInput -configuration Debug -derivedDataPath /tmp/DesktopVoiceInputDerivedData build
```

For user-facing changes, run the debug app after building:

```bash
open /tmp/DesktopVoiceInputDerivedData/Build/Products/Debug/DesktopVoiceInput.app
```

If another `DesktopVoiceInput` process is already running, stop it before opening the newly built app.

## Git Workflow

- Current stable checkpoint: `stable-2026-05-01`
- Stable commit: `960f2b3`
- Remote repository: `https://github.com/HawkkZhang/GuGuSpeak`
- Current local branch may be `codex/archive-current-state` while tracking `origin/main`.

Before editing:

```bash
git status --short --branch
```

After a stable change:

```bash
git add -A
git commit -m "<short clear summary>"
git push
```

If pushing over HTTPS fails because macOS keychain credential helper interferes, use GitHub CLI credential helper for that push:

```bash
git -c credential.helper= -c credential.https://github.com.helper='!/opt/homebrew/bin/gh auth git-credential' push
```

## Sensitive Data

Do not commit:

- Qwen API keys
- Doubao App ID or Access Token
- personal tokens
- local user defaults
- signing certificates
- provisioning profiles
- machine-specific Xcode user data

Provider credentials are entered in the app settings and stored locally on each Mac.

## Product Guardrails

- This is not a system IME yet.
- This is not a meeting transcription app.
- This is not a voice command system.
- Partial recognition updates the overlay only.
- Final text is inserted only after the recording session ends.
- If insertion fails, keep the final text visible and copyable.

## Important UX Rules

- Permission guidance should appear only when useful.
- Settings should be simple and grouped by task.
- Recognition mode is a single choice: local, Doubao, or Qwen.
- Only Doubao and Qwen need provider configuration.
- Shortcut recording must suspend global voice-input hotkeys.
- The overlay should stay small and out of the user's workspace.
- Long transcript preview should preserve the newest text and omit only from the beginning.
