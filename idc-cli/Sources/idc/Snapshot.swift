import ArgumentParser
import Foundation

struct Snapshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Snapshot current UI hierarchy from idc-server"
    )

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    @Option(name: .long, help: "Device selector: auto|sim|real|<udid>.")
    var device: DeviceSelection = .auto

    @Option(name: .long, help: "Request timeout in seconds.")
    var timeout: Double = 5

    mutating func run() async throws {
        let target = try await DeviceResolver.resolve(device, allowedKinds: [.simulator])
        let simulator = try target.requireSimulator()
        try await simulator.validateServer(timeout: timeout)

        let data: Data
        do {
            data = try await fetchData(path: "/snapshot", timeout: timeout)
        } catch {
            throw serverUnreachableError(error)
        }

        if json {
            writeJSON(data)
            return
        }

        let payload = try JSONDecoder().decode(SnapshotResponse.self, from: data)
        if let simplified = simplifySnapshotTree(payload.root) {
            renderSnapshotTree(simplified, depth: 0)
        }
    }
}
