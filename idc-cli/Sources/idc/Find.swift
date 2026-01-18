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

    @Flag(name: .long, help: "Use live query (slower, reflects current UI state).")
    var live: Bool = false

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

        let request = FindRequest(plan: plan, limit: limit, live: live ? true : nil)
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
    let live: Bool?
}

struct FindResponse: Decodable {
    let matches: [FindElement]
    let truncated: Bool
}

typealias FindElement = ElementAttributes

func formatFindLine(index: Int, element: FindElement) -> String {
    let node = SnapshotNode(element: element, children: [])
    return "#\(index) \(snapshotLine(for: node))"
}
