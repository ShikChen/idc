import FlyingFox
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

struct AppOpenHandler {
    private static let defaultWait: TimeInterval = 5

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        do {
            let payload = try await decodeRequest(request)
            let response = try await open(payload)
            return jsonResponse(response)
        } catch let error as RequestDecodingError {
            switch error {
            case .emptyBody:
                return jsonError(error.localizedDescription, code: .emptyBody, status: .badRequest)
            case .decoding:
                return jsonError(error.localizedDescription, code: .invalidJSON, status: .badRequest)
            }
        } catch let error as AppOpenError {
            switch error {
            case .invalidBundleId, .invalidWait:
                return jsonError(error.localizedDescription, code: .invalidPlan, status: .badRequest)
            case .timeout:
                return jsonError(error.localizedDescription, code: .noForeground, status: .conflict)
            }
        } catch {
            return jsonError(error.localizedDescription, code: .internalError, status: .internalServerError)
        }
    }

    private func open(_ request: AppOpenRequest) async throws -> AppOpenResponse {
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

private func decodeRequest(_ request: HTTPRequest) async throws -> AppOpenRequest {
    let data = try await request.bodyData
    guard !data.isEmpty else {
        throw RequestDecodingError.emptyBody
    }
    do {
        return try JSONDecoder().decode(AppOpenRequest.self, from: data)
    } catch let error as DecodingError {
        throw RequestDecodingError.decoding(error)
    }
}
