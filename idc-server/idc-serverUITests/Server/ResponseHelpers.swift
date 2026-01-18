import FlyingFox
import Foundation

enum RequestDecodingError: LocalizedError {
    case emptyBody
    case decoding(DecodingError)

    var errorDescription: String? {
        switch self {
        case .emptyBody:
            return "Request body is empty."
        case let .decoding(error):
            return "Invalid JSON: \(error.localizedDescription)"
        }
    }
}

func jsonResponse<T: Encodable>(_ payload: T, status: HTTPStatusCode = .ok) -> HTTPResponse {
    do {
        let body = try JSONEncoder().encode(payload)
        return HTTPResponse(
            statusCode: status,
            headers: [.contentType: "application/json"],
            body: body
        )
    } catch {
        let body = (try? JSONEncoder().encode(ErrorResponse(errorCode: .internalError, error: "Failed to encode response."))) ?? Data()
        return HTTPResponse(
            statusCode: .internalServerError,
            headers: [.contentType: "application/json"],
            body: body
        )
    }
}

func jsonError(_ message: String, code: ErrorCode, status: HTTPStatusCode) -> HTTPResponse {
    jsonResponse(ErrorResponse(errorCode: code, error: message), status: status)
}

func handleJSONRequest<T: Decodable, R: Encodable>(
    _ request: HTTPRequest,
    handler: (T) async throws -> R
) async -> HTTPResponse {
    do {
        let payload: T = try await decodeJSONBody(request)
        let response = try await handler(payload)
        return jsonResponse(response)
    } catch let error as RequestDecodingError {
        return jsonError(error.localizedDescription, code: errorCode(for: error), status: .badRequest)
    } catch let error as PlanError {
        return jsonError(error.localizedDescription, code: errorCode(for: error), status: .badRequest)
    } catch {
        return jsonError(error.localizedDescription, code: .internalError, status: .internalServerError)
    }
}

private func decodeJSONBody<T: Decodable>(_ request: HTTPRequest) async throws -> T {
    let data = try await request.bodyData
    guard !data.isEmpty else {
        throw RequestDecodingError.emptyBody
    }
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch let error as DecodingError {
        throw RequestDecodingError.decoding(error)
    }
}

private func errorCode(for error: RequestDecodingError) -> ErrorCode {
    switch error {
    case .emptyBody:
        return .emptyBody
    case .decoding:
        return .invalidJSON
    }
}

private func errorCode(for error: PlanError) -> ErrorCode {
    switch error {
    case .invalidPlan, .invalidType:
        return .invalidPlan
    case .invalidPredicate:
        return .invalidPredicate
    case .noMatches:
        return .noMatches
    case .notUnique:
        return .notUnique
    }
}
