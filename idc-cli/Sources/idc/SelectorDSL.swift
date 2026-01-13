import Foundation
import Parsing

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

enum Axis: String, Equatable {
    case descendant
    case child
}

enum CaseFlag: String, Equatable {
    case s
    case i
}

enum StringMatch: String, Equatable {
    case eq
    case contains
    case begins
    case ends
    case regex
}

enum StringField: String, Equatable {
    case identifier
    case title
    case label
    case value
    case placeholderValue
}

enum BoolField: String, Equatable {
    case isEnabled
    case isSelected
    case hasFocus
}

enum PointUnit: String, Equatable, Encodable {
    case pt
    case pct
}

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

enum Pick: Equatable {
    case index(Int)
    case only
}

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

// MARK: - Parser

struct SelectorParser {
    private var input: Substring

    init(_ input: String) {
        self.input = input[...]
    }

    mutating func parseSelector() throws -> SelectorAST {
        do {
            return try SelectorParsers.selector.parse(&input)
        } catch {
            throw SelectorParseError.parsing(String(describing: error))
        }
    }
}

private enum SelectorParsers {
    static var selector: some Parser<Substring, SelectorAST> {
        OneOf {
            Parse {
                OptionalWhitespaceParser()
                End()
            }
            .map { SelectorAST(steps: []) }
            Parse {
                OptionalWhitespaceParser()
                StepCoreParser()
                Many {
                    combinator
                }
                OptionalWhitespaceParser()
                End()
            }
            .map { first, rest in
                var steps: [SelectorStep] = [
                    SelectorStep(axis: .descendant, type: first.type, filters: first.filters, pick: first.pick)
                ]
                for (axis, core) in rest {
                    steps.append(SelectorStep(axis: axis, type: core.type, filters: core.filters, pick: core.pick))
                }
                return SelectorAST(steps: steps)
            }
        }
    }

    static var combinator: some Parser<Substring, (Axis, StepCore)> {
        OneOf {
            Parse {
                OptionalWhitespaceParser()
                ">"
                OptionalWhitespaceParser()
                StepCoreParser()
            }
            .map { (.child, $0) }
            Backtracking {
                Parse {
                    RequiredWhitespaceParser()
                    StepCoreParser()
                }
            }
            .map { (.descendant, $0) }
        }
    }
}

private struct StepCore {
    var type: String?
    var filters: [Filter]
    var pick: Pick?
}

private enum StepToken {
    case filter(Filter)
    case pick(Pick)
}

private struct StepCoreParser: Parser {
    func parse(_ input: inout Substring) throws -> StepCore {
        let type = Optionally { IdentifierParser() }.parse(&input)?.lowercased()
        let tokens = try Many {
            StepTokenParser(allowHas: true, allowOnly: true, allowPick: true)
        } terminator: {
            Not { StepTokenStartParser() }
        }
        .parse(&input)

        return try assembleStep(type: type, tokens: tokens)
    }
}

private struct SimpleStepParser: Parser {
    func parse(_ input: inout Substring) throws -> SimpleStep {
        let type = Optionally { IdentifierParser() }.parse(&input)?.lowercased()
        let tokens = try Many {
            Parse {
                OptionalWhitespaceParser()
                StepTokenParser(allowHas: false, allowOnly: false, allowPick: false)
            }
        } terminator: {
            Not { SimpleTokenStartParser() }
        }
        .parse(&input)

        var filters: [Filter] = []
        filters.reserveCapacity(tokens.count)
        for token in tokens {
            guard case let .filter(filter) = token else {
                throw SelectorParseError.expected("filter")
            }
            filters.append(filter)
        }

        guard type != nil || !filters.isEmpty else {
            throw SelectorParseError.expected("simple step")
        }

        return SimpleStep(type: type, filters: filters)
    }
}

private struct StepTokenParser: Parser {
    let allowHas: Bool
    let allowOnly: Bool
    let allowPick: Bool

    func parse(_ input: inout Substring) throws -> StepToken {
        guard let char = input.first else {
            throw SelectorParseError.expected("filter")
        }
        switch char {
        case "[":
            return try BracketTokenParser(allowPick: allowPick).parse(&input)
        case ":":
            return try PseudoTokenParser(allowHas: allowHas, allowOnly: allowOnly).parse(&input)
        default:
            throw SelectorParseError.expected("filter")
        }
    }
}

private struct StepTokenStartParser: Parser {
    func parse(_ input: inout Substring) throws {
        guard let char = input.first, char == "[" || char == ":" else {
            throw SelectorParseError.expected("filter")
        }
        input.removeFirst()
    }
}

private struct SimpleTokenStartParser: Parser {
    func parse(_ input: inout Substring) throws {
        var snapshot = input
        skipWhitespace(&snapshot)
        guard let char = snapshot.first, char == "[" || char == ":" else {
            throw SelectorParseError.expected("filter")
        }
        snapshot.removeFirst()
        input = snapshot
    }
}

private struct IdentifierParser: Parser {
    func parse(_ input: inout Substring) throws -> String {
        guard let first = input.first, isIdentStart(first) else {
            throw SelectorParseError.expected("identifier")
        }
        var index = input.index(after: input.startIndex)
        while index < input.endIndex, isIdentChar(input[index]) {
            index = input.index(after: index)
        }
        let value = String(input[..<index])
        input = input[index...]
        return value
    }
}

private struct QuotedStringParser: Parser {
    func parse(_ input: inout Substring) throws -> String {
        guard input.first == "\"" else {
            throw SelectorParseError.expected("\"")
        }
        input.removeFirst()
        var result = ""
        while let char = input.first {
            input.removeFirst()
            if char == "\"" {
                return result
            }
            if char == "\\" {
                guard let esc = input.first else {
                    throw SelectorParseError.unexpectedEnd(expected: "escape")
                }
                input.removeFirst()
                switch esc {
                case "\\":
                    result.append("\\")
                case "\"":
                    result.append("\"")
                case "n":
                    result.append("\n")
                case "r":
                    result.append("\r")
                case "t":
                    result.append("\t")
                default:
                    throw SelectorParseError.invalidEscape(String(esc))
                }
                continue
            }
            result.append(char)
        }
        throw SelectorParseError.unexpectedEnd(expected: "\"")
    }
}

private struct CaseFlagParser: Parser {
    func parse(_ input: inout Substring) throws -> CaseFlag {
        var snapshot = input
        skipWhitespace(&snapshot)
        guard let char = snapshot.first else {
            throw SelectorParseError.expected("case flag")
        }
        let lower = String(char).lowercased()
        guard lower == "i" || lower == "s" else {
            throw SelectorParseError.expected("case flag")
        }
        snapshot.removeFirst()
        if let next = snapshot.first, !next.isWhitespace, next != "]", next != ")", next != "," {
            throw SelectorParseError.expected("case flag")
        }
        input = snapshot
        return lower == "i" ? .i : .s
    }
}

private struct MatchOperatorParser: Parser {
    func parse(_ input: inout Substring) throws -> StringMatch {
        if input.first == "*", input.dropFirst().first == "=" {
            input.removeFirst(2)
            return .contains
        }
        if input.first == "^", input.dropFirst().first == "=" {
            input.removeFirst(2)
            return .begins
        }
        if input.first == "$", input.dropFirst().first == "=" {
            input.removeFirst(2)
            return .ends
        }
        if input.first == "~", input.dropFirst().first == "=" {
            input.removeFirst(2)
            return .regex
        }
        if input.first == "=" {
            input.removeFirst()
            return .eq
        }
        if let char = input.first {
            throw SelectorParseError.unexpectedCharacter(char, expected: "match operator")
        }
        throw SelectorParseError.unexpectedEnd(expected: "match operator")
    }
}

private struct BoolLiteralParser: Parser {
    func parse(_ input: inout Substring) throws -> Bool {
        let value = try IdentifierParser().parse(&input).lowercased()
        switch value {
        case "true": return true
        case "false": return false
        default:
            throw SelectorParseError.invalidBoolean(value)
        }
    }
}

private struct IntLiteralParser: Parser {
    func parse(_ input: inout Substring) throws -> Int {
        guard let first = input.first, first == "-" || isDigit(first) else {
            throw SelectorParseError.expected("integer")
        }
        var index = input.startIndex
        if input[index] == "-" {
            index = input.index(after: index)
        }
        guard index < input.endIndex, isDigit(input[index]) else {
            throw SelectorParseError.expected("integer")
        }
        var end = index
        while end < input.endIndex, isDigit(input[end]) {
            end = input.index(after: end)
        }
        let value = String(input[..<end])
        guard let intValue = Int(value) else {
            throw SelectorParseError.invalidNumber(value)
        }
        input = input[end...]
        return intValue
    }
}

private struct BracketTokenParser: Parser {
    let allowPick: Bool

    func parse(_ input: inout Substring) throws -> StepToken {
        try consume("[", from: &input)
        skipWhitespace(&input)

        if input.first == "\"" {
            let text = try QuotedStringParser().parse(&input)
            let caseFlag = (try? CaseFlagParser().parse(&input)) ?? .s
            skipWhitespace(&input)
            try consume("]", from: &input)
            return .filter(.shorthand(text, caseFlag))
        }

        if let char = input.first, char == "-" || isDigit(char) {
            guard allowPick else {
                throw SelectorParseError.expected("filter")
            }
            let index = try IntLiteralParser().parse(&input)
            skipWhitespace(&input)
            try consume("]", from: &input)
            return .pick(.index(index))
        }

        var negated = false
        if input.first == "!" {
            input.removeFirst()
            negated = true
            skipWhitespace(&input)
        }

        let name = try IdentifierParser().parse(&input)
        let nameLower = name.lowercased()
        skipWhitespace(&input)

        if input.first == "]" {
            input.removeFirst()
            if let (field, value) = boolFilterValue(nameLower: nameLower, explicit: nil, negated: negated) {
                return .filter(.attrBool(field: field, value: value))
            }
            throw SelectorParseError.invalidIdentifier(name)
        }

        if negated {
            throw SelectorParseError.expected("bool filter")
        }

        let matchType = try MatchOperatorParser().parse(&input)

        if let boolField = parseBoolField(nameLower), matchType == .eq {
            skipWhitespace(&input)
            let boolValue = try BoolLiteralParser().parse(&input)
            skipWhitespace(&input)
            try consume("]", from: &input)
            if nameLower == "disabled" {
                return .filter(.attrBool(field: .isEnabled, value: !boolValue))
            }
            return .filter(.attrBool(field: boolField, value: boolValue))
        }

        guard let field = parseStringField(nameLower) else {
            if parseBoolField(nameLower) != nil {
                throw SelectorParseError.expected("boolean")
            }
            throw SelectorParseError.invalidIdentifier(name)
        }

        skipWhitespace(&input)
        let value = try QuotedStringParser().parse(&input)
        let caseFlag = (try? CaseFlagParser().parse(&input)) ?? .s
        skipWhitespace(&input)
        try consume("]", from: &input)

        return .filter(.attrString(field: field, match: matchType, value: value, caseFlag: caseFlag))
    }
}

private struct PseudoTokenParser: Parser {
    let allowHas: Bool
    let allowOnly: Bool

    func parse(_ input: inout Substring) throws -> StepToken {
        try consume(":", from: &input)
        let name = try IdentifierParser().parse(&input).lowercased()

        if name == "only" {
            guard allowOnly else {
                throw SelectorParseError.expected("filter")
            }
            return .pick(.only)
        }

        skipWhitespace(&input)
        try consume("(", from: &input)
        skipWhitespace(&input)

        switch name {
        case "has":
            guard allowHas else {
                throw SelectorParseError.invalidIdentifier(name)
            }
            let step = try SimpleStepParser().parse(&input)
            skipWhitespace(&input)
            try consume(")", from: &input)
            return .filter(.has(step))
        case "not":
            let step = try SimpleStepParser().parse(&input)
            skipWhitespace(&input)
            try consume(")", from: &input)
            return .filter(.not(step))
        case "is":
            var steps: [SimpleStep] = []
            while true {
                let step = try SimpleStepParser().parse(&input)
                steps.append(step)
                skipWhitespace(&input)
                if input.first == "," {
                    input.removeFirst()
                    skipWhitespace(&input)
                    continue
                }
                try consume(")", from: &input)
                break
            }
            return .filter(.isMatch(steps))
        case "predicate":
            skipWhitespace(&input)
            let value = try QuotedStringParser().parse(&input)
            skipWhitespace(&input)
            try consume(")", from: &input)
            return .filter(.predicate(value))
        default:
            throw SelectorParseError.invalidIdentifier(name)
        }
    }
}

private func assembleStep(type: String?, tokens: [StepToken]) throws -> StepCore {
    var filters: [Filter] = []
    var pick: Pick?
    var parsedAnything = type != nil

    for token in tokens {
        switch token {
        case let .filter(filter):
            if pick != nil {
                throw SelectorParseError.unexpectedToken("picker must be last in step")
            }
            filters.append(filter)
            parsedAnything = true
        case let .pick(value):
            if pick != nil {
                throw SelectorParseError.unexpectedToken("multiple pickers in step")
            }
            guard parsedAnything else {
                throw SelectorParseError.expected("step")
            }
            pick = value
        }
    }

    if pick != nil, let last = tokens.last, case .pick = last {
        // ok
    } else if pick != nil {
        throw SelectorParseError.unexpectedToken("picker must be last in step")
    }

    guard parsedAnything else {
        throw SelectorParseError.expected("step")
    }

    return StepCore(type: type, filters: filters, pick: pick)
}

private struct OptionalWhitespaceParser: Parser {
    func parse(_ input: inout Substring) throws {
        skipWhitespace(&input)
    }
}

private struct RequiredWhitespaceParser: Parser {
    func parse(_ input: inout Substring) throws {
        let start = input.startIndex
        skipWhitespace(&input)
        if input.startIndex == start {
            throw SelectorParseError.expected("whitespace")
        }
    }
}

private func consume(_ char: Character, from input: inout Substring) throws {
    guard let current = input.first else {
        throw SelectorParseError.unexpectedEnd(expected: "'\(char)'")
    }
    guard current == char else {
        throw SelectorParseError.unexpectedCharacter(current, expected: "'\(char)'")
    }
    input.removeFirst()
}

private func skipWhitespace(_ input: inout Substring) {
    while let char = input.first, char.isWhitespace {
        input.removeFirst()
    }
}

private func boolFilterValue(nameLower: String, explicit: Bool?, negated: Bool) -> (BoolField, Bool)? {
    if nameLower == "disabled" {
        var value = explicit.map { !$0 } ?? false
        if negated {
            value.toggle()
        }
        return (.isEnabled, value)
    }
    guard let field = parseBoolField(nameLower) else {
        return nil
    }
    var value = explicit ?? true
    if negated {
        value.toggle()
    }
    return (field, value)
}

private func parseBoolField(_ nameLower: String) -> BoolField? {
    switch nameLower {
    case "enabled", "isenabled": return .isEnabled
    case "selected", "isselected": return .isSelected
    case "focused", "hasfocus": return .hasFocus
    case "disabled": return .isEnabled
    default: return nil
    }
}

private func parseStringField(_ nameLower: String) -> StringField? {
    switch nameLower {
    case "identifier": return .identifier
    case "title": return .title
    case "label": return .label
    case "value": return .value
    case "placeholder", "placeholdervalue": return .placeholderValue
    default: return nil
    }
}

private func isIdentStart(_ char: Character) -> Bool {
    return (char >= "A" && char <= "Z") || (char >= "a" && char <= "z") || char == "_"
}

private func isIdentChar(_ char: Character) -> Bool {
    return isIdentStart(char) || isDigit(char)
}

private func isDigit(_ char: Character) -> Bool {
    return char >= "0" && char <= "9"
}

// MARK: - Compiler

struct SelectorCompiler {
    func compile(_ selector: SelectorAST) throws -> ExecutionPlan {
        guard !selector.steps.isEmpty else {
            return ExecutionPlan(pipeline: [])
        }

        var pipeline: [ExecutionOp] = []

        for step in selector.steps {
            let axisOp = axisOperation(step: step)
            pipeline.append(axisOp)

            var filters = step.filters

            if let typeName = step.type,
               filters.count == 1,
               case let .shorthand(value, caseFlag) = filters[0],
               caseFlag == .s
            {
                pipeline.removeLast()
                pipeline.append(axisOperation(step: step, overrideType: "any"))
                pipeline.append(.matchTypeIdentifier(type: typeName, value: value))
                filters.removeAll()
            }

            var predicateParts: [String] = []

            for filter in filters {
                switch filter {
                case let .shorthand(value, caseFlag):
                    if caseFlag == .s {
                        pipeline.append(.matchIdentifier(value))
                    } else {
                        predicateParts.append(predicateForShorthand(value, caseFlag: caseFlag))
                    }
                case let .attrString(field, match, value, caseFlag):
                    predicateParts.append(predicateForString(field: field, match: match, value: value, caseFlag: caseFlag))
                case let .attrBool(field, value):
                    predicateParts.append(predicateForBool(field: field, value: value))
                case let .predicate(value):
                    predicateParts.append(value)
                case let .isMatch(steps):
                    try predicateParts.append(predicateForIs(steps))
                case let .not(step):
                    try predicateParts.append(predicateForNot(step))
                case let .has(step):
                    try pipeline.append(compileHas(step))
                }
            }

            if !predicateParts.isEmpty {
                let combined = predicateParts
                    .map { "(\($0))" }
                    .joined(separator: " AND ")
                pipeline.append(.matchPredicate(combined))
            }

            if let pick = step.pick {
                switch pick {
                case let .index(value):
                    pipeline.append(.pickIndex(value))
                case .only:
                    pipeline.append(.pickOnly)
                }
            }
        }

        return ExecutionPlan(pipeline: pipeline)
    }

    private func axisOperation(step: SelectorStep, overrideType: String? = nil) -> ExecutionOp {
        let typeValue = overrideType ?? step.type ?? "any"
        switch step.axis {
        case .descendant:
            return .descendants(type: typeValue)
        case .child:
            return .children(type: typeValue)
        }
    }

    private func compileHas(_ step: SimpleStep) throws -> ExecutionOp {
        if let typeName = step.type,
           step.filters.count == 1,
           case let .shorthand(value, caseFlag) = step.filters[0],
           caseFlag == .s
        {
            return .containTypeIdentifier(type: typeName, value: value)
        }
        let predicate = try predicateForSimpleStep(step)
        return .containPredicate(predicate)
    }

    private func predicateForIs(_ steps: [SimpleStep]) throws -> String {
        let parts = try steps.map { try predicateForSimpleStep($0) }
        return parts.map { "(\($0))" }.joined(separator: " OR ")
    }

    private func predicateForNot(_ step: SimpleStep) throws -> String {
        let predicate = try predicateForSimpleStep(step)
        return "NOT (\(predicate))"
    }

    private func predicateForSimpleStep(_ step: SimpleStep) throws -> String {
        var parts: [String] = []
        if let typeName = step.type {
            guard let raw = elementTypeRawValue(typeName) else {
                throw SelectorCompileError.invalidType(typeName)
            }
            parts.append("elementType == \(raw)")
        }

        for filter in step.filters {
            switch filter {
            case let .shorthand(value, caseFlag):
                parts.append(predicateForShorthand(value, caseFlag: caseFlag))
            case let .attrString(field, match, value, caseFlag):
                parts.append(predicateForString(field: field, match: match, value: value, caseFlag: caseFlag))
            case let .attrBool(field, value):
                parts.append(predicateForBool(field: field, value: value))
            case let .predicate(value):
                parts.append(value)
            case let .isMatch(steps):
                try parts.append(predicateForIs(steps))
            case let .not(step):
                try parts.append(predicateForNot(step))
            case .has:
                throw SelectorCompileError.invalidSelector(":has is not allowed inside simpleStep")
            }
        }

        guard !parts.isEmpty else {
            throw SelectorCompileError.invalidSelector("simpleStep must have type or filters")
        }

        return parts.map { "(\($0))" }.joined(separator: " AND ")
    }

    private func predicateForString(field: StringField, match: StringMatch, value: String, caseFlag: CaseFlag) -> String {
        let modifier = caseFlag == .i ? "[c]" : ""
        let literal: String
        if match == .regex, caseFlag == .i {
            literal = predicateStringLiteral("(?i)" + value)
        } else {
            literal = predicateStringLiteral(value)
        }
        switch match {
        case .eq:
            return "\(field.rawValue) ==\(modifier) \(literal)"
        case .contains:
            return "\(field.rawValue) CONTAINS\(modifier) \(literal)"
        case .begins:
            return "\(field.rawValue) BEGINSWITH\(modifier) \(literal)"
        case .ends:
            return "\(field.rawValue) ENDSWITH\(modifier) \(literal)"
        case .regex:
            return "\(field.rawValue) MATCHES \(literal)"
        }
    }

    private func predicateForBool(field: BoolField, value: Bool) -> String {
        let key: String
        switch field {
        case .isEnabled: key = "enabled"
        case .isSelected: key = "selected"
        case .hasFocus: key = "hasFocus"
        }
        return "\(key) == \(value ? 1 : 0)"
    }

    private func predicateForShorthand(_ value: String, caseFlag: CaseFlag) -> String {
        let modifier = caseFlag == .i ? "[c]" : ""
        let literal = predicateStringLiteral(value)
        let fields = ["identifier", "title", "label", "value", "placeholderValue"]
        let parts = fields.map { "\($0) ==\(modifier) \(literal)" }
        return parts.map { "(\($0))" }.joined(separator: " OR ")
    }

    private func predicateStringLiteral(_ value: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(value.count)
        for char in value {
            switch char {
            case "\\": escaped.append("\\\\")
            case "\"": escaped.append("\\\"")
            case "\n": escaped.append("\\n")
            case "\r": escaped.append("\\r")
            case "\t": escaped.append("\\t")
            default: escaped.append(char)
            }
        }
        return "\"\(escaped)\""
    }

    private func elementTypeRawValue(_ name: String) -> Int? {
        return elementTypeRawValues[name.lowercased()]
    }
}

private let elementTypeRawValues: [String: Int] = [
    "any": 0,
    "other": 1,
    "application": 2,
    "group": 3,
    "window": 4,
    "sheet": 5,
    "drawer": 6,
    "alert": 7,
    "dialog": 8,
    "button": 9,
    "radiobutton": 10,
    "radiogroup": 11,
    "checkbox": 12,
    "disclosuretriangle": 13,
    "popupbutton": 14,
    "combobox": 15,
    "menubutton": 16,
    "toolbarbutton": 17,
    "popover": 18,
    "keyboard": 19,
    "key": 20,
    "navigationbar": 21,
    "tabbar": 22,
    "tabgroup": 23,
    "toolbar": 24,
    "statusbar": 25,
    "table": 26,
    "tablerow": 27,
    "tablecolumn": 28,
    "outline": 29,
    "outlinerow": 30,
    "browser": 31,
    "collectionview": 32,
    "slider": 33,
    "pageindicator": 34,
    "progressindicator": 35,
    "activityindicator": 36,
    "segmentedcontrol": 37,
    "picker": 38,
    "pickerwheel": 39,
    "switch": 40,
    "toggle": 41,
    "link": 42,
    "image": 43,
    "icon": 44,
    "searchfield": 45,
    "scrollview": 46,
    "scrollbar": 47,
    "statictext": 48,
    "textfield": 49,
    "securetextfield": 50,
    "datepicker": 51,
    "textview": 52,
    "menu": 53,
    "menuitem": 54,
    "menubar": 55,
    "menubaritem": 56,
    "map": 57,
    "webview": 58,
    "incrementarrow": 59,
    "decrementarrow": 60,
    "timeline": 61,
    "ratingindicator": 62,
    "valueindicator": 63,
    "splitgroup": 64,
    "splitter": 65,
    "relevanceindicator": 66,
    "colorwell": 67,
    "helptag": 68,
    "matte": 69,
    "dockitem": 70,
    "ruler": 71,
    "rulermarker": 72,
    "grid": 73,
    "levelindicator": 74,
    "cell": 75,
    "layoutarea": 76,
    "layoutitem": 77,
    "handle": 78,
    "stepper": 79,
    "tab": 80,
    "touchbar": 81,
    "statusitem": 82,
]
