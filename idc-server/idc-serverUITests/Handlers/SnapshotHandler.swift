import FlyingFox

struct SnapshotHandler {
    let service: SnapshotService

    func handle(_: HTTPRequest) async -> HTTPResponse {
        do {
            let response = try await service.snapshot()
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
}
