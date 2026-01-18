import Foundation
import XCTest

enum AppOpenError: LocalizedError {
    case invalidBundleId
    case invalidWait
    case timeout(Double)

    var errorDescription: String? {
        switch self {
        case .invalidBundleId:
            return "Bundle ID must not be empty."
        case .invalidWait:
            return "Wait timeout must be greater than or equal to 0."
        case let .timeout(wait):
            return "App did not reach foreground within \(wait) seconds."
        }
    }
}

struct AppOpenService {
    private static let defaultWait: TimeInterval = 5

    func open(_ request: AppOpenRequest) async throws -> AppOpenResponse {
        let bundleId = request.bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleId.isEmpty else {
            throw AppOpenError.invalidBundleId
        }

        let wait = request.wait ?? Self.defaultWait
        guard wait >= 0 else {
            throw AppOpenError.invalidWait
        }

        let didReachForeground = try await MainActor.run { () -> Bool in
            let app = XCUIApplication(bundleIdentifier: bundleId)
            app.activate()
            guard wait > 0 else { return true }
            return app.wait(for: .runningForeground, timeout: wait)
        }

        if wait > 0, !didReachForeground {
            throw AppOpenError.timeout(wait)
        }

        return AppOpenResponse(status: "ok")
    }
}
