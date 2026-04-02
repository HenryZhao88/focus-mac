// FocusApp/Utilities/Constants.swift
import Foundation

enum Constants {
    static let wsPort: UInt16 = 54321
    static let monitorIntervalSeconds: TimeInterval = 10
    static let nudgeGracePeriodSeconds: TimeInterval = 120  // 2 minutes
    static let openAIModel = "gpt-4.1"
    static let openAIAPIURL = "https://api.openai.com/v1/chat/completions"
    static let openAIAPIKey: String = loadOpenAIAPIKey()

    private static func loadOpenAIAPIKey() -> String {
        if let value = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return stripWrappingQuotes(from: value)
        }

        for url in candidateDotEnvURLs() {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  let value = value(for: "OPENAI_API_KEY", in: contents),
                  !value.isEmpty else { continue }
            return value
        }

        return ""
    }

    private static func candidateDotEnvURLs() -> [URL] {
        var candidates: [URL] = []
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        candidates.append(cwd.appendingPathComponent(".env"))

        var current = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<5 {
            candidates.append(current.appendingPathComponent(".env"))
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }

        candidates.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".env"))

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func value(for key: String, in dotenv: String) -> String? {
        for line in dotenv.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let assignment = trimmed.hasPrefix("export ") ? String(trimmed.dropFirst(7)) : trimmed
            guard let separator = assignment.firstIndex(of: "=") else { continue }

            let candidateKey = assignment[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            guard candidateKey == key else { continue }

            let rawValue = assignment[assignment.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stripWrappingQuotes(from: rawValue)
        }

        return nil
    }

    private static func stripWrappingQuotes(from value: String) -> String {
        guard value.count >= 2,
              let first = value.first,
              let last = value.last,
              (first == "\"" && last == "\"") || (first == "'" && last == "'") else {
            return value
        }

        return String(value.dropFirst().dropLast())
    }
}
