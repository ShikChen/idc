// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation

@main
struct Idc: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "idc",
        abstract: "iOS Device Control CLI",
        subcommands: [Server.self]
    )
}

struct Server: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage idc-server",
        subcommands: [Start.self]
    )
}

struct Start: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start idc-server on a booted simulator (keep-alive test)"
    )

    @Option(name: .long, help: "Booted simulator UDID to target.")
    var udid: String?

    mutating func run() throws {
        let projectURL = try locateServerProject()
        let device = try resolveBootedDevice(selectedUDID: udid)

        let destination = "platform=iOS Simulator,id=\(device.udid)"
        let args = [
            "test",
            "-project", projectURL.path,
            "-scheme", "idc-server",
            "-destination", destination,
            "-only-testing:idc-serverUITests/ServerKeepAliveTests/testServerKeepAlive"
        ]

        try runStreamingProcess("/usr/bin/xcodebuild", args)
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

private func resolveBootedDevice(selectedUDID: String?) throws -> SimDevice {
    let data = try runProcess("/usr/bin/xcrun", ["simctl", "list", "devices", "booted", "--json"])
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

private func runProcess(_ launchPath: String, _ arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
    let errData = stderr.fileHandleForReading.readDataToEndOfFile()

    if process.terminationStatus != 0 {
        let message = String(data: errData, encoding: .utf8) ?? "Unknown error"
        throw ValidationError("Command failed: \(message)")
    }

    return outData
}

private func runStreamingProcess(_ launchPath: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        throw ValidationError("xcodebuild failed with exit code \(process.terminationStatus).")
    }
}
