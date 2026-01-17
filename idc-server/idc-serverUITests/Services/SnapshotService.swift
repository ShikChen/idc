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

struct SnapshotService {
    func snapshot() async throws -> SnapshotResponse {
        return try await MainActor.run {
            guard let app = RunningApp.getForegroundApp() else {
                throw SnapshotError.noForeground
            }
            do {
                let snapshot = try app.snapshot()
                return SnapshotResponse(root: buildSnapshotNode(snapshot))
            } catch {
                throw SnapshotError.snapshotFailed(error.localizedDescription)
            }
        }
    }
}
