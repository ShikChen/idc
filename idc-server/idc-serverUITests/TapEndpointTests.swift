import XCTest

final class TapEndpointTests: XCTestCase {
    private static let server = TestServer()

    override func setUp() async throws {
        continueAfterFailure = false
        try await Self.server.start()
        let isRunning = await MainActor.run {
            let app = XCUIApplication()
            if app.state != .notRunning {
                app.terminate()
            }
            app.launchEnvironment["IDC_TEST_MODE"] = "1"
            app.launch()
            return app.wait(for: .runningForeground, timeout: 5)
        }
        XCTAssertTrue(isRunning)
    }

    override func tearDown() async throws {
        await Self.server.stop()
    }

    func testTapByIdentifier() async throws {
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .identifier, match: .eq, value: "root", caseFlag: .s)
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertEqual(response.selected?.identifier, "root")
    }

    func testTapDescendantCombinator() async throws {
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .identifier, match: .eq, value: "root", caseFlag: .s)
            ]),
            SelectorStep(axis: .descendant, ops: [
                .attrString(field: .identifier, match: .eq, value: "button-group", caseFlag: .s)
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertEqual(response.selected?.identifier, "button-group")
    }

    func testTapChildCombinator() async throws {
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .identifier, match: .eq, value: "root", caseFlag: .s)
            ]),
            SelectorStep(axis: .child, ops: [
                .attrString(field: .identifier, match: .eq, value: "button-group", caseFlag: .s)
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertEqual(response.selected?.identifier, "button-group")
    }

    func testTapHas() async throws {
        let nested = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .type("button"),
                .attrString(field: .label, match: .eq, value: "Secondary", caseFlag: .s)
            ])
        ])
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .identifier, match: .eq, value: "root", caseFlag: .s),
                .has(nested)
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertEqual(response.selected?.identifier, "root")
    }

    func testTapIs() async throws {
        let first = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .label, match: .eq, value: "Primary", caseFlag: .s)
            ])
        ])
        let second = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .label, match: .eq, value: "Secondary", caseFlag: .s)
            ])
        ])
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .type("button"),
                .isMatch([first, second])
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertEqual(response.matched, 2)
        XCTAssertEqual(response.selected?.label, "Primary")
    }

    func testTapNot() async throws {
        let nested = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .label, match: .eq, value: "Secondary", caseFlag: .s)
            ])
        ])
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .type("button"),
                .not(nested)
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertGreaterThanOrEqual(response.matched, 2)
        XCTAssertEqual(response.selected?.label, "Primary")
    }

    func testTapOnlyError() async throws {
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .type("button"),
                .only
            ])
        ])
        let (data, response) = try await postTapRaw(selector)
        XCTAssertEqual(response.statusCode, 400)
        let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
        XCTAssertTrue(error.error.contains("unique"))
    }

    func testTapPlaceholderValue() async throws {
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .placeholderValue, match: .eq, value: "Email", caseFlag: .s)
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertEqual(response.selected?.placeholderValue, "Email")
    }

    func testTapValue() async throws {
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .value, match: .eq, value: "hello", caseFlag: .s)
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertEqual(response.selected?.value, "hello")
    }

    func testTapDisabled() async throws {
        let selector = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .identifier, match: .eq, value: "root", caseFlag: .s),
                .attrBool(field: .isEnabled, value: false)
            ])
        ])
        let (response, _) = try await postTap(selector)
        XCTAssertEqual(response.selected?.identifier, "root")
    }

    private func postTap(_ selector: SelectorProgram) async throws -> (TapResponse, HTTPURLResponse) {
        let (data, response) = try await postTapRaw(selector)
        let httpResponse = response
        XCTAssertEqual(httpResponse.statusCode, 200)
        let payload = try JSONDecoder().decode(TapResponse.self, from: data)
        return (payload, httpResponse)
    }

    private func postTapRaw(_ selector: SelectorProgram) async throws -> (Data, HTTPURLResponse) {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestServer.defaultPort)/tap"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = TapRequest(selector: selector)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        return (data, httpResponse)
    }
}
