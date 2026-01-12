import ArgumentParser
import Foundation

struct Tap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Tap a UI element (debug: print parsed selector)."
    )

    @Argument(help: "Selector DSL (optional).")
    var selector: String?

    @Option(name: .long, help: "Tap point x,y or x%,y% (optional).")
    var at: String?

    mutating func run() throws {
        if selector == nil && at == nil {
            throw ValidationError("Provide a selector or --at.")
        }

        let program: SelectorProgram?
        if let selector {
            var parser = SelectorParser(selector)
            do {
                program = try parser.parseSelector()
            } catch let error as SelectorParseError {
                throw ValidationError(error.description)
            }
        } else {
            program = nil
        }

        let point: TapPoint?
        if let at {
            let space: TapPointSpace = program == nil ? .screen : .element
            point = try TapPoint(space: space, point: parseTapPoint(at))
        } else {
            point = nil
        }

        let output = TapDebugOutput(selector: program, at: point)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(output)
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        } else {
            throw ValidationError("Unable to encode output.")
        }
    }
}

struct TapDebugOutput: Encodable {
    let selector: SelectorProgram?
    let at: TapPoint?
}

enum TapPointSpace: String, Encodable {
    case element
    case screen
}

struct TapPoint: Encodable {
    let space: TapPointSpace
    let point: PointSpec
}

enum TapParseError: Error, CustomStringConvertible {
    case invalidFormat
    case invalidNumber(String)

    var description: String {
        switch self {
        case .invalidFormat:
            return "Expected point format x,y or x%,y%."
        case let .invalidNumber(value):
            return "Invalid number: \(value)."
        }
    }
}

func parseTapPoint(_ input: String) throws -> PointSpec {
    let parts = input.split(separator: ",", omittingEmptySubsequences: false)
    guard parts.count == 2 else {
        throw TapParseError.invalidFormat
    }

    let x = try parsePointComponent(String(parts[0]).trimmingCharacters(in: .whitespaces))
    let y = try parsePointComponent(String(parts[1]).trimmingCharacters(in: .whitespaces))
    return PointSpec(x: x, y: y)
}

private func parsePointComponent(_ raw: String) throws -> PointComponent {
    guard !raw.isEmpty else {
        throw TapParseError.invalidFormat
    }
    let unit: PointUnit
    let numberText: String
    if raw.hasSuffix("%") {
        unit = .pct
        numberText = String(raw.dropLast())
    } else {
        unit = .pt
        numberText = raw
    }
    guard let value = Double(numberText) else {
        throw TapParseError.invalidNumber(numberText)
    }
    return PointComponent(value: value, unit: unit)
}
