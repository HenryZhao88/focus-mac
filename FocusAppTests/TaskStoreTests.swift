// FocusAppTests/TaskStoreTests.swift
import XCTest
@testable import FocusApp

final class TaskStoreTests: XCTestCase {
    func test_task_roundtripsJSON() throws {
        let task = Task(title: "CS Homework")
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)
        XCTAssertEqual(decoded.id, task.id)
        XCTAssertEqual(decoded.title, "CS Homework")
        XCTAssertFalse(decoded.isComplete)
    }
}
