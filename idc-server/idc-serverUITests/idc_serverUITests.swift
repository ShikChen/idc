//
//  idc_serverUITests.swift
//  idc-serverUITests
//
//  Created by Shik Chen on 2026/1/10.
//

import XCTest

final class HealthEndpointTests: XCTestCase {
    private static let server = TestServer()

    override func setUp() async throws {
        continueAfterFailure = false
        try await Self.server.start()
    }

    override func tearDown() async throws {
        await Self.server.stop()
    }

    func testHealthEndpoint() async throws {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestServer.defaultPort)/health"))
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)

        let payload = try JSONDecoder().decode(HealthResponse.self, from: data)
        XCTAssertEqual(payload.status, "ok")
    }
}

final class ServerKeepAliveTests: XCTestCase {
    private static let server = TestServer()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testServerKeepAlive() async throws {
        try await Self.server.runForever()
    }
}
