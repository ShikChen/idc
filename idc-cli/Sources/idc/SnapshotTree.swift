import Foundation

struct SnapshotResponse: Decodable {
    let root: SnapshotNode
}

struct SnapshotNode: Decodable, Equatable {
    let identifier: String
    let elementType: String
    let value: JSONValue?
    let placeholderValue: String?
    let title: String
    let label: String
    let hasFocus: Bool
    let isEnabled: Bool
    let isSelected: Bool
    let frame: Frame
    let children: [SnapshotNode]
}

struct Frame: Decodable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

enum JSONValue: Decodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }
        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }
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

    return SnapshotNode(
        identifier: node.identifier,
        elementType: node.elementType,
        value: node.value,
        placeholderValue: node.placeholderValue,
        title: node.title,
        label: node.label,
        hasFocus: node.hasFocus,
        isEnabled: node.isEnabled,
        isSelected: node.isSelected,
        frame: node.frame,
        children: simplifiedChildren
    )
}

func snapshotLine(for node: SnapshotNode) -> String {
    let head = String(format: "%@@(%.0f,%.0f,%.0f,%.0f)", node.elementType, node.frame.x, node.frame.y, node.frame.width, node.frame.height)
    var parts: [String] = [head]
    if !node.label.isEmpty {
        parts.append("label=\"\(escapeSnapshotValue(node.label))\"")
    }
    if !node.title.isEmpty {
        parts.append("title=\"\(escapeSnapshotValue(node.title))\"")
    }
    if !node.identifier.isEmpty {
        parts.append("identifier=\"\(escapeSnapshotValue(node.identifier))\"")
    }
    if let value = node.value {
        parts.append("value=\(formatSnapshotValue(value))")
    }
    if let placeholder = node.placeholderValue {
        parts.append("placeholder=\"\(escapeSnapshotValue(placeholder))\"")
    }
    if node.hasFocus {
        parts.append("hasFocus=true")
    }
    if !node.isEnabled {
        parts.append("isEnabled=false")
    }
    if node.isSelected {
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

private func escapeSnapshotValue(_ value: String) -> String {
    var escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
    escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
    escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
    escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
    escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
    return escaped
}

private func formatSnapshotValue(_ value: JSONValue) -> String {
    switch value {
    case let .string(s):
        return "\"\(escapeSnapshotValue(s))\""
    case let .number(n):
        if n == n.rounded() && abs(n) < Double(Int.max) {
            return String(Int(n))
        }
        return String(n)
    case let .bool(b):
        return b ? "true" : "false"
    case .null:
        return "null"
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
    var flattened: [SnapshotNode] = node.children
    var didChange = true
    while didChange {
        didChange = false
        var next: [SnapshotNode] = []
        for child in flattened {
            if shouldFlattenNode(child) {
                next.append(contentsOf: child.children)
                didChange = true
            } else {
                next.append(child)
            }
        }
        flattened = next
    }
    return flattened
}

private func shouldFlattenNode(_ node: SnapshotNode) -> Bool {
    guard node.elementType == "other" else { return false }
    guard !hasValueLike(node) else { return false }
    guard node.hasFocus == false, node.isEnabled == true, node.isSelected == false else {
        return false
    }
    return true
}

private func hasValueLike(_ node: SnapshotNode) -> Bool {
    if !node.label.isEmpty { return true }
    if !node.title.isEmpty { return true }
    if !node.identifier.isEmpty { return true }
    if node.placeholderValue != nil { return true }
    if node.value != nil { return true }
    return false
}

private func isSameShape(_ lhs: SnapshotNode, _ rhs: SnapshotNode) -> Bool {
    return lhs.elementType == rhs.elementType &&
        lhs.hasFocus == rhs.hasFocus &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.isSelected == rhs.isSelected &&
        isSameFrame(lhs.frame, rhs.frame)
}

private func isSameFrame(_ lhs: Frame, _ rhs: Frame) -> Bool {
    return lhs.x == rhs.x &&
        lhs.y == rhs.y &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height
}
