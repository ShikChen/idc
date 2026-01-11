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

struct DescribeUIResponse: Codable {
    let root: DescribeUINode
}

struct DescribeUINode: Codable {
    let identifier: String
    let elementType: String
    let value: JSONValue?
    let placeholderValue: String?
    let title: String
    let label: String
    let hasFocus: Bool
    let isEnabled: Bool
    let isSelected: Bool
    let frame: Frame
    let children: [DescribeUINode]
}

struct Frame: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.size.width)
        self.height = Double(rect.size.height)
    }
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    static func fromAny(_ value: Any?) -> JSONValue? {
        guard let value else { return nil }
        if let string = value as? String {
            return .string(string)
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        }
        if let bool = value as? Bool {
            return .bool(bool)
        }
        if let int = value as? Int {
            return .number(Double(int))
        }
        if let double = value as? Double {
            return .number(double)
        }
        if let float = value as? Float {
            return .number(Double(float))
        }
        if let cgFloat = value as? CGFloat {
            return .number(Double(cgFloat))
        }
        return .string(String(describing: value))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }
        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }
}

struct ErrorResponse: Codable {
    let error: String
}

struct RunningApp {
    static func getForegroundApp() -> XCUIApplication? {
        let runningAppIds = XCUIApplication.activeAppsInfo().compactMap { $0["bundleId"] as? String }
        if runningAppIds.count == 1, let bundleId = runningAppIds.first {
            return XCUIApplication(bundleIdentifier: bundleId)
        }
        for bundleId in runningAppIds {
            let app = XCUIApplication(bundleIdentifier: bundleId)
            if app.state == XCUIApplication.State.runningForeground {
                return app
            }
        }
        return nil
    }
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
        routesConfigured = true
    }
}

@MainActor
private func buildDescribeNode(_ snapshot: XCUIElementSnapshot) -> DescribeUINode {
    let children = snapshot.children.map { buildDescribeNode($0) }
    return DescribeUINode(
        identifier: snapshot.identifier,
        elementType: elementTypeName(snapshot.elementType),
        value: JSONValue.fromAny(snapshot.value),
        placeholderValue: snapshot.placeholderValue,
        title: snapshot.title,
        label: snapshot.label,
        hasFocus: snapshot.hasFocus,
        isEnabled: snapshot.isEnabled,
        isSelected: snapshot.isSelected,
        frame: Frame(snapshot.frame),
        children: children
    )
}

private func elementTypeName(_ type: XCUIElement.ElementType) -> String {
    if let name = elementTypeNames[type] {
        return name
    }
    return "unknown(\(type.rawValue))"
}

private let elementTypeNames: [XCUIElement.ElementType: String] = [
    .any: "any",
    .other: "other",
    .application: "application",
    .group: "group",
    .window: "window",
    .sheet: "sheet",
    .drawer: "drawer",
    .alert: "alert",
    .dialog: "dialog",
    .button: "button",
    .radioButton: "radioButton",
    .radioGroup: "radioGroup",
    .checkBox: "checkBox",
    .disclosureTriangle: "disclosureTriangle",
    .popUpButton: "popUpButton",
    .comboBox: "comboBox",
    .menuButton: "menuButton",
    .toolbarButton: "toolbarButton",
    .popover: "popover",
    .keyboard: "keyboard",
    .key: "key",
    .navigationBar: "navigationBar",
    .tabBar: "tabBar",
    .tabGroup: "tabGroup",
    .toolbar: "toolbar",
    .statusBar: "statusBar",
    .table: "table",
    .tableRow: "tableRow",
    .tableColumn: "tableColumn",
    .outline: "outline",
    .outlineRow: "outlineRow",
    .browser: "browser",
    .collectionView: "collectionView",
    .slider: "slider",
    .pageIndicator: "pageIndicator",
    .progressIndicator: "progressIndicator",
    .activityIndicator: "activityIndicator",
    .segmentedControl: "segmentedControl",
    .picker: "picker",
    .pickerWheel: "pickerWheel",
    .switch: "switch",
    .toggle: "toggle",
    .link: "link",
    .image: "image",
    .icon: "icon",
    .searchField: "searchField",
    .scrollView: "scrollView",
    .scrollBar: "scrollBar",
    .staticText: "staticText",
    .textField: "textField",
    .secureTextField: "secureTextField",
    .datePicker: "datePicker",
    .textView: "textView",
    .menu: "menu",
    .menuItem: "menuItem",
    .menuBar: "menuBar",
    .menuBarItem: "menuBarItem",
    .map: "map",
    .webView: "webView",
    .incrementArrow: "incrementArrow",
    .decrementArrow: "decrementArrow",
    .timeline: "timeline",
    .ratingIndicator: "ratingIndicator",
    .valueIndicator: "valueIndicator",
    .splitGroup: "splitGroup",
    .splitter: "splitter",
    .relevanceIndicator: "relevanceIndicator",
    .colorWell: "colorWell",
    .helpTag: "helpTag",
    .matte: "matte",
    .dockItem: "dockItem",
    .ruler: "ruler",
    .rulerMarker: "rulerMarker",
    .grid: "grid",
    .levelIndicator: "levelIndicator",
    .cell: "cell",
    .layoutArea: "layoutArea",
    .layoutItem: "layoutItem",
    .handle: "handle",
    .stepper: "stepper",
    .tab: "tab",
    .touchBar: "touchBar",
    .statusItem: "statusItem",
]
