import XCTest

final class FindEndpointTests: XCTestCase {
    private static let server = TestServer()

    override func setUp() async throws {
        continueAfterFailure = false
        try await TestHelpers.startServer(Self.server)
        try await TestHelpers.launchOrActivateApp()
        try await TestHelpers.switchToTestTab()
        try await TestHelpers.waitForForegroundFixture()
    }

    override func tearDown() async throws {
        await TestHelpers.stopServer(Self.server)
    }

    func testFindByIdentifier() async throws {
        let plan = TestHelpers.plan(
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
        let plan = TestHelpers.plan(
            .descendants(type: "button")
        )
        let (response, http) = try await postFind(plan: plan, limit: 1)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(response.matches.count, 1)
        XCTAssertTrue(response.truncated)
    }

    func testFindNoMatches() async throws {
        let plan = TestHelpers.plan(
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
        try TestHelpers.assertBadRequest(http, data: data, contains: "empty")
    }

    func testFindInvalidJSONError() async throws {
        let (data, http) = try await postFindRaw(body: Data("{".utf8))
        try TestHelpers.assertBadRequest(http, data: data, contains: "Invalid JSON")
    }

    private func postFind(plan: ExecutionPlan, limit: Int) async throws -> (FindResponse, HTTPURLResponse) {
        let (data, response) = try await postFindRaw(plan: plan, limit: limit)
        let httpResponse = response
        let payload = try TestHelpers.decode(FindResponse.self, from: data)
        return (payload, httpResponse)
    }

    private func postFindRaw(plan: ExecutionPlan, limit: Int) async throws -> (Data, HTTPURLResponse) {
        let body = FindRequest(plan: plan, limit: limit)
        return try await postFindRaw(body: try JSONEncoder().encode(body))
    }

    private func postFindRaw(body: Data?) async throws -> (Data, HTTPURLResponse) {
        return try await TestHelpers.post("find", body: body)
    }
}
