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
    let indent = String(repeating: "  ", count: depth)
    print(indent + describeLine(for: node))
    for child in node.children {
        renderDescribeTree(child, depth: depth + 1)
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
