// FocusApp/Models/Task.swift
import Foundation

struct FocusTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isComplete: Bool

    init(id: UUID = UUID(), title: String, isComplete: Bool = false) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
    }
}
