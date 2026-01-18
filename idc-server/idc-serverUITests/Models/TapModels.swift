import Foundation
import XCTest

struct TapRequest: Codable {
    let plan: ExecutionPlan?
    let at: TapPoint?
}

struct TapResponse: Codable {
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
        value = ElementValue.stringValue(element.value)
        placeholderValue = element.placeholderValue
        frame = Frame(element.frame)
    }
}

enum ElementValue {
    static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case let bool as Bool:
            return bool ? "true" : "false"
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        case let float as Float:
            return String(float)
        case let cgFloat as CGFloat:
            return String(Double(cgFloat))
        default:
            return value.map { String(describing: $0) }
        }
    }
}
