import FlyingFox

struct FindHandler {
    let service: FindService

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        do {
            let findRequest = try JSONDecoder().decode(FindRequest.self, from: await request.bodyData)
            let response = try await service.resolve(findRequest)
            return jsonResponse(response)
        } catch let error as PlanError {
            return jsonError(error.localizedDescription, status: .badRequest)
        } catch {
            return jsonError(error.localizedDescription, status: .internalServerError)
        }
    }
}
