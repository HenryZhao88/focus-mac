// FocusAppTests/SessionManagerTests.swift
import XCTest
@testable import FocusApp

final class SessionManagerTests: XCTestCase {
    func test_startSession_setsActiveSession() {
        let manager = SessionManager()
        let task = FocusTask(title: "CS Homework")
        manager.startSession(task: task)
        XCTAssertNotNil(manager.activeSession)
        XCTAssertEqual(manager.activeSession?.task.title, "CS Homework")
    }

    func test_endSession_clearsActiveSession() {
        let manager = SessionManager()
        manager.startSession(task: FocusTask(title: "Math"))
        manager.endSession()
        XCTAssertNil(manager.activeSession)
    }

    func test_addToAllowlist_isReflected() {
        let manager = SessionManager()
        manager.startSession(task: FocusTask(title: "CS Homework"))
        manager.addToAllowlist("youtube.com")
        XCTAssertTrue(manager.isAllowlisted("youtube.com"))
    }

    func test_allowlist_clearsOnNewSession() {
        let manager = SessionManager()
        manager.startSession(task: FocusTask(title: "CS Homework"))
        manager.addToAllowlist("spotify.com")
        manager.endSession()
        manager.startSession(task: FocusTask(title: "Math"))
        XCTAssertFalse(manager.isAllowlisted("spotify.com"))
    }
}
