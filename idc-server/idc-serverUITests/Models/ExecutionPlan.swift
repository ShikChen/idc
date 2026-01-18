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

private struct SnapshotIndex {
    struct Node {
        let snapshot: XCUIElementSnapshot
        let parent: Int?
        var children: [Int]
    }

    let nodes: [Node]
    let rootIndex: Int

    init(root: XCUIElementSnapshot) {
        var nodes: [Node] = []

        func walk(_ snapshot: XCUIElementSnapshot, parent: Int?) -> Int {
            let index = nodes.count
            nodes.append(Node(snapshot: snapshot, parent: parent, children: []))
            for child in snapshot.children {
                let childIndex = walk(child, parent: index)
                nodes[index].children.append(childIndex)
            }
            return index
        }

        let rootIndex = walk(root, parent: nil)
        self.nodes = nodes
        self.rootIndex = rootIndex
    }
}

private struct ActiveSet {
    var bits: [Bool]

    init(size: Int) {
        bits = Array(repeating: false, count: size)
    }

    mutating func set(_ index: Int) {
        bits[index] = true
    }

    func orderedIndices() -> [Int] {
        var indices: [Int] = []
        indices.reserveCapacity(bits.count)
        for (index, active) in bits.enumerated() where active {
            indices.append(index)
        }
        return indices
    }
}

private enum IndexedPlanNode {
    case element(Int)
    case query(ActiveSet)
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
        let index = SnapshotIndex(root: root)
        var node: IndexedPlanNode = .element(index.rootIndex)
        for op in plan.pipeline {
            node = try apply(op, to: node, index: index)
        }
        return materialize(node, index: index)
    }

    private func apply(_ op: ExecutionOp, to node: IndexedPlanNode, index: SnapshotIndex) throws -> IndexedPlanNode {
        switch op {
        case let .descendants(type):
            let elementType = try resolveElementType(type)
            let roots = roots(from: node, size: index.nodes.count)
            return .query(descendants(from: roots, type: elementType, index: index))
        case let .children(type):
            let elementType = try resolveElementType(type)
            let roots = roots(from: node, size: index.nodes.count)
            return .query(children(from: roots, type: elementType, index: index))
        case let .matchIdentifier(value):
            let query = try requireQuery(node)
            return .query(try filter(query, index: index) { $0.identifier == value })
        case let .matchTypeIdentifier(type, value):
            let elementType = try resolveElementType(type)
            let query = try requireQuery(node)
            return .query(try filter(query, index: index) { $0.elementType == elementType && $0.identifier == value })
        case let .matchPredicate(format, args):
            let predicate = try predicateFromFormat(format, args: args)
            let query = try requireQuery(node)
            return .query(try filter(query, index: index) { try predicateMatches(predicate, snapshot: $0) })
        case let .containPredicate(format, args):
            let predicate = try predicateFromFormat(format, args: args)
            let query = try requireQuery(node)
            return .query(try contain(query, predicate: predicate, index: index))
        case let .containTypeIdentifier(type, value):
            let elementType = try resolveElementType(type)
            let query = try requireQuery(node)
            return .query(contain(query, type: elementType, identifier: value, index: index))
        case let .pickIndex(index):
            let query = try requireQuery(node)
            let resolved = try resolveIndex(query: query, index: index)
            return .element(resolved)
        case .pickOnly:
            let query = try requireQuery(node)
            let resolved = try resolveOnly(query: query)
            return .element(resolved)
        }
    }

    private func roots(from node: IndexedPlanNode, size: Int) -> ActiveSet {
        switch node {
        case let .element(index):
            var roots = ActiveSet(size: size)
            roots.set(index)
            return roots
        case let .query(active):
            return active
        }
    }

    private func requireQuery(_ node: IndexedPlanNode) throws -> ActiveSet {
        guard case let .query(query) = node else {
            throw PlanError.invalidPlan("Expected query for operation.")
        }
        return query
    }

    private func descendants(from roots: ActiveSet, type: XCUIElement.ElementType, index: SnapshotIndex) -> ActiveSet {
        let count = index.nodes.count
        var result = ActiveSet(size: count)
        var ancestorActive = Array(repeating: false, count: count)
        for i in 0 ..< count {
            if let parent = index.nodes[i].parent {
                ancestorActive[i] = roots.bits[parent] || ancestorActive[parent]
            }
            if ancestorActive[i], typeMatches(index.nodes[i].snapshot, type: type) {
                result.bits[i] = true
            }
        }
        return result
    }

    private func children(from roots: ActiveSet, type: XCUIElement.ElementType, index: SnapshotIndex) -> ActiveSet {
        let count = index.nodes.count
        var result = ActiveSet(size: count)
        for i in 0 ..< count {
            guard let parent = index.nodes[i].parent, roots.bits[parent] else { continue }
            if typeMatches(index.nodes[i].snapshot, type: type) {
                result.bits[i] = true
            }
        }
        return result
    }

    private func filter(_ active: ActiveSet, index: SnapshotIndex, matches: (XCUIElementSnapshot) throws -> Bool) throws -> ActiveSet {
        let count = index.nodes.count
        var result = ActiveSet(size: count)
        for i in 0 ..< count where active.bits[i] {
            if try matches(index.nodes[i].snapshot) {
                result.bits[i] = true
            }
        }
        return result
    }

    private func contain(_ active: ActiveSet, predicate: NSPredicate, index: SnapshotIndex) throws -> ActiveSet {
        let count = index.nodes.count
        var selfMatches = Array(repeating: false, count: count)
        for i in 0 ..< count {
            selfMatches[i] = try predicateMatches(predicate, snapshot: index.nodes[i].snapshot)
        }
        let descendantMatches = descendantMatchFlags(selfMatches: selfMatches, index: index)
        var result = ActiveSet(size: count)
        for i in 0 ..< count where active.bits[i] && descendantMatches[i] {
            result.bits[i] = true
        }
        return result
    }

    private func contain(_ active: ActiveSet, type: XCUIElement.ElementType, identifier: String, index: SnapshotIndex) -> ActiveSet {
        let count = index.nodes.count
        var selfMatches = Array(repeating: false, count: count)
        for i in 0 ..< count {
            let snapshot = index.nodes[i].snapshot
            selfMatches[i] = (type == .any || snapshot.elementType == type) && snapshot.identifier == identifier
        }
        let descendantMatches = descendantMatchFlags(selfMatches: selfMatches, index: index)
        var result = ActiveSet(size: count)
        for i in 0 ..< count where active.bits[i] && descendantMatches[i] {
            result.bits[i] = true
        }
        return result
    }

    private func descendantMatchFlags(selfMatches: [Bool], index: SnapshotIndex) -> [Bool] {
        let count = index.nodes.count
        var descendantMatches = Array(repeating: false, count: count)
        if count == 0 {
            return descendantMatches
        }
        for i in stride(from: count - 1, through: 0, by: -1) {
            var hasMatch = false
            for child in index.nodes[i].children {
                if selfMatches[child] || descendantMatches[child] {
                    hasMatch = true
                    break
                }
            }
            descendantMatches[i] = hasMatch
        }
        return descendantMatches
    }

    private func resolveIndex(query: ActiveSet, index: Int) throws -> Int {
        let ordered = query.orderedIndices()
        if index >= 0 {
            guard index < ordered.count else { throw PlanError.noMatches }
            return ordered[index]
        }
        let resolved = ordered.count + index
        guard resolved >= 0, resolved < ordered.count else { throw PlanError.noMatches }
        return ordered[resolved]
    }

    private func resolveOnly(query: ActiveSet) throws -> Int {
        let ordered = query.orderedIndices()
        guard let first = ordered.first else { throw PlanError.noMatches }
        guard ordered.count == 1 else { throw PlanError.notUnique }
        return first
    }

    private func predicateMatches(_ predicate: NSPredicate, snapshot: XCUIElementSnapshot) throws -> Bool {
        var errorMessage: NSString?
        let result = ObjCExceptionCatcher.perform({
            NSNumber(value: predicate.evaluate(with: snapshot))
        }, errorMessage: &errorMessage) as? NSNumber
        if let errorMessage {
            throw PlanError.invalidPredicate(errorMessage as String)
        }
        return result?.boolValue ?? false
    }

    private func typeMatches(_ snapshot: XCUIElementSnapshot, type: XCUIElement.ElementType) -> Bool {
        type == .any || snapshot.elementType == type
    }

    private func materialize(_ node: IndexedPlanNode, index: SnapshotIndex) -> SnapshotPlanNode {
        switch node {
        case let .element(idx):
            return .element(index.nodes[idx].snapshot)
        case let .query(active):
            let snapshots = active.orderedIndices().map { index.nodes[$0].snapshot }
            return .query(snapshots)
        }
    }
}
