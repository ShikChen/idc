import ArgumentParser
import Dispatch
import Foundation
import Subprocess

struct ServerStart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
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
            "-testPlan", "idc-server-keep-alive",
            "-destination", destination,
            "-only-testing:idc-serverUITests/ServerKeepAliveTests/testServerKeepAlive",
        ]

        try await runStreamingCommand("xcodebuild", args)
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

    for _ in 0 ..< 6 {
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
    case let .exited(code) where code == 0:
        return Data(result.standardOutput)
    case let .exited(code):
        let stderr = result.standardError ?? ""
        throw ValidationError("Command failed (\(command)) exit code \(code): \(stderr)")
    case let .unhandledException(code):
        let stderr = result.standardError ?? ""
        throw ValidationError("Command failed (\(command)) unhandled exception \(code): \(stderr)")
    }
}

private func runStreamingCommand(_ command: String, _ arguments: [String]) async throws {
    let shutdown = ShutdownController()
    let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    signal(SIGINT, SIG_IGN)
    interruptSource.setEventHandler {
        Task { await shutdown.requestStop() }
    }
    interruptSource.resume()
    defer {
        interruptSource.cancel()
        signal(SIGINT, SIG_DFL)
    }

    var options = PlatformOptions()
    options.processGroupID = 0
    let result = try await run(
        .name(command),
        arguments: Arguments(arguments),
        platformOptions: options,
        output: .fileDescriptor(.standardOutput, closeAfterSpawningProcess: false),
        error: .fileDescriptor(.standardError, closeAfterSpawningProcess: false)
    ) { execution in
        await shutdown.set(execution)
    }

    if await shutdown.didRequestStop {
        return
    }

    switch result.terminationStatus {
    case let .exited(code) where code == 0:
        return
    case let .exited(code):
        throw ValidationError("\(command) failed with exit code \(code).")
    case let .unhandledException(code):
        throw ValidationError("\(command) failed with unhandled exception \(code).")
    }
}

private actor ShutdownController {
    private var execution: Execution?
    private var stopRequested = false
    private var stopTask: Task<Void, Never>?
    private var killScheduled = false

    func set(_ execution: Execution) {
        self.execution = execution
        if stopRequested {
            startStopTask(execution)
        }
    }

    func requestStop() {
        guard let execution else {
            stopRequested = true
            return
        }
        if stopRequested {
            sendSignals(execution)
            return
        }
        stopRequested = true
        startStopTask(execution)
    }

    var didRequestStop: Bool {
        stopRequested
    }

    private func startStopTask(_ execution: Execution) {
        guard stopTask == nil else { return }
        stopTask = Task {
            if await sendStopRequest() {
                return
            }
            sendSignals(execution)
        }
    }

    private func sendStopRequest() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:8080/stop") else {
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200 ..< 300).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func sendSignals(_ execution: Execution) {
        try? execution.send(signal: .terminate, toProcessGroup: true)
        guard !killScheduled else { return }
        killScheduled = true
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            try? execution.send(signal: .kill, toProcessGroup: true)
        }
    }
}
