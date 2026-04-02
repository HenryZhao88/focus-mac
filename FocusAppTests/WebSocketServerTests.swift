// FocusAppTests/WebSocketServerTests.swift
import XCTest
@testable import FocusApp

final class WebSocketServerTests: XCTestCase {

    func test_server_starts_without_crash() {
        let server = WebSocketServer()
        server.start()
        Thread.sleep(forTimeInterval: 0.1)
        // No crash == pass
    }

    func test_server_stop_without_crash() {
        let server = WebSocketServer()
        server.start()
        Thread.sleep(forTimeInterval: 0.1)
        server.stop()
        // No crash == pass
    }

    func test_callback_set() {
        let server = WebSocketServer()
        var received: String? = "sentinel"
        server.onURLChange = { url in
            received = url
        }
        // Callback property can be assigned without crashing
        XCTAssertNotNil(server.onURLChange)
        // The sentinel value should still be unchanged (callback not fired yet)
        XCTAssertEqual(received, "sentinel")
    }
}
