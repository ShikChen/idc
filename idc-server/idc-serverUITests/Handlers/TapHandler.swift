import FlyingFox

struct TapHandler {
    let service: TapService

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        await handleJSONRequest(request) { (tapRequest: TapRequest) async throws -> TapResponse in
            try await service.resolve(tapRequest)
        }
    }
}
