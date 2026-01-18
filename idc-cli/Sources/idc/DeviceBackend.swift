import ArgumentParser
import Foundation

enum DeviceSelection: Equatable, ExpressibleByArgument {
    case auto
    case simulatorOnly
    case deviceOnly
    case udid(String)

    init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        switch trimmed.lowercased() {
        case "auto":
            self = .auto
        case "simulator":
            self = .simulatorOnly
        case "device":
            self = .deviceOnly
        default:
            guard looksLikeUDID(trimmed) else {
                return nil
            }
            self = .udid(trimmed)
        }
    }
}

struct DeviceKindSet: OptionSet {
    let rawValue: Int

    static let simulator = DeviceKindSet(rawValue: 1 << 0)
    static let device = DeviceKindSet(rawValue: 1 << 1)
    static let all: DeviceKindSet = [.simulator, .device]
}

protocol DeviceBackend {
    func listApps() async throws -> [InstalledApp]
    func openApp(bundleId: String) async throws
}

private let defaultOpenWait: Double = 5

struct SimulatorBackend: DeviceBackend {
    let simulator: SimDevice

    func listApps() async throws -> [InstalledApp] {
        let data = try await runCommand("xcrun", ["simctl", "listapps", simulator.udid, "--json"])
        return try parseSimctlListApps(data)
    }

    func openApp(bundleId: String) async throws {
        let wait = defaultOpenWait
        let timeout = max(wait, 5)
        try await validateServer(timeout: timeout)
        try await openAppViaServer(bundleId: bundleId, wait: wait, timeout: timeout)
    }

    func validateServer(timeout: TimeInterval) async throws {
        try await validateUDID(simulator.udid, timeout: timeout)
    }
}

struct RealDeviceInfo: Equatable {
    let udid: String
    let name: String?
}

struct RealDeviceBackend: DeviceBackend {
    let device: RealDeviceInfo

    func listApps() async throws -> [InstalledApp] {
        try await listDeviceApps(deviceId: device.udid)
    }

    func openApp(bundleId: String) async throws {
        try await openDeviceApp(deviceId: device.udid, bundleId: bundleId, wait: defaultOpenWait)
    }
}

enum ResolvedDevice: DeviceBackend {
    case simulator(SimulatorBackend)
    case device(RealDeviceBackend)

    func listApps() async throws -> [InstalledApp] {
        switch self {
        case let .simulator(simulator):
            return try await simulator.listApps()
        case let .device(device):
            return try await device.listApps()
        }
    }

    func openApp(bundleId: String) async throws {
        switch self {
        case let .simulator(simulator):
            try await simulator.openApp(bundleId: bundleId)
        case let .device(device):
            try await device.openApp(bundleId: bundleId)
        }
    }

    func requireSimulator() throws -> SimulatorBackend {
        switch self {
        case let .simulator(simulator):
            return simulator
        case .device:
            throw ValidationError("This command only supports simulators.")
        }
    }
}

enum DeviceResolver {
    static func resolve(
        _ selection: DeviceSelection,
        allowedKinds: DeviceKindSet
    ) async throws -> ResolvedDevice {
        guard allowedKinds != [] else {
            throw ValidationError("No available device kinds.")
        }

        switch selection {
        case .auto:
            return try await resolveAuto(allowedKinds: allowedKinds)
        case .simulatorOnly:
            guard allowedKinds.contains(.simulator) else {
                throw ValidationError("This command only supports real devices.")
            }
            return try await resolveSimulatorOnly()
        case .deviceOnly:
            guard allowedKinds.contains(.device) else {
                throw ValidationError("This command only supports simulators.")
            }
            return try await resolveDeviceOnly()
        case let .udid(udid):
            return try await resolveUDID(udid, allowedKinds: allowedKinds)
        }
    }

    private static func resolveUDID(
        _ udid: String,
        allowedKinds: DeviceKindSet
    ) async throws -> ResolvedDevice {
        if allowedKinds.contains(.simulator),
           let simulator = try await findSimulator(udid: udid)
        {
            guard isPhonePadSimulator(simulator) else {
                throw ValidationError("Only iPhone/iPad simulators are supported.")
            }
            guard simulator.state == "Booted" else {
                throw ValidationError("Simulator not booted: \(simulator.name) (\(simulator.udid)).")
            }
            return .simulator(SimulatorBackend(simulator: simulator))
        }

        if allowedKinds.contains(.device),
           let device = try await findConnectedDevice(udid: udid)
        {
            return .device(RealDeviceBackend(device: device))
        }

        if allowedKinds == [.simulator] {
            throw ValidationError("No booted simulator matches UDID: \(udid).")
        }
        if allowedKinds == [.device] {
            throw ValidationError("No connected device matches UDID: \(udid).")
        }
        throw ValidationError("No available simulator or device matches UDID: \(udid).")
    }

    private static func resolveSimulatorOnly() async throws -> ResolvedDevice {
        let booted = try await listBootedSimulators()
            .filter(isPhonePadSimulator)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !booted.isEmpty else {
            throw ValidationError("No booted iPhone/iPad simulators found.")
        }
        if booted.count == 1, let only = booted.first {
            return .simulator(SimulatorBackend(simulator: only))
        }
        throw ValidationError("Multiple booted simulators. Use --device <udid>. Booted: \(formatSimulators(booted))")
    }

    private static func resolveDeviceOnly() async throws -> ResolvedDevice {
        let devices = try await listConnectedDevices()
        guard !devices.isEmpty else {
            throw ValidationError("No connected iPhone/iPad devices found.")
        }
        if devices.count == 1, let only = devices.first {
            return .device(RealDeviceBackend(device: only))
        }
        throw ValidationError("Multiple connected devices. Use --device <udid>. Devices: \(formatDevices(devices))")
    }

    private static func resolveAuto(allowedKinds: DeviceKindSet) async throws -> ResolvedDevice {
        var simulators: [SimDevice] = []
        var devices: [RealDeviceInfo] = []

        if allowedKinds.contains(.simulator) {
            simulators = try await listBootedSimulators()
                .filter(isPhonePadSimulator)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        if allowedKinds.contains(.device) {
            devices = try await listConnectedDevices()
        }

        let total = simulators.count + devices.count
        guard total > 0 else {
            var sources: [String] = []
            if allowedKinds.contains(.simulator) {
                sources.append("booted iPhone/iPad simulators")
            }
            if allowedKinds.contains(.device) {
                sources.append("connected iPhone/iPad devices")
            }
            let description = sources.joined(separator: " or ")
            throw ValidationError("No \(description) found.")
        }

        if total == 1 {
            if let only = simulators.first {
                return .simulator(SimulatorBackend(simulator: only))
            }
            if let only = devices.first {
                return .device(RealDeviceBackend(device: only))
            }
        }

        var message = "Multiple available targets. Use --device <udid> or --device simulator/device."
        if !simulators.isEmpty {
            message += " Simulators: \(formatSimulators(simulators))."
        }
        if !devices.isEmpty {
            message += " Devices: \(formatDevices(devices))."
        }
        throw ValidationError(message)
    }
}

private func looksLikeUDID(_ value: String) -> Bool {
    let simulatorRegex = #"^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$"#
    let deviceRegex = #"^[0-9A-Fa-f]{40}$"#
    return value.range(of: simulatorRegex, options: .regularExpression) != nil ||
        value.range(of: deviceRegex, options: .regularExpression) != nil
}

private func formatSimulators(_ simulators: [SimDevice]) -> String {
    simulators.map { "\($0.name) (\($0.udid))" }.joined(separator: ", ")
}

private func formatDevices(_ devices: [RealDeviceInfo]) -> String {
    devices.map { device in
        let label = device.name ?? device.udid
        return "\(label) (\(device.udid))"
    }.joined(separator: ", ")
}
