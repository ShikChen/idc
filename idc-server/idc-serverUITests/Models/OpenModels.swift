import Foundation

struct AppOpenRequest: Codable {
    let bundleId: String
    let wait: Double?

    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case wait
    }
}

struct AppOpenResponse: Codable {
    let status: String
}
