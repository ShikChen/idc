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

enum ErrorCode: String, Codable {
    case emptyBody = "empty_body"
    case invalidJSON = "invalid_json"
    case invalidPlan = "invalid_plan"
    case invalidPredicate = "invalid_predicate"
    case noMatches = "no_matches"
    case notUnique = "not_unique"
    case noForeground = "no_foreground"
    case snapshotFailed = "snapshot_failed"
    case internalError = "internal_error"
}

struct ErrorResponse: Codable {
    let errorCode: ErrorCode
    let error: String

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case error
    }
}
