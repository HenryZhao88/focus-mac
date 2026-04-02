// FocusApp/AppDelegate.swift
import AppKit
import ApplicationServices
import Combine
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Services
    private let taskStore = TaskStore()
    private let sessionManager = SessionManager()
    private let appMonitor = AppMonitor()
    private let ai = AIService(apiKey: Constants.claudeAPIKey)
    private var escalationManager: EscalationManager!
    private var wsServer: WebSocketServer?

    // MARK: - UI
    private var overlayController: OverlayWindowController?
    // MARK: - Combine
    private var lastSession: FocusSession?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()

        // 0. Initialize @MainActor-isolated service on main thread
        escalationManager = EscalationManager(
            ai: ai,
            sessionManager: sessionManager,
            appMonitor: appMonitor
        )

        // 1. Set up main window
        setupMainWindow()

        // 2. Set up overlay
        overlayController = OverlayWindowController(
            escalationManager: escalationManager,
            sessionManager: sessionManager,
            appMonitor: appMonitor
        )

        // 3. Observe EscalationState to resize overlay
        escalationManager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        // 4. Warn if API key is missing
        if Constants.claudeAPIKey.isEmpty {
            let alert = NSAlert()
            alert.messageText = "API Key Missing"
            alert.informativeText = "Set ANTHROPIC_API_KEY in your environment to enable AI monitoring."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }

        // 5. Start WebSocket server
        wsServer = WebSocketServer()
        wsServer?.onURLChange = { [weak self] url in
            guard let self else { return }
            Task { @MainActor in
                self.escalationManager.updateCurrentURL(url)
            }
        }
        wsServer?.start()

        // 6. Observe session lifecycle
        sessionManager.$activeSession
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                if let session {
                    self.lastSession = session
                    self.overlayController?.show()
                    self.escalationManager.startMonitoring()
                } else {
                    // Session ended — mark the task complete
                    if let completedTask = self.lastSession?.task {
                        self.taskStore.markComplete(id: completedTask.id)
                    }
                    self.lastSession = nil
                    self.overlayController?.hide()
                    self.escalationManager.stopMonitoring()
                }
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        wsServer?.stop()
        escalationManager?.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Private

    private func requestAccessibilityIfNeeded() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)

            let alert = NSAlert()
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = "Focus needs Accessibility access to monitor which app you're using. Please enable it in System Settings → Privacy & Security → Accessibility, then relaunch Focus."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func setupMainWindow() {
        let contentView = MainWindowView(
            taskStore: taskStore,
            sessionManager: sessionManager,
            onStartFocus: { [weak self] task in
                self?.sessionManager.startSession(task: task)
            }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Focus"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func handleStateChange(_ state: EscalationState) {
        switch state {
        case .monitoring:
            overlayController?.collapseToBar()
        case .nudging:
            overlayController?.expandForNudge()
        case .blocking:
            overlayController?.expandForBlock()
        }
    }
}
