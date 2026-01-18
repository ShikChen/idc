import Foundation

struct FindRequest: Codable {
    let plan: ExecutionPlan?
    let limit: Int?
    let live: Bool?
}

struct FindResponse: Codable {
    let matches: [FindElement]
    let truncated: Bool
}

typealias FindElement = ElementAttributes
