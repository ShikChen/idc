import ArgumentParser
import Foundation

struct Tap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Tap a UI element."
    )

    @Argument(help: "Selector DSL (optional).")
    var selector: String?

    @Option(name: .long, help: "Tap point x,y or x%,y% (optional).")
    var at: String?

    @Option(name: .long, help: "Expected simulator UDID (optional).")
    var udid: String?

    @Option(name: .long, help: "Request timeout in seconds.")
    var timeout: Double = 5

    mutating func run() async throws {
        if selector == nil, at == nil {
            throw ValidationError("Provide a selector or --at.")
        }

        let plan: ExecutionPlan?
        if let selector {
            var parser = SelectorParser(selector)
            do {
                let parsed = try parser.parseSelector()
                plan = try SelectorCompiler().compile(parsed)
            } catch let error as SelectorParseError {
                throw ValidationError(error.description)
            } catch let error as SelectorCompileError {
                throw ValidationError(error.description)
            }
        } else {
            plan = nil
        }

        let point: TapPoint?
        if let at {
            let space: TapPointSpace = plan == nil ? .screen : .element
            point = try TapPoint(space: space, point: parseTapPoint(at))
        } else {
            point = nil
        }

        if let udid {
            let info: InfoResponse = try await fetchJSON(path: "/info", timeout: timeout)
            if info.udid != udid {
                let actual = info.udid ?? "nil"
                throw ValidationError("Server is running for a different simulator. Expected \(udid), got \(actual).")
            }
        }

        let request = TapRequest(plan: plan, at: point)
        let (data, response) = try await postJSON(path: "/tap", body: request, timeout: timeout)
        guard response.statusCode == 200 else {
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ValidationError(error.error)
            }
            throw ValidationError("Tap failed with HTTP \(response.statusCode).")
        }
    }
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

struct TapRequest: Encodable {
    let plan: ExecutionPlan?
    let at: TapPoint?
}

struct ErrorResponse: Decodable {
    let error: String
}
