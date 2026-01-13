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

private let elementTypeRawValues: [String: Int] = {
    // Order matches XCUIElement.ElementType raw values.
    let names = """
    any other application group window sheet drawer alert dialog button radiobutton radiogroup checkbox disclosuretriangle popupbutton combobox menubutton toolbarbutton popover keyboard key navigationbar tabbar tabgroup toolbar statusbar table tablerow tablecolumn outline outlinerow browser collectionview slider pageindicator progressindicator activityindicator segmentedcontrol picker pickerwheel switch toggle link image icon searchfield scrollview scrollbar statictext textfield securetextfield datepicker textview menu menuitem menubar menubaritem map webview incrementarrow decrementarrow timeline ratingindicator valueindicator splitgroup splitter relevanceindicator colorwell helptag matte dockitem ruler rulermarker grid levelindicator cell layoutarea layoutitem handle stepper tab touchbar statusitem
    """
    return Dictionary(uniqueKeysWithValues: names.split(separator: " ").enumerated().map { (String($0.element), $0.offset) })
}()
