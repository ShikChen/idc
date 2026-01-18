import ArgumentParser
import Foundation

struct ServerHealth: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "health",
        abstract: "Check idc-server health on localhost:8080"
    )

    @Option(name: .long, help: "Device selector: auto|simulator|device|<udid>.")
    var device: DeviceSelection = .auto

    @Option(name: .long, help: "Request timeout in seconds.")
    var timeout: Double = 3

    mutating func run() async throws {
        let target = try await DeviceResolver.resolve(device, allowedKinds: [.simulator])
        let simulator = try target.requireSimulator()

        let health: HealthResponse = try await fetchJSON(
            path: "/health",
            timeout: timeout
        )

        guard health.status.lowercased() == "ok" else {
            throw ValidationError("Server unhealthy: \(health.status)")
        }

        try await simulator.validateServer(timeout: timeout)

        print("ok")
    }
}

private struct HealthResponse: Decodable {
    let status: String
}
