// FocusApp/Utilities/Constants.swift
import Foundation

enum Constants {
    static let wsPort: UInt16 = 54321
    static let monitorIntervalSeconds: TimeInterval = 10
    static let nudgeGracePeriodSeconds: TimeInterval = 120  // 2 minutes
    static let openAIModel = "gpt-4.1"
    static let openAIAPIURL = "https://api.openai.com/v1/chat/completions"
    static let openAIAPIKey: String = {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }()
}
