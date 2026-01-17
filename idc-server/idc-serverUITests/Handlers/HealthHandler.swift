import FlyingFox

struct HealthHandler {
    func handle(_: HTTPRequest) async -> HTTPResponse {
        jsonResponse(HealthResponse(status: "ok"))
    }
}
