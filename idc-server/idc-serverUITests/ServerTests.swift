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
        try await Self.server.start()
    }

    override func tearDown() async throws {
        await Self.server.stop()
    }

    func testHealth() async throws {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestServer.defaultPort)/health"))
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)

        let payload = try JSONDecoder().decode(HealthResponse.self, from: data)
        XCTAssertEqual(payload.status, "ok")
    }

    func testInfo() async throws {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestServer.defaultPort)/info"))
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)

        let info = try JSONDecoder().decode(InfoResponse.self, from: data)
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

    func testDescribeUI() async throws {
        let appState = await MainActor.run {
            let app = XCUIApplication()
            app.launch()
            let tab = app.tabBars.buttons["Test"]
            if tab.waitForExistence(timeout: 5) {
                tab.tap()
            }
            return app.state
        }
        XCTAssertEqual(appState, .runningForeground)

        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestServer.defaultPort)/describe-ui"))
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)

        let payload = try JSONDecoder().decode(DescribeUIResponse.self, from: data)
        XCTAssertFalse(payload.root.elementType.isEmpty)
        XCTAssertGreaterThanOrEqual(payload.root.frame.width, 0)
        XCTAssertGreaterThanOrEqual(payload.root.frame.height, 0)
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
