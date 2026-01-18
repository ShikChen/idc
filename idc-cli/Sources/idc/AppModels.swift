import Foundation

struct InstalledApp: Codable, Equatable {
    let bundleId: String
    let name: String?
    let version: String?
    let type: String?
}

struct AppOpenRequest: Encodable {
    let bundleId: String
    let wait: Double?

    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case wait
    }
}
