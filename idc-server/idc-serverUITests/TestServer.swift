//
//  TestServer.swift
//  idc-serverUITests
//
//  Created by Shik Chen on 2026/1/10.
//

import FlyingFox
import Foundation
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
        server = HTTPServer(port: port)
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
                let response = try await resolveTapRequest(tapRequest)
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

private func resolveTapRequest(_ tapRequest: TapRequest) async throws -> TapResponse {
    let executor = PlanExecutor()
    var lastError: Error?
    for attempt in 0 ..< 5 {
        do {
            return try await MainActor.run {
                guard let app = RunningApp.getForegroundApp() else {
                    throw PlanError.invalidPlan("No foreground app found.")
                }
                if tapRequest.plan == nil && tapRequest.at == nil {
                    throw PlanError.invalidPlan("Missing selector or tap point.")
                }
                let selected = try executor.resolve(tapRequest.plan, from: app)
                if tapRequest.at == nil, selected == nil {
                    throw PlanError.noMatches
                }
                try performTap(app: app, element: selected, point: tapRequest.at)
                let tapped = selected.map { TapElement(from: $0) }
                return TapResponse(selected: tapped)
            }
        } catch let error as PlanError {
            lastError = error
            if case .noMatches = error, attempt < 4 {
                try await Task.sleep(nanoseconds: 200_000_000)
                continue
            }
            throw error
        }
    }
    throw lastError ?? PlanError.noMatches
}

private func performTap(app: XCUIApplication, element: XCUIElement?, point: TapPoint?) throws {
    if let point {
        switch point.space {
        case .screen:
            let screenPoint = resolveScreenPoint(point.point)
            tapScreen(app: app, point: screenPoint)
        case .element:
            guard let element else {
                throw PlanError.invalidPlan("Missing selector for element-local tap.")
            }
            tapElement(element: element, point: point.point)
        }
        return
    }

    guard let element else {
        throw PlanError.invalidPlan("Missing selector or tap point.")
    }
    tapElementSmart(element)
}

private func tapElement(element: XCUIElement, point: PointSpec) {
    let size = element.frame.size
    let x = resolvePointComponent(point.x, size: size.width)
    let y = resolvePointComponent(point.y, size: size.height)
    let origin = element.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
    origin.withOffset(CGVector(dx: x, dy: y)).tap()
}

private func tapScreen(app: XCUIApplication, point: CGPoint) {
    let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
    let offset = CGVector(
        dx: point.x - app.frame.minX,
        dy: point.y - app.frame.minY
    )
    origin.withOffset(offset).tap()
}

private func tapElementSmart(_ element: XCUIElement) {
    // SwiftUI Toggle exposes an outer switch element whose label area isn't tappable in UI tests.
    // Tap the innermost switch descendant to hit the actual UISwitch control.
    if element.elementType == .switch {
        let target = toggleTapTarget(for: element)
        target.tap()
        return
    }
    element.tap()
}

private func toggleTapTarget(for element: XCUIElement) -> XCUIElement {
    let candidates = element.descendants(matching: .switch).allElementsBoundByIndex
    guard !candidates.isEmpty else { return element }
    var best: XCUIElement = element
    var bestArea = CGFloat.greatestFiniteMagnitude
    for candidate in candidates {
        let frame = candidate.frame
        let area = frame.width * frame.height
        guard area > 0 else { continue }
        if area < bestArea {
            best = candidate
            bestArea = area
        }
    }
    return best
}

private func resolveScreenPoint(_ point: PointSpec) -> CGPoint {
    let screenSize = XCUIScreen.main.screenshot().image.size
    let x = resolvePointComponent(point.x, size: screenSize.width)
    let y = resolvePointComponent(point.y, size: screenSize.height)
    return CGPoint(x: x, y: y)
}

private func resolvePointComponent(_ component: PointComponent, size: CGFloat) -> CGFloat {
    switch component.unit {
    case .pt:
        return component.value
    case .pct:
        return (component.value / 100.0) * size
    }
}
