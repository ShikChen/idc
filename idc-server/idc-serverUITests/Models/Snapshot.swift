import XCTest

struct SnapshotResponse: Codable {
    let root: SnapshotNode
}

struct SnapshotNode: Codable {
    let element: ElementAttributes
    let children: [SnapshotNode]
}

func buildSnapshotNode(_ snapshot: XCUIElementSnapshot) -> SnapshotNode {
    let children = snapshot.children.map { buildSnapshotNode($0) }
    return SnapshotNode(
        element: ElementAttributes(from: snapshot),
        children: children
    )
}
