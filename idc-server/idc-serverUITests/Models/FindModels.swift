import Foundation
import XCTest

struct FindRequest: Codable {
    let plan: ExecutionPlan?
    let limit: Int?
}

struct FindResponse: Codable {
    let matches: [FindElement]
    let truncated: Bool
}

struct FindElement: Codable {
    let identifier: String
    let elementType: String
    let value: JSONValue?
    let placeholderValue: String?
    let title: String
    let label: String
    let hasFocus: Bool
    let isEnabled: Bool
    let isSelected: Bool
    let frame: Frame

    init(from element: XCUIElement) {
        identifier = element.identifier
        elementType = elementTypeName(element.elementType)
        value = JSONValue.fromAny(element.value)
        placeholderValue = element.placeholderValue
        title = element.title
        label = element.label
        hasFocus = element.hasFocus
        isEnabled = element.isEnabled
        isSelected = element.isSelected
        frame = Frame(element.frame)
    }

    init(from snapshot: XCUIElementSnapshot) {
        identifier = snapshot.identifier
        elementType = elementTypeName(snapshot.elementType)
        value = JSONValue.fromAny(snapshot.value)
        placeholderValue = snapshot.placeholderValue
        title = snapshot.title
        label = snapshot.label
        hasFocus = snapshot.hasFocus
        isEnabled = snapshot.isEnabled
        isSelected = snapshot.isSelected
        frame = Frame(snapshot.frame)
    }
}
