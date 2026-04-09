// FocusApp/Services/EscalationManager.swift
import Foundation

enum EscalationState {
    case monitoring
    case nudging(since: Date, appName: String)
    case blocking
}

@MainActor
final class EscalationManager: ObservableObject {
    @Published var state: EscalationState = .monitoring

    let sessionManager: SessionManager
    private let ai: AIServiceProtocol
    private let appMonitor: AppMonitorProtocol
    private let nudgeGracePeriod: TimeInterval

    private var monitorTimer: Timer?
    private var nudgeTimer: Timer?
    private(set) var currentURL: String?

    init(ai: AIServiceProtocol, sessionManager: SessionManager, appMonitor: AppMonitorProtocol, nudgeGracePeriod: TimeInterval = Constants.nudgeGracePeriodSeconds) {
        self.ai = ai
        self.sessionManager = sessionManager
        self.appMonitor = appMonitor
        self.nudgeGracePeriod = nudgeGracePeriod
    }

    func startMonitoring() {
        monitorTimer?.invalidate()
        nudgeTimer?.invalidate()
        nudgeTimer = nil
        state = .monitoring
        Task { await runCheck() }
        monitorTimer = Timer.scheduledTimer(withTimeInterval: Constants.monitorIntervalSeconds, repeats: true) { [weak self] _ in
            Task { await self?.runCheck() }
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        nudgeTimer?.invalidate()
        monitorTimer = nil
        nudgeTimer = nil
        state = .monitoring
    }

    func updateCurrentURL(_ url: String?) {
        currentURL = url
        guard sessionManager.isActive else { return }
        Task { await runCheck() }
    }

    func dismissNudge() {
        nudgeTimer?.invalidate()
        nudgeTimer = nil
        state = .monitoring
    }

    func requestUnlock(request: String) async -> GatekeeperDecision {
        guard let session = sessionManager.activeSession else {
            return .denied(reason: "No active session.")
        }
        let activity = appMonitor.currentActivity()
        do {
            let decision = try await ai.evaluateRequest(
                task: session.task.title,
                request: request,
                currentApp: activity.appName,
                currentURL: currentURL
            )
            switch decision {
            case .approved:
                if let url = currentURL, let host = URL(string: url)?.host {
                    // Browser: allowlist just this site, not the whole browser
                    sessionManager.addToAllowlist(host)
                } else if let bundleID = activity.bundleID {
                    let knownBrowsers: Set<String> = ["com.google.chrome", "com.apple.safari", "com.apple.safaritechnologypreview", "org.mozilla.firefox", "com.brave.browser", "com.microsoft.edgemac", "company.thebrowser.browser"]
                    if knownBrowsers.contains(bundleID.lowercased()) {
                        // Deny blanket allowlist of browser if URL isn't captured
                        return .denied(reason: "Content not fully loaded. Wait a moment and try again.")
                    } else {
                        // Non-browser app: allowlist the whole app
                        sessionManager.addToAllowlist(bundleID)
                    }
                }
                nudgeTimer?.invalidate()
                state = .monitoring
            case .denied:
                // Reset the grace period so user gets another 2 minutes before hard block
                nudgeTimer?.invalidate()
                scheduleEscalation()
            }
            return decision
        } catch {
            return .denied(reason: "Couldn't reach AI. Try again.")
        }
    }

    // Internal: exposed for testing
    func runCheck() async {
        guard let session = sessionManager.activeSession else { return }
        guard case .blocking != state else { return } // Stop checking if already hard-blocked

        let activity = appMonitor.currentActivity()

        // Skip if allowlisted
        if let id = activity.bundleID, sessionManager.isAllowlisted(id) { return }
        if let url = currentURL, let host = URL(string: url)?.host, sessionManager.isAllowlisted(host) { return }

        do {
            let signal = try await ai.checkActivity(
                task: session.task.title,
                activeApp: activity.appName,
                windowTitle: activity.windowTitle,
                url: currentURL,
                allowlist: session.allowlist
            )
            switch signal {
            case .onTask:
                if case .nudging = state {
                    dismissNudge()
                }
            case .drifting, .offTask:
                if case .monitoring = state {
                    state = .nudging(since: Date(), appName: activity.appName)
                    scheduleEscalation()
                }
            }
        } catch {
            // Don't disrupt user on API errors
        }
    }

    private func scheduleEscalation() {
        nudgeTimer = Timer.scheduledTimer(withTimeInterval: nudgeGracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.state = .blocking }
        }
    }
}
