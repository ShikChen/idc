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

        if let udid {
            let info: InfoResponse = try await fetchJSON(
                path: "/info",
                timeout: timeout
            )
            if info.udid != udid {
                let actual = info.udid ?? "nil"
                throw ValidationError("Server is running for a different simulator. Expected \(udid), got \(actual).")
            }
        }

        print("ok")
    }
}

private struct HealthResponse: Decodable {
    let status: String
}
