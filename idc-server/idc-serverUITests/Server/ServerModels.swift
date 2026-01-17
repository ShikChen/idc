import Foundation

struct HealthResponse: Codable {
    let status: String
}

struct InfoResponse: Codable {
    let name: String
    let model: String
    let os_version: String
    let is_simulator: Bool
    let udid: String?
}

struct ErrorResponse: Codable {
    let error: String
}
