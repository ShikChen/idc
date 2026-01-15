@testable import idc
import XCTest

final class TapTests: XCTestCase {
    func testParseTapPointPoints() throws {
        let point = try parseTapPoint("10,20")
        XCTAssertEqual(point, PointSpec(
            x: PointComponent(value: 10, unit: .pt),
            y: PointComponent(value: 20, unit: .pt)
        ))
    }

    func testParseTapPointPercent() throws {
        let point = try parseTapPoint("70%,40%")
        XCTAssertEqual(point, PointSpec(
            x: PointComponent(value: 70, unit: .pct),
            y: PointComponent(value: 40, unit: .pct)
        ))
    }

    func testParseTapPointMixed() throws {
        let point = try parseTapPoint("100,20%")
        XCTAssertEqual(point, PointSpec(
            x: PointComponent(value: 100, unit: .pt),
            y: PointComponent(value: 20, unit: .pct)
        ))
    }

    func testParseTapPointInvalid() {
        XCTAssertThrowsError(try parseTapPoint("10"))
        XCTAssertThrowsError(try parseTapPoint("10,abc"))
    }

    func testParseTapPointNonFinite() {
        XCTAssertThrowsError(try parseTapPoint("nan,0"))
        XCTAssertThrowsError(try parseTapPoint("inf,0"))
        XCTAssertThrowsError(try parseTapPoint("-inf,0"))
    }

    func testEmptySelectorRequiresPoint() async throws {
        await XCTAssertThrowsErrorAsync {
            var tap = Tap()
            tap.selector = "   "
            tap.at = nil
            try await tap.run()
        }
    }
}

private func XCTAssertThrowsErrorAsync(_ expression: @escaping @Sendable () async throws -> Void) async {
    do {
        try await expression()
        XCTFail("Expected error to be thrown.")
    } catch {
        return
    }
}
