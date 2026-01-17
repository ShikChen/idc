import ArgumentParser
import Foundation

struct Find: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Find UI elements by selector."
    )

    @Argument(help: "Selector DSL.")
    var selector: String

    @Option(name: .long, help: "Max results to return (default: 20).")
    var limit: Int = 20

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    @Option(name: .long, help: "Expected simulator UDID (optional).")
    var udid: String?

    @Option(name: .long, help: "Request timeout in seconds.")
    var timeout: Double = 5

    mutating func run() async throws {
        let trimmed = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Selector must not be empty.")
        }
        guard limit > 0 else {
            throw ValidationError("Limit must be greater than 0.")
        }

        var parser = SelectorParser(trimmed)
        let plan: ExecutionPlan
        do {
            let parsed = try parser.parseSelector()
            plan = try SelectorCompiler().compile(parsed)
        } catch let error as SelectorParseError {
            throw ValidationError(error.description)
        } catch let error as SelectorCompileError {
            throw ValidationError(error.description)
        }

        try await validateUDID(udid, timeout: timeout)

        let request = FindRequest(plan: plan, limit: limit)
        let (data, response) = try await postJSON(path: "/find", body: request, timeout: timeout)
        guard response.statusCode == 200 else {
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ValidationError(error.error)
            }
            throw ValidationError("Find failed with HTTP \(response.statusCode).")
        }

        if json {
            FileHandle.standardOutput.write(data)
            if data.last != 0x0A {
                FileHandle.standardOutput.write(Data([0x0A]))
            }
            return
        }

        let payload = try JSONDecoder().decode(FindResponse.self, from: data)
        for (index, element) in payload.matches.enumerated() {
            print(formatFindLine(index: index, element: element))
        }
    }
}

struct FindRequest: Encodable {
    let plan: ExecutionPlan
    let limit: Int
}

struct FindResponse: Decodable {
    let matches: [FindElement]
    let truncated: Bool
}

struct FindElement: Decodable, Equatable {
    let identifier: String
    let elementType: String
    let value: JSONValue?
    let placeholderValue: String?
    let title: String
    let label: String
    let hasFocus: Bool
    let isEnabled: Bool
    let isSelected: Bool
    let frame: Frame
}

func formatFindLine(index: Int, element: FindElement) -> String {
    let node = SnapshotNode(
        identifier: element.identifier,
        elementType: element.elementType,
        value: element.value,
        placeholderValue: element.placeholderValue,
        title: element.title,
        label: element.label,
        hasFocus: element.hasFocus,
        isEnabled: element.isEnabled,
        isSelected: element.isSelected,
        frame: element.frame,
        children: []
    )
    return "#\(index) \(snapshotLine(for: node))"
}
