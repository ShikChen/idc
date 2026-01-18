import Foundation

struct Frame: Decodable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct ElementAttributes: Decodable, Equatable {
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
}
