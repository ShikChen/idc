import FlyingFox
import Foundation

func jsonResponse<T: Encodable>(_ payload: T, status: HTTPStatusCode = .ok) -> HTTPResponse {
    do {
        let body = try JSONEncoder().encode(payload)
        return HTTPResponse(
            statusCode: status,
            headers: [.contentType: "application/json"],
            body: body
        )
    } catch {
        let body = (try? JSONEncoder().encode(ErrorResponse(error: "Failed to encode response."))) ?? Data()
        return HTTPResponse(
            statusCode: .internalServerError,
            headers: [.contentType: "application/json"],
            body: body
        )
    }
}

func jsonError(_ message: String, status: HTTPStatusCode) -> HTTPResponse {
    jsonResponse(ErrorResponse(error: message), status: status)
}
