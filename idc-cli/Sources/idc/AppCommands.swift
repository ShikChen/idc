import ArgumentParser
import Foundation

struct App: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage apps",
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
            var details: [String] = []
            if let name = app.name, !name.isEmpty {
                details.append(name)
            }
            if let version = app.version, !version.isEmpty {
                details.append("v\(version)")
            }
            if let type = app.type, !type.isEmpty {
                details.append(type)
            }

            if details.isEmpty {
                print(app.bundleId)
            } else {
                print("\(app.bundleId) (\(details.joined(separator: ", ")))")
            }
        }
    }
}

struct AppOpen: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open an app by bundle ID via idc-server"
    )

    @Argument(help: "App bundle identifier.")
    var bundleId: String

    @Option(name: .long, help: "Expected device UDID (optional).")
    var udid: String?

    @Option(name: .long, help: "Wait for foreground confirmation in seconds (0 disables).")
    var wait: Double = 5

    mutating func run() async throws {
        let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Bundle ID must not be empty.")
        }

        let timeout = max(wait, 5)
        try await validateUDID(udid, timeout: timeout)

        let request = AppOpenRequest(bundleId: trimmed, wait: wait)
        let (data, response) = try await postJSON(path: "/app/open", body: request, timeout: timeout)
        guard response.statusCode == 200 else {
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ValidationError(error.error)
            }
            throw ValidationError("App open failed with HTTP \(response.statusCode).")
        }
    }
}

private struct AppListResponse: Encodable {
    let apps: [SimctlAppInfo]
}

private struct AppOpenRequest: Encodable {
    let bundleId: String
    let wait: Double

    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case wait
    }
}
