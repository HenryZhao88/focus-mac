// FocusApp/Services/SessionManager.swift
import Foundation

final class SessionManager: ObservableObject {
    @Published private(set) var activeSession: FocusSession?

    var isActive: Bool { activeSession != nil }

    func startSession(task: FocusTask) {
        activeSession = FocusSession(task: task)
    }

    func endSession() {
        activeSession = nil
    }

    func addToAllowlist(_ identifier: String) {
        activeSession?.allowlist.insert(identifier.lowercased())
    }

    func isAllowlisted(_ identifier: String) -> Bool {
        activeSession?.allowlist.contains(identifier.lowercased()) ?? false
    }
}
