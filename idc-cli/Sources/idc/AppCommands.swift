import ArgumentParser
import Foundation

struct App: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage apps on the simulator",
        subcommands: [AppList.self, AppOpen.self]
    )
}

struct AppList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List installed apps on a booted simulator"
    )

    @Option(name: .long, help: "Booted simulator UDID to target.")
    var udid: String?

    @Flag(name: .long, help: "Output JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let device = try await resolveBootedDevice(selectedUDID: udid)
        let data = try await runCommand("xcrun", ["simctl", "listapps", device.udid, "--json"])
        let apps = try parseSimctlListApps(data)

        if json {
            let payload = AppListResponse(apps: apps)
            let output = try JSONEncoder().encode(payload)
            FileHandle.standardOutput.write(output)
            if output.last != 0x0A {
                FileHandle.standardOutput.write(Data([0x0A]))
            }
            return
        }

        for app in apps {
            if let name = app.name, !name.isEmpty {
                print("\(app.bundleId) (\(name))")
            } else {
                print(app.bundleId)
            }
        }
    }
}

struct AppOpen: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open an app on a booted simulator by bundle ID"
    )

    @Argument(help: "App bundle identifier.")
    var bundleId: String

    @Option(name: .long, help: "Booted simulator UDID to target.")
    var udid: String?

    mutating func run() async throws {
        let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Bundle ID must not be empty.")
        }

        let device = try await resolveBootedDevice(selectedUDID: udid)
        let data = try await runCommand("xcrun", ["simctl", "launch", device.udid, trimmed])
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !output.isEmpty
        {
            print(output)
        }
    }
}

private struct AppListResponse: Encodable {
    let apps: [SimctlAppInfo]
}
