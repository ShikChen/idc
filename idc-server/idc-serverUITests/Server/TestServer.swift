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

        typealias RouteHandler = @Sendable (HTTPRequest) async -> HTTPResponse
        let routes: [(path: String, methods: [HTTPMethod], handler: RouteHandler)] = [
            ("/health", [.GET], { request in await healthHandler.handle(request) }),
            ("/info", [.GET], { request in await infoHandler.handle(request) }),
            ("/screenshot", [.GET], { request in await screenshotHandler.handle(request) }),
            ("/snapshot", [.GET], { request in await snapshotHandler.handle(request) }),
            ("/tap", [.POST], { request in await tapHandler.handle(request) }),
            ("/find", [.POST], { request in await findHandler.handle(request) }),
            ("/stop", [.POST], { _ in
                Task { await self.stop() }
                return jsonResponse(HealthResponse(status: "stopping"))
            })
        ]

        for route in routes {
            await server.appendRoute(route.path, for: route.methods, handler: route.handler)
        }
        routesConfigured = true
    }
}
