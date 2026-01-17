import FlyingFox
import UIKit

struct InfoHandler {
    func handle(_: HTTPRequest) async -> HTTPResponse {
        let response = await MainActor.run {
            InfoResponse(
                name: UIDevice.current.name,
                model: UIDevice.current.model,
                os_version: UIDevice.current.systemVersion,
                is_simulator: isSimulator,
                udid: ProcessInfo.processInfo.environment["SIMULATOR_UDID"]
            )
        }
        return jsonResponse(response)
    }
}

private var isSimulator: Bool {
    #if targetEnvironment(simulator)
        return true
    #else
        return false
    #endif
}
