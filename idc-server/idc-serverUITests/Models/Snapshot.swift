import CoreGraphics
import Foundation
import XCTest

struct SnapshotResponse: Codable {
    let root: SnapshotNode
}

struct SnapshotNode: Codable {
    let identifier: String
    let elementType: String
    let value: String?
    let placeholderValue: String?
    let title: String
    let label: String
    let hasFocus: Bool
    let isEnabled: Bool
    let isSelected: Bool
    let frame: Frame
    let children: [SnapshotNode]
}

struct Frame: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }
}

func buildSnapshotNode(_ snapshot: XCUIElementSnapshot) -> SnapshotNode {
    let children = snapshot.children.map { buildSnapshotNode($0) }
    return SnapshotNode(
        identifier: snapshot.identifier,
        elementType: elementTypeName(snapshot.elementType),
        value: ElementValue.stringValue(snapshot.value),
        placeholderValue: snapshot.placeholderValue,
        title: snapshot.title,
        label: snapshot.label,
        hasFocus: snapshot.hasFocus,
        isEnabled: snapshot.isEnabled,
        isSelected: snapshot.isSelected,
        frame: Frame(snapshot.frame),
        children: children
    )
}
