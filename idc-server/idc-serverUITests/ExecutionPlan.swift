import Foundation
import XCTest

struct ExecutionPlan: Codable, Equatable {
    var version: Int = 3
    var pipeline: [ExecutionOp]
}

enum ExecutionOp: Equatable {
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

enum PredicateArg: Equatable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case elementType(String)
}

extension PredicateArg: Codable {
    enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    enum Kind: String, Codable {
        case string
        case bool
        case number
        case elementType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case .number:
            self = .number(try container.decode(Double.self, forKey: .value))
        case .elementType:
            self = .elementType(try container.decode(String.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .string(value):
            try container.encode(Kind.string, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .bool(value):
            try container.encode(Kind.bool, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .number(value):
            try container.encode(Kind.number, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .elementType(value):
            try container.encode(Kind.elementType, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

extension ExecutionOp: Codable {
    enum CodingKeys: String, CodingKey {
        case op
        case type
        case value
        case format
        case args
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(String.self, forKey: .op)
        switch op {
        case "descendants":
            let type = try container.decode(String.self, forKey: .type)
            self = .descendants(type: type)
        case "children":
            let type = try container.decode(String.self, forKey: .type)
            self = .children(type: type)
        case "matchIdentifier":
            let value = try container.decode(String.self, forKey: .value)
            self = .matchIdentifier(value)
        case "matchTypeIdentifier":
            let type = try container.decode(String.self, forKey: .type)
            let value = try container.decode(String.self, forKey: .value)
            self = .matchTypeIdentifier(type: type, value: value)
        case "matchPredicate":
            let format = try container.decode(String.self, forKey: .format)
            let args = try container.decode([PredicateArg].self, forKey: .args)
            self = .matchPredicate(format: format, args: args)
        case "containPredicate":
            let format = try container.decode(String.self, forKey: .format)
            let args = try container.decode([PredicateArg].self, forKey: .args)
            self = .containPredicate(format: format, args: args)
        case "containTypeIdentifier":
            let type = try container.decode(String.self, forKey: .type)
            let value = try container.decode(String.self, forKey: .value)
            self = .containTypeIdentifier(type: type, value: value)
        case "pickIndex":
            let value = try container.decode(Int.self, forKey: .value)
            self = .pickIndex(value)
        case "pickOnly":
            self = .pickOnly
        default:
            throw DecodingError.dataCorruptedError(forKey: .op, in: container, debugDescription: "Unknown op: \(op)")
        }
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
        case let .matchPredicate(format, args):
            try container.encode("matchPredicate", forKey: .op)
            try container.encode(format, forKey: .format)
            try container.encode(args, forKey: .args)
        case let .containPredicate(format, args):
            try container.encode("containPredicate", forKey: .op)
            try container.encode(format, forKey: .format)
            try container.encode(args, forKey: .args)
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

enum PlanError: LocalizedError {
    case invalidType(String)
    case invalidPlan(String)
    case noMatches
    case notUnique

    var errorDescription: String? {
        switch self {
        case let .invalidType(value):
            return "Unknown element type: \(value)."
        case let .invalidPlan(value):
            return value
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

struct PlanExecutor {
    func resolve(_ plan: ExecutionPlan?, from root: XCUIElement) throws -> XCUIElement? {
        guard let plan, !plan.pipeline.isEmpty else {
            return root
        }
        guard plan.version == 3 else {
            throw PlanError.invalidPlan("Unsupported plan version: \(plan.version)")
        }

        var node: PlanNode = .element(root)

        for op in plan.pipeline {
            node = try apply(op, to: node)
        }

        switch node {
        case let .element(element):
            return element
        case let .query(query):
            let first = query.firstMatch
            guard first.exists else { throw PlanError.noMatches }
            return first
        }
    }

    private func apply(_ op: ExecutionOp, to node: PlanNode) throws -> PlanNode {
        switch op {
        case let .descendants(type):
            let elementType = try resolveType(type)
            return .query(descendants(from: node, type: elementType))
        case let .children(type):
            let elementType = try resolveType(type)
            return .query(children(from: node, type: elementType))
        case let .matchIdentifier(value):
            let query = try requireQuery(node)
            return .query(query.matching(identifier: value))
        case let .matchTypeIdentifier(type, value):
            let elementType = try resolveType(type)
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
            let elementType = try resolveType(type)
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

    private func resolveType(_ name: String) throws -> XCUIElement.ElementType {
        guard let type = elementTypeFromName(name) else {
            throw PlanError.invalidType(name)
        }
        return type
    }

    private func predicateFromFormat(_ format: String, args: [PredicateArg]) throws -> NSPredicate {
        let resolvedArgs = try args.map { try resolvePredicateArg($0) }
        return NSPredicate(format: format, argumentArray: resolvedArgs)
    }

    private func resolvePredicateArg(_ arg: PredicateArg) throws -> Any {
        switch arg {
        case let .string(value):
            return value
        case let .bool(value):
            return value
        case let .number(value):
            return value
        case let .elementType(value):
            return try resolveType(value).rawValue
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
