// FocusApp/Services/AIService.swift
import Foundation

protocol AIServiceProtocol {
    func checkActivity(task: String, activeApp: String, windowTitle: String, url: String?, allowlist: Set<String>) async throws -> AISignal
    func evaluateRequest(task: String, request: String, currentApp: String, currentURL: String?) async throws -> GatekeeperDecision
}

final class AIService: AIServiceProtocol {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Public API

    func checkActivity(task: String, activeApp: String, windowTitle: String, url: String?, allowlist: Set<String>) async throws -> AISignal {
        let urlPart = url.map { " (URL: \($0))" } ?? ""
        let allowPart = allowlist.isEmpty ? "" : "\nApproved for this session: \(allowlist.joined(separator: ", "))"
        let message = """
        Task: "\(task)"
        Currently active: \(activeApp) — "\(windowTitle)"\(urlPart)\(allowPart)
        Reply with exactly one word: on_task, drifting, or off_task
        """
        let response = try await callAPI(
            system: "You are a focus monitor for a high school student. Be lenient — only flag clear distractions, not ambiguous cases.",
            user: message,
            maxTokens: 10
        )
        return parseSignal(response)
    }

    func evaluateRequest(task: String, request: String, currentApp: String, currentURL: String?) async throws -> GatekeeperDecision {
        let urlPart = currentURL.map { " at \($0)" } ?? ""
        let message = """
        Task: "\(task)"
        Currently on: \(currentApp)\(urlPart)
        Request: "\(request)"
        Reply with JSON only: {"decision": "approved" or "denied", "message": "one sentence"}
        """
        let response = try await callAPI(
            system: "You are a helpful focus guardian for a high school student. Approve genuinely useful requests. Deny clear distractions with a kind message.",
            user: message,
            maxTokens: 80
        )
        return parseGatekeeperResponse(response)
    }

    // MARK: - Parsing (internal for testability)

    func parseSignal(_ raw: String) -> AISignal {
        AISignal(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .onTask
    }

    func parseGatekeeperResponse(_ raw: String) -> GatekeeperDecision {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let decision = json["decision"] else {
            return .denied(reason: "Couldn't reach a decision. Stay focused!")
        }
        let message = json["message"]
        return decision == "approved" ? .approved(message: message) : .denied(reason: message ?? "Request denied.")
    }

    // MARK: - Network

    private func callAPI(system: String, user: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: Constants.openAIAPIURL) else { throw AIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Constants.openAIModel,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = ((json["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String else {
            throw AIError.malformedResponse
        }
        return content
    }
}

enum AIError: Error {
    case invalidURL
    case apiError(Int)
    case malformedResponse
}
