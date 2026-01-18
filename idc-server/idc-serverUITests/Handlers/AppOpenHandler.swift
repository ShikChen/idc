import FlyingFox

struct AppOpenHandler {
    let service: AppOpenService

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        do {
            let payload = try await decodeRequest(request)
            let response = try await service.open(payload)
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
