import Foundation

struct TapRequest: Codable {
    let plan: ExecutionPlan?
    let at: TapPoint?
}

struct TapResponse: Codable {
    let selected: TapElement?
}

typealias TapElement = ElementAttributes

enum TapPointSpace: String, Codable {
    case element
    case screen
}

struct TapPoint: Codable {
    let space: TapPointSpace
    let point: PointSpec
}

enum PointUnit: String, Codable {
    case pt
    case pct
}

struct PointComponent: Codable {
    let value: Double
    let unit: PointUnit
}

struct PointSpec: Codable {
    let x: PointComponent
    let y: PointComponent
}
