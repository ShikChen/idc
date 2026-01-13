import ArgumentParser
import Foundation

struct ServerHealth: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "health",
        abstract: "Check idc-server health on localhost:8080"
    )

    @Option(name: .long, help: "Expected simulator UDID (optional).")
    var udid: String?

    @Option(name: .long, help: "Request timeout in seconds.")
    var timeout: Double = 3

    mutating func run() async throws {
        let health: HealthResponse = try await fetchJSON(
            path: "/health",
            timeout: timeout
        )

        guard health.status.lowercased() == "ok" else {
            throw ValidationError("Server unhealthy: \(health.status)")
        }

        try await validateUDID(udid, timeout: timeout)

        print("ok")
    }
}

private struct HealthResponse: Decodable {
    let status: String
}
