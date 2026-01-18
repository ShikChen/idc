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

    private enum State {
        case idle
        case running
        case stopping
    }

    private let server: HTTPServer
    private var serverTask: Task<Void, Error>?
    private var stopTask: Task<Void, Never>?
    private var routesConfigured = false
    private var state: State = .idle

    init(port: UInt16 = TestServer.defaultPort) {
        server = HTTPServer(port: port)
    }

    func start() async throws {
        await configureRoutesIfNeeded()
        if let stopTask {
            await stopTask.value
        }
        guard state != .running else { return }
        state = .running
        startServerTaskIfNeeded()
        try await server.waitUntilListening(timeout: 5)
    }

    func stop() async {
        guard state != .idle else { return }
        if let stopTask {
            await stopTask.value
            return
        }
        state = .stopping
        let server = server
        let task = Task { [serverTask] in
            await server.stop()
            if let serverTask {
                _ = try? await serverTask.value
            }
        }
        stopTask = task
        await task.value
        stopTask = nil
        serverTask = nil
        state = .idle
    }

    func runForever() async throws {
        try await start()
        guard let task = serverTask else { return }
        do {
            try await task.value
        } catch {
            if state == .stopping { return }
            throw error
        }
    }

    private func startServerTaskIfNeeded() {
        guard serverTask == nil else { return }
        let server = server
        serverTask = Task { [weak self] in
            do {
                try await server.run()
            } catch {
                await self?.serverDidFinish()
                throw error
            }
            await self?.serverDidFinish()
        }
    }

    private func serverDidFinish() async {
        serverTask = nil
        if state != .stopping {
            state = .idle
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
