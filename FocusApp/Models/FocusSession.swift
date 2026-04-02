// FocusApp/Models/FocusSession.swift
import Foundation

struct FocusSession {
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
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
