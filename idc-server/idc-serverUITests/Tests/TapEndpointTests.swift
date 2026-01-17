import XCTest

final class TapEndpointTests: XCTestCase {
    private static let server = TestServer()

    override func setUp() async throws {
        continueAfterFailure = false
        try await TestHelpers.startServer(Self.server)
        try await TestHelpers.launchOrActivateApp()
        try await TestHelpers.switchToTestTab()
        try await TestHelpers.resetTapCount()
        try await TestHelpers.waitForForegroundFixture()
    }

    override func tearDown() async throws {
        await TestHelpers.stopServer(Self.server)
    }

    func testTapByIdentifier() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchIdentifier("Tap Me")
        )
        try await assertTapCount("Tap Count: 0")
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Tap Me")
        try await waitForTapCount("Tap Count: 1")
    }

    func testTapDescendantCombinator() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .descendants(type: "button"),
            .matchPredicate(format: "label == %@", args: [TestHelpers.arg("Primary")])
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Primary")
    }

    func testTapChildCombinator() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .children(type: "any"),
            .matchIdentifier("button-group")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.identifier, "button-group")
    }

    func testTapHasTypeAndIdentifier() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .containTypeIdentifier(type: "button", value: "Secondary")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.identifier, "root")
    }

    func testTapHasPredicate() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .containPredicate(
                format: "(elementType == %@) AND (label == %@)",
                args: [TestHelpers.typeArg("button"), TestHelpers.arg("Secondary")]
            )
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.identifier, "root")
    }

    func testTapMatchTypeIdentifier() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchTypeIdentifier(type: "button", value: "Primary")
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Primary")
    }

    func testTapPredicateOr() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "button"),
            .matchPredicate(
                format: "(label == %@) OR (label == %@)",
                args: [TestHelpers.arg("Primary"), TestHelpers.arg("Secondary")]
            )
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Primary")
    }

    func testTapPredicateNot() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchIdentifier("root"),
            .descendants(type: "button"),
            .matchPredicate(format: "NOT (label == %@)", args: [TestHelpers.arg("Secondary")])
        )
        let (response, _) = try await postTap(plan)
        XCTAssertNotEqual(response.selected?.label, "Secondary")
    }

    func testTapInvalidPredicateFormat() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "button"),
            .matchPredicate(format: "label ==", args: [])
        )
        let (data, response) = try await postTapRaw(plan: plan, at: nil)
        try TestHelpers.assertBadRequest(response, data: data, contains: "Invalid predicate")
    }

    func testTapOnlyError() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "button"),
            .pickOnly
        )
        let (data, response) = try await postTapRaw(plan: plan, at: nil)
        try TestHelpers.assertBadRequest(response, data: data, contains: "unique")
    }

    func testTapEmptyPlanError() async throws {
        let plan = ExecutionPlan(pipeline: [])
        let (data, response) = try await postTapRaw(plan: plan, at: nil)
        XCTAssertEqual(response.statusCode, 400)
        let error = try TestHelpers.decode(ErrorResponse.self, from: data)
        XCTAssertTrue(error.error.lowercased().contains("selector") || error.error.lowercased().contains("tap point"))
    }

    func testTapEmptyBodyError() async throws {
        let (data, response) = try await postTapRaw(body: Data())
        try TestHelpers.assertBadRequest(response, data: data, contains: "empty")
    }

    func testTapInvalidJSONError() async throws {
        let (data, response) = try await postTapRaw(body: Data("nope".utf8))
        try TestHelpers.assertBadRequest(response, data: data, contains: "Invalid JSON")
    }

    func testTapPickIndex() async throws {
        let plan = TestHelpers.plan(
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
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchPredicate(format: "placeholderValue == %@", args: [TestHelpers.arg("Email")])
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.placeholderValue, "Email")
    }

    func testTapValue() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchPredicate(format: "value == %@", args: [TestHelpers.arg("hello")])
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.value, "hello")
    }

    func testTapDisabled() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchIdentifier("Disabled"),
            .matchPredicate(format: "isEnabled == %@", args: [TestHelpers.arg(false)])
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Disabled")
    }

    func testTapSelectedIsSelectedKey() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "button"),
            .matchIdentifier("Test"),
            .matchPredicate(format: "isSelected == %@", args: [TestHelpers.arg(true)])
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Test")
    }

    func testTapHasFocusKey() async throws {
        let plan = TestHelpers.plan(
            .descendants(type: "any"),
            .matchIdentifier("Tap Me"),
            .matchPredicate(format: "hasFocus == %@", args: [TestHelpers.arg(false)])
        )
        let (response, _) = try await postTap(plan)
        XCTAssertEqual(response.selected?.label, "Tap Me")
    }

    func testTapToggleSwitch() async throws {
        let plan = TestHelpers.plan(
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

    func testTapScreenPointPercent() async throws {
        let point = await MainActor.run { () -> TapPoint in
            let app = XCUIApplication()
            let button = app.buttons["Tap Me"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            let appFrame = app.frame
            let buttonFrame = button.frame
            let xPct = ((buttonFrame.midX - appFrame.minX) / appFrame.width) * 100.0
            let yPct = ((buttonFrame.midY - appFrame.minY) / appFrame.height) * 100.0
            return TapPoint(
                space: .screen,
                point: PointSpec(
                    x: PointComponent(value: xPct, unit: .pct),
                    y: PointComponent(value: yPct, unit: .pct)
                )
            )
        }
        let (data, response) = try await postTapRaw(plan: nil, at: point)
        XCTAssertEqual(response.statusCode, 200)
        let payload = try TestHelpers.decode(TapResponse.self, from: data)
        XCTAssertNil(payload.selected)
        try await waitForTapCount("Tap Count: 1")
    }

    private func postTap(_ plan: ExecutionPlan) async throws -> (TapResponse, HTTPURLResponse) {
        let (data, response) = try await postTapRaw(plan: plan, at: nil)
        let httpResponse = response
        XCTAssertEqual(httpResponse.statusCode, 200)
        let payload = try TestHelpers.decode(TapResponse.self, from: data)
        return (payload, httpResponse)
    }

    private func postTapRaw(plan: ExecutionPlan?, at: TapPoint?) async throws -> (Data, HTTPURLResponse) {
        let body = TapRequest(plan: plan, at: at)
        return try await postTapRaw(body: try JSONEncoder().encode(body))
    }

    private func postTapRaw(body: Data?) async throws -> (Data, HTTPURLResponse) {
        return try await TestHelpers.post("tap", body: body)
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
        try await TestHelpers.waitForForegroundFixture(timeout: timeout)
    }
}
