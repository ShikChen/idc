import ArgumentParser
import Foundation
import Subprocess

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
        abstract: "Open an app on a booted simulator by bundle ID"
    )

    @Argument(help: "App bundle identifier.")
    var bundleId: String

    @Option(name: .long, help: "Booted simulator UDID to target.")
    var udid: String?

    @Option(name: .long, help: "Wait for app to be running in seconds (0 disables).")
    var wait: Double = 5

    mutating func run() async throws {
        let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Bundle ID must not be empty.")
        }

        let device = try await resolveBootedDevice(selectedUDID: udid)
        let data = try await runCommand("xcrun", ["simctl", "launch", device.udid, trimmed])
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !output.isEmpty {
            print(output)
        }

        guard wait > 0 else { return }
        guard let pid = parseLaunchPID(output) else {
            throw ValidationError("Unable to parse launch pid from simctl output.")
        }
        try await waitForProcess(udid: device.udid, pid: pid, timeout: wait)
    }
}

private struct AppListResponse: Encodable {
    let apps: [SimctlAppInfo]
}

private func parseLaunchPID(_ output: String) -> Int? {
    let tokens = output.split { $0 == " " || $0 == "\t" || $0 == "\n" }
    guard let last = tokens.last else { return nil }
    return Int(last.trimmingCharacters(in: .whitespacesAndNewlines))
}

private func waitForProcess(udid: String, pid: Int, timeout: Double) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await isProcessRunning(udid: udid, pid: pid) {
            return
        }
        try await Task.sleep(nanoseconds: 200_000_000)
    }
    throw ValidationError("App did not launch within \(timeout)s.")
}

private func isProcessRunning(udid: String, pid: Int) async -> Bool {
    do {
        let result = try await run(
            .name("xcrun"),
            arguments: Arguments(["simctl", "spawn", udid, "ps", "-p", String(pid), "-o", "pid="]),
            output: .bytes(limit: 1024),
            error: .string(limit: 1024)
        )
        switch result.terminationStatus {
        case let .exited(code) where code == 0:
            let output = String(decoding: result.standardOutput, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return !output.isEmpty
        default:
            return false
        }
    } catch {
        return false
    }
}
