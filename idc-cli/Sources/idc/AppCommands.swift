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
        abstract: "List installed apps on a device or booted simulator"
    )

    @Option(name: .long, help: "Device UDID (real device or booted simulator).")
    var udid: String?

    @Flag(name: .long, help: "Output JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let apps: [SimctlAppInfo]
        if let udid {
            if let simulator = try await findSimulator(udid: udid) {
                guard simulator.state == "Booted" else {
                    throw ValidationError("Simulator not booted: \(simulator.name) (\(simulator.udid)).")
                }
                let data = try await runCommand("xcrun", ["simctl", "listapps", simulator.udid, "--json"])
                apps = try parseSimctlListApps(data)
            } else {
                apps = try await listDeviceApps(deviceId: udid)
            }
        } else {
            let simulator = try await resolveBootedDevice(selectedUDID: nil)
            let data = try await runCommand("xcrun", ["simctl", "listapps", simulator.udid, "--json"])
            apps = try parseSimctlListApps(data)
        }

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

    @Option(name: .long, help: "Device UDID (real device or booted simulator).")
    var udid: String?

    @Option(name: .long, help: "Wait for foreground confirmation in seconds (0 disables).")
    var wait: Double = 5

    mutating func run() async throws {
        let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Bundle ID must not be empty.")
        }
        guard wait >= 0 else {
            throw ValidationError("Wait must be greater than or equal to 0.")
        }

        let timeout = max(wait, 5)

        if let udid {
            if let simulator = try await findSimulator(udid: udid) {
                guard simulator.state == "Booted" else {
                    throw ValidationError("Simulator not booted: \(simulator.name) (\(simulator.udid)).")
                }
                try await validateUDID(udid, timeout: timeout)
                try await openViaServer(bundleId: trimmed, wait: wait, timeout: timeout)
            } else {
                try await openDeviceApp(deviceId: udid, bundleId: trimmed, wait: wait)
            }
            return
        }

        try await openViaServer(bundleId: trimmed, wait: wait, timeout: timeout)
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

private func openViaServer(bundleId: String, wait: Double, timeout: TimeInterval) async throws {
    let request = AppOpenRequest(bundleId: bundleId, wait: wait)
    let (data, response) = try await postJSON(path: "/app/open", body: request, timeout: timeout)
    guard response.statusCode == 200 else {
        if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw ValidationError(error.error)
        }
        throw ValidationError("App open failed with HTTP \(response.statusCode).")
    }
}
