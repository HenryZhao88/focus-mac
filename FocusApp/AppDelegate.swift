// FocusApp/AppDelegate.swift
import AppKit
import ApplicationServices
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Services
    private let taskStore = TaskStore()
    private let sessionManager = SessionManager()
    private let appMonitor = AppMonitor()
    private let ai = AIService(apiKey: Constants.openAIAPIKey)
    private var escalationManager: EscalationManager!
    private var wsServer: WebSocketServer?

    // MARK: - UI
    private var mainWindow: NSWindow?
    private var overlayController: OverlayWindowController?
    private var accessibilityPollTimer: Timer?
    private var didPromptForAccessibilityThisRun = false
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // 0. Set up the main window first so permission/config alerts don't
        // make the app look like it launched without any UI.
        showMainWindow()

        // 1. Initialize @MainActor-isolated service on main thread
        escalationManager = EscalationManager(
            ai: ai,
            sessionManager: sessionManager,
            appMonitor: appMonitor
        )

        // 2. Show any launch-time alerts after the app is already visible.
        refreshAccessibilityAccess(promptIfNeeded: true)

        // 3. Set up overlay
        overlayController = OverlayWindowController(
            escalationManager: escalationManager,
            sessionManager: sessionManager,
            appMonitor: appMonitor,
            onStopFocus: { [weak self] in
                guard let self else { return }
                self.escalationManager.stopMonitoring()
                self.sessionManager.endSession()
            },
            onCompleteFocus: { [weak self] in
                guard let self, let task = self.sessionManager.activeSession?.task else { return }
                self.taskStore.markComplete(id: task.id)
                self.escalationManager.stopMonitoring()
                self.sessionManager.endSession()
            }
        )

        // 4. Observe EscalationState to resize overlay
        escalationManager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        // 5. Warn if API key is missing
        if Constants.openAIAPIKey.isEmpty {
            presentAlertSheet(
                messageText: "API Key Missing",
                informativeText: "Set OPENAI_API_KEY in your environment or .env file to enable AI monitoring.",
                style: .warning,
                buttons: ["OK"]
            ) { _ in }
        }

        // 6. Start WebSocket server
        wsServer = WebSocketServer()
        wsServer?.onURLChange = { [weak self] url in
            guard let self else { return }
            Task { @MainActor in
                self.escalationManager.updateCurrentURL(url)
            }
        }
        wsServer?.start()

        // 7. Observe session lifecycle
        sessionManager.$activeSession
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                if session != nil {
                    self.overlayController?.show()
                    self.escalationManager.startMonitoring()
                } else {
                    self.overlayController?.hide()
                    self.escalationManager.stopMonitoring()
                }
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        wsServer?.stop()
        escalationManager?.stopMonitoring()
        accessibilityPollTimer?.invalidate()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshAccessibilityAccess(promptIfNeeded: false)

        if NSApp.windows.allSatisfy({ !$0.isVisible }) {
            showMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return false }
        showMainWindow()
        return true
    }

    // MARK: - Private

    private func refreshAccessibilityAccess(promptIfNeeded: Bool) {
        guard !AXIsProcessTrusted() else {
            accessibilityPollTimer?.invalidate()
            accessibilityPollTimer = nil
            return
        }

        startAccessibilityPolling()

        guard promptIfNeeded, !didPromptForAccessibilityThisRun else { return }
        didPromptForAccessibilityThisRun = true

        presentAlertSheet(
            messageText: "Accessibility Access Required",
            informativeText: "Focus needs Accessibility access to monitor which app you're using. Turn it on in System Settings → Privacy & Security → Accessibility, then come back to Focus. The app will re-check automatically.",
            style: .warning,
            buttons: ["Open System Settings", "Later"]
        ) { response in
            if response == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func startAccessibilityPolling() {
        guard accessibilityPollTimer == nil else { return }

        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self.accessibilityPollTimer = nil
        }
    }

    private func setupMainWindow() {
        let rootView = MainWindowView(
            taskStore: taskStore,
            sessionManager: sessionManager,
            onStartFocus: { [weak self] task in
                self?.sessionManager.startSession(task: task)
            },
            onToggleComplete: { [weak self] task in
                Task { @MainActor [weak self] in
                    self?.toggleTaskCompletion(task)
                }
            }
        )

        if let mainWindow {
            if let hostingController = mainWindow.contentViewController as? NSHostingController<MainWindowView> {
                hostingController.rootView = rootView
            } else {
                mainWindow.contentViewController = NSHostingController(rootView: rootView)
            }
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Focus"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: rootView)
        window.center()
        mainWindow = window
    }

    private func presentAlertSheet(
        messageText: String,
        informativeText: String,
        style: NSAlert.Style,
        buttons: [String],
        completion: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = style
        buttons.forEach { alert.addButton(withTitle: $0) }

        if let mainWindow {
            alert.beginSheetModal(for: mainWindow, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
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

    private func showMainWindow() {
        setupMainWindow()
        mainWindow?.makeKeyAndOrderFront(nil)
        mainWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func toggleTaskCompletion(_ task: FocusTask) {
        guard let updatedTask = taskStore.toggleComplete(id: task.id) else { return }

        if updatedTask.isComplete,
           sessionManager.activeSession?.task.id == updatedTask.id {
            escalationManager?.stopMonitoring()
            sessionManager.endSession()
        }
    }
}
