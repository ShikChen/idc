import Foundation
import XCTest

// Shared test utilities to keep endpoint tests small and readable.
enum TestHelpers {
    static func baseURL() throws -> URL {
        try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestServer.defaultPort)"))
    }

    // MARK: - Server lifecycle

    static func startServer(_ server: TestServer) async throws {
        try await server.start()
    }

    static func stopServer(_ server: TestServer) async {
        await server.stop()
    }

    // MARK: - HTTP helpers

    static func get(_ path: String) async throws -> (Data, HTTPURLResponse) {
        let url = try baseURL().appendingPathComponent(path)
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        return (data, httpResponse)
    }

    static func post(_ path: String, body: Data?) async throws -> (Data, HTTPURLResponse) {
        let url = try baseURL().appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        return (data, httpResponse)
    }

    static func postJSON<T: Encodable>(_ path: String, payload: T) async throws -> (Data, HTTPURLResponse) {
        try await post(path, body: JSONEncoder().encode(payload))
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Fixture helpers

    static func launchOrActivateApp() async throws {
        let isRunning = await MainActor.run {
            let app = XCUIApplication()
            if app.state == .notRunning {
                app.launch()
            } else {
                app.activate()
            }
            return app.wait(for: .runningForeground, timeout: 5)
        }
        XCTAssertTrue(isRunning)
    }

    static func switchToTab(_ label: String) async throws {
        await MainActor.run {
            let app = XCUIApplication()
            let tab = app.tabBars.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
        }
    }

    static func resetTapCount() async throws {
        await MainActor.run {
            let app = XCUIApplication()
            let reset = app.buttons["Reset Tap Count"]
            XCTAssertTrue(reset.waitForExistence(timeout: 5))
            reset.tap()
            let label = app.staticTexts["Tap Count: 0"]
            XCTAssertTrue(label.waitForExistence(timeout: 5))
        }
    }

    static func waitForForegroundFixture(timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let ready = await MainActor.run {
                guard let app = RunningApp.getForegroundApp() else { return false }
                return app.staticTexts["Tap Count: 0"].exists
            }
            if ready { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTFail("Foreground app did not expose fixture UI in time.")
    }

    // MARK: - Builders

    static func plan(_ ops: ExecutionOp...) -> ExecutionPlan {
        ExecutionPlan(pipeline: ops)
    }

    static func arg(_ value: String) -> PredicateArg {
        .string(value)
    }

    static func arg(_ value: Bool) -> PredicateArg {
        .bool(value)
    }

    static func arg(_ value: Double) -> PredicateArg {
        .number(value)
    }

    static func typeArg(_ value: String) -> PredicateArg {
        .elementType(value)
    }

    // MARK: - Assertions

    static func assertBadRequest(_ response: HTTPURLResponse, data: Data, contains text: String, code: ErrorCode? = nil) throws {
        XCTAssertEqual(response.statusCode, 400)
        let error = try decode(ErrorResponse.self, from: data)
        XCTAssertTrue(error.error.contains(text))
        if let code {
            XCTAssertEqual(error.errorCode, code)
        }
    }
}
