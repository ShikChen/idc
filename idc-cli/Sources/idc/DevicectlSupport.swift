import ArgumentParser
import Foundation

private struct DevicectlAppsResponse: Decodable {
    let info: DevicectlInfo?
    let result: DevicectlAppsResult?
    let error: DevicectlError?
}

private struct DevicectlOutcomeResponse: Decodable {
    let info: DevicectlInfo?
    let error: DevicectlError?
}

private struct DevicectlInfo: Decodable {
    let outcome: String?
}

private struct DevicectlAppsResult: Decodable {
    let apps: [DevicectlApp]?
}

private struct DevicectlApp: Decodable {
    let appClip: Bool?
    let bundleIdentifier: String?
    let bundleID: String?
    let bundleVersion: String?
    let builtByDeveloper: Bool?
    let defaultApp: Bool?
    let internalApp: Bool?
    let name: String?
    let removable: Bool?
    let version: String?

    enum CodingKeys: String, CodingKey {
        case appClip
        case bundleIdentifier
        case bundleID
        case bundleVersion
        case builtByDeveloper
        case defaultApp
        case internalApp
        case name
        case removable
        case version
    }
}

private struct DevicectlError: Decodable {
    let userInfo: DevicectlUserInfo?
}

private struct DevicectlUserInfo: Decodable {
    let localizedDescription: DevicectlLocalizedDescription?

    enum CodingKeys: String, CodingKey {
        case localizedDescription = "NSLocalizedDescription"
    }
}

private struct DevicectlLocalizedDescription: Decodable {
    let string: String?
}

func listDeviceApps(deviceId: String) async throws -> [SimctlAppInfo] {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "devicectl-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let outputURL = tempDir.appendingPathComponent("apps.json")
    _ = try await runCommand(
        "xcrun",
        [
            "devicectl",
            "device",
            "info",
            "apps",
            "--device",
            deviceId,
            "--include-all-apps",
            "--json-output",
            outputURL.path,
        ]
    )

    guard let data = try? Data(contentsOf: outputURL) else {
        throw ValidationError("Unable to read devicectl JSON output.")
    }

    let response = try JSONDecoder().decode(DevicectlAppsResponse.self, from: data)
    if response.info?.outcome == "failed" {
        if let message = response.error?.userInfo?.localizedDescription?.string, !message.isEmpty {
            throw ValidationError(message)
        }
        throw ValidationError("devicectl reported a failure.")
    }

    guard let apps = response.result?.apps else {
        throw ValidationError("Unexpected devicectl app list output.")
    }

    let mapped = apps.compactMap { app -> SimctlAppInfo? in
        guard let bundleId = app.bundleIdentifier ?? app.bundleID else {
            return nil
        }
        let version = app.version ?? app.bundleVersion
        let type = mapDevicectlAppType(app)
        return SimctlAppInfo(bundleId: bundleId, name: app.name, version: version, type: type)
    }

    return mapped.sorted { $0.bundleId.localizedStandardCompare($1.bundleId) == .orderedAscending }
}

func openDeviceApp(deviceId: String, bundleId: String, wait: Double) async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "devicectl-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let outputURL = tempDir.appendingPathComponent("launch.json")
    var arguments = ["devicectl", "--json-output", outputURL.path]
    if wait > 0 {
        let timeoutSeconds = max(5, Int(ceil(wait)))
        arguments.append(contentsOf: ["--timeout", String(timeoutSeconds)])
    }
    arguments.append(contentsOf: [
        "device",
        "process",
        "launch",
        "--device",
        deviceId,
        bundleId,
        "--activate",
    ])

    _ = try await runCommand("xcrun", arguments)

    guard let data = try? Data(contentsOf: outputURL) else {
        throw ValidationError("Unable to read devicectl JSON output.")
    }

    let response = try JSONDecoder().decode(DevicectlOutcomeResponse.self, from: data)
    if response.info?.outcome == "failed" {
        if let message = response.error?.userInfo?.localizedDescription?.string, !message.isEmpty {
            throw ValidationError(message)
        }
        throw ValidationError("devicectl reported a failure.")
    }
}

private func mapDevicectlAppType(_ app: DevicectlApp) -> String? {
    if app.appClip == true {
        return "App Clip"
    }
    if app.defaultApp == true {
        return "Default"
    }
    if app.internalApp == true {
        return "Internal"
    }
    if app.builtByDeveloper == true {
        return "Developer"
    }
    if app.removable == false {
        return "System"
    }
    return nil
}
