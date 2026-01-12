import Foundation

struct SelectorProgram: Codable, Equatable {
    var version: Int = 1
    var steps: [SelectorStep]
}

struct SelectorStep: Codable, Equatable {
    var axis: Axis
    var ops: [SelectorOp]
}

enum Axis: String, Codable, Equatable {
    case descendantOrSelf
    case descendant
    case child
}

enum CaseFlag: String, Codable, Equatable {
    case s
    case i
}

enum StringMatch: String, Codable, Equatable {
    case eq
    case contains
    case begins
    case ends
    case regex
}

enum StringField: String, Codable, Equatable {
    case identifier
    case title
    case label
    case value
    case placeholderValue
}

enum BoolField: String, Codable, Equatable {
    case isEnabled
    case isSelected
    case hasFocus
}

enum FrameMatch: String, Codable, Equatable {
    case contains
}

enum PointUnit: String, Codable, Equatable {
    case pt
    case pct
}

struct PointComponent: Codable, Equatable {
    var value: Double
    var unit: PointUnit
}

struct PointSpec: Codable, Equatable {
    var x: PointComponent
    var y: PointComponent
}

enum SelectorOp: Equatable {
    case type(String)
    case subscriptValue(String, CaseFlag)
    case attrString(field: StringField, match: StringMatch, value: String, caseFlag: CaseFlag)
    case attrBool(field: BoolField, value: Bool)
    case index(Int)
    case only
    case frame(match: FrameMatch, point: PointSpec)
    case has(SelectorProgram)
    case isMatch([SelectorProgram])
    case not(SelectorProgram)
}

extension SelectorOp: Codable {
    enum CodingKeys: String, CodingKey {
        case op
        case value
        case `case`
        case field
        case match
        case point
        case selector
        case selectors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(String.self, forKey: .op)
        switch op {
        case "type":
            let value = try container.decode(String.self, forKey: .value)
            self = .type(value)
        case "subscript":
            let value = try container.decode(String.self, forKey: .value)
            let caseFlag = try container.decodeIfPresent(CaseFlag.self, forKey: .case) ?? .s
            self = .subscriptValue(value, caseFlag)
        case "attrString":
            let field = try container.decode(StringField.self, forKey: .field)
            let match = try container.decode(StringMatch.self, forKey: .match)
            let value = try container.decode(String.self, forKey: .value)
            let caseFlag = try container.decodeIfPresent(CaseFlag.self, forKey: .case) ?? .s
            self = .attrString(field: field, match: match, value: value, caseFlag: caseFlag)
        case "attrBool":
            let field = try container.decode(BoolField.self, forKey: .field)
            let value = try container.decode(Bool.self, forKey: .value)
            self = .attrBool(field: field, value: value)
        case "index":
            let value = try container.decode(Int.self, forKey: .value)
            self = .index(value)
        case "only":
            self = .only
        case "frame":
            let match = try container.decode(FrameMatch.self, forKey: .match)
            let point = try container.decode(PointSpec.self, forKey: .point)
            self = .frame(match: match, point: point)
        case "has":
            let selector = try container.decode(SelectorProgram.self, forKey: .selector)
            self = .has(selector)
        case "is":
            let selectors = try container.decode([SelectorProgram].self, forKey: .selectors)
            self = .isMatch(selectors)
        case "not":
            let selector = try container.decode(SelectorProgram.self, forKey: .selector)
            self = .not(selector)
        default:
            throw DecodingError.dataCorruptedError(forKey: .op, in: container, debugDescription: "Unknown op: \(op)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .type(value):
            try container.encode("type", forKey: .op)
            try container.encode(value, forKey: .value)
        case let .subscriptValue(value, caseFlag):
            try container.encode("subscript", forKey: .op)
            try container.encode(value, forKey: .value)
            try container.encode(caseFlag, forKey: .case)
        case let .attrString(field, match, value, caseFlag):
            try container.encode("attrString", forKey: .op)
            try container.encode(field, forKey: .field)
            try container.encode(match, forKey: .match)
            try container.encode(value, forKey: .value)
            try container.encode(caseFlag, forKey: .case)
        case let .attrBool(field, value):
            try container.encode("attrBool", forKey: .op)
            try container.encode(field, forKey: .field)
            try container.encode(value, forKey: .value)
        case let .index(value):
            try container.encode("index", forKey: .op)
            try container.encode(value, forKey: .value)
        case .only:
            try container.encode("only", forKey: .op)
        case let .frame(match, point):
            try container.encode("frame", forKey: .op)
            try container.encode(match, forKey: .match)
            try container.encode(point, forKey: .point)
        case let .has(selector):
            try container.encode("has", forKey: .op)
            try container.encode(selector, forKey: .selector)
        case let .isMatch(selectors):
            try container.encode("is", forKey: .op)
            try container.encode(selectors, forKey: .selectors)
        case let .not(selector):
            try container.encode("not", forKey: .op)
            try container.encode(selector, forKey: .selector)
        }
    }
}
