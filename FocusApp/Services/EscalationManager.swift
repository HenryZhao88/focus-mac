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
                if let bundleID = activity.bundleID { sessionManager.addToAllowlist(bundleID) }
                if let url = currentURL, let host = URL(string: url)?.host { sessionManager.addToAllowlist(host) }
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
        guard case .monitoring = state else { return }

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
                break
            case .drifting, .offTask:
                state = .nudging(since: Date(), appName: activity.appName)
                scheduleEscalation()
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
