import ArgumentParser
import Foundation

struct Snapshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Snapshot current UI hierarchy from idc-server"
    )

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    @Option(name: .long, help: "Expected simulator UDID (optional).")
    var udid: String?

    @Option(name: .long, help: "Request timeout in seconds.")
    var timeout: Double = 5

    mutating func run() async throws {
        let data: Data
        do {
            data = try await fetchData(path: "/snapshot", timeout: timeout)
        } catch {
            throw serverUnreachableError(error)
        }

        try await validateUDID(udid, timeout: timeout)

        if json {
            FileHandle.standardOutput.write(data)
            if data.last != 0x0A {
                FileHandle.standardOutput.write(Data([0x0A]))
            }
            return
        }

        let payload = try JSONDecoder().decode(SnapshotResponse.self, from: data)
        if let simplified = simplifySnapshotTree(payload.root) {
            renderSnapshotTree(simplified, depth: 0)
        }
    }
}
