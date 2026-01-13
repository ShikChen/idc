import Foundation
import XCTest

struct TapRequest: Codable {
    let plan: ExecutionPlan?
    let at: TapPoint?
}

struct TapResponse: Codable {
    let matched: Int
    let selected: TapElement?
}

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

struct TapElement: Codable {
    let elementType: String
    let identifier: String
    let label: String
    let title: String
    let value: String?
    let placeholderValue: String?
    let frame: Frame

    init(from element: XCUIElement) {
        elementType = elementTypeName(element.elementType)
        identifier = element.identifier
        label = element.label
        title = element.title
        value = TapElement.stringValue(element.value)
        placeholderValue = element.placeholderValue
        frame = Frame(element.frame)
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }
}
