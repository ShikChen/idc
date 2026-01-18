import XCTest

final class AppOpenEndpointTests: XCTestCase {
    private static let server = TestServer()
    private let hostBundleId = "dev.lv1.idc-server"

    override func setUp() async throws {
        continueAfterFailure = false
        try await TestHelpers.startServer(Self.server)
    }

    override func tearDown() async throws {
        await TestHelpers.stopServer(Self.server)
    }

    func testAppOpenLaunchesHostApp() async throws {
        await MainActor.run {
            let app = XCUIApplication(bundleIdentifier: hostBundleId)
            app.terminate()
        }

        let request = AppOpenRequest(bundleId: hostBundleId, wait: 5)
        let (data, response) = try await postOpen(request)
        XCTAssertEqual(response.statusCode, 200)

        let payload = try TestHelpers.decode(AppOpenResponse.self, from: data)
        XCTAssertEqual(payload.status, "ok")

        let isForeground = await MainActor.run {
            let app = XCUIApplication(bundleIdentifier: hostBundleId)
            return app.wait(for: .runningForeground, timeout: 2)
        }
        XCTAssertTrue(isForeground)
    }

    func testAppOpenEmptyBodyError() async throws {
        let (data, response) = try await postOpenRaw(body: Data())
        try TestHelpers.assertBadRequest(response, data: data, contains: "empty", code: .emptyBody)
    }

    func testAppOpenInvalidWaitError() async throws {
        let request = AppOpenRequest(bundleId: hostBundleId, wait: -1)
        let (data, response) = try await postOpenRaw(payload: request)
        try TestHelpers.assertBadRequest(response, data: data, contains: "greater than or equal to 0", code: .invalidPlan)
    }

    private func postOpen(_ request: AppOpenRequest) async throws -> (Data, HTTPURLResponse) {
        try await postOpenRaw(payload: request)
    }

    private func postOpenRaw(payload: AppOpenRequest) async throws -> (Data, HTTPURLResponse) {
        try await TestHelpers.postJSON("app/open", payload: payload)
    }

    private func postOpenRaw(body: Data?) async throws -> (Data, HTTPURLResponse) {
        try await TestHelpers.post("app/open", body: body)
    }
}
