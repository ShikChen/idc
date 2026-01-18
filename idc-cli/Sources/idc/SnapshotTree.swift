import Foundation

struct SnapshotResponse: Decodable {
    let root: SnapshotNode
}

struct SnapshotNode: Decodable, Equatable {
    let element: ElementAttributes
    let children: [SnapshotNode]
}

/// Simplify snapshot tree by collapsing redundant nodes and dropping empty leaves.
///
/// Rules:
/// - Collapse a non-root node if it has a single child with the same shape and neither node is value-like.
/// - Flatten value-less "other" nodes by splicing their children into the parent.
/// - Drop non-root leaves that have no value-like attributes.
func simplifySnapshotTree(_ node: SnapshotNode, isRoot: Bool = true) -> SnapshotNode? {
    if !isRoot, let child = simplifiableChild(for: node) {
        return simplifySnapshotTree(child, isRoot: false)
    }

    let flattened = flattenedChildren(for: node, isRoot: isRoot)
    let simplifiedChildren = flattened.compactMap { simplifySnapshotTree($0, isRoot: false) }

    if !isRoot, !hasValueLike(node), simplifiedChildren.isEmpty {
        return nil
    }

    return SnapshotNode(element: node.element, children: simplifiedChildren)
}

func snapshotLine(for node: SnapshotNode) -> String {
    let element = node.element
    let head = String(format: "%@@(%.0f,%.0f,%.0f,%.0f)", element.elementType, element.frame.x, element.frame.y, element.frame.width, element.frame.height)
    var parts: [String] = [head]
    func addString(_ key: String, _ value: String, skipIfEmpty: Bool) {
        if skipIfEmpty, value.isEmpty {
            return
        }
        parts.append("\(key)=\"\(escapeSnapshotValue(value))\"")
    }

    addString("label", element.label, skipIfEmpty: true)
    addString("title", element.title, skipIfEmpty: true)
    addString("identifier", element.identifier, skipIfEmpty: true)
    if let value = element.value, !value.isEmpty {
        parts.append("value=\"\(escapeSnapshotValue(value))\"")
    }
    if let placeholder = element.placeholderValue, !placeholder.isEmpty {
        addString("placeholder", placeholder, skipIfEmpty: false)
    }
    if element.hasFocus {
        parts.append("hasFocus=true")
    }
    if !element.isEnabled {
        parts.append("isEnabled=false")
    }
    if element.isSelected {
        parts.append("isSelected=true")
    }
    return parts.joined(separator: " ")
}

func renderSnapshotTree(_ node: SnapshotNode, depth: Int) {
    let indent = String(repeating: "  ", count: depth)
    print(indent + snapshotLine(for: node))
    for child in node.children {
        renderSnapshotTree(child, depth: depth + 1)
    }
}

private func simplifiableChild(for node: SnapshotNode) -> SnapshotNode? {
    guard node.children.count == 1, let child = node.children.first else {
        return nil
    }
    guard !hasValueLike(node) else {
        return nil
    }
    guard !hasValueLike(child) else {
        return nil
    }
    guard isSameShape(node, child) else {
        return nil
    }
    return child
}

private func flattenedChildren(for node: SnapshotNode, isRoot: Bool) -> [SnapshotNode] {
    guard !isRoot else {
        return node.children
    }
    return node.children.flatMap(flattenNode)
}

private func flattenNode(_ node: SnapshotNode) -> [SnapshotNode] {
    if shouldFlattenNode(node) {
        return node.children.flatMap(flattenNode)
    }
    return [node]
}

private func shouldFlattenNode(_ node: SnapshotNode) -> Bool {
    guard node.element.elementType == "other" else { return false }
    guard !hasValueLike(node) else { return false }
    let element = node.element
    guard element.hasFocus == false, element.isEnabled == true, element.isSelected == false else {
        return false
    }
    return true
}

private func hasValueLike(_ node: SnapshotNode) -> Bool {
    let element = node.element
    if !element.label.isEmpty { return true }
    if !element.title.isEmpty { return true }
    if !element.identifier.isEmpty { return true }
    if element.placeholderValue != nil { return true }
    if let value = element.value, !value.isEmpty { return true }
    return false
}

private func isSameShape(_ lhs: SnapshotNode, _ rhs: SnapshotNode) -> Bool {
    return lhs.element.elementType == rhs.element.elementType &&
        lhs.element.hasFocus == rhs.element.hasFocus &&
        lhs.element.isEnabled == rhs.element.isEnabled &&
        lhs.element.isSelected == rhs.element.isSelected &&
        isSameFrame(lhs.element.frame, rhs.element.frame)
}

private func isSameFrame(_ lhs: Frame, _ rhs: Frame) -> Bool {
    return lhs.x == rhs.x &&
        lhs.y == rhs.y &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height
}

private func escapeSnapshotValue(_ value: String) -> String {
    var escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
    escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
    escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
    escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
    escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
    return escaped
}
