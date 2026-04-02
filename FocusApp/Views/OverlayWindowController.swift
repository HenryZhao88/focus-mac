// FocusApp/Views/OverlayWindowController.swift
import AppKit
import SwiftUI

final class OverlayWindowController: NSWindowController {
    private var escalationManager: EscalationManager
    private var sessionManager: SessionManager
    private let appMonitor: AppMonitorProtocol
    private let onStopFocus: () -> Void
    private let onCompleteFocus: () -> Void

    init(
        escalationManager: EscalationManager,
        sessionManager: SessionManager,
        appMonitor: AppMonitorProtocol = AppMonitor(),
        onStopFocus: @escaping () -> Void,
        onCompleteFocus: @escaping () -> Void
    ) {
        self.escalationManager = escalationManager
        self.sessionManager = sessionManager
        self.appMonitor = appMonitor
        self.onStopFocus = onStopFocus
        self.onCompleteFocus = onCompleteFocus

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 48),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false

        super.init(window: panel)

        let rootView = OverlayView(
            escalationManager: escalationManager,
            sessionManager: sessionManager,
            onStopFocus: onStopFocus,
            onCompleteFocus: onCompleteFocus
        )
        panel.contentView = NSHostingView(rootView: rootView)
        positionAtTopCenter()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() { window?.orderFrontRegardless() }
    func hide() { window?.orderOut(nil) }

    func expandForNudge() {
        guard let panel = window,
              let screenFrame = appMonitor.frontScreenFrame() ?? NSScreen.main?.frame else { return }
        let w: CGFloat = 320
        let h: CGFloat = 120
        let x = screenFrame.midX - w / 2
        let y = screenFrame.maxY - h - 8
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }
    }

    func expandForBlock() {
        guard let panel = window,
              let screenFrame = appMonitor.frontScreenFrame() ?? NSScreen.main?.frame else { return }
        let targetFrame = appMonitor.frontWindowFrame() ?? NSRect(
            x: screenFrame.midX - 300,
            y: screenFrame.midY - 200,
            width: 600,
            height: 400
        )
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    func collapseToBar() {
        positionAtTopCenter()
    }

    private func positionAtTopCenter() {
        guard let panel = window,
              let screenFrame = appMonitor.frontScreenFrame() ?? NSScreen.main?.frame else { return }
        let w: CGFloat = 320
        let h: CGFloat = 48
        let x = screenFrame.midX - w / 2
        let y = screenFrame.maxY - h - 8
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }
    }
}
