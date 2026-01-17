@testable import idc
import XCTest

final class FindTests: XCTestCase {
    func testFormatFindLine() {
        let element = FindElement(
            identifier: "gearshape",
            elementType: "button",
            value: nil,
            placeholderValue: nil,
            title: "",
            label: "設定",
            hasFocus: false,
            isEnabled: false,
            isSelected: true,
            frame: Frame(x: 10, y: 20, width: 30, height: 40)
        )

        let line = formatFindLine(index: 2, element: element)

        XCTAssertEqual(line, #"#2 button@(10,20,30,40) label="設定" identifier="gearshape" isEnabled=false isSelected=true"#)
    }
}
