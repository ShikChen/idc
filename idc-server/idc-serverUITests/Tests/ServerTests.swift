//
//  ServerTests.swift
//  idc-serverUITests
//
//  Created by Shik Chen on 2026/1/10.
//

import XCTest

final class ServerEndpointsTests: XCTestCase {
    private static let server = TestServer()

    override func setUp() async throws {
        continueAfterFailure = false
        try await TestHelpers.startServer(Self.server)
    }

    override func tearDown() async throws {
        await TestHelpers.stopServer(Self.server)
    }

    func testHealth() async throws {
        let (data, httpResponse) = try await TestHelpers.get("health")

        XCTAssertEqual(httpResponse.statusCode, 200)

        let payload = try TestHelpers.decode(HealthResponse.self, from: data)
        XCTAssertEqual(payload.status, "ok")
    }

    func testInfo() async throws {
        let (data, httpResponse) = try await TestHelpers.get("info")

        XCTAssertEqual(httpResponse.statusCode, 200)

        let info = try TestHelpers.decode(InfoResponse.self, from: data)
        XCTAssertFalse(info.name.isEmpty)
        XCTAssertFalse(info.model.isEmpty)
        XCTAssertFalse(info.os_version.isEmpty)
        #if targetEnvironment(simulator)
            XCTAssertTrue(info.is_simulator)
            XCTAssertNotNil(info.udid)
        #else
            XCTAssertFalse(info.is_simulator)
        #endif
    }

    func testSnapshot() async throws {
        let appState = await MainActor.run {
            let app = XCUIApplication()
            app.launch()
            let tab = app.tabBars.buttons["Controls"]
            if tab.waitForExistence(timeout: 5) {
                tab.tap()
            }
            return app.state
        }
        XCTAssertEqual(appState, .runningForeground)

        let (data, httpResponse) = try await TestHelpers.get("snapshot")

        XCTAssertEqual(httpResponse.statusCode, 200)

        let payload = try TestHelpers.decode(SnapshotResponse.self, from: data)
        XCTAssertFalse(payload.root.element.elementType.isEmpty)
        XCTAssertGreaterThanOrEqual(payload.root.element.frame.width, 0)
        XCTAssertGreaterThanOrEqual(payload.root.element.frame.height, 0)
    }
}

final class ServerKeepAliveTests: XCTestCase {
    private static let server = TestServer()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testServerKeepAlive() async throws {
        guard ProcessInfo.processInfo.environment["IDC_KEEP_ALIVE"] == "1" else {
            throw XCTSkip("IDC_KEEP_ALIVE not set.")
        }
        try await Self.server.runForever()
    }
}
