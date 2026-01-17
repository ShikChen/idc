import FlyingFox
import XCTest

struct ScreenshotHandler {
    func handle(_: HTTPRequest) async -> HTTPResponse {
        let data = await MainActor.run {
            XCUIScreen.main.screenshot().pngRepresentation
        }
        return HTTPResponse(
            statusCode: .ok,
            headers: [.contentType: "image/png"],
            body: data
        )
    }
}
