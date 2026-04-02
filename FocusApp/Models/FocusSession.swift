// FocusApp/Models/FocusSession.swift
import Foundation

struct FocusSession: Equatable, Codable {
    let task: FocusTask
    let startTime: Date
    var allowlist: Set<String>  // bundle IDs and hostnames

    init(task: FocusTask) {
        self.task = task
        self.startTime = Date()
        self.allowlist = []
    }

    var elapsed: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var elapsedFormatted: String {
        let t = elapsed
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
