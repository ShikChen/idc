import ArgumentParser
import Foundation

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
            throw serverUnreachableError(error)
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

private func defaultScreenshotPath() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return "screenshot-\(formatter.string(from: Date())).png"
}
