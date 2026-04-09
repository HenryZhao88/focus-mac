// FocusApp/Services/AppMonitor.swift
import AppKit
import ApplicationServices

struct ActivitySnapshot {
    let appName: String
    let windowTitle: String
    let bundleID: String?
}

protocol AppMonitorProtocol {
    func currentActivity() -> ActivitySnapshot
    func frontWindowFrame() -> NSRect?
    func frontScreenFrame() -> NSRect?
}

extension AppMonitorProtocol {
    func frontWindowFrame() -> NSRect? { nil }
    func frontScreenFrame() -> NSRect? { nil }
}

final class AppMonitor: AppMonitorProtocol {
    func currentActivity() -> ActivitySnapshot {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return ActivitySnapshot(appName: "Unknown", windowTitle: "", bundleID: nil)
        }
        return ActivitySnapshot(
            appName: frontApp.localizedName ?? "Unknown",
            windowTitle: windowTitle(for: frontApp) ?? "",
            bundleID: frontApp.bundleIdentifier
        )
    }

    private func windowTitle(for app: NSRunningApplication) -> String? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let window = windowRef else { return nil }
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef) == .success else { return nil }
        return titleRef as? String
    }

    /// Returns the screen frame of the frontmost app's focused window in NSWindow coordinates (bottom-left origin).
    func frontWindowFrame() -> NSRect? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        guard let windowInfo = windowList.first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }),
              let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }

        let cgRect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0,
                            width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        guard primaryScreenHeight > 0 else { return nil }
        return NSRect(x: cgRect.origin.x,
                      y: primaryScreenHeight - cgRect.origin.y - cgRect.height,
                      width: cgRect.width,
                      height: cgRect.height)
    }

    func frontScreenFrame() -> NSRect? {
        guard let windowFrame = frontWindowFrame() else { return nil }

        return NSScreen.screens
            .max { lhs, rhs in
                intersectionArea(windowFrame, lhs.frame) < intersectionArea(windowFrame, rhs.frame)
            }?
            .frame
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}
