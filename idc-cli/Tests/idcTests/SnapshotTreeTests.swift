@testable import idc
import XCTest

final class SnapshotTreeTests: XCTestCase {
    func testSimplifyDropsEmptyLeaf() {
        let root = tree("application", tree("other"))

        let simplified = simplifySnapshotTree(root)

        XCTAssertEqual(simplified?.children, [])
    }

    func testSimplifyFlattensOtherChildIntoParent() {
        let button = tree("button", label: "Tap Me")
        let root = tree("application", tree("window", tree("other", button)))

        let simplified = simplifySnapshotTree(root)

        XCTAssertEqual(simplified?.children.first?.children, [button])
    }

    func testSimplifyCollapsesSingleChildSameShape() {
        let inner = tree("window", tree("staticText", label: "Title"))
        let root = tree("application", tree("window", inner))

        let simplified = simplifySnapshotTree(root)

        XCTAssertEqual(simplified?.children.first, inner)
    }

    func testSimplifyInterleavesRulesMultipleTimes() {
        let root = tree(
            "application",
            tree(
                "window",
                tree(
                    "window",
                    tree(
                        "other",
                        tree(
                            "window",
                            tree(
                                "window",
                                tree(
                                    "other",
                                    tree("image"),
                                    tree(
                                        "window",
                                        tree(
                                            "window",
                                            tree(
                                                "other",
                                                tree("image"),
                                                tree("button", label: "Save")
                                            )
                                        )
                                    ),
                                    tree("image")
                                )
                            )
                        )
                    )
                )
            )
        )

        let expected = tree(
            "application",
            tree(
                "window",
                tree(
                    "window",
                    tree(
                        "window",
                        tree("button", label: "Save")
                    )
                )
            )
        )

        let simplified = simplifySnapshotTree(root)

        XCTAssertEqual(simplified, expected)
    }

    private func tree(
        _ type: String,
        identifier: String = "",
        label: String = "",
        title: String = "",
        value: String? = nil,
        placeholderValue: String? = nil,
        hasFocus: Bool = false,
        isEnabled: Bool = true,
        isSelected: Bool = false,
        frame: Frame = Frame(x: 0, y: 0, width: 10, height: 10),
        _ children: SnapshotNode...
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
