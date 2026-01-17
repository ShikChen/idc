//
//  TestServer.swift
//  idc-serverUITests
//
//  Created by Shik Chen on 2026/1/10.
//

import FlyingFox
import Foundation

actor TestServer {
    static let defaultPort: UInt16 = 8080

    private let server: HTTPServer
    private var serverTask: Task<Void, Error>?
    private var routesConfigured = false
    private var isStopping = false

    init(port: UInt16 = TestServer.defaultPort) {
        server = HTTPServer(port: port)
    }

    func start() async throws {
        await configureRoutesIfNeeded()
        if serverTask == nil {
            isStopping = false
            serverTask = Task { try await server.run() }
            try await server.waitUntilListening(timeout: 5)
        }
    }

    func stop() async {
        isStopping = true
        await server.stop()
        serverTask = nil
    }

    func runForever() async throws {
        await configureRoutesIfNeeded()
        isStopping = false
        do {
            try await server.run()
        } catch {
            if isStopping { return }
            throw error
        }
    }

    private func configureRoutesIfNeeded() async {
        guard !routesConfigured else { return }
        let healthHandler = HealthHandler()
        let infoHandler = InfoHandler()
        let screenshotHandler = ScreenshotHandler()
        let snapshotHandler = SnapshotHandler(service: SnapshotService())
        let tapHandler = TapHandler(service: TapService())
        let findHandler = FindHandler(service: FindService())

        await server.appendRoute("/health", for: [.GET]) { request in
            await healthHandler.handle(request)
        }
        await server.appendRoute("/info", for: [.GET]) { request in
            await infoHandler.handle(request)
        }
        await server.appendRoute("/screenshot", for: [.GET]) { request in
            await screenshotHandler.handle(request)
        }
        await server.appendRoute("/snapshot", for: [.GET]) { request in
            await snapshotHandler.handle(request)
        }
        await server.appendRoute("/tap", for: [.POST]) { request in
            await tapHandler.handle(request)
        }
        await server.appendRoute("/find", for: [.POST]) { request in
            await findHandler.handle(request)
        }
        await server.appendRoute("/stop", for: [.POST]) { _ in
            Task { await self.stop() }
            return jsonResponse(HealthResponse(status: "stopping"))
        }
        routesConfigured = true
    }
}
