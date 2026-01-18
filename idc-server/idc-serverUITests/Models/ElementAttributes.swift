import CoreGraphics
import Foundation
import XCTest

struct Frame: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }
}

struct ElementAttributes: Codable, Equatable {
    let elementType: String
    let identifier: String
    let label: String
    let title: String
    let value: String?
    let placeholderValue: String?
    let hasFocus: Bool
    let isEnabled: Bool
    let isSelected: Bool
    let frame: Frame

    init(from element: XCUIElement) {
        elementType = elementTypeName(element.elementType)
        identifier = element.identifier
        label = element.label
        title = element.title
        value = ElementValue.stringValue(element.value)
        placeholderValue = element.placeholderValue
        hasFocus = element.hasFocus
        isEnabled = element.isEnabled
        isSelected = element.isSelected
        frame = Frame(element.frame)
    }

    init(from snapshot: XCUIElementSnapshot) {
        elementType = elementTypeName(snapshot.elementType)
        identifier = snapshot.identifier
        label = snapshot.label
        title = snapshot.title
        value = ElementValue.stringValue(snapshot.value)
        placeholderValue = snapshot.placeholderValue
        hasFocus = snapshot.hasFocus
        isEnabled = snapshot.isEnabled
        isSelected = snapshot.isSelected
        frame = Frame(snapshot.frame)
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
