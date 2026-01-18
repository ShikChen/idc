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

    @Option(name: .long, help: "Device selector: auto|simulator|device|<udid>.")
    var device: DeviceSelection = .auto

    @Flag(name: .long, help: "Output JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let target = try await DeviceResolver.resolve(device, allowedKinds: .all)
        let apps = try await target.listApps()

        if json {
            try writeJSON(AppListResponse(apps: apps))
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
        abstract: "Open an app by bundle ID"
    )

    @Argument(help: "App bundle identifier.")
    var bundleId: String

    @Option(name: .long, help: "Device selector: auto|simulator|device|<udid>.")
    var device: DeviceSelection = .auto

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

        let target = try await DeviceResolver.resolve(device, allowedKinds: .all)
        try await target.openApp(bundleId: trimmed, wait: wait)
    }
}

private struct AppListResponse: Encodable {
    let apps: [InstalledApp]
}
