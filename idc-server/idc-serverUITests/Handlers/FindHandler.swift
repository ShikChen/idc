import FlyingFox

struct FindHandler {
    let service: FindService

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        await handleJSONRequest(request) { (findRequest: FindRequest) async throws -> FindResponse in
            try await service.resolve(findRequest)
        }
    }
}
