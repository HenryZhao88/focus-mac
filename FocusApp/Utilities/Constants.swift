// FocusApp/Utilities/Constants.swift
import Foundation

enum Constants {
    static let wsPort: UInt16 = 54321
    static let monitorIntervalSeconds: TimeInterval = 10
    static let nudgeGracePeriodSeconds: TimeInterval = 120  // 2 minutes
    static let claudeModel = "claude-haiku-4-5-20251001"
    static let claudeAPIURL = "https://api.anthropic.com/v1/messages"
    static let claudeAPIKey: String = {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }()
}
