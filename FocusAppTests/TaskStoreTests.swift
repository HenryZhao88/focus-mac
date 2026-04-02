// FocusAppTests/TaskStoreTests.swift
import XCTest
@testable import FocusApp

final class TaskStoreTests: XCTestCase {
    func test_task_roundtripsJSON() throws {
        let task = FocusTask(title: "CS Homework")
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(FocusTask.self, from: data)
        XCTAssertEqual(decoded.id, task.id)
        XCTAssertEqual(decoded.title, "CS Homework")
        XCTAssertFalse(decoded.isComplete)
    }

    func test_taskStore_addTask() {
        let store = TaskStore(storageKey: "test_tasks_\(UUID())")
        store.add(title: "CS Homework")
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].title, "CS Homework")
    }

    func test_taskStore_removeTask() {
        let store = TaskStore(storageKey: "test_tasks_\(UUID())")
        store.add(title: "Math Homework")
        let id = store.tasks[0].id
        store.remove(id: id)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    func test_taskStore_markComplete() {
        let store = TaskStore(storageKey: "test_tasks_\(UUID())")
        store.add(title: "History Reading")
        let id = store.tasks[0].id
        store.markComplete(id: id)
        XCTAssertTrue(store.tasks[0].isComplete)
    }
}
