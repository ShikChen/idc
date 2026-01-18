import FlyingFox
import XCTest

enum SnapshotError: LocalizedError {
    case noForeground
    case snapshotFailed(String)

    var errorDescription: String? {
        switch self {
        case .noForeground:
            return "No foreground app found."
        case let .snapshotFailed(message):
            return message
        }
    }
}

struct SnapshotHandler {
    func handle(_: HTTPRequest) async -> HTTPResponse {
        do {
            let response = try await snapshot()
            return jsonResponse(response)
        } catch let error as SnapshotError {
            switch error {
            case .noForeground:
                return jsonError(error.localizedDescription, code: .noForeground, status: .conflict)
            case .snapshotFailed:
                return jsonError(error.localizedDescription, code: .snapshotFailed, status: .internalServerError)
            }
        } catch {
            return jsonError(error.localizedDescription, code: .internalError, status: .internalServerError)
        }
    }

    private func snapshot() async throws -> SnapshotResponse {
        let snapshot = try await MainActor.run {
            guard let app = RunningApp.getForegroundApp() else {
                throw SnapshotError.noForeground
            }
            do {
                return try app.snapshot()
            } catch {
                throw SnapshotError.snapshotFailed(error.localizedDescription)
            }
        }
        return SnapshotResponse(root: buildSnapshotNode(snapshot))
    }
}
