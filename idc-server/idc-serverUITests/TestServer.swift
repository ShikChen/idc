//
//  TestServer.swift
//  idc-serverUITests
//
//  Created by Shik Chen on 2026/1/10.
//

import Foundation
import FlyingFox
import UIKit
import XCTest

struct HealthResponse: Codable {
    let status: String
}

struct InfoResponse: Codable {
    let name: String
    let model: String
    let os_version: String
    let is_simulator: Bool
    let udid: String?
}

struct ErrorResponse: Codable {
    let error: String
}

private let isSimulator: Bool = {
#if targetEnvironment(simulator)
    return true
#else
    return false
#endif
}()

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
        await server.appendRoute("/info", for: [.GET]) { _ in
            let response = await MainActor.run {
                InfoResponse(
                    name: UIDevice.current.name,
                    model: UIDevice.current.model,
                    os_version: UIDevice.current.systemVersion,
                    is_simulator: isSimulator,
                    udid: ProcessInfo.processInfo.environment["SIMULATOR_UDID"]
                )
            }
            let body = try JSONEncoder().encode(response)
            return HTTPResponse(
                statusCode: .ok,
                headers: [.contentType: "application/json"],
                body: body
            )
        }
        await server.appendRoute("/screenshot", for: [.GET]) { _ in
            let data = await MainActor.run {
                XCUIScreen.main.screenshot().pngRepresentation
            }
            return HTTPResponse(
                statusCode: .ok,
                headers: [.contentType: "image/png"],
                body: data
            )
        }
        await server.appendRoute("/describe-ui", for: [.GET]) { _ in
            do {
                let root = try await MainActor.run {
                    guard let app = RunningApp.getForegroundApp() else {
                        throw NSError(
                            domain: "idc.describe-ui",
                            code: 409,
                            userInfo: [NSLocalizedDescriptionKey: "No foreground app found."]
                        )
                    }
                    let snapshot = try app.snapshot()
                    return buildDescribeNode(snapshot)
                }
                let body = try JSONEncoder().encode(DescribeUIResponse(root: root))
                return HTTPResponse(
                    statusCode: .ok,
                    headers: [.contentType: "application/json"],
                    body: body
                )
            } catch {
                let nsError = error as NSError
                let status: HTTPStatusCode = nsError.code == 409 ? .conflict : .internalServerError
                let body = try JSONEncoder().encode(ErrorResponse(error: error.localizedDescription))
                return HTTPResponse(
                    statusCode: status,
                    headers: [.contentType: "application/json"],
                    body: body
                )
            }
        }
        await server.appendRoute("/tap", for: [.POST]) { request in
            do {
                let tapRequest = try JSONDecoder().decode(TapRequest.self, from: await request.bodyData)
                guard let selector = tapRequest.selector else {
                    throw SelectorError.invalidQuery("Missing selector.")
                }
                let response = try await MainActor.run {
                    guard let app = RunningApp.getForegroundApp() else {
                        throw SelectorError.invalidQuery("No foreground app found.")
                    }
                    let matches = try resolveSelector(selector, from: app)
                    guard !matches.isEmpty else {
                        throw SelectorError.noMatches
                    }
                    let selected = TapElement(from: matches[0])
                    return TapResponse(matched: matches.count, selected: selected)
                }
                let body = try JSONEncoder().encode(response)
                return HTTPResponse(
                    statusCode: .ok,
                    headers: [.contentType: "application/json"],
                    body: body
                )
            } catch {
                let message = error.localizedDescription
                let body = try JSONEncoder().encode(ErrorResponse(error: message))
                return HTTPResponse(
                    statusCode: .badRequest,
                    headers: [.contentType: "application/json"],
                    body: body
                )
            }
        }
        routesConfigured = true
    }
}
