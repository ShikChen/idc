//
//  TestServer.swift
//  idc-serverUITests
//
//  Created by Shik Chen on 2026/1/10.
//

import Foundation
import FlyingFox

struct HealthResponse: Codable {
    let status: String
}

actor TestServer {
    static let defaultPort: UInt16 = 8080

    private let server: HTTPServer
    private var serverTask: Task<Void, Error>?
    private var routesConfigured = false

    init(port: UInt16 = TestServer.defaultPort) {
        self.server = HTTPServer(port: port)
    }

    func start() async throws {
        await configureRoutesIfNeeded()
        if serverTask == nil {
            serverTask = Task { try await server.run() }
            try await server.waitUntilListening(timeout: 5)
        }
    }

    func stop() async {
        guard serverTask != nil else { return }
        await server.stop()
        serverTask = nil
    }

    func runForever() async throws {
        await configureRoutesIfNeeded()
        try await server.run()
    }

    private func configureRoutesIfNeeded() async {
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
