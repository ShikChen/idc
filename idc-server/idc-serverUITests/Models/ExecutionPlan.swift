import Foundation
import XCTest

struct ExecutionPlan: Codable, Equatable {
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

enum PlanError: LocalizedError {
    case invalidType(String)
    case invalidPlan(String)
    case invalidPredicate(String)
    case noMatches
    case notUnique

    var errorDescription: String? {
        switch self {
        case let .invalidType(value):
            return "Unknown element type: \(value)."
        case let .invalidPlan(value):
            return value
        case let .invalidPredicate(value):
            return "Invalid predicate: \(value)."
        case .noMatches:
            return "No matching elements."
        case .notUnique:
            return "Expected unique match but found multiple results."
        }
    }
}

enum PlanNode {
    case element(XCUIElement)
    case query(XCUIElementQuery)
}

enum SnapshotPlanNode {
    case element(XCUIElementSnapshot)
    case query([XCUIElementSnapshot])
}

func resolveElementType(_ name: String) throws -> XCUIElement.ElementType {
    guard let type = elementTypeFromName(name) else {
        throw PlanError.invalidType(name)
    }
    return type
}

func resolvePredicateArg(_ arg: PredicateArg) throws -> Any {
    switch arg {
    case let .string(value):
        return value
    case let .bool(value):
        return value
    case let .number(value):
        return value
    case let .elementType(value):
        return try resolveElementType(value).rawValue
    }
}

func predicateFromFormat(_ format: String, args: [PredicateArg]) throws -> NSPredicate {
    let resolvedArgs = try args.map { try resolvePredicateArg($0) }
    var errorMessage: NSString?
    let predicate = ObjCExceptionCatcher.perform({
        NSPredicate(format: format, argumentArray: resolvedArgs)
    }, errorMessage: &errorMessage) as? NSPredicate
    guard let predicate else {
        throw PlanError.invalidPredicate(errorMessage as String? ?? "Invalid predicate.")
    }
    return predicate
}

struct PlanExecutor {
    func resolve(_ plan: ExecutionPlan?, from root: XCUIElement) throws -> XCUIElement? {
        guard let plan, !plan.pipeline.isEmpty else {
            return root
        }
        let node = try resolveNode(plan, from: root)

        switch node {
        case let .element(element):
            return element
        case let .query(query):
            let first = query.firstMatch
            guard first.exists else { throw PlanError.noMatches }
            return first
        }
    }

    func resolveNode(_ plan: ExecutionPlan, from root: XCUIElement) throws -> PlanNode {
        guard plan.version == 3 else {
            throw PlanError.invalidPlan("Unsupported plan version: \(plan.version)")
        }
        var node: PlanNode = .element(root)
        for op in plan.pipeline {
            node = try apply(op, to: node)
        }
        return node
    }

    private func apply(_ op: ExecutionOp, to node: PlanNode) throws -> PlanNode {
        switch op {
        case let .descendants(type):
            let elementType = try resolveElementType(type)
            return .query(descendants(from: node, type: elementType))
        case let .children(type):
            let elementType = try resolveElementType(type)
            return .query(children(from: node, type: elementType))
        case let .matchIdentifier(value):
            let query = try requireQuery(node)
            return .query(query.matching(identifier: value))
        case let .matchTypeIdentifier(type, value):
            let elementType = try resolveElementType(type)
            let query = try requireQuery(node)
            return .query(query.matching(elementType, identifier: value))
        case let .matchPredicate(format, args):
            let query = try requireQuery(node)
            let predicate = try predicateFromFormat(format, args: args)
            return .query(query.matching(predicate))
        case let .containPredicate(format, args):
            let query = try requireQuery(node)
            let predicate = try predicateFromFormat(format, args: args)
            return .query(query.containing(predicate))
        case let .containTypeIdentifier(type, value):
            let elementType = try resolveElementType(type)
            let query = try requireQuery(node)
            return .query(query.containing(elementType, identifier: value))
        case let .pickIndex(index):
            let query = try requireQuery(node)
            let element = try resolveIndex(query: query, index: index)
            return .element(element)
        case .pickOnly:
            let query = try requireQuery(node)
            let element = try resolveOnly(query: query)
            return .element(element)
        }
    }

    private func requireQuery(_ node: PlanNode) throws -> XCUIElementQuery {
        guard case let .query(query) = node else {
            throw PlanError.invalidPlan("Expected query for operation.")
        }
        return query
    }

    private func descendants(from node: PlanNode, type: XCUIElement.ElementType) -> XCUIElementQuery {
        switch node {
        case let .element(element):
            return element.descendants(matching: type)
        case let .query(query):
            return query.descendants(matching: type)
        }
    }

    private func children(from node: PlanNode, type: XCUIElement.ElementType) -> XCUIElementQuery {
        switch node {
        case let .element(element):
            return element.children(matching: type)
        case let .query(query):
            return query.children(matching: type)
        }
    }

    private func resolveIndex(query: XCUIElementQuery, index: Int) throws -> XCUIElement {
        if index >= 0 {
            let element = query.element(boundBy: index)
            guard element.exists else { throw PlanError.noMatches }
            return element
        }
        let count = query.count
        let resolved = count + index
        guard resolved >= 0 else { throw PlanError.noMatches }
        let element = query.element(boundBy: resolved)
        guard element.exists else { throw PlanError.noMatches }
        return element
    }

    private func resolveOnly(query: XCUIElementQuery) throws -> XCUIElement {
        let first = query.firstMatch
        guard first.exists else { throw PlanError.noMatches }
        let second = query.element(boundBy: 1)
        guard !second.exists else { throw PlanError.notUnique }
        return first
    }
}

struct SnapshotPlanExecutor {
    func resolveNode(_ plan: ExecutionPlan, from root: XCUIElementSnapshot) throws -> SnapshotPlanNode {
        guard plan.version == 3 else {
            throw PlanError.invalidPlan("Unsupported plan version: \(plan.version)")
        }
        var node: SnapshotPlanNode = .element(root)
        for op in plan.pipeline {
            node = try apply(op, to: node)
        }
        return node
    }

    private func apply(_ op: ExecutionOp, to node: SnapshotPlanNode) throws -> SnapshotPlanNode {
        switch op {
        case let .descendants(type):
            let elementType = try resolveElementType(type)
            return .query(descendants(from: node, type: elementType))
        case let .children(type):
            let elementType = try resolveElementType(type)
            return .query(children(from: node, type: elementType))
        case let .matchIdentifier(value):
            let query = try requireQuery(node)
            return .query(query.filter { $0.identifier == value })
        case let .matchTypeIdentifier(type, value):
            let elementType = try resolveElementType(type)
            let query = try requireQuery(node)
            return .query(query.filter { $0.elementType == elementType && $0.identifier == value })
        case let .matchPredicate(format, args):
            let query = try requireQuery(node)
            let predicate = try predicateFromFormat(format, args: args)
            return .query(query.filter { predicateMatches(predicate, snapshot: $0) })
        case let .containPredicate(format, args):
            let query = try requireQuery(node)
            let predicate = try predicateFromFormat(format, args: args)
            return .query(query.filter { containsMatch(snapshot: $0, predicate: predicate) })
        case let .containTypeIdentifier(type, value):
            let elementType = try resolveElementType(type)
            let query = try requireQuery(node)
            return .query(query.filter { containsMatch(snapshot: $0, type: elementType, identifier: value) })
        case let .pickIndex(index):
            let query = try requireQuery(node)
            let element = try resolveIndex(query: query, index: index)
            return .element(element)
        case .pickOnly:
            let query = try requireQuery(node)
            let element = try resolveOnly(query: query)
            return .element(element)
        }
    }

    private func requireQuery(_ node: SnapshotPlanNode) throws -> [XCUIElementSnapshot] {
        guard case let .query(query) = node else {
            throw PlanError.invalidPlan("Expected query for operation.")
        }
        return query
    }

    private func descendants(from node: SnapshotPlanNode, type: XCUIElement.ElementType) -> [XCUIElementSnapshot] {
        switch node {
        case let .element(element):
            return collectDescendants(from: element, type: type)
        case let .query(query):
            return query.flatMap { collectDescendants(from: $0, type: type) }
        }
    }

    private func children(from node: SnapshotPlanNode, type: XCUIElement.ElementType) -> [XCUIElementSnapshot] {
        let matches: (XCUIElementSnapshot) -> Bool = { snapshot in
            type == .any || snapshot.elementType == type
        }
        switch node {
        case let .element(element):
            return element.children.filter(matches)
        case let .query(query):
            return query.flatMap { $0.children.filter(matches) }
        }
    }

    private func collectDescendants(from snapshot: XCUIElementSnapshot, type: XCUIElement.ElementType) -> [XCUIElementSnapshot] {
        var results: [XCUIElementSnapshot] = []
        collectDescendants(from: snapshot, type: type, into: &results)
        return results
    }

    private func collectDescendants(from snapshot: XCUIElementSnapshot, type: XCUIElement.ElementType, into results: inout [XCUIElementSnapshot]) {
        for child in snapshot.children {
            if type == .any || child.elementType == type {
                results.append(child)
            }
            collectDescendants(from: child, type: type, into: &results)
        }
    }

    private func resolveIndex(query: [XCUIElementSnapshot], index: Int) throws -> XCUIElementSnapshot {
        if index >= 0 {
            guard index < query.count else { throw PlanError.noMatches }
            return query[index]
        }
        let resolved = query.count + index
        guard resolved >= 0, resolved < query.count else { throw PlanError.noMatches }
        return query[resolved]
    }

    private func resolveOnly(query: [XCUIElementSnapshot]) throws -> XCUIElementSnapshot {
        guard let first = query.first else { throw PlanError.noMatches }
        guard query.count == 1 else { throw PlanError.notUnique }
        return first
    }

    private func predicateMatches(_ predicate: NSPredicate, snapshot: XCUIElementSnapshot) -> Bool {
        predicate.evaluate(with: SnapshotPredicateContext(snapshot: snapshot))
    }

    private func containsMatch(snapshot: XCUIElementSnapshot, predicate: NSPredicate) -> Bool {
        for child in snapshot.children {
            if predicateMatches(predicate, snapshot: child) {
                return true
            }
            if containsMatch(snapshot: child, predicate: predicate) {
                return true
            }
        }
        return false
    }

    private func containsMatch(snapshot: XCUIElementSnapshot, type: XCUIElement.ElementType, identifier: String) -> Bool {
        for child in snapshot.children {
            if (type == .any || child.elementType == type), child.identifier == identifier {
                return true
            }
            if containsMatch(snapshot: child, type: type, identifier: identifier) {
                return true
            }
        }
        return false
    }
}

@objcMembers
final class SnapshotPredicateContext: NSObject {
    let identifier: String
    let label: String
    let title: String
    let value: NSObject?
    let placeholderValue: String?
    let elementType: Int
    let hasFocus: Bool
    let isEnabled: Bool
    let isSelected: Bool
    let frame: SnapshotFrame

    init(snapshot: XCUIElementSnapshot) {
        identifier = snapshot.identifier
        label = snapshot.label
        title = snapshot.title
        value = snapshot.value as? NSObject
        placeholderValue = snapshot.placeholderValue
        elementType = Int(snapshot.elementType.rawValue)
        hasFocus = snapshot.hasFocus
        isEnabled = snapshot.isEnabled
        isSelected = snapshot.isSelected
        frame = SnapshotFrame(snapshot.frame)
    }
}

@objcMembers
final class SnapshotFrame: NSObject {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }
}
