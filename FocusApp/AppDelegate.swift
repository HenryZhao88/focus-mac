// FocusApp/AppDelegate.swift
import AppKit
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
    private var mainWindow: NSWindow?

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        // 4. Start WebSocket server
        wsServer = WebSocketServer()
        wsServer?.onURLChange = { [weak self] url in
            guard let self else { return }
            Task { @MainActor in
                self.escalationManager.updateCurrentURL(url)
            }
        }
        wsServer?.start()

        // 5. Observe session lifecycle
        sessionManager.$activeSession
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                if session != nil {
                    self.overlayController?.show()
                    Task { @MainActor in
                        self.escalationManager.startMonitoring()
                    }
                } else {
                    self.overlayController?.hide()
                    Task { @MainActor in
                        self.escalationManager.stopMonitoring()
                    }
                }
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        wsServer?.stop()
        Task { @MainActor in
            escalationManager.stopMonitoring()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Private

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
        self.mainWindow = window
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
