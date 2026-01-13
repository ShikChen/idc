import Parsing

// MARK: - Parser

struct SelectorParser {
    private var input: Substring

    init(_ input: String) {
        self.input = input[...]
    }

    mutating func parseSelector() throws -> SelectorAST {
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

    private enum AttrValue {
        case bool(Bool)
        case string(String, CaseFlag)
    }

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
        let combinator = combinatorParser(step)
        return OneOf {
            Parse {
                Whitespace()
                End()
            }
            .map { SelectorAST(steps: []) }

            Parse {
                Whitespace()
                step
                Many { combinator }
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
        }
        .eraseToAnyParser()
    }

    private static func combinatorParser(_ step: P<StepCore>) -> P<(Axis, StepCore)> {
        OneOf {
            Parse { Whitespace(); ">"; Whitespace(); step }
                .map { (.child, $0) }
            Backtracking {
                Parse { Whitespace(1...); step }
                    .map { (Axis.descendant, $0) }
            }
        }
        .eraseToAnyParser()
    }

    private static func stepCore(allowHas: Bool, allowPick: Bool, allowOnly: Bool) -> P<StepCore> {
        let pick: P<Pick?> = allowPick
            ? Optionally { pickParser(allowOnly: allowOnly) }.eraseToAnyParser()
            : Always(nil).eraseToAnyParser()
        return Parse {
            Optionally { identifier() }
            Many { filterParser(allowHas: allowHas) }
            pick
        }
        .flatMap { type, filters, pick in
            validate {
                try makeStep(type: type?.lowercased(), filters: filters, pick: pick)
            }
        }
        .eraseToAnyParser()
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

    private static func filterParser(allowHas: Bool) -> P<Filter> {
        OneOf {
            bracketFilter()
            pseudoFilter(allowHas: allowHas)
        }
        .eraseToAnyParser()
    }

    private static func bracketFilter() -> P<Filter> {
        OneOf {
            shorthandFilter()
            attrFilter()
        }
        .eraseToAnyParser()
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
        Parse {
            "["
            Whitespace()
            Optionally { "!" }
            identifier()
            Whitespace()
            Optionally {
                matchOperator()
                Whitespace()
                attrValue()
            }
            Whitespace()
            "]"
        }
        .flatMap { negated, name, match in
            validate {
                try buildAttrFilter(nameLower: name.lowercased(), negated: negated != nil, match: match)
            }
        }
        .eraseToAnyParser()
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

        let predicate = Parse { ":"; "predicate"; Whitespace(); "("; Whitespace(); quotedString(); Whitespace(); ")" }
            .map(Filter.predicate)

        let has = Parse { ":"; "has"; Whitespace(); "("; Whitespace(); simpleStep(); Whitespace(); ")" }
            .map(Filter.has)

        if allowHas {
            return OneOf { has; not; isMatch; predicate }.eraseToAnyParser()
        }
        return OneOf { not; isMatch; predicate }.eraseToAnyParser()
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

    private static func matchOperator() -> P<StringMatch> {
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

    private static func attrValue() -> P<AttrValue> {
        OneOf {
            boolLiteral().map(AttrValue.bool)
            Parse { quotedString(); caseFlag() }.map(AttrValue.string)
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
        guard type != nil || !filters.isEmpty else {
            throw SelectorParseError.expected("step")
        }
        return StepCore(type: type, filters: filters, pick: pick)
    }

    private static func buildAttrFilter(
        nameLower: String,
        negated: Bool,
        match: (StringMatch, AttrValue)?
    ) throws -> Filter {
        if match != nil, negated {
            throw SelectorParseError.expected("bool filter")
        }
        guard let spec = attrSpecs[nameLower] else {
            throw SelectorParseError.invalidIdentifier(nameLower)
        }
        switch spec {
        case let .bool(field, invert):
            if let match {
                let (op, value) = match
                guard op == .eq, case let .bool(boolValue) = value else {
                    throw SelectorParseError.expected("boolean")
                }
                return .attrBool(field: field, value: invert ? !boolValue : boolValue)
            }
            var value = !invert
            if negated {
                value.toggle()
            }
            return .attrBool(field: field, value: value)
        case let .string(field):
            guard let match else {
                throw SelectorParseError.invalidIdentifier(nameLower)
            }
            let (op, value) = match
            guard case let .string(text, flag) = value else {
                throw SelectorParseError.expected("boolean")
            }
            return .attrString(field: field, match: op, value: text, caseFlag: flag)
        }
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
