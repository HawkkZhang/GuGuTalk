---
name: Desktop Voice Input
description: A quiet native macOS voice input utility for Chinese writing workflows.
colors:
  accent-blue: "#0066D6"
  accent-green: "#007A4F"
  accent-amber: "#B86B00"
  danger-red: "#C22938"
  text-primary: "#1F2126"
  text-secondary: "#5C616B"
  border-subtle: "#BDC0C7"
  surface-light: "#F3F4F6"
  surface-panel-light: "#FCFCFD"
  surface-dark: "#1F2023"
  surface-panel-dark: "#2B2C2F"
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
    backgroundColor: "{colors.accent-blue}"
    textColor: "{colors.surface-panel-light}"
    rounded: "{rounded.sm}"
    padding: "6px 12px"
  panel:
    backgroundColor: "{colors.surface-panel-light}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
---

# Design System: Desktop Voice Input

## 1. Overview

**Creative North Star: "Quiet Mac Companion"**

Desktop Voice Input should feel like a small native utility that belongs beside Spotlight, Shortcuts, and the menu bar. The interface is compact, scan-friendly, and calm. It uses system typography, macOS-like neutral surfaces, and small semantic state colors so the product disappears into the user's writing flow while still making state changes easy to read.

The system rejects flashy AI styling, web-dashboard density, game-panel drama, and decorative effects that make simple actions feel loud.

**Key Characteristics:**
- Native macOS controls and system font.
- Native neutral surfaces with blue, green, amber, and red reserved for state.
- Compact panels with shallow elevation and clear dividers.
- Smooth state feedback without ornamental motion.

## 2. Colors

The palette is a native-neutral utility palette: light and dark surfaces should feel close to macOS system panels. Color is not atmosphere. Color is only for action, selection, recording, readiness, warning, and error.

### Primary
- **System Blue** (#0066D6): Primary action, selected controls, and active focus.

### Secondary
- **Ready Green** (#007A4F): Ready, success, recording health, and usable permission state.
- **Signal Amber** (#B86B00): Caution, attention, and configuration warnings.

### Tertiary
- **Error Red** (#C22938): Errors, blocked states, and destructive attention.

### Neutral
- **Ink** (#1F2126): Primary text in light mode.
- **Secondary Ink** (#5C616B): Secondary labels and helper text.
- **Subtle Border** (#BDC0C7): Dividers and quiet outlines.
- **Light Surface** (#F3F4F6): Window background in light mode.
- **Light Panel** (#FCFCFD): Raised content surfaces in light mode.
- **Dark Surface** (#1F2023): Window background in dark mode.
- **Dark Panel** (#2B2C2F): Raised content surfaces in dark mode.

### Named Rules

**The State Color Rule.** Blue, green, amber, and red are for state and action only. They should be legible, distinct, and never used as decoration.

**The Selection Rule.** Selected controls should use Action Blue through native tint plus a visibly stronger fill or outline when custom-drawn. Inactive controls stay neutral.

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

Depth is conveyed through native macOS material, subtle borders, and small shadows. Surfaces should feel layered but not glassy or decorative.

### Shadow Vocabulary
- **Panel Lift** (`0 6px 16px rgba(0,0,0,0.08)`): Floating menu and overlay panels only.
- **Inline Lift** (`0 2px 8px rgba(0,0,0,0.04)`): Rare, for compact grouped content when needed.

### Named Rules

**The Shallow Surface Rule.** Use material and border before shadow. Shadow is reserved for floating UI.

## 5. Components

### Buttons
- **Shape:** Native macOS button shapes, normally 6px visual radius.
- **Primary:** System bordered prominent for the main action in a group.
- **Hover / Focus:** Follow native macOS behavior; add no decorative glow.
- **Secondary / Ghost / Tertiary:** Use bordered or plain styles according to system conventions.

### Switches
- **Use case:** Binary enable or disable settings only, such as turning a shortcut mode on or off.
- **Style:** Use native macOS switch toggles with the app accent tint. Do not represent binary enablement as segmented controls, buttons, or custom chips.

### Chips
- **Style:** Compact text or icon plus text, with a subtle background tint only when showing state.
- **State:** Use mint for ready, amber for warning, red for error, blue for active.

### Cards / Containers
- **Corner Style:** 10px for app panels, 7px for inline controls, 12px only for floating overlay shells.
- **Background:** Native window and control background colors.
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
- **Selection consistency:** Settings selections use native segmented controls. Custom colored blocks are for status only, never for choosing one option.

### Inputs / Fields
- **Style:** Native rounded border fields.
- **Focus:** Native focus ring.
- **Error / Disabled:** Keep labels readable and use concise inline messages.

### Navigation
- **Style:** No custom navigation chrome. Settings use grouped sections and native controls.

### Menu Bar Console
- **Purpose:** Show readiness at a glance and expose only the next useful action.
- **Structure:** Use a compact native status header, a concise shortcut summary, conditional notices, and a small action row.
- **Density:** Do not repeat app name, permission details, or provider setup text unless the user is blocked.
- **Notices:** Permission and error content should appear as compact state strips, not full cards.
- **Color:** Stay very close to macOS system panels. Use only a small status dot and subtle notice outlines for state.

### Recording Overlay
- **Purpose:** Confirm that the app is listening, show live recognition, and stay out of the user's workspace.
- **Initial size:** Start compact when there is no recognized text.
- **Expansion:** Grow smoothly as recognized text appears, capped to a modest maximum size.
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
