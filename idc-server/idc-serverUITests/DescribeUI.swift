import CoreGraphics
import Foundation
import XCTest

struct DescribeUIResponse: Codable {
    let root: DescribeUINode
}

struct DescribeUINode: Codable {
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

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    static func fromAny(_ value: Any?) -> JSONValue? {
        guard let value else { return nil }
        if let string = value as? String {
            return .string(string)
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        }
        if let bool = value as? Bool {
            return .bool(bool)
        }
        if let int = value as? Int {
            return .number(Double(int))
        }
        if let double = value as? Double {
            return .number(double)
        }
        if let float = value as? Float {
            return .number(Double(float))
        }
        if let cgFloat = value as? CGFloat {
            return .number(Double(cgFloat))
        }
        return .string(String(describing: value))
    }

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

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(string):
            try container.encode(string)
        case let .number(number):
            try container.encode(number)
        case let .bool(bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }
}

@MainActor
func buildDescribeNode(_ snapshot: XCUIElementSnapshot) -> DescribeUINode {
    let children = snapshot.children.map { buildDescribeNode($0) }
    return DescribeUINode(
        identifier: snapshot.identifier,
        elementType: elementTypeName(snapshot.elementType),
        value: JSONValue.fromAny(snapshot.value),
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
