// MARK: - AST

struct SelectorAST: Equatable {
    var steps: [SelectorStep]
}

struct SelectorStep: Equatable {
    var axis: Axis
    var type: String?
    var filters: [Filter]
    var pick: Pick?
}

struct SimpleStep: Equatable {
    var type: String?
    var filters: [Filter]
}

enum Axis: String, Equatable { case descendant, child }
enum CaseFlag: String, Equatable { case s, i }
enum StringMatch: String, Equatable { case eq, contains, begins, ends, regex }
enum StringField: String, Equatable { case identifier, title, label, value, placeholderValue }
enum BoolField: String, Equatable { case isEnabled, isSelected, hasFocus }
enum PointUnit: String, Equatable, Encodable { case pt, pct }

struct PointComponent: Equatable, Encodable {
    var value: Double
    var unit: PointUnit
}

struct PointSpec: Equatable, Encodable {
    var x: PointComponent
    var y: PointComponent
}

enum Filter: Equatable {
    case shorthand(String, CaseFlag)
    case attrString(field: StringField, match: StringMatch, value: String, caseFlag: CaseFlag)
    case attrBool(field: BoolField, value: Bool)
    case has(SimpleStep)
    case isMatch([SimpleStep])
    case not(SimpleStep)
    case predicate(String)
}

enum Pick: Equatable { case index(Int), only }

// MARK: - Execution Plan

struct ExecutionPlan: Equatable, Encodable {
    var version: Int = 2
    var pipeline: [ExecutionOp]
}

enum ExecutionOp: Equatable {
    case descendants(type: String)
    case children(type: String)
    case matchIdentifier(String)
    case matchTypeIdentifier(type: String, value: String)
    case matchPredicate(String)
    case containPredicate(String)
    case containTypeIdentifier(type: String, value: String)
    case pickIndex(Int)
    case pickOnly
}

extension ExecutionOp: Encodable {
    enum CodingKeys: String, CodingKey {
        case op
        case type
        case value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .descendants(type):
            try container.encode("descendants", forKey: .op)
            try container.encode(type, forKey: .type)
        case let .children(type):
            try container.encode("children", forKey: .op)
            try container.encode(type, forKey: .type)
        case let .matchIdentifier(value):
            try container.encode("matchIdentifier", forKey: .op)
            try container.encode(value, forKey: .value)
        case let .matchTypeIdentifier(type, value):
            try container.encode("matchTypeIdentifier", forKey: .op)
            try container.encode(type, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .matchPredicate(value):
            try container.encode("matchPredicate", forKey: .op)
            try container.encode(value, forKey: .value)
        case let .containPredicate(value):
            try container.encode("containPredicate", forKey: .op)
            try container.encode(value, forKey: .value)
        case let .containTypeIdentifier(type, value):
            try container.encode("containTypeIdentifier", forKey: .op)
            try container.encode(type, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .pickIndex(value):
            try container.encode("pickIndex", forKey: .op)
            try container.encode(value, forKey: .value)
        case .pickOnly:
            try container.encode("pickOnly", forKey: .op)
        }
    }
}

// MARK: - Errors

enum SelectorParseError: Error, CustomStringConvertible {
    case parsing(String)
    case unexpectedEnd(expected: String)
    case unexpectedCharacter(Character, expected: String)
    case expected(String)
    case invalidNumber(String)
    case invalidEscape(String)
    case emptySelector
    case invalidIdentifier(String)
    case invalidBoolean(String)
    case unexpectedToken(String)

    var description: String {
        switch self {
        case let .parsing(message):
            return message
        case let .unexpectedEnd(expected):
            return "Unexpected end of input. Expected \(expected)."
        case let .unexpectedCharacter(char, expected):
            return "Unexpected character '\(char)'. Expected \(expected)."
        case let .expected(expected):
            return "Expected \(expected)."
        case let .invalidNumber(value):
            return "Invalid number: \(value)."
        case let .invalidEscape(value):
            return "Invalid escape sequence: \\ \(value)."
        case .emptySelector:
            return "Selector is empty."
        case let .invalidIdentifier(value):
            return "Invalid identifier: \(value)."
        case let .invalidBoolean(value):
            return "Invalid boolean: \(value)."
        case let .unexpectedToken(value):
            return "Unexpected token: \(value)."
        }
    }
}

enum SelectorCompileError: Error, CustomStringConvertible {
    case invalidType(String)
    case invalidSelector(String)

    var description: String {
        switch self {
        case let .invalidType(value):
            return "Unknown element type: \(value)."
        case let .invalidSelector(value):
            return value
        }
    }
}
