import Foundation
import XCTest

enum SelectorError: LocalizedError {
    case invalidType(String)
    case notUnique(Int)
    case noMatches
    case invalidQuery(String)

    var errorDescription: String? {
        switch self {
        case let .invalidType(value):
            return "Unknown element type: \(value)."
        case let .notUnique(count):
            return "Expected unique match but found \(count)."
        case .noMatches:
            return "No matching elements."
        case let .invalidQuery(message):
            return message
        }
    }
}

private enum CandidateSet {
    case query(XCUIElementQuery)
    case queryAndSelf(query: XCUIElementQuery, selfElement: XCUIElement)
    case elements([XCUIElement])

    func elements() -> [XCUIElement] {
        switch self {
        case let .elements(elements):
            return elements
        case let .query(query):
            return query.allElementsBoundByIndex
        case let .queryAndSelf(query, selfElement):
            return [selfElement] + query.allElementsBoundByIndex
        }
    }
}

private enum Anchor {
    case `self`
    case descendant
    case `default`
}

private enum ResolvedAxis {
    case descendantOrSelf
    case descendant
    case child
    case selfOnly
}

func resolveSelector(_ program: SelectorProgram, from root: XCUIElement) throws -> [XCUIElement] {
    return try resolveSelector(program, from: root, anchor: .default)
}

private func resolveSelector(_ program: SelectorProgram, from root: XCUIElement, anchor: Anchor) throws -> [XCUIElement] {
    var current: [XCUIElement] = [root]

    for (index, step) in program.steps.enumerated() {
        var next: [XCUIElement] = []
        let axis = resolvedAxis(step.axis, index: index, anchor: anchor)
        for base in current {
            let candidates = initialCandidates(axis: axis, base: base)
            let filtered = try applyOps(step.ops, to: candidates, base: base)
            next.append(contentsOf: filtered)
        }
        current = next
    }

    return current
}

private func resolvedAxis(_ axis: Axis, index: Int, anchor: Anchor) -> ResolvedAxis {
    guard index == 0 else { return convertAxis(axis) }
    switch anchor {
    case .self:
        return axis == .descendantOrSelf ? .selfOnly : convertAxis(axis)
    case .descendant:
        return axis == .descendantOrSelf ? .descendant : convertAxis(axis)
    case .default:
        return convertAxis(axis)
    }
}

private func convertAxis(_ axis: Axis) -> ResolvedAxis {
    switch axis {
    case .descendantOrSelf:
        return .descendantOrSelf
    case .descendant:
        return .descendant
    case .child:
        return .child
    }
}

private func initialCandidates(axis: ResolvedAxis, base: XCUIElement) -> CandidateSet {
    switch axis {
    case .descendantOrSelf:
        let query = base.descendants(matching: .any)
        return .queryAndSelf(query: query, selfElement: base)
    case .descendant:
        return .query(base.descendants(matching: .any))
    case .child:
        return .query(base.children(matching: .any))
    case .selfOnly:
        return .elements([base])
    }
}

private func applyOps(_ ops: [SelectorOp], to set: CandidateSet, base: XCUIElement) throws -> [XCUIElement] {
    var current = set
    for op in ops {
        current = try apply(op, to: current, base: base)
    }
    return current.elements()
}

private func apply(_ op: SelectorOp, to set: CandidateSet, base: XCUIElement) throws -> CandidateSet {
    switch op {
    case let .type(name):
        guard let elementType = elementTypeFromName(name) else {
            throw SelectorError.invalidType(name)
        }
        let predicate = predicateForElementType(elementType)
        return applyQueryOrFilter(set) { query in
            query.matching(predicate)
        } elementFilter: { element in
            element.elementType == elementType
        }
    case let .subscriptValue(value, caseFlag):
        let predicate = predicateForSubscript(value, caseFlag: caseFlag)
        return applyQueryOrFilter(set) { query in
            query.matching(predicate)
        } elementFilter: { element in
            matchesSubscript(value, caseFlag: caseFlag, element: element)
        }
    case let .attrString(field, match, value, caseFlag):
        let predicate = predicateForAttr(field: field, match: match, value: value, caseFlag: caseFlag)
        return applyQueryOrFilter(set) { query in
            query.matching(predicate)
        } elementFilter: { element in
            matchesString(field: field, match: match, value: value, caseFlag: caseFlag, element: element)
        }
    case let .attrBool(field, value):
        let predicate = NSPredicate(format: "%K == %@", boolPredicateKey(field), NSNumber(value: value))
        return applyQueryOrFilter(set) { query in
            query.matching(predicate)
        } elementFilter: { element in
            matchesBool(field: field, value: value, element: element)
        }
    case let .index(value):
        let elements = set.elements()
        let resolved = resolveIndex(value, count: elements.count)
        if let resolved {
            return .elements([elements[resolved]])
        }
        return .elements([])
    case .only:
        let elements = set.elements()
        guard elements.count == 1 else {
            throw SelectorError.notUnique(elements.count)
        }
        return .elements(elements)
    case let .frame(match, point):
        let elements = set.elements()
        let filtered = elements.filter { frameMatches(element: $0, match: match, point: point) }
        return .elements(filtered)
    case let .has(selector):
        let elements = set.elements()
        var filtered: [XCUIElement] = []
        for element in elements {
            if try !resolveSelector(selector, from: element, anchor: .descendant).isEmpty {
                filtered.append(element)
            }
        }
        return .elements(filtered)
    case let .isMatch(selectors):
        let elements = set.elements()
        var filtered: [XCUIElement] = []
        for element in elements {
            var matched = false
            for selector in selectors {
                if try !resolveSelector(selector, from: element, anchor: .self).isEmpty {
                    matched = true
                    break
                }
            }
            if matched {
                filtered.append(element)
            }
        }
        return .elements(filtered)
    case let .not(selector):
        let elements = set.elements()
        var filtered: [XCUIElement] = []
        for element in elements {
            if try resolveSelector(selector, from: element, anchor: .self).isEmpty {
                filtered.append(element)
            }
        }
        return .elements(filtered)
    }
}

private func applyQueryOrFilter(
    _ set: CandidateSet,
    queryTransform: (XCUIElementQuery) -> XCUIElementQuery,
    elementFilter: (XCUIElement) -> Bool
) -> CandidateSet {
    switch set {
    case let .query(query):
        return .query(queryTransform(query))
    case let .queryAndSelf(query, selfElement):
        let nextQuery = queryTransform(query)
        if elementFilter(selfElement) {
            return .queryAndSelf(query: nextQuery, selfElement: selfElement)
        }
        return .query(nextQuery)
    case let .elements(elements):
        return .elements(elements.filter(elementFilter))
    }
}

private func resolveIndex(_ index: Int, count: Int) -> Int? {
    if index >= 0 {
        return index < count ? index : nil
    }
    let resolved = count + index
    return resolved >= 0 ? resolved : nil
}

private func predicateForSubscript(_ text: String, caseFlag: CaseFlag) -> NSPredicate {
    let modifier = caseFlag == .i ? "[c]" : ""
    let format = "identifier ==\(modifier) %@ OR title ==\(modifier) %@ OR label ==\(modifier) %@ OR value ==\(modifier) %@ OR placeholderValue ==\(modifier) %@"
    return NSPredicate(format: format, text, text, text, text, text)
}

private func predicateForAttr(field: StringField, match: StringMatch, value: String, caseFlag: CaseFlag) -> NSPredicate {
    let modifier = caseFlag == .i ? "[c]" : ""
    let format: String
    switch match {
    case .eq:
        format = "%K ==\(modifier) %@"
    case .contains:
        format = "%K CONTAINS\(modifier) %@"
    case .begins:
        format = "%K BEGINSWITH\(modifier) %@"
    case .ends:
        format = "%K ENDSWITH\(modifier) %@"
    case .regex:
        format = "%K MATCHES %@"
    }
    let rhs = (match == .regex && caseFlag == .i) ? "(?i)" + value : value
    return NSPredicate(format: format, field.rawValue, rhs)
}

private func predicateForElementType(_ type: XCUIElement.ElementType) -> NSPredicate {
    return NSPredicate(format: "elementType == %@", NSNumber(value: type.rawValue))
}

private func boolPredicateKey(_ field: BoolField) -> String {
    switch field {
    case .isEnabled:
        return "enabled"
    case .isSelected:
        return "selected"
    case .hasFocus:
        return "hasFocus"
    }
}

private func matchesSubscript(_ text: String, caseFlag: CaseFlag, element: XCUIElement) -> Bool {
    let fields: [String?] = [
        element.identifier,
        element.title,
        element.label,
        stringValue(for: .value, element: element),
        element.placeholderValue
    ]
    return fields.contains { value in
        guard let value else { return false }
        return matchesStringValue(value, match: .eq, target: text, caseFlag: caseFlag)
    }
}

private func matchesString(field: StringField, match: StringMatch, value: String, caseFlag: CaseFlag, element: XCUIElement) -> Bool {
    guard let target = stringValue(for: field, element: element) else { return false }
    return matchesStringValue(target, match: match, target: value, caseFlag: caseFlag)
}

private func stringValue(for field: StringField, element: XCUIElement) -> String? {
    switch field {
    case .identifier:
        return element.identifier
    case .title:
        return element.title
    case .label:
        return element.label
    case .value:
        if let string = element.value as? String {
            return string
        }
        if let number = element.value as? NSNumber {
            return number.stringValue
        }
        return nil
    case .placeholderValue:
        return element.placeholderValue
    }
}

private func matchesStringValue(_ value: String, match: StringMatch, target: String, caseFlag: CaseFlag) -> Bool {
    let options: String.CompareOptions = caseFlag == .i ? .caseInsensitive : []
    switch match {
    case .eq:
        return value.compare(target, options: options) == .orderedSame
    case .contains:
        return value.range(of: target, options: options) != nil
    case .begins:
        var opts = options
        opts.insert(.anchored)
        return value.range(of: target, options: opts) != nil
    case .ends:
        var opts = options
        opts.insert(.anchored)
        opts.insert(.backwards)
        return value.range(of: target, options: opts) != nil
    case .regex:
        let regexOptions: NSRegularExpression.Options = caseFlag == .i ? .caseInsensitive : []
        guard let regex = try? NSRegularExpression(pattern: target, options: regexOptions) else {
            return false
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, options: [], range: range) != nil
    }
}

private func matchesBool(field: BoolField, value: Bool, element: XCUIElement) -> Bool {
    switch field {
    case .isEnabled:
        return element.isEnabled == value
    case .isSelected:
        return element.isSelected == value
    case .hasFocus:
        return element.hasFocus == value
    }
}

private func frameMatches(element: XCUIElement, match: FrameMatch, point: PointSpec) -> Bool {
    guard match == .contains else { return false }
    let frame = element.frame.insetBy(dx: -0.5, dy: -0.5)
    let size = XCUIScreen.main.screenshot().image.size
    let point = resolvePoint(point, screen: size)
    return frame.contains(point)
}

private func resolvePoint(_ point: PointSpec, screen: CGSize) -> CGPoint {
    let x = resolvePointComponent(point.x, screenSize: screen.width)
    let y = resolvePointComponent(point.y, screenSize: screen.height)
    return CGPoint(x: x, y: y)
}

private func resolvePointComponent(_ component: PointComponent, screenSize: CGFloat) -> CGFloat {
    switch component.unit {
    case .pt:
        return component.value
    case .pct:
        return (component.value / 100.0) * screenSize
    }
}
