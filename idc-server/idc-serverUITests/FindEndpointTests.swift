import XCTest

final class FindEndpointTests: XCTestCase {
    private static let server = TestServer()

    override func setUp() async throws {
        continueAfterFailure = false
        try await Self.server.start()
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
        await MainActor.run {
            let app = XCUIApplication()
            let tab = app.tabBars.buttons["Test"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
        }
        try await waitForForegroundFixture()
    }

    override func tearDown() async throws {
        await Self.server.stop()
    }

    func testFindByIdentifier() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("Tap Me")
        )
        let (response, http) = try await postFind(plan: plan, limit: 20)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(response.matches.count, 1)
        XCTAssertEqual(response.matches.first?.label, "Tap Me")
        XCTAssertEqual(response.truncated, false)
    }

    func testFindLimitTruncates() async throws {
        let plan = plan(
            .descendants(type: "button")
        )
        let (response, http) = try await postFind(plan: plan, limit: 1)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(response.matches.count, 1)
        XCTAssertTrue(response.truncated)
    }

    func testFindNoMatches() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("nope")
        )
        let (response, http) = try await postFind(plan: plan, limit: 5)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(response.matches.count, 0)
        XCTAssertEqual(response.truncated, false)
    }

    func testFindEmptyBodyError() async throws {
        let (data, http) = try await postFindRaw(body: Data())
        XCTAssertEqual(http.statusCode, 400)
        let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
        XCTAssertTrue(error.error.lowercased().contains("empty"))
    }

    func testFindInvalidJSONError() async throws {
        let (data, http) = try await postFindRaw(body: Data("{".utf8))
        XCTAssertEqual(http.statusCode, 400)
        let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
        XCTAssertTrue(error.error.contains("Invalid JSON"))
    }

    private func plan(_ ops: ExecutionOp...) -> ExecutionPlan {
        ExecutionPlan(pipeline: ops)
    }

    private func postFind(plan: ExecutionPlan, limit: Int) async throws -> (FindResponse, HTTPURLResponse) {
        let (data, response) = try await postFindRaw(plan: plan, limit: limit)
        let httpResponse = response
        let payload = try JSONDecoder().decode(FindResponse.self, from: data)
        return (payload, httpResponse)
    }

    private func postFindRaw(plan: ExecutionPlan, limit: Int) async throws -> (Data, HTTPURLResponse) {
        let body = FindRequest(plan: plan, limit: limit)
        return try await postFindRaw(body: try JSONEncoder().encode(body))
    }

    private func postFindRaw(body: Data?) async throws -> (Data, HTTPURLResponse) {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestServer.defaultPort)/find"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        return (data, httpResponse)
    }

    private func waitForForegroundFixture(timeout: TimeInterval = 5) async throws {
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
}
