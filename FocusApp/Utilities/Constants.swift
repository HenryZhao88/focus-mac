// FocusApp/Utilities/Constants.swift
import Foundation

enum Constants {
    static let wsPort: UInt16 = 54321
    static let monitorIntervalSeconds: TimeInterval = 10
    static let nudgeGracePeriodSeconds: TimeInterval = 120  // 2 minutes
    static let openAIModel = "gpt-4.1"
    static let openAIAPIURL = "https://api.openai.com/v1/chat/completions"
    static let openAIAPIKey: String = {
        // 1. Prefer env var (e.g. set in Xcode scheme or shell)
        if let val = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !val.isEmpty { return val }
        // 2. Fall back to .env file in working directory (project root when run from Xcode)
        if let contents = try? String(contentsOfFile: ".env", encoding: .utf8) {
            for line in contents.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("#"), trimmed.contains("=") else { continue }
                let parts = trimmed.components(separatedBy: "=")
                if parts[0].trimmingCharacters(in: .whitespaces) == "OPENAI_API_KEY" {
                    return parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }()
}
