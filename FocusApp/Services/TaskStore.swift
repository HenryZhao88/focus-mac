// FocusApp/Services/TaskStore.swift
import Foundation

final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [FocusTask] = []
    private let storageKey: String

    init(storageKey: String = "focusapp.tasks") {
        self.storageKey = storageKey
        load()
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tasks.append(FocusTask(title: trimmed))
        save()
    }

    func remove(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func markComplete(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isComplete = true
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([FocusTask].self, from: data) else { return }
        tasks = saved
    }
}
