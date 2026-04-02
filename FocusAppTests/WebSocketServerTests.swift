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

    func test_onURLChange_fires_on_main_thread() {
        let expectation = self.expectation(description: "onURLChange fires on main thread")
        let server = WebSocketServer()
        var receivedURL: String?
        var wasMainThread = false

        server.onURLChange = { url in
            receivedURL = url
            wasMainThread = Thread.isMainThread
            expectation.fulfill()
        }
        server.start()

        // Give server time to bind
        Thread.sleep(forTimeInterval: 0.2)

        // Connect and send a URL via URLSession WebSocket
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: URL(string: "ws://localhost:54321")!)
        task.resume()
        task.send(.string("https://example.com")) { _ in }

        waitForExpectations(timeout: 3.0)
        XCTAssertEqual(receivedURL, "https://example.com")
        XCTAssertTrue(wasMainThread, "onURLChange should fire on main thread")

        task.cancel(with: .normalClosure, reason: nil)
        server.stop()
    }
}
