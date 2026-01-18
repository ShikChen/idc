import ArgumentParser
import Foundation

struct SimDevice: Decodable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool?
}

private struct SimctlList: Decodable {
    let devices: [String: [SimDevice]]
}

func listSimulators() async throws -> [SimDevice] {
    let data = try await runCommand("xcrun", ["simctl", "list", "devices", "--json"])
    let decoded = try JSONDecoder().decode(SimctlList.self, from: data)
    return decoded.devices.values.flatMap { $0 }
}

func listBootedSimulators() async throws -> [SimDevice] {
    let data = try await runCommand("xcrun", ["simctl", "list", "devices", "booted", "--json"])
    let decoded = try JSONDecoder().decode(SimctlList.self, from: data)
    return decoded.devices.values.flatMap { $0 }
}

func findSimulator(udid: String) async throws -> SimDevice? {
    let simulators = try await listSimulators()
    let needle = udid.lowercased()
    return simulators.first(where: { $0.udid.lowercased() == needle })
}

func isPhonePadSimulator(_ simulator: SimDevice) -> Bool {
    simulator.name.hasPrefix("iPhone") || simulator.name.hasPrefix("iPad")
}

func parseSimctlListApps(_ data: Data) throws -> [InstalledApp] {
    var format = PropertyListSerialization.PropertyListFormat.openStep
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
    guard let dict = plist as? [String: Any] else {
        throw ValidationError("Unexpected simctl listapps output.")
    }

    var apps: [InstalledApp] = []
    apps.reserveCapacity(dict.count)
    for (bundleId, rawInfo) in dict {
        guard let info = rawInfo as? [String: Any] else {
            continue
        }
        let name = stringValue(info["CFBundleDisplayName"]) ?? stringValue(info["CFBundleName"])
        let version = stringValue(info["CFBundleShortVersionString"]) ?? stringValue(info["CFBundleVersion"])
        let appType = stringValue(info["ApplicationType"])
        apps.append(InstalledApp(bundleId: bundleId, name: name, version: version, type: appType))
    }
    return apps.sorted { $0.bundleId.localizedStandardCompare($1.bundleId) == .orderedAscending }
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
