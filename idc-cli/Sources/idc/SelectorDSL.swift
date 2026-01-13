import Foundation

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
    private var characters: [Character]
    private var index: Int = 0

    init(_ input: String) {
        self.characters = Array(input)
    }

    mutating func parseSelector() throws -> SelectorAST {
        skipWhitespace()
        if isAtEnd() {
            return SelectorAST(steps: [])
        }
        var steps: [SelectorStep] = []
        if match(">") {
            throw SelectorParseError.unexpectedCharacter(">", expected: "step")
        }
        steps.append(try parseStep(axis: .descendant))

        while true {
            let hadWhitespace = skipWhitespace()
            guard let char = peek() else { break }
            if match(">") {
                skipWhitespace()
                steps.append(try parseStep(axis: .child))
                continue
            }
            if hadWhitespace {
                if isStepStart(char) {
                    steps.append(try parseStep(axis: .descendant))
                    continue
                }
                break
            }
            throw SelectorParseError.unexpectedCharacter(char, expected: "combinator")
        }

        skipWhitespace()
        if let char = peek() {
            throw SelectorParseError.unexpectedCharacter(char, expected: "end of input")
        }

        return SelectorAST(steps: steps)
    }

    private mutating func parseStep(axis: Axis) throws -> SelectorStep {
        skipWhitespace()
        var type: String? = nil
        var filters: [Filter] = []
        var pick: Pick? = nil
        var didParse = false
        var didPick = false

        if let char = peek(), isIdentStart(char) {
            let value = parseIdentifier().lowercased()
            type = value
            didParse = true
        }

        while true {
            let whitespaceStart = index
            let hadWhitespace = skipWhitespace()
            guard let char = peek() else { break }
            if hadWhitespace, (isIdentStart(char) || char == ">") {
                index = whitespaceStart
                break
            }
            if didPick {
                if isIdentStart(char) || char == "[" || char == ":" {
                    throw SelectorParseError.unexpectedToken("picker must be last in step")
                }
                break
            }
            if char == "[" {
                _ = advance()
                let token = try parseBracketToken(allowPick: true, parsedAnything: didParse)
                switch token {
                case let .filter(filter):
                    filters.append(filter)
                case let .pick(newPick):
                    guard didParse else {
                        throw SelectorParseError.expected("step")
                    }
                    if pick != nil {
                        throw SelectorParseError.unexpectedToken("multiple pickers in step")
                    }
                    pick = newPick
                    didPick = true
                    break
                }
                didParse = true
                continue
            }
            if char == ":" {
                _ = advance()
                let token = try parsePseudoToken(allowHas: true)
                switch token {
                case let .filter(filter):
                    filters.append(filter)
                case let .pick(newPick):
                    guard didParse else {
                        throw SelectorParseError.expected("step")
                    }
                    if pick != nil {
                        throw SelectorParseError.unexpectedToken("multiple pickers in step")
                    }
                    pick = newPick
                    didPick = true
                    break
                }
                didParse = true
                continue
            }
            if isIdentStart(char) {
                if hadWhitespace {
                    break
                }
                throw SelectorParseError.unexpectedCharacter(char, expected: "filter")
            }
            break
        }

        guard didParse else {
            throw SelectorParseError.expected("step")
        }

        return SelectorStep(axis: axis, type: type, filters: filters, pick: pick)
    }

    private enum ParsedToken {
        case filter(Filter)
        case pick(Pick)
    }

    private mutating func parseBracketToken(allowPick: Bool, parsedAnything: Bool) throws -> ParsedToken {
        skipWhitespace()

        if match("\"") {
            let text = try parseStringBody(untilQuote: true)
            let caseFlag = parseCaseFlag() ?? .s
            skipWhitespace()
            try expect("]")
            return .filter(.shorthand(text, caseFlag))
        }

        if let char = peek(), char == "-" || isDigit(char) {
            guard allowPick, parsedAnything else {
                throw SelectorParseError.expected("filter")
            }
            let number = try parseInteger()
            skipWhitespace()
            try expect("]")
            return .pick(.index(number))
        }

        var negated = false
        if match("!") {
            negated = true
            skipWhitespace()
        }

        let name = try parseRequiredIdentifier()
        let nameLower = name.lowercased()
        skipWhitespace()

        if match("]") {
            if let (field, value) = boolFilterValue(nameLower: nameLower, explicit: nil, negated: negated) {
                return .filter(.attrBool(field: field, value: value))
            }
            throw SelectorParseError.invalidIdentifier(name)
        }

        if negated {
            throw SelectorParseError.expected("bool filter")
        }

        let matchType = try parseMatchOperator()

        if let boolField = parseBoolField(nameLower), matchType == .eq {
            skipWhitespace()
            let boolValue = try parseBoolean()
            skipWhitespace()
            try expect("]")
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

        skipWhitespace()
        try expect("\"")
        let value = try parseStringBody(untilQuote: true)
        let caseFlag = parseCaseFlag() ?? .s
        skipWhitespace()
        try expect("]")

        return .filter(.attrString(field: field, match: matchType, value: value, caseFlag: caseFlag))
    }

    private mutating func parsePseudoToken(allowHas: Bool) throws -> ParsedToken {
        let name = try parseRequiredIdentifier().lowercased()

        if name == "only" {
            return .pick(.only)
        }

        skipWhitespace()
        try expect("(")
        skipWhitespace()

        switch name {
        case "has":
            guard allowHas else {
                throw SelectorParseError.invalidIdentifier(name)
            }
            let step = try parseSimpleStep(terminators: [")"])
            try expect(")")
            return .filter(.has(step))
        case "not":
            let step = try parseSimpleStep(terminators: [")"])
            try expect(")")
            return .filter(.not(step))
        case "is":
            var steps: [SimpleStep] = []
            while true {
                let step = try parseSimpleStep(terminators: [",", ")"])
                steps.append(step)
                skipWhitespace()
                if match(",") {
                    skipWhitespace()
                    continue
                }
                try expect(")")
                break
            }
            return .filter(.isMatch(steps))
        case "predicate":
            skipWhitespace()
            try expect("\"")
            let value = try parseStringBody(untilQuote: true)
            skipWhitespace()
            try expect(")")
            return .filter(.predicate(value))
        default:
            throw SelectorParseError.invalidIdentifier(name)
        }
    }

    private mutating func parseSimpleStep(terminators: Set<Character>) throws -> SimpleStep {
        skipWhitespace()
        var type: String? = nil
        var filters: [Filter] = []
        var didParse = false

        if let char = peek(), isIdentStart(char) {
            type = parseIdentifier().lowercased()
            didParse = true
        }

        while true {
            skipWhitespace()
            guard let char = peek() else { break }
            if terminators.contains(char) {
                break
            }
            if char == ">" {
                throw SelectorParseError.unexpectedCharacter(char, expected: "simple step")
            }
            if char == "[" {
                _ = advance()
                let token = try parseBracketToken(allowPick: false, parsedAnything: true)
                guard case let .filter(filter) = token else {
                    throw SelectorParseError.expected("filter")
                }
                filters.append(filter)
                didParse = true
                continue
            }
            if char == ":" {
                _ = advance()
                let token = try parsePseudoToken(allowHas: false)
                guard case let .filter(filter) = token else {
                    throw SelectorParseError.expected("filter")
                }
                filters.append(filter)
                didParse = true
                continue
            }
            if isIdentStart(char) {
                throw SelectorParseError.unexpectedCharacter(char, expected: "filter")
            }
            break
        }

        guard didParse else {
            throw SelectorParseError.expected("simple step")
        }

        return SimpleStep(type: type, filters: filters)
    }

    private mutating func parseMatchOperator() throws -> StringMatch {
        if match("*") {
            try expect("=")
            return .contains
        }
        if match("^") {
            try expect("=")
            return .begins
        }
        if match("$") {
            try expect("=")
            return .ends
        }
        if match("~") {
            try expect("=")
            return .regex
        }
        if match("=") {
            return .eq
        }
        if let char = peek() {
            throw SelectorParseError.unexpectedCharacter(char, expected: "match operator")
        }
        throw SelectorParseError.unexpectedEnd(expected: "match operator")
    }

    private mutating func parseBoolean() throws -> Bool {
        let value = parseIdentifier().lowercased()
        switch value {
        case "true": return true
        case "false": return false
        default:
            throw SelectorParseError.invalidBoolean(value)
        }
    }

    private mutating func parseInteger() throws -> Int {
        let start = index
        if match("-") {}
        guard let char = peek(), isDigit(char) else {
            throw SelectorParseError.expected("integer")
        }
        while let char = peek(), isDigit(char) {
            _ = advance()
        }
        let value = String(characters[start..<index])
        guard let intValue = Int(value) else {
            throw SelectorParseError.invalidNumber(value)
        }
        return intValue
    }

    private mutating func parseIdentifier() -> String {
        guard let char = peek(), isIdentStart(char) else {
            return ""
        }
        let start = index
        _ = advance()
        while let char = peek(), isIdentChar(char) {
            _ = advance()
        }
        return String(characters[start..<index])
    }

    private mutating func parseRequiredIdentifier() throws -> String {
        let value = parseIdentifier()
        if value.isEmpty {
            throw SelectorParseError.expected("identifier")
        }
        return value
    }

    private mutating func parseStringBody(untilQuote: Bool) throws -> String {
        var result = ""
        while let char = peek() {
            _ = advance()
            if char == "\"" {
                if untilQuote {
                    return result
                }
                result.append(char)
                continue
            }
            if char == "\\" {
                guard let esc = advance() else {
                    throw SelectorParseError.unexpectedEnd(expected: "escape")
                }
                switch esc {
                case "\\": result.append("\\")
                case "\"": result.append("\"")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                default:
                    throw SelectorParseError.invalidEscape(String(esc))
                }
                continue
            }
            result.append(char)
        }
        throw SelectorParseError.unexpectedEnd(expected: "\"")
    }

    private mutating func parseCaseFlag() -> CaseFlag? {
        let snapshot = index
        skipWhitespace()
        guard let char = peek() else {
            index = snapshot
            return nil
        }
        let lower = String(char).lowercased()
        guard lower == "i" || lower == "s" else {
            index = snapshot
            return nil
        }
        _ = advance()
        if let next = peek(), !next.isWhitespace, next != "]", next != ")", next != "," {
            index = snapshot
            return nil
        }
        return lower == "i" ? .i : .s
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

    private mutating func expect(_ char: Character) throws {
        guard match(char) else {
            if let found = peek() {
                throw SelectorParseError.unexpectedCharacter(found, expected: "'\(char)'")
            }
            throw SelectorParseError.unexpectedEnd(expected: "'\(char)'")
        }
    }

    @discardableResult
    private mutating func match(_ char: Character) -> Bool {
        guard let current = peek(), current == char else { return false }
        index += 1
        return true
    }

    private func peek() -> Character? {
        guard index < characters.count else { return nil }
        return characters[index]
    }

    @discardableResult
    private mutating func advance() -> Character? {
        guard index < characters.count else { return nil }
        let char = characters[index]
        index += 1
        return char
    }

    @discardableResult
    private mutating func skipWhitespace() -> Bool {
        var consumed = false
        while let char = peek(), char.isWhitespace {
            consumed = true
            index += 1
        }
        return consumed
    }

    private func isAtEnd() -> Bool {
        return index >= characters.count
    }

    private func isDigit(_ char: Character) -> Bool {
        return char >= "0" && char <= "9"
    }

    private func isIdentStart(_ char: Character) -> Bool {
        return (char >= "A" && char <= "Z") || (char >= "a" && char <= "z") || char == "_"
    }

    private func isIdentChar(_ char: Character) -> Bool {
        return isIdentStart(char) || isDigit(char)
    }

    private func isStepStart(_ char: Character) -> Bool {
        return isIdentStart(char) || char == "[" || char == ":"
    }
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
               caseFlag == .s {
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
                    predicateParts.append(try predicateForIs(steps))
                case let .not(step):
                    predicateParts.append(try predicateForNot(step))
                case let .has(step):
                    pipeline.append(try compileHas(step))
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
           caseFlag == .s {
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
                parts.append(try predicateForIs(steps))
            case let .not(step):
                parts.append(try predicateForNot(step))
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
