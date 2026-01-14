import Parsing

// MARK: - Parser

struct SelectorParser {
    private var input: Substring

    init(_ input: String) {
        self.input = input[...]
    }

    mutating func parseSelector() throws -> SelectorAST {
        if input.allSatisfy({ $0.isWhitespace }) {
            return SelectorAST(steps: [])
        }
        do {
            return try DSL.selector.parse(&input)
        } catch {
            throw SelectorParseError.parsing(String(describing: error))
        }
    }
}

private enum DSL {
    typealias Input = Substring
    typealias P<T> = AnyParser<Input, T>

    private struct StepCore {
        var type: String?
        var filters: [Filter]
        var pick: Pick?
    }

    private enum AttrSpec {
        case bool(BoolField, invert: Bool)
        case string(StringField)
    }

    static var selector: P<SelectorAST> {
        let step = stepCore(allowHas: true, allowPick: true, allowOnly: true)
        let combinators = combinatorsParser(step)
        return Parse {
            Whitespace()
            step
            combinators
            Whitespace()
            End()
        }
        .map { first, rest in
            var steps = [SelectorStep(axis: .descendant, type: first.type, filters: first.filters, pick: first.pick)]
            steps.append(contentsOf: rest.map { axis, core in
                SelectorStep(axis: axis, type: core.type, filters: core.filters, pick: core.pick)
            })
            return SelectorAST(steps: steps)
        }
        .eraseToAnyParser()
    }

    private static func combinatorParser(_ step: P<StepCore>) -> P<(Axis, StepCore)> {
        AnyParser { input in
            var lookahead = input
            while lookahead.first?.isWhitespace == true {
                lookahead.removeFirst()
            }
            guard let next = lookahead.first else {
                throw SelectorParseError.expected("step")
            }
            if next == ">" {
                return try Parse { Whitespace(); ">"; Whitespace(); step }
                    .map { (.child, $0) }
                    .parse(&input)
            }
            return try Parse { Whitespace(1...); step }
                .map { (Axis.descendant, $0) }
                .parse(&input)
        }
    }

    private static func combinatorsParser(_ step: P<StepCore>) -> P<[(Axis, StepCore)]> {
        AnyParser { input in
            var results: [(Axis, StepCore)] = []
            while true {
                guard let first = input.first else { break }
                if first == ">" {
                    results.append(try combinatorParser(step).parse(&input))
                    continue
                }
                if first.isWhitespace {
                    var lookahead = input
                    while lookahead.first?.isWhitespace == true {
                        lookahead.removeFirst()
                    }
                    if lookahead.isEmpty {
                        break
                    }
                    results.append(try combinatorParser(step).parse(&input))
                    continue
                }
                break
            }
            return results
        }
    }

    private static func stepCore(allowHas: Bool, allowPick: Bool, allowOnly: Bool) -> P<StepCore> {
        let pick: P<Pick?> = allowPick
            ? Optionally { pickParser(allowOnly: allowOnly) }.eraseToAnyParser()
            : Always(nil).eraseToAnyParser()
        return AnyParser { input in
            var type: String?
            var snapshot = input
            if let parsed = try? identifier().parse(&snapshot) {
                type = parsed.lowercased()
                input = snapshot
            }
            let filters = try filtersParser(allowHas: allowHas, allowPick: allowPick).parse(&input)
            let picked = try pick.parse(&input)
            return try makeStep(type: type, filters: filters, pick: picked)
        }
    }

    private static func simpleStep() -> P<SimpleStep> {
        Lazy {
            stepCore(allowHas: false, allowPick: false, allowOnly: false)
                .flatMap { core in
                    validate {
                        guard core.pick == nil else { throw SelectorParseError.expected("filter") }
                        return SimpleStep(type: core.type, filters: core.filters)
                    }
                }
        }
        .eraseToAnyParser()
    }

    private static func filtersParser(allowHas: Bool, allowPick: Bool) -> P<[Filter]> {
        AnyParser { input in
            var filters: [Filter] = []
            while let first = input.first {
                if first == "[" {
                    if allowPick, isPickIndexPrefix(input) {
                        break
                    }
                    filters.append(try bracketFilter().parse(&input))
                    continue
                }
                if first == ":" {
                    if allowPick, isPickOnlyPrefix(input) {
                        break
                    }
                    filters.append(try pseudoFilter(allowHas: allowHas).parse(&input))
                    continue
                }
                break
            }
            return filters
        }
    }

    private static func bracketFilter() -> P<Filter> {
        AnyParser { input in
            var lookahead = input
            guard lookahead.first == "[" else {
                throw SelectorParseError.expected("[")
            }
            lookahead.removeFirst()
            while lookahead.first?.isWhitespace == true {
                lookahead.removeFirst()
            }
            if lookahead.first == "\"" {
                return try shorthandFilter().parse(&input)
            }
            return try attrFilter().parse(&input)
        }
    }

    private static func shorthandFilter() -> P<Filter> {
        Parse {
            "["
            Whitespace()
            quotedString()
            caseFlag()
            Whitespace()
            "]"
        }
        .map(Filter.shorthand)
        .eraseToAnyParser()
    }

    private static func attrFilter() -> P<Filter> {
        AnyParser { input in
            try expectPrefix("[", in: &input)
            consumeWhitespace(&input)

            let negated = consumePrefix("!", in: &input)
            if negated {
                consumeWhitespace(&input)
            }

            let (nameLower, spec) = try attributeName().parse(&input)
            consumeWhitespace(&input)

            switch spec {
            case let .bool(field, invert):
                if input.first == "]" {
                    input.removeFirst()
                    var value = !invert
                    if negated { value.toggle() }
                    return .attrBool(field: field, value: value)
                }

                if negated {
                    throw SelectorParseError.expected("bool filter")
                }

                let op = try parseMatchOperator(in: &input, expected: "bool filter")
                guard op == .eq else {
                    throw SelectorParseError.expected("bool filter")
                }
                consumeWhitespace(&input)
                guard let boolValue = try? boolLiteral().parse(&input) else {
                    throw SelectorParseError.expected("boolean")
                }
                consumeWhitespace(&input)
                try expectPrefix("]", in: &input)
                let value = invert ? !boolValue : boolValue
                return .attrBool(field: field, value: value)

            case let .string(field):
                if negated {
                    throw SelectorParseError.expected("bool filter")
                }
                guard input.first != "]" else {
                    throw SelectorParseError.expected("string match operator for \(nameLower)")
                }
                let op = try parseMatchOperator(in: &input, expected: "string match operator for \(nameLower)")
                consumeWhitespace(&input)
                guard let text = try? quotedString().parse(&input) else {
                    throw SelectorParseError.expected("string literal")
                }
                let flag = try caseFlag().parse(&input)
                consumeWhitespace(&input)
                try expectPrefix("]", in: &input)
                return .attrString(field: field, match: op, value: text, caseFlag: flag)
            }
        }
    }

    private static func pseudoFilter(allowHas: Bool) -> P<Filter> {
        let not = Parse { ":"; "not"; Whitespace(); "("; Whitespace(); simpleStep(); Whitespace(); ")" }
            .map(Filter.not)

        let isMatch = Parse {
            ":"; "is"; Whitespace(); "("; Whitespace(); simpleStep()
            Many { Whitespace(); ","; Whitespace(); simpleStep() }
            Whitespace(); ")"
        }
        .map { first, rest in Filter.isMatch([first] + rest) }

        let predicate = Parse {
            ":"; "predicate"; Whitespace(); "("; Whitespace()
            quotedString()
                .flatMap { value in
                    validate {
                        do {
                            try PredicateValidator.validate(value)
                        } catch let error as PredicateValidationError {
                            throw SelectorParseError.invalidPredicate(error.description)
                        }
                        return value
                    }
                }
            Whitespace(); ")"
        }
        .map(Filter.predicate)

        let has = Parse { ":"; "has"; Whitespace(); "("; Whitespace(); simpleStep(); Whitespace(); ")" }
            .map(Filter.has)

        return AnyParser { input in
            var lookahead = input
            try expectPrefix(":", in: &lookahead)
            let name = try identifier().parse(&lookahead)
            switch name.lowercased() {
            case "has":
                guard allowHas else { throw SelectorParseError.expected("filter") }
                return try has.parse(&input)
            case "not":
                return try not.parse(&input)
            case "is":
                return try isMatch.parse(&input)
            case "predicate":
                return try predicate.parse(&input)
            default:
                throw SelectorParseError.unexpectedToken(name)
            }
        }
    }

    private static func pickParser(allowOnly: Bool) -> P<Pick> {
        let index = Parse { "["; Whitespace(); intLiteral(); Whitespace(); "]" }
            .map(Pick.index)
        if allowOnly {
            let only = Parse { ":"; "only" }.map { Pick.only }
            return OneOf { index; only }.eraseToAnyParser()
        }
        return index.eraseToAnyParser()
    }

    private static func identifier() -> P<String> {
        Parse {
            Prefix(1) { isIdentStart($0) }
            Prefix(0...) { isIdentChar($0) }
        }
        .map { first, rest in String(first) + rest }
        .eraseToAnyParser()
    }

    private static func attributeName() -> P<(String, AttrSpec)> {
        identifier()
            .flatMap { name in
                validate {
                    let lower = name.lowercased()
                    guard let spec = attrSpecs[lower] else {
                        throw SelectorParseError.invalidIdentifier(lower)
                    }
                    return (lower, spec)
                }
            }
            .eraseToAnyParser()
    }

    private static let escapeMap: [Character: Character] = [
        "\\": "\\",
        "\"": "\"",
        "n": "\n",
        "r": "\r",
        "t": "\t",
    ]

    private static func escapedChar() -> P<Character> {
        Parse { "\\"; Prefix(1) }
            .flatMap { value in
                validate {
                    guard let key = value.first, let mapped = escapeMap[key] else {
                        throw SelectorParseError.invalidEscape(String(value))
                    }
                    return mapped
                }
            }
            .eraseToAnyParser()
    }

    private static func normalChar() -> P<Character> {
        Prefix(1) { $0 != "\"" && $0 != "\\" }
            .map { $0.first! }
            .eraseToAnyParser()
    }

    private static func quotedString() -> P<String> {
        Parse {
            "\""
            Many(into: "") { $0.append($1) } element: { OneOf { escapedChar(); normalChar() } }
            "\""
        }
        .eraseToAnyParser()
    }

    private static func caseFlag() -> P<CaseFlag> {
        Parse {
            Optionally {
                Whitespace()
                OneOf {
                    Parse { "i" }.map { CaseFlag.i }
                    Parse { "s" }.map { CaseFlag.s }
                }
            }
        }
        .map { $0 ?? .s }
        .eraseToAnyParser()
    }

    fileprivate static func matchOperator() -> P<StringMatch> {
        OneOf {
            Parse { "*=" }.map { StringMatch.contains }
            Parse { "^=" }.map { StringMatch.begins }
            Parse { "$=" }.map { StringMatch.ends }
            Parse { "~=" }.map { StringMatch.regex }
            Parse { "=" }.map { StringMatch.eq }
        }
        .eraseToAnyParser()
    }

    private static func boolLiteral() -> P<Bool> {
        OneOf {
            Parse { "true" }.map { true }
            Parse { "false" }.map { false }
        }
        .eraseToAnyParser()
    }

    private static func intLiteral() -> P<Int> {
        AnyParser { input in
            var snapshot = input
            var sign = 1
            if snapshot.first == "-" {
                sign = -1
                snapshot.removeFirst()
            }
            let digits = snapshot
            let count = digits.prefix(while: { $0 >= "0" && $0 <= "9" }).count
            guard count > 0 else {
                throw SelectorParseError.expected("integer")
            }
            let text = String(digits.prefix(count))
            guard let value = Int(text) else {
                throw SelectorParseError.invalidNumber(text)
            }
            snapshot.removeFirst(count)
            input = snapshot
            return sign * value
        }
    }

    private static let attrSpecs: [String: AttrSpec] = [
        "enabled": .bool(.isEnabled, invert: false),
        "isenabled": .bool(.isEnabled, invert: false),
        "selected": .bool(.isSelected, invert: false),
        "isselected": .bool(.isSelected, invert: false),
        "focused": .bool(.hasFocus, invert: false),
        "hasfocus": .bool(.hasFocus, invert: false),
        "disabled": .bool(.isEnabled, invert: true),
        "identifier": .string(.identifier),
        "title": .string(.title),
        "label": .string(.label),
        "value": .string(.value),
        "placeholder": .string(.placeholderValue),
        "placeholdervalue": .string(.placeholderValue),
    ]

    private static func makeStep(type: String?, filters: [Filter], pick: Pick?) throws -> StepCore {
        guard type != nil || !filters.isEmpty || pick != nil else {
            throw SelectorParseError.expected("step")
        }
        return StepCore(type: type, filters: filters, pick: pick)
    }

    private static func validate<T>(_ work: () throws -> T) -> P<T> {
        do {
            return try Always(work()).eraseToAnyParser()
        } catch {
            return Fail(throwing: error).eraseToAnyParser()
        }
    }
}

private func isIdentStart(_ char: Character) -> Bool {
    (char >= "A" && char <= "Z") || (char >= "a" && char <= "z") || char == "_"
}

private func isIdentChar(_ char: Character) -> Bool {
    isIdentStart(char) || isDigit(char)
}

private func isDigit(_ char: Character) -> Bool {
    char >= "0" && char <= "9"
}

private func isPickIndexPrefix(_ input: Substring) -> Bool {
    var snapshot = input
    guard snapshot.first == "[" else { return false }
    snapshot.removeFirst()
    while snapshot.first?.isWhitespace == true { snapshot.removeFirst() }
    if snapshot.first == "-" { snapshot.removeFirst() }
    let digits = snapshot.prefix(while: isDigit)
    guard !digits.isEmpty else { return false }
    snapshot.removeFirst(digits.count)
    while snapshot.first?.isWhitespace == true { snapshot.removeFirst() }
    return snapshot.first == "]"
}

private func isPickOnlyPrefix(_ input: Substring) -> Bool {
    let token = ":only"
    guard input.hasPrefix(token) else { return false }
    let rest = input.dropFirst(token.count)
    guard let next = rest.first else { return true }
    return next.isWhitespace || next == ">"
}

private func consumeWhitespace(_ input: inout Substring) {
    while input.first?.isWhitespace == true {
        input.removeFirst()
    }
}

private func consumePrefix(_ prefix: Character, in input: inout Substring) -> Bool {
    guard input.first == prefix else { return false }
    input.removeFirst()
    return true
}

private func expectPrefix(_ prefix: Character, in input: inout Substring) throws {
    guard consumePrefix(prefix, in: &input) else {
        throw SelectorParseError.expected("\"\(prefix)\"")
    }
}

private func parseMatchOperator(in input: inout Substring, expected: String) throws -> StringMatch {
    var snapshot = input
    guard let op = try? DSL.matchOperator().parse(&snapshot) else {
        throw SelectorParseError.expected(expected)
    }
    input = snapshot
    return op
}
