// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation
import Subprocess

@main
struct Idc: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "idc",
        abstract: "iOS Device Control CLI",
        subcommands: [Server.self, Screenshot.self]
    )
}

struct Server: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage idc-server",
        subcommands: [Start.self, Health.self]
    )
}

struct Start: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start idc-server on a booted simulator (keep-alive test)"
    )

    @Option(name: .long, help: "Booted simulator UDID to target.")
    var udid: String?

    mutating func run() async throws {
        let projectURL = try locateServerProject()
        let device = try await resolveBootedDevice(selectedUDID: udid)

        let destination = "platform=iOS Simulator,id=\(device.udid)"
        let args = [
            "test",
            "-project", projectURL.path,
            "-scheme", "idc-server",
            "-destination", destination,
            "-only-testing:idc-serverUITests/ServerKeepAliveTests/testServerKeepAlive"
        ]

        try await runStreamingCommand("xcodebuild", args)
    }
}

struct Health: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
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

struct Screenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture a screenshot from idc-server"
    )

    @Option(name: [.customShort("o"), .long], help: "Output path. Use '-' for stdout.")
    var output: String?

    @Option(name: .long, help: "Request timeout in seconds.")
    var timeout: Double = 5

    mutating func run() async throws {
        // TODO: Use simctl screenshot when targeting a simulator.
        let data: Data
        do {
            data = try await fetchData(path: "/screenshot", timeout: timeout)
        } catch {
            throw ValidationError("Unable to reach idc-server. Run `idc server start`. (\(error.localizedDescription))")
        }

        if output == "-" {
            FileHandle.standardOutput.write(data)
            return
        }

        let path = output ?? defaultScreenshotPath()
        let url = URL(fileURLWithPath: path)
        try data.write(to: url)
        print(path)
    }
}

private struct SimctlList: Decodable {
    let devices: [String: [SimDevice]]
}

private struct SimDevice: Decodable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool?
}

private func resolveBootedDevice(selectedUDID: String?) async throws -> SimDevice {
    let data = try await runCommand("xcrun", ["simctl", "list", "devices", "booted", "--json"])
    let decoded = try JSONDecoder().decode(SimctlList.self, from: data)
    let devices = decoded.devices.values.flatMap { $0 }

    if devices.isEmpty {
        throw ValidationError("No booted simulators found. Boot a simulator or specify --udid.")
    }

    if let selectedUDID {
        if let match = devices.first(where: { $0.udid == selectedUDID }) {
            return match
        }
        let available = devices.map { "\($0.name) (\($0.udid))" }.joined(separator: ", ")
        throw ValidationError("UDID not booted: \(selectedUDID). Booted: \(available)")
    }

    if devices.count == 1, let only = devices.first {
        return only
    }

    let available = devices.map { "\($0.name) (\($0.udid))" }.joined(separator: ", ")
    throw ValidationError("Multiple booted simulators. Specify --udid. Booted: \(available)")
}

private func locateServerProject() throws -> URL {
    let fm = FileManager.default
    var current = URL(fileURLWithPath: fm.currentDirectoryPath)

    for _ in 0..<6 {
        let candidate = current.appendingPathComponent("idc-server/idc-server.xcodeproj")
        if fm.fileExists(atPath: candidate.path) {
            return candidate
        }
        if current.path == "/" { break }
        current.deleteLastPathComponent()
    }

    throw ValidationError("Unable to locate idc-server.xcodeproj. Run from repo root or idc-cli.")
}

private func runCommand(_ command: String, _ arguments: [String]) async throws -> Data {
    let result = try await run(
        .name(command),
        arguments: Arguments(arguments),
        output: .bytes(limit: 2 * 1024 * 1024),
        error: .string(limit: 32 * 1024)
    )

    switch result.terminationStatus {
    case .exited(let code) where code == 0:
        return Data(result.standardOutput)
    case .exited(let code):
        let stderr = result.standardError ?? ""
        throw ValidationError("Command failed (\(command)) exit code \(code): \(stderr)")
    case .unhandledException(let code):
        let stderr = result.standardError ?? ""
        throw ValidationError("Command failed (\(command)) unhandled exception \(code): \(stderr)")
    }
}

private func runStreamingCommand(_ command: String, _ arguments: [String]) async throws {
    let result = try await run(
        .name(command),
        arguments: Arguments(arguments),
        output: .fileDescriptor(.standardOutput, closeAfterSpawningProcess: false),
        error: .fileDescriptor(.standardError, closeAfterSpawningProcess: false)
    )

    switch result.terminationStatus {
    case .exited(let code) where code == 0:
        return
    case .exited(let code):
        throw ValidationError("\(command) failed with exit code \(code).")
    case .unhandledException(let code):
        throw ValidationError("\(command) failed with unhandled exception \(code).")
    }
}

private struct HealthResponse: Decodable {
    let status: String
}

private struct InfoResponse: Decodable {
    let udid: String?
}

private func fetchJSON<T: Decodable>(path: String, timeout: TimeInterval) async throws -> T {
    do {
        let data = try await fetchData(path: path, timeout: timeout)
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        throw ValidationError("Unable to reach idc-server. Run `idc server start`. (\(error.localizedDescription))")
    }
}

private func fetchData(path: String, timeout: TimeInterval) async throws -> Data {
    let url = URL(string: "http://127.0.0.1:8080\(path)")!
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout

    return try await withCheckedThrowingContinuation { continuation in
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            guard let data else {
                continuation.resume(throwing: URLError(.badServerResponse))
                return
            }
            continuation.resume(returning: data)
        }
        task.resume()
    }
}

private func defaultScreenshotPath() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return "screenshot-\(formatter.string(from: Date())).png"
}
