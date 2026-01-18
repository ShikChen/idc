import ArgumentParser
import Foundation
import Subprocess

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
