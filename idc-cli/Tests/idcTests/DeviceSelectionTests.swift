@testable import idc
import XCTest

final class DeviceSelectionTests: XCTestCase {
    func testAutoSelection() {
        let value = DeviceSelection(argument: "auto")
        XCTAssertEqual(value, .auto)
    }

    func testSimulatorSelectionCaseInsensitive() {
        let value = DeviceSelection(argument: "SiMuLaToR")
        XCTAssertEqual(value, .simulatorOnly)
    }

    func testDeviceSelection() {
        let value = DeviceSelection(argument: "device")
        XCTAssertEqual(value, .deviceOnly)
    }

    func testUDIDSelectionWithSimulatorUUID() {
        let value = DeviceSelection(argument: "F8F0DB42-AA71-40C6-908C-EC88E69ABB6F")
        XCTAssertEqual(value, .udid("F8F0DB42-AA71-40C6-908C-EC88E69ABB6F"))
    }

    func testUDIDSelectionWithDeviceUDID() {
        let value = DeviceSelection(argument: "00008150000E41100E08401C0000000000000000")
        XCTAssertEqual(value, .udid("00008150000E41100E08401C0000000000000000"))
    }

    func testInvalidSelection() {
        let value = DeviceSelection(argument: "phone")
        XCTAssertNil(value)
    }
}
