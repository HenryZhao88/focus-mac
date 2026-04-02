// FocusAppTests/AIServiceTests.swift
import XCTest
@testable import FocusApp

final class AIServiceTests: XCTestCase {
    func test_parseSignal_onTask() {
        let service = AIService(apiKey: "test")
        XCTAssertEqual(service.parseSignal("on_task"), .onTask)
        XCTAssertEqual(service.parseSignal("  on_task  "), .onTask)
    }

    func test_parseSignal_drifting() {
        let service = AIService(apiKey: "test")
        XCTAssertEqual(service.parseSignal("drifting"), .drifting)
    }

    func test_parseSignal_offTask() {
        let service = AIService(apiKey: "test")
        XCTAssertEqual(service.parseSignal("off_task"), .offTask)
    }

    func test_parseSignal_unknownDefaultsToOnTask() {
        let service = AIService(apiKey: "test")
        XCTAssertEqual(service.parseSignal("garbage"), .onTask)
    }

    func test_parseGatekeeper_approvedJSON() {
        let service = AIService(apiKey: "test")
        let json = #"{"decision": "approved", "message": "Go for it!"}"#
        if case .approved(let msg) = service.parseGatekeeperResponse(json) {
            XCTAssertEqual(msg, "Go for it!")
        } else {
            XCTFail("Expected approved")
        }
    }

    func test_parseGatekeeper_deniedJSON() {
        let service = AIService(apiKey: "test")
        let json = #"{"decision": "denied", "message": "Stay focused."}"#
        if case .denied(let reason) = service.parseGatekeeperResponse(json) {
            XCTAssertEqual(reason, "Stay focused.")
        } else {
            XCTFail("Expected denied")
        }
    }

    func test_parseGatekeeper_malformedFallsBackToDenied() {
        let service = AIService(apiKey: "test")
        let result = service.parseGatekeeperResponse("not json at all")
        if case .denied = result { } else { XCTFail("Expected denied fallback") }
    }
}
