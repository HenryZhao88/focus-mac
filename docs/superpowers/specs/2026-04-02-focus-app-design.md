# Focus App Design Spec
*Date: 2026-04-02*

## Overview

A macOS focus app for a high school student that enforces homework sessions with a "comfy but firm" approach. Soft by default, with escalating enforcement as a last resort. An AI acts as both a background monitor and an interactive gatekeeper.

---

## Architecture

Two components communicating over a local WebSocket:

### 1. Focus Guardian (Swift/SwiftUI macOS App)
The main app. Handles the overlay, todo list, session management, app monitoring, AI integration, and escalation logic.

### 2. Tab Watcher (Browser Extension)
A lightweight extension (Chrome + Safari) that reports the active tab's URL and page title to the Swift app over WebSocket. Receives block/allow commands and redirects blocked tabs to a "blocked" page.

---

## Components

### Todo List
- Simple list of homework tasks (e.g. "CS Homework", "Math Homework")
- No duration estimates — tasks are open-ended
- Each task has a "Focus" button to start a session
- Tasks can be marked complete at session end

### Focus Session
- Starts when user clicks "Focus" on a task
- AI context is initialized with the task name
- Overlay activates (slim bar at top of screen)
- Ends when user clicks "End session" — task marked complete

### Overlay Window
An `NSWindow` that floats above all other windows. Three states:

**State 1 — On Task (default)**
- Slim translucent bar pinned to top of screen
- Shows task name + elapsed time + "End" button
- Transparent, non-intrusive, click-through except its own controls

**State 2 — Gentle Nudge**
- Small popup appears (does not cover work)
- Message: "Hey, you've been on [app/site] for X min. Still on task?"
- Two buttons: "I need this" (triggers AI gatekeeper) / "Get me back" (dismisses and refocuses)
- Grace period: 2 minutes to respond before escalation

**State 3 — Hard Block**
- Covers the specific off-task window (not the full screen)
- Shows task reminder and an AI chat input
- User can type a justification to request an unlock
- Only the off-task window is blocked — actual work remains visible

### App Monitor
- Uses `NSWorkspace` notifications + Accessibility API to track active app name and window title
- Polls every ~10 seconds during a session
- Sends activity to AI Core for evaluation

### AI Core (Claude API)
Uses `claude-haiku-4-5` for low-latency, low-cost background checks.

**Role 1 — Monitor (background, every ~10 seconds)**
- Input: task name, active app, active window title, active URL, session allowlist
- Output: `on_task` | `drifting` | `off_task`
- `drifting` triggers State 2 nudge; `off_task` after grace period triggers State 3 block

**Role 2 — Gatekeeper (on-demand)**
- Triggered when user types a request in the block screen (e.g. "I need YouTube for a coding tutorial")
- Input: task name, request text, current app/URL
- Output: `approved` (with optional message) | `denied` (with short explanation)
- Approved requests are added to the session allowlist for the remainder of the session

### Session Allowlist
- In-memory list of approved apps/domains for the current session
- Cleared when session ends
- AI-approved items skip monitoring checks for that session

---

## Escalation Flow

```
AI signals `drifting` or `off_task`
  → State 2: Nudge popup appears
    → User responds "I need this" → AI Gatekeeper evaluates
      → Approved → added to session allowlist, monitoring resumes
      → Denied → nudge stays, 2-min grace period resets
    → User responds "Get me back" → dismissed, back to State 1
    → User ignores for 2 minutes → State 3: Hard block covers off-task window
      → User types justification → AI Gatekeeper evaluates
        → Approved → block lifts, added to allowlist
        → Denied → block remains, explanation shown
```

---

## Browser Extension

- Manifest V3 (works for both Chrome and Safari via Safari Web Extension converter)
- Background service worker monitors `tabs.onActivated` and `tabs.onUpdated`
- Sends `{ url, title }` to Swift app via WebSocket on every tab change
- Listens for `block` / `allow` commands from Swift app
- On `block`: redirects current tab to a local "blocked" page
- On `allow`: removes domain from blocked list for this session

### WebSocket Protocol (localhost)
```json
// Extension → Swift
{ "type": "tab_update", "url": "https://youtube.com/watch?v=...", "title": "Lo-fi beats" }

// Swift → Extension
{ "type": "block", "domain": "youtube.com" }
{ "type": "allow", "domain": "youtube.com" }
```

---

## Privacy
- No screen recording, no keylogging
- Only active app name, window title, and active browser URL are read
- No data persisted beyond the current session
- Claude API calls contain only task name + app/URL context — no personal content

---

## Out of Scope
- Scheduling / calendar integration
- Time tracking / analytics
- Multiple simultaneous tasks
- iOS/cross-platform support
- Custom escalation timing settings (defaults: nudge after 2 min off-task, block after 2 min of ignored nudge)
