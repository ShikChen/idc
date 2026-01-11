import ArgumentParser
import Foundation

struct DescribeUI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Describe current UI hierarchy from idc-server"
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
            data = try await fetchData(path: "/describe-ui", timeout: timeout)
        } catch {
            throw ValidationError("Unable to reach idc-server. Run `idc server start`. (\(error.localizedDescription))")
        }

        if let udid {
            let info: InfoResponse = try await fetchJSON(path: "/info", timeout: timeout)
            if info.udid != udid {
                let actual = info.udid ?? "nil"
                throw ValidationError("Server is running for a different simulator. Expected \(udid), got \(actual).")
            }
        }

        if json {
            FileHandle.standardOutput.write(data)
            if data.last != 0x0a {
                FileHandle.standardOutput.write(Data([0x0a]))
            }
            return
        }

        let payload = try JSONDecoder().decode(DescribeUIResponse.self, from: data)
        renderDescribeTree(payload.root, depth: 0)
    }
}

private struct DescribeUIResponse: Decodable {
    let root: DescribeUINode
}

private struct DescribeUINode: Decodable {
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
    let children: [DescribeUINode]
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

private func renderDescribeTree(_ node: DescribeUINode, depth: Int) {
    renderDescribeTree(node, depth: depth, isRoot: true)
}

private func renderDescribeTree(_ node: DescribeUINode, depth: Int, isRoot: Bool) {
    if !isRoot, let child = simplifiableChild(for: node) {
        renderDescribeTree(child, depth: depth, isRoot: false)
        return
    }

    let indent = String(repeating: "  ", count: depth)
    print(indent + describeLine(for: node))
    for child in flattenedChildren(for: node, isRoot: isRoot) {
        renderDescribeTree(child, depth: depth + 1, isRoot: false)
    }
}

private func describeLine(for node: DescribeUINode) -> String {
    var parts: [String] = [node.elementType]
    if !node.label.isEmpty {
        parts.append("label=\"\(escapeValue(node.label))\"")
    }
    if !node.title.isEmpty {
        parts.append("title=\"\(escapeValue(node.title))\"")
    }
    if !node.identifier.isEmpty {
        parts.append("identifier=\"\(escapeValue(node.identifier))\"")
    }
    parts.append(String(format: "frame=(%.1f,%.1f,%.1f,%.1f)", node.frame.x, node.frame.y, node.frame.width, node.frame.height))
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

private func simplifiableChild(for node: DescribeUINode) -> DescribeUINode? {
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

private func flattenedChildren(for node: DescribeUINode, isRoot: Bool) -> [DescribeUINode] {
    guard !isRoot else {
        return node.children
    }
    var flattened: [DescribeUINode] = node.children
    var didChange = true
    while didChange {
        didChange = false
        var next: [DescribeUINode] = []
        for child in flattened {
            if shouldFlattenNode(child, parent: node) {
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

private func shouldFlattenNode(_ node: DescribeUINode, parent: DescribeUINode) -> Bool {
    guard node.elementType == "other" else { return false }
    guard !hasValueLike(node) else { return false }
    guard node.hasFocus == false, node.isEnabled == true, node.isSelected == false else {
        return false
    }
    guard isSameFrame(node.frame, parent.frame) else { return false }
    return true
}

private func hasValueLike(_ node: DescribeUINode) -> Bool {
    if !node.label.isEmpty { return true }
    if !node.title.isEmpty { return true }
    if !node.identifier.isEmpty { return true }
    if node.placeholderValue != nil { return true }
    if node.value != nil { return true }
    return false
}

private func isSameShape(_ lhs: DescribeUINode, _ rhs: DescribeUINode) -> Bool {
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
