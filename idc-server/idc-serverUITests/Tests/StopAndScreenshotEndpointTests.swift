import XCTest

final class StopAndScreenshotEndpointTests: XCTestCase {
    private static let server = TestServer()

    override func setUp() async throws {
        continueAfterFailure = false
        try await TestHelpers.startServer(Self.server)
    }

    override func tearDown() async throws {
        await TestHelpers.stopServer(Self.server)
    }

    func testScreenshotEndpointReturnsPNG() async throws {
        try await TestHelpers.launchOrActivateApp()
        let (data, response) = try await TestHelpers.get("screenshot")

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.value(forHTTPHeaderField: "Content-Type"), "image/png")
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(data.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
    }

    func testStopEndpointStopsServer() async throws {
        let (data, response) = try await TestHelpers.post("stop", body: nil)
        XCTAssertEqual(response.statusCode, 200)

        let payload = try TestHelpers.decode(HealthResponse.self, from: data)
        XCTAssertEqual(payload.status, "stopping")

        let didStop = try await waitForServerStop(timeout: 5)
        XCTAssertTrue(didStop)
    }

    private func waitForServerStop(timeout: TimeInterval) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            do {
                let (_, response) = try await TestHelpers.get("health")
                if response.statusCode != 200 {
                    return true
                }
            } catch {
                return true
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        return false
    }
}
