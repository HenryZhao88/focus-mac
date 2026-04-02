// FocusApp/Models/AISignal.swift
import Foundation

enum AISignal: String {
    case onTask = "on_task"
    case drifting = "drifting"
    case offTask = "off_task"
}

enum GatekeeperDecision {
    case approved(message: String?)
    case denied(reason: String)
}
