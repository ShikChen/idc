//
//  idc_serverUITests.swift
//  idc-serverUITests
//
//  Created by Shik Chen on 2026/1/10.
//

import FlyingFox
import XCTest

final class idc_serverUITests: XCTestCase {
    private static let serverPort: UInt16 = 8080
    private static let server = HTTPServer(port: serverPort)
    private static var serverTask: Task<Void, Error>?
    private static var routesConfigured = false

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIApplication().launch()
    }

    func testHealthEndpoint() async throws {
        try await Self.startServerIfNeeded()

        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(Self.serverPort)/health"))
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)

        let payload = try JSONDecoder().decode(HealthResponse.self, from: data)
        XCTAssertEqual(payload.status, "ok")

        await Self.stopServerIfNeeded()
    }

    func testServerKeepAlive() async throws {
        try await Self.runServerForever()
    }
}

private extension idc_serverUITests {
    struct HealthResponse: Codable {
        let status: String
    }

    static func startServerIfNeeded() async throws {
        await configureRoutesIfNeeded()
        if serverTask == nil {
            serverTask = Task { try await server.run() }
            try await server.waitUntilListening(timeout: 5)
        }
    }

    static func stopServerIfNeeded() async {
        guard serverTask != nil else { return }
        await server.stop()
        serverTask?.cancel()
        serverTask = nil
    }

    static func runServerForever() async throws {
        await configureRoutesIfNeeded()
        try await server.run()
    }

    static func configureRoutesIfNeeded() async {
        guard !routesConfigured else { return }
        await server.appendRoute("/health", for: [.GET]) { _ in
            let body = try JSONEncoder().encode(HealthResponse(status: "ok"))
            return HTTPResponse(
                statusCode: .ok,
                headers: [.contentType: "application/json"],
                body: body
            )
        }
        routesConfigured = true
    }
}
