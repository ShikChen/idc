import ArgumentParser
import Foundation
import Subprocess

struct SimDevice: Decodable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool?
}

struct SimctlAppInfo: Codable, Equatable {
    let bundleId: String
    let name: String?
    let version: String?
    let type: String?
}

private struct SimctlList: Decodable {
    let devices: [String: [SimDevice]]
}

func findSimulator(udid: String) async throws -> SimDevice? {
    let data = try await runCommand("xcrun", ["simctl", "list", "devices", "--json"])
    let decoded = try JSONDecoder().decode(SimctlList.self, from: data)
    return decoded.devices.values.flatMap { $0 }.first(where: { $0.udid == udid })
}

func resolveBootedDevice(selectedUDID: String?) async throws -> SimDevice {
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

func parseSimctlListApps(_ data: Data) throws -> [SimctlAppInfo] {
    var format = PropertyListSerialization.PropertyListFormat.openStep
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
    guard let dict = plist as? [String: Any] else {
        throw ValidationError("Unexpected simctl listapps output.")
    }

    var apps: [SimctlAppInfo] = []
    apps.reserveCapacity(dict.count)
    for (bundleId, rawInfo) in dict {
        guard let info = rawInfo as? [String: Any] else {
            continue
        }
        let name = stringValue(info["CFBundleDisplayName"]) ?? stringValue(info["CFBundleName"])
        let version = stringValue(info["CFBundleShortVersionString"]) ?? stringValue(info["CFBundleVersion"])
        let appType = stringValue(info["ApplicationType"])
        apps.append(SimctlAppInfo(bundleId: bundleId, name: name, version: version, type: appType))
    }
    return apps.sorted { $0.bundleId.localizedStandardCompare($1.bundleId) == .orderedAscending }
}

func runCommand(_ command: String, _ arguments: [String]) async throws -> Data {
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

private func stringValue(_ value: Any?) -> String? {
    switch value {
    case let string as String:
        return string
    case let number as NSNumber:
        return number.stringValue
    default:
        return nil
    }
}
