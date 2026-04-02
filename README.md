# Focus

A macOS app that uses AI to keep you on task. You pick a task, start a focus session, and Focus monitors what you're doing — nudging you when you drift and blocking your screen if you ignore it. You can ask the AI to approve distractions, and it decides whether they're actually relevant to your work.

---

## Features

- **Task list** — add, complete, and delete tasks
- **Focus sessions** — start a session tied to a specific task
- **AI monitoring** — checks your active app and window title every 10 seconds against your task
- **Browser extension support** — optionally connects to send the active tab URL for richer context
- **Escalation system** — nudge → block → ask AI to unlock
- **Session allowlist** — approved apps/sites are remembered for the rest of the session

---

## Requirements

- macOS 13.0 or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An OpenAI API key

---

## Setup

### 1. Generate the Xcode project

```bash
git clone https://github.com/HenryZhao88/focus-mac
cd FocusApp
xcodegen generate
```

### 2. Set your OpenAI API key

Focus reads your API key from the environment or a `.env` file. Create a `.env` in the project root:

```
OPENAI_API_KEY=sk-...
```

Or set it in your shell before launching:

```bash
export OPENAI_API_KEY=sk-...
```

### 3. Grant Accessibility access

Focus uses Accessibility APIs to read the active app and window title. On first launch, it will prompt you to grant access:

**System Settings → Privacy & Security → Accessibility → Focus → toggle on**

After granting access, no restart is required — the app detects it automatically.

### 4. Build and run

Open `FocusApp.xcodeproj` in Xcode and press **Run**, or build from the terminal:

```bash
xcodebuild -scheme FocusApp -configuration Debug build
open build/Debug/FocusApp.app
```

---

## Browser Extension (Optional)

A Chrome extension is included at `FocusApp/Extension/`. It connects to the Focus app over a local WebSocket and sends your active tab URL automatically — no polling, it fires instantly on tab switches, URL changes, and window focus changes. Without it, Focus still monitors all apps using window titles; the extension just gives the AI more context when you're in a browser.

### Installing the extension

1. Open Chrome and go to `chrome://extensions`
2. Enable **Developer mode** (top right)
3. Click **Load unpacked** and select the `FocusApp/Extension` folder
4. The Focus Guard icon will appear in your toolbar — a green dot means it's connected to the app

The extension reconnects automatically with exponential backoff if the Focus app isn't running yet.

---

## How It Works

### Escalation flow

```
Monitoring → (AI detects drift) → Nudging → (2 min grace) → Blocking
```

| State | What you see |
|---|---|
| **Monitoring** | Thin bar overlay at the bottom of the focused window |
| **Nudging** | Small popup: "Hey, you drifted a bit" with two buttons |
| **Blocking** | Full overlay covering the app with a request field |

### Nudge options

- **Get me back** — dismisses the nudge and resets the grace period
- **I need this** — opens a dialog to explain why; the AI decides whether to approve it

### Block options

- Type a reason and hit **Ask** — the AI approves or denies it with a one-sentence explanation
- If approved, the current site (browser) or app (everything else) is added to the session allowlist and won't trigger checks again this session

### Allowlist behavior

- **Browser**: only the specific hostname is allowlisted (approving `github.com` doesn't whitelist all of Chrome)
- **Native app**: the whole app is allowlisted (e.g., Xcode approved → Xcode is never flagged again this session)

---

## Project Structure

```
FocusApp/
├── AppDelegate.swift           # App lifecycle, wires all services together
├── main.swift                  # Entry point
├── Models/
│   ├── Task.swift              # FocusTask model
│   ├── FocusSession.swift      # Active session state (task + allowlist + start time)
│   └── AISignal.swift          # on_task / drifting / off_task + GatekeeperDecision
├── Services/
│   ├── TaskStore.swift         # Persists tasks to UserDefaults
│   ├── SessionManager.swift    # Manages the active focus session
│   ├── EscalationManager.swift # Drives the monitoring → nudge → block state machine
│   ├── AIService.swift         # OpenAI API calls (activity check + gatekeeper)
│   ├── AppMonitor.swift        # Reads frontmost app name, window title, and frame via Accessibility APIs
│   └── WebSocketServer.swift   # Local WebSocket server for browser extension URL relay
├── Views/
│   ├── MainWindowView.swift    # Task list UI
│   ├── NudgeView.swift         # Nudge overlay
│   ├── BlockView.swift         # Block overlay
│   ├── OverlayView.swift       # Container that switches between nudge/block
│   └── OverlayWindowController.swift  # Manages the floating overlay window
└── Utilities/
    └── Constants.swift         # Ports, intervals, model name, API key loading
└── Extension/                  # Chrome extension (Manifest V3)
    ├── manifest.json           # Permissions: tabs, activeTab, windows, storage
    ├── background.js           # WebSocket client — pushes URL on tab/window events
    ├── popup.html              # Toolbar popup
    └── popup.js                # Shows connected/disconnected status
```

---

## Configuration

All tunable values live in [FocusApp/Utilities/Constants.swift](FocusApp/Utilities/Constants.swift):

| Constant | Default | Description |
|---|---|---|
| `monitorIntervalSeconds` | `10` | How often the AI checks your activity |
| `nudgeGracePeriodSeconds` | `120` | Seconds between nudge and hard block |
| `wsPort` | `54321` | WebSocket port for the browser extension |
| `openAIModel` | `gpt-4.1` | Model used for all AI calls |

---

## Running Tests

```bash
xcodebuild test -scheme FocusApp -destination 'platform=macOS'
```

Tests cover `TaskStore`, `SessionManager`, `EscalationManager`, `AIService` parsing, and `WebSocketServer`.
