import ArgumentParser
import Foundation

struct Snapshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Snapshot current UI hierarchy from idc-server"
    )

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    @Option(name: .long, help: "Expected simulator UDID (optional).")
    var udid: String?

    @Option(name: .long, help: "Request timeout in seconds.")
    var timeout: Double = 5

    mutating func run() async throws {
        let data: Data
        do {
            data = try await fetchData(path: "/snapshot", timeout: timeout)
        } catch {
            throw serverUnreachableError(error)
        }

        try await validateUDID(udid, timeout: timeout)

        if json {
            FileHandle.standardOutput.write(data)
            if data.last != 0x0A {
                FileHandle.standardOutput.write(Data([0x0A]))
            }
            return
        }

        let payload = try JSONDecoder().decode(SnapshotResponse.self, from: data)
        renderSnapshotTree(payload.root, depth: 0)
    }
}

private struct SnapshotResponse: Decodable {
    let root: SnapshotNode
}

private struct SnapshotNode: Decodable {
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

private struct Frame: Decodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private enum JSONValue: Decodable {
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

private func renderSnapshotTree(_ node: SnapshotNode, depth: Int, isRoot: Bool = true) {
    if !isRoot, let child = simplifiableChild(for: node) {
        renderSnapshotTree(child, depth: depth, isRoot: false)
        return
    }

    let childrenToRender = flattenedChildren(for: node, isRoot: isRoot)
        .filter { !shouldSkipLeaf($0) }

    if !isRoot, !hasValueLike(node), childrenToRender.isEmpty {
        return
    }

    let indent = String(repeating: "  ", count: depth)
    print(indent + snapshotLine(for: node))
    for child in childrenToRender {
        renderSnapshotTree(child, depth: depth + 1, isRoot: false)
    }
}

private func snapshotLine(for node: SnapshotNode) -> String {
    let head = String(format: "%@@(%.0f,%.0f,%.0f,%.0f)", node.elementType, node.frame.x, node.frame.y, node.frame.width, node.frame.height)
    var parts: [String] = [head]
    if !node.label.isEmpty {
        parts.append("label=\"\(escapeValue(node.label))\"")
    }
    if !node.title.isEmpty {
        parts.append("title=\"\(escapeValue(node.title))\"")
    }
    if !node.identifier.isEmpty {
        parts.append("identifier=\"\(escapeValue(node.identifier))\"")
    }
    if let value = node.value {
        parts.append("value=\(formatJSONValue(value))")
    }
    if let placeholder = node.placeholderValue {
        parts.append("placeholder=\"\(escapeValue(placeholder))\"")
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

private func escapeValue(_ value: String) -> String {
    var escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
    escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
    escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
    escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
    escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
    return escaped
}

private func formatJSONValue(_ value: JSONValue) -> String {
    switch value {
    case let .string(s):
        return "\"\(escapeValue(s))\""
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

private func shouldSkipLeaf(_ node: SnapshotNode) -> Bool {
    guard node.children.isEmpty else { return false }
    return !hasValueLike(node)
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
