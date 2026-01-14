import XCTest

final class TapEndpointTests: XCTestCase {
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
            let reset = app.buttons["Reset Tap Count"]
            XCTAssertTrue(reset.waitForExistence(timeout: 5))
            reset.tap()
            let label = app.staticTexts["Tap Count: 0"]
            XCTAssertTrue(label.waitForExistence(timeout: 5))
        }
        try await waitForForegroundFixture()
    }

    override func tearDown() async throws {
        await Self.server.stop()
    }

    func testTapByIdentifier() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("Tap Me")
        )
        try await assertTapCount("Tap Count: 0")
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Tap Me")
        try await waitForTapCount("Tap Count: 1")
    }

    func testTapDescendantCombinator() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .descendants(type: "button"),
            .matchPredicate("label == \"Primary\"")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Primary")
    }

    func testTapChildCombinator() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .children(type: "any"),
            .matchIdentifier("button-group")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.identifier, "button-group")
    }

    func testTapHasTypeAndIdentifier() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .containTypeIdentifier(type: "button", value: "Secondary")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.identifier, "root")
    }

    func testTapHasPredicate() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .containPredicate("(elementType == 9) AND (label == \"Secondary\")")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.identifier, "root")
    }

    func testTapMatchTypeIdentifier() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchTypeIdentifier(type: "button", value: "Primary")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Primary")
    }

    func testTapPredicateOr() async throws {
        let plan = plan(
            .descendants(type: "button"),
            .matchPredicate("(label == \"Primary\") OR (label == \"Secondary\")")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Primary")
    }

    func testTapPredicateNot() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .descendants(type: "button"),
            .matchPredicate("NOT (label == \"Secondary\")")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertNotEqual(response.selected?.label, "Secondary")
    }

    func testTapOnlyError() async throws {
        let plan = plan(
            .descendants(type: "button"),
            .pickOnly
        )
        let (data, response) = try await postTapRaw(plan)
        XCTAssertEqual(response.statusCode, 400)
        let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
        XCTAssertTrue(error.error.lowercased().contains("unique"))
    }

    func testTapPickIndex() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchTypeIdentifier(type: "other", value: "root"),
            .descendants(type: "button"),
            .pickIndex(1)
        )
        let (exists, expectedLabel) = await MainActor.run {
            let app = XCUIApplication()
            let root = app.otherElements["root"]
            let element = root.descendants(matching: .button).element(boundBy: 1)
            return (element.exists, element.label)
        }
        XCTAssertTrue(exists)
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, expectedLabel)
    }

    func testTapPlaceholderValue() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchPredicate("placeholderValue == \"Email\"")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.placeholderValue, "Email")
    }

    func testTapValue() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchPredicate("value == \"hello\"")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.value, "hello")
    }

    func testTapDisabled() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("Disabled"),
            .matchPredicate("isEnabled == 0")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Disabled")
    }

    func testTapSelectedIsSelectedKey() async throws {
        let plan = plan(
            .descendants(type: "button"),
            .matchIdentifier("Test"),
            .matchPredicate("isSelected == 1")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Test")
    }

    func testTapHasFocusKey() async throws {
        let plan = plan(
            .descendants(type: "any"),
            .matchIdentifier("Tap Me"),
            .matchPredicate("hasFocus == 0")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Tap Me")
    }

    func testTapToggleSwitch() async throws {
        let plan = plan(
            .descendants(type: "switch"),
            .matchIdentifier("notifications-toggle")
        )
        await MainActor.run {
            let app = XCUIApplication()
            let label = app.staticTexts["Notifications: Off"]
            XCTAssertTrue(label.waitForExistence(timeout: 5))
        }
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.identifier, "notifications-toggle")
        await MainActor.run {
            let app = XCUIApplication()
            let label = app.staticTexts["Notifications: On"]
            XCTAssertTrue(label.waitForExistence(timeout: 5))
        }
    }

    private func plan(_ ops: ExecutionOp...) -> ExecutionPlan {
        ExecutionPlan(pipeline: ops)
    }

    private func postTap(_ plan: ExecutionPlan) async throws -> (TapResponse, HTTPURLResponse) {
        let (data, response) = try await postTapRaw(plan)
        let httpResponse = response
        XCTAssertEqual(httpResponse.statusCode, 200)
        let payload = try JSONDecoder().decode(TapResponse.self, from: data)
        return (payload, httpResponse)
    }

    private func postTapRaw(_ plan: ExecutionPlan) async throws -> (Data, HTTPURLResponse) {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestServer.defaultPort)/tap"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = TapRequest(plan: plan, at: nil)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        return (data, httpResponse)
    }

    private func assertTapCount(_ expected: String) async throws {
        await MainActor.run {
            let app = XCUIApplication()
            let label = app.staticTexts[expected]
            XCTAssertTrue(label.waitForExistence(timeout: 5))
        }
    }

    private func waitForTapCount(_ expected: String) async throws {
        await MainActor.run {
            let app = XCUIApplication()
            let label = app.staticTexts[expected]
            XCTAssertTrue(label.waitForExistence(timeout: 5))
        }
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
