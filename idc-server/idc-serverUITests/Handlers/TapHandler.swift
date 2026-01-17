import FlyingFox

struct TapHandler {
    let service: TapService

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        do {
            let tapRequest = try JSONDecoder().decode(TapRequest.self, from: await request.bodyData)
            let response = try await service.resolve(tapRequest)
            return jsonResponse(response)
        } catch let error as PlanError {
            return jsonError(error.localizedDescription, status: .badRequest)
        } catch {
            return jsonError(error.localizedDescription, status: .internalServerError)
        }
    }
}
