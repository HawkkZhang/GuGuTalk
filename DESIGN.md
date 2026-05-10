---
name: Desktop Voice Input
description: A quiet native macOS voice input utility for Chinese writing workflows.
colors:
  icon-aqua: "#29B8C7"
  icon-aqua-deep: "#0A7887"
  icon-aqua-soft: "#D4F7FA"
  icon-orange: "#F28C38"
  ready-green: "#159B70"
  signal-amber: "#D16E1A"
  danger-red: "#D62E2E"
  text-primary: "#142226"
  text-secondary: "#506B6E"
  border-subtle: "#A0C7CC"
  surface-paper: "#F1FAFA"
  surface-panel: "#FFFCF5"
  surface-dark: "#0E1314"
  surface-panel-dark: "#1A2526"
typography:
  title:
    fontFamily: "system-ui"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "system-ui"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "system-ui"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: 1.25
rounded:
  sm: "7px"
  md: "10px"
spacing:
  xs: "6px"
  sm: "10px"
  md: "16px"
  lg: "24px"
components:
  button-primary:
    backgroundColor: "{colors.icon-aqua}"
    textColor: "{colors.surface-panel}"
    rounded: "{rounded.sm}"
    padding: "6px 12px"
  panel:
    backgroundColor: "{colors.surface-panel}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
---

# Design System: Desktop Voice Input

## 1. Overview

**Creative North Star: "Aqua Chick Companion"**

Desktop Voice Input should feel like a crafted Mac companion built around the GuGuTalk icon: clear aqua, soft white, and a small warm orange note. The interface is compact and scan-friendly, but no longer relies on default gray panels or system blue. It uses system typography and custom controls so the product has a recognizable identity without feeling like a flashy AI tool.

The system rejects flashy AI styling, web-dashboard density, game-panel drama, and decorative effects that make simple actions feel loud.

**Key Characteristics:**
- Native macOS window behavior, system font, and Mac-like custom controls.
- Light aqua surfaces with icon-aqua as the primary action and selection color.
- Compact panels with shallow elevation and clear dividers.
- Smooth state feedback without ornamental motion.

## 2. Colors

The palette is extracted from the app icon: aqua background, soft white body, and orange beak/feet. Color should add identity and legibility, not decoration. Amber and red remain semantic only.

### Primary
- **Icon Aqua** (#29B8C7): Primary action, selected controls, recording signal, and focused custom controls.
- **Deep Aqua** (#0A7887): Strong active states and overlay recording background.
- **Aqua Soft** (#D4F7FA): Quiet selected backgrounds, provider-ready surfaces, and subtle atmosphere.
- **Icon Orange** (#F28C38): Tiny brand warmth only, never large decorative fills.

### Dark Mode Adjustment
- **Dark Aqua Active** should be deeper and less luminous than light-mode aqua. Use it for selected controls without making the surface glow.
- **Dark Aqua Soft** should be a muted atmospheric tint, not a large cyan wash. Settings backgrounds should stay mostly near-neutral.
- **Dark panels** should lean charcoal-teal with low saturation so primary and secondary text remain readable.

### Secondary
- **Ready Green** (#008F63): Ready, success, recording health, and usable permission state.
- **Signal Amber** (#C27514): Caution, attention, and configuration warnings.

### Tertiary
- **Error Red** (#D1332E): Errors, blocked states, and destructive attention.

### Neutral
- **Ink** (#171F1D): Primary text in light mode.
- **Secondary Ink** (#55665E): Secondary labels and helper text.
- **Subtle Border** (#B3C2AD): Dividers and quiet outlines.
- **Paper Surface** (#F4F2E6): Window background in light mode.
- **Panel Surface** (#FCFAF0): Raised content surfaces in light mode.
- **Dark Surface** (#111917): Window background in dark mode.
- **Dark Panel** (#1F2B27): Raised content surfaces in dark mode.

### Named Rules

**The State Color Rule.** Aqua, green, amber, and red are for state and action. Icon orange is allowed only as a very small brand note.

**The Selection Rule.** Selected custom controls should use a solid aqua fill and white text. Inactive controls stay on soft aqua or warm-white surfaces.

**The Dark Aqua Rule.** In dark mode, aqua is an accent, not ambient lighting. Large surfaces should use low-saturation dark neutrals; cyan should be reserved for selected states, focused controls, and small status marks.

## 3. Typography

**Display Font:** System font
**Body Font:** System font
**Label/Mono Font:** System font, with monospaced style only for shortcuts and technical credentials.

**Character:** Native, crisp, and restrained. Text hierarchy should come from weight and size, not novelty.

### Hierarchy
- **Title** (semibold, 20-30px, 1.2): Screen and panel titles.
- **Headline** (semibold, 17-22px, 1.25): Section headers and important status.
- **Body** (regular, 13px, 1.45): Help text, status explanations, compact descriptions.
- **Label** (medium, 11-12px, 1.25): Field labels, state tags, and compact metadata.

### Named Rules

**The Native Type Rule.** Do not use display fonts, negative letter spacing, or marketing-sized headings inside product panels.

## 4. Elevation

Depth is conveyed through solid surfaces, subtle borders, and small shadows. Avoid translucent glassmorphism; the recording overlay should never look like an accidental gray blur.

### Shadow Vocabulary
- **Panel Lift** (`0 6px 16px rgba(0,0,0,0.08)`): Floating menu and overlay panels only.
- **Inline Lift** (`0 2px 8px rgba(0,0,0,0.04)`): Rare, for compact grouped content when needed.

### Named Rules

**The Shallow Surface Rule.** Use material and border before shadow. Shadow is reserved for floating UI.

## 5. Components

### Buttons
- **Shape:** Continuous rounded rectangles with a consistent radius scale.
- **Primary:** Solid aqua fill with white text for the main action in a group.
- **Hover / Focus:** Follow native macOS behavior; add no decorative glow.
- **Secondary / Ghost / Tertiary:** Use bordered or plain styles according to system conventions.

### Switches
- **Use case:** Binary enable or disable settings only, such as turning a shortcut mode on or off.
- **Style:** Use the project `DVISwitch` style: compact, rounded, clear on/off state, and aligned with the app accent tint. Do not represent binary enablement as segmented controls, buttons, or custom chips.

### Chips
- **Style:** Compact text or icon plus text, with a subtle background tint only when showing state.
- **State:** Use aqua for active, green for ready, amber for warning, red for error.

### Cards / Containers
- **Corner Style:** 10px for app panels, 7px for inline controls, 12px only for floating overlay shells.
- **Background:** Soft aqua and warm-white control backgrounds.
- **Shadow Strategy:** Use shallow elevation only for menu and overlay surfaces.
- **Border:** One-pixel separator color with low opacity.
- **Internal Padding:** 10-24px depending on density.

### Shape Language
- **Primary shape:** Rounded rectangles. Use them for panels, inline controls, selected rows, status tags, hotkey blocks, and overlay content.
- **Avoid mixed geometry:** Do not combine circles, pills, and rounded cards in the same compact surface unless a native macOS control requires it.
- **Status marks:** Prefer SF Symbols without circular badges, or a rounded-rectangle icon tile. Avoid decorative dots.
- **Pills:** Avoid capsule containers for app-specific UI. Native segmented controls and macOS buttons may keep their system shapes.

### Information Density
- **One state, one place:** Do not repeat the same readiness, mode, or permission state in adjacent areas.
- **Explain only when blocked:** Permission and configuration guidance should appear when an action is unavailable or likely to fail.
- **Settings are controls first:** Avoid generic subtitles such as "choose a mode" when the control already explains itself.
- **Selection consistency:** Settings selections use the project `DVIChoiceBar` style: one compact segmented surface, one unmistakable selected state, and no competing card-style selection patterns. Custom colored blocks are for status only, never for choosing one option.

### Inputs / Fields
- **Style:** Quiet custom fields on elevated warm surfaces.
- **Focus:** Native focus ring.
- **Error / Disabled:** Keep labels readable and use concise inline messages.

### Navigation
- **Style:** A compact custom sidebar is acceptable, but selected state must be visually consistent and unmistakable.

### App Entry / Onboarding Window
- **Launch behavior:** Opening GuGuTalk from Finder, Launchpad, or `/Applications` should show a real app window. The app must not appear to disappear into the menu bar.
- **Window role:** Use one dedicated native settings/onboarding window for launch, menu bar Settings, and permission guidance.
- **Initial route:** If required permissions are missing, open directly to Permissions. If permissions are ready, open to the General/Home page.
- **Implementation preference:** Prefer a dedicated app window over treating SwiftUI's `Settings {}` scene as the main entry surface. `Settings {}` is acceptable for conventional app preferences, but this product needs onboarding and permission recovery as primary flows.

### Menu Bar Console
- **Purpose:** Show readiness at a glance and expose only the next useful action.
- **Structure:** Use a compact native status header, a concise shortcut summary, conditional notices, and a small action row.
- **Density:** Do not repeat app name, permission details, or provider setup text unless the user is blocked.
- **Notices:** Permission and error content should appear as compact state strips, not full cards.
- **Color:** Stay compact and Mac-like, but use the icon-aqua brand system consistently instead of default blue-gray controls.

### Recording Overlay
- **Purpose:** Confirm that the app is listening, show live recognition, and stay out of the user's workspace.
- **Initial size:** Start compact when there is no recognized text.
- **Expansion:** Grow smoothly as recognized text appears, capped to a modest maximum size.
- **Surface consistency:** Waiting waveform and live transcript use the same icon-aqua theme surface. Do not switch to a different bubble color just because text has not arrived yet.
- **Edges:** The rounded overlay must not show square backing, hidden glass frames, or heavy shadows outside the shape.
- **Transcript:** Show the newest recognized text. When content is too long, keep the tail and prefix the whole transcript with a single ellipsis. Never truncate again inside later lines.
- **Waveform:** Use a compact animated waveform as the primary recording indicator before text appears. Once transcript text exists, embed the waveform as a quiet background signal so it does not consume its own row.
- **Motion:** Use soft 150-250 ms transitions for expansion, transcript reveal, and state changes.

## 6. Do's and Don'ts

### Do:
- **Do** follow the system appearance by default, with explicit Light and Dark overrides.
- **Do** keep advanced provider settings collapsed until needed.
- **Do** make recording, permission blockers, and errors immediately legible.
- **Do** keep motion under 250ms and tied to state changes.

### Don't:
- **Don't** make it look like a flashy AI tool.
- **Don't** use web-admin dashboards, game panels, heavy gradients, or decorative glassmorphism.
- **Don't** use oversized marketing panels or in-app text that explains obvious controls.
- **Don't** use color as decoration when a neutral surface is enough.
