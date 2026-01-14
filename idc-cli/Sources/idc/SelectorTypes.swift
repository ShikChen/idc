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
enum StringMatch: String, Equatable {
    case eq = "=="
    case contains = "CONTAINS"
    case begins = "BEGINSWITH"
    case ends = "ENDSWITH"
    case regex = "MATCHES"
}
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

struct ExecutionPlan: Equatable, Codable {
    var version: Int = 3
    var pipeline: [ExecutionOp]
}

enum ExecutionOp: Equatable, Codable {
    case descendants(type: String)
    case children(type: String)
    case matchIdentifier(String)
    case matchTypeIdentifier(type: String, value: String)
    case matchPredicate(format: String, args: [PredicateArg])
    case containPredicate(format: String, args: [PredicateArg])
    case containTypeIdentifier(type: String, value: String)
    case pickIndex(Int)
    case pickOnly
}

enum PredicateArg: Equatable, Codable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case elementType(String)
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
