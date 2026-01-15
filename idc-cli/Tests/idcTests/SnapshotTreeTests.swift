import XCTest
@testable import idc

final class SnapshotTreeTests: XCTestCase {
    func testSimplifyDropsEmptyLeaf() {
        let root = node(type: "application", children: [
            node(type: "other")
        ])

        let simplified = simplifySnapshotTree(root)

        XCTAssertEqual(simplified?.children, [])
    }

    func testSimplifyFlattensOtherChildIntoParent() {
        let button = node(type: "button", label: "Tap Me")
        let other = node(type: "other", children: [button])
        let window = node(type: "window", children: [other])
        let root = node(type: "application", children: [window])

        let simplified = simplifySnapshotTree(root)

        XCTAssertEqual(simplified?.children.first?.children, [button])
    }

    func testSimplifyCollapsesSingleChildSameShape() {
        let leaf = node(type: "staticText", label: "Title")
        let inner = node(type: "window", children: [leaf])
        let outer = node(type: "window", children: [inner])
        let root = node(type: "application", children: [outer])

        let simplified = simplifySnapshotTree(root)

        XCTAssertEqual(simplified?.children.first, inner)
    }

    private func node(
        type: String,
        identifier: String = "",
        label: String = "",
        title: String = "",
        value: JSONValue? = nil,
        placeholderValue: String? = nil,
        hasFocus: Bool = false,
        isEnabled: Bool = true,
        isSelected: Bool = false,
        frame: Frame = Frame(x: 0, y: 0, width: 10, height: 10),
        children: [SnapshotNode] = []
    ) -> SnapshotNode {
        SnapshotNode(
            identifier: identifier,
            elementType: type,
            value: value,
            placeholderValue: placeholderValue,
            title: title,
            label: label,
            hasFocus: hasFocus,
            isEnabled: isEnabled,
            isSelected: isSelected,
            frame: frame,
            children: children
        )
    }
}
