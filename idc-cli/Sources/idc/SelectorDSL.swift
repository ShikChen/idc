import Foundation

struct SelectorProgram: Equatable, Encodable {
    var version: Int = 1
    var steps: [SelectorStep]
}

struct SelectorStep: Equatable, Encodable {
    var axis: Axis
    var ops: [SelectorOp]
}

enum Axis: String, Equatable, Encodable {
    case descendantOrSelf
    case descendant
    case child
}

enum CaseFlag: String, Equatable, Encodable {
    case s
    case i
}

enum StringMatch: String, Equatable, Encodable {
    case eq
    case contains
    case begins
    case ends
    case regex
}

enum StringField: String, Equatable, Encodable {
    case identifier
    case title
    case label
    case value
    case placeholderValue
}

enum BoolField: String, Equatable, Encodable {
    case isEnabled
    case isSelected
    case hasFocus
}

enum FrameMatch: String, Equatable, Encodable {
    case contains
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

extension SelectorOp: Encodable {
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

enum SelectorParseError: Error, CustomStringConvertible {
    case unexpectedEnd(expected: String)
    case unexpectedCharacter(Character, expected: String)
    case expected(String)
    case invalidNumber(String)
    case invalidEscape(String)
    case emptySelector
    case invalidIdentifier(String)

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
        }
    }
}

struct SelectorParser {
    private var characters: [Character]
    private var index: Int = 0

    init(_ input: String) {
        self.characters = Array(input)
    }

    mutating func parseSelector() throws -> SelectorProgram {
        let selector = try parseSelector(terminators: [])
        skipWhitespace()
        if let char = peek() {
            throw SelectorParseError.unexpectedCharacter(char, expected: "end of input")
        }
        return selector
    }

    private mutating func parseSelector(terminators: Set<Character>) throws -> SelectorProgram {
        skipWhitespace()
        guard !isAtEnd() else { throw SelectorParseError.emptySelector }

        var steps: [SelectorStep] = []
        if match(">") {
            skipWhitespace()
            steps.append(try parseStep(axis: .child))
        } else {
            steps.append(try parseStep(axis: .descendantOrSelf))
        }

        while true {
            let hadWhitespace = skipWhitespace()
            if let char = peek(), terminators.contains(char) {
                break
            }
            if match(">") {
                skipWhitespace()
                steps.append(try parseStep(axis: .child))
                continue
            }
            if hadWhitespace {
                if let char = peek(), isStepStart(char) {
                    steps.append(try parseStep(axis: .descendant))
                    continue
                }
                break
            }
            if let char = peek() {
                throw SelectorParseError.unexpectedCharacter(char, expected: "combinator")
            }
            break
        }

        return SelectorProgram(steps: steps)
    }

    private mutating func parseStep(axis: Axis) throws -> SelectorStep {
        skipWhitespace()
        var ops: [SelectorOp] = []
        var didParse = false

        if let char = peek(), isIdentStart(char) {
            let type = parseIdentifier()
            ops.append(.type(type.lowercased()))
            didParse = true
        }

        while true {
            if match("[") {
                ops.append(try parseFilter(afterOpeningBracket: true))
                didParse = true
                continue
            }
            if match(":") {
                ops.append(try parsePseudo(afterColon: true))
                didParse = true
                continue
            }
            break
        }

        guard didParse else {
            throw SelectorParseError.expected("step")
        }

        return SelectorStep(axis: axis, ops: ops)
    }

    private mutating func parseFilter(afterOpeningBracket: Bool) throws -> SelectorOp {
        if !afterOpeningBracket {
            guard match("[") else {
                throw SelectorParseError.expected("[")
            }
        }
        skipWhitespace()

        if match("\"") {
            let text = try parseStringBody(untilQuote: true)
            let caseFlag = parseCaseFlag() ?? .s
            skipWhitespace()
            try expect("]")
            return .subscriptValue(text, caseFlag)
        }

        if let char = peek(), char == "-" || isDigit(char) {
            let number = try parseInteger()
            skipWhitespace()
            try expect("]")
            return .index(number)
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
            if let boolOp = boolAliasOp(nameLower: nameLower, negated: negated) {
                return boolOp
            }
            if let field = parseBoolField(nameLower) {
                return .attrBool(field: field, value: !negated)
            }
            throw SelectorParseError.invalidIdentifier(name)
        }

        let matchType = try parseMatchOperator()

        if nameLower == "frame" {
            guard matchType == .contains else {
                throw SelectorParseError.expected("frame*=...")
            }
            skipWhitespace()
            try expect("(")
            let x = try parsePointComponent()
            skipWhitespace()
            try expect(",")
            let y = try parsePointComponent()
            skipWhitespace()
            try expect(")")
            skipWhitespace()
            try expect("]")
            return .frame(match: .contains, point: PointSpec(x: x, y: y))
        }

        guard let field = parseStringField(nameLower) else {
            if let _ = parseBoolField(nameLower) {
                throw SelectorParseError.expected("bool filter without operator")
            }
            throw SelectorParseError.invalidIdentifier(name)
        }

        skipWhitespace()
        try expect("\"")
        let value = try parseStringBody(untilQuote: true)
        let caseFlag = parseCaseFlag() ?? .s
        skipWhitespace()
        try expect("]")

        return .attrString(field: field, match: matchType, value: value, caseFlag: caseFlag)
    }

    private mutating func parsePseudo(afterColon: Bool) throws -> SelectorOp {
        if !afterColon {
            guard match(":") else {
                throw SelectorParseError.expected(":")
            }
        }

        let name = try parseRequiredIdentifier().lowercased()
        if name == "only" {
            return .only
        }

        skipWhitespace()
        try expect("(")
        skipWhitespace()

        switch name {
        case "has":
            let selector = try parseSelector(terminators: [")"])
            try expect(")")
            return .has(selector)
        case "not":
            let selector = try parseSelector(terminators: [")"])
            try expect(")")
            return .not(selector)
        case "is":
            var selectors: [SelectorProgram] = []
            while true {
                let selector = try parseSelector(terminators: [",", ")"])
                selectors.append(selector)
                skipWhitespace()
                if match(",") {
                    skipWhitespace()
                    continue
                }
                try expect(")")
                break
            }
            return .isMatch(selectors)
        default:
            throw SelectorParseError.invalidIdentifier(name)
        }
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

    private mutating func parsePointComponent() throws -> PointComponent {
        let number = try parseNumber()
        var unit: PointUnit = .pt
        if match("%") {
            unit = .pct
        }
        return PointComponent(value: number, unit: unit)
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

    private mutating func parseNumber() throws -> Double {
        let start = index
        if match("-") {}
        guard let char = peek(), isDigit(char) else {
            throw SelectorParseError.expected("number")
        }
        while let char = peek(), isDigit(char) {
            _ = advance()
        }
        if match(".") {
            guard let char = peek(), isDigit(char) else {
                throw SelectorParseError.expected("digit")
            }
            while let char = peek(), isDigit(char) {
                _ = advance()
            }
        }
        let value = String(characters[start..<index])
        guard let number = Double(value) else {
            throw SelectorParseError.invalidNumber(value)
        }
        return number
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
        if let next = peek(), !next.isWhitespace, next != "]" {
            index = snapshot
            return nil
        }
        return lower == "i" ? .i : .s
    }

    private func boolAliasOp(nameLower: String, negated: Bool) -> SelectorOp? {
        if nameLower == "disabled" {
            guard !negated else { return nil }
            return .attrBool(field: .isEnabled, value: false)
        }
        return nil
    }

    private func parseBoolField(_ nameLower: String) -> BoolField? {
        switch nameLower {
        case "enabled", "isenabled": return .isEnabled
        case "selected", "isselected": return .isSelected
        case "focused", "hasfocus": return .hasFocus
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
