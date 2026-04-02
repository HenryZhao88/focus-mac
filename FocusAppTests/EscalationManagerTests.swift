// FocusAppTests/EscalationManagerTests.swift
import XCTest
@testable import FocusApp

// Mock AI that always returns a fixed signal
final class MockAIService: AIServiceProtocol {
    var monitorSignal: AISignal = .onTask
    var gatekeeperDecision: GatekeeperDecision = .approved(message: nil)

    func checkActivity(task: String, activeApp: String, windowTitle: String, url: String?, allowlist: Set<String>) async throws -> AISignal {
        monitorSignal
    }
    func evaluateRequest(task: String, request: String, currentApp: String, currentURL: String?) async throws -> GatekeeperDecision {
        gatekeeperDecision
    }
}

// Mock app monitor
final class MockAppMonitor: AppMonitorProtocol {
    var snapshot = ActivitySnapshot(appName: "YouTube", windowTitle: "Watch", bundleID: "com.google.youtube")
    func currentActivity() -> ActivitySnapshot { snapshot }
    func frontScreenFrame() -> NSRect? { nil }
}

@MainActor
final class EscalationManagerTests: XCTestCase {
    func test_check_onTask_staysMonitoring() async {
        let ai = MockAIService()
        ai.monitorSignal = .onTask
        let session = SessionManager()
        session.startSession(task: FocusTask(title: "CS Homework"))
        let manager = EscalationManager(ai: ai, sessionManager: session, appMonitor: MockAppMonitor(), nudgeGracePeriod: 60)

        await manager.runCheck()

        if case .monitoring = manager.state { } else { XCTFail("Expected monitoring, got \(manager.state)") }
    }

    func test_check_drifting_transitionsToNudging() async {
        let ai = MockAIService()
        ai.monitorSignal = .drifting
        let session = SessionManager()
        session.startSession(task: FocusTask(title: "CS Homework"))
        let manager = EscalationManager(ai: ai, sessionManager: session, appMonitor: MockAppMonitor(), nudgeGracePeriod: 60)

        await manager.runCheck()

        if case .nudging = manager.state { } else { XCTFail("Expected nudging, got \(manager.state)") }
    }

    func test_dismissNudge_returnsToMonitoring() async {
        let ai = MockAIService()
        ai.monitorSignal = .drifting
        let session = SessionManager()
        session.startSession(task: FocusTask(title: "CS Homework"))
        let manager = EscalationManager(ai: ai, sessionManager: session, appMonitor: MockAppMonitor(), nudgeGracePeriod: 60)
        await manager.runCheck()
        manager.dismissNudge()
        if case .monitoring = manager.state { } else { XCTFail("Expected monitoring") }
    }

    func test_noSession_doesNotChangeState() async {
        let ai = MockAIService()
        ai.monitorSignal = .offTask
        let session = SessionManager()  // no active session
        let manager = EscalationManager(ai: ai, sessionManager: session, appMonitor: MockAppMonitor(), nudgeGracePeriod: 60)

        await manager.runCheck()

        if case .monitoring = manager.state { } else { XCTFail("Expected monitoring") }
    }
}
