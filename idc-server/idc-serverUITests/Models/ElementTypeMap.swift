import XCTest

func elementTypeName(_ type: XCUIElement.ElementType) -> String {
    if let name = elementTypeNames[type] {
        return name
    }
    return "unknown(\(type.rawValue))"
}

func elementTypeFromName(_ name: String) -> XCUIElement.ElementType? {
    return elementTypeByName[name.lowercased()]
}

private let elementTypeNames: [XCUIElement.ElementType: String] = [
    .any: "any",
    .other: "other",
    .application: "application",
    .group: "group",
    .window: "window",
    .sheet: "sheet",
    .drawer: "drawer",
    .alert: "alert",
    .dialog: "dialog",
    .button: "button",
    .radioButton: "radioButton",
    .radioGroup: "radioGroup",
    .checkBox: "checkBox",
    .disclosureTriangle: "disclosureTriangle",
    .popUpButton: "popUpButton",
    .comboBox: "comboBox",
    .menuButton: "menuButton",
    .toolbarButton: "toolbarButton",
    .popover: "popover",
    .keyboard: "keyboard",
    .key: "key",
    .navigationBar: "navigationBar",
    .tabBar: "tabBar",
    .tabGroup: "tabGroup",
    .toolbar: "toolbar",
    .statusBar: "statusBar",
    .table: "table",
    .tableRow: "tableRow",
    .tableColumn: "tableColumn",
    .outline: "outline",
    .outlineRow: "outlineRow",
    .browser: "browser",
    .collectionView: "collectionView",
    .slider: "slider",
    .pageIndicator: "pageIndicator",
    .progressIndicator: "progressIndicator",
    .activityIndicator: "activityIndicator",
    .segmentedControl: "segmentedControl",
    .picker: "picker",
    .pickerWheel: "pickerWheel",
    .switch: "switch",
    .toggle: "toggle",
    .link: "link",
    .image: "image",
    .icon: "icon",
    .searchField: "searchField",
    .scrollView: "scrollView",
    .scrollBar: "scrollBar",
    .staticText: "staticText",
    .textField: "textField",
    .secureTextField: "secureTextField",
    .datePicker: "datePicker",
    .textView: "textView",
    .menu: "menu",
    .menuItem: "menuItem",
    .menuBar: "menuBar",
    .menuBarItem: "menuBarItem",
    .map: "map",
    .webView: "webView",
    .incrementArrow: "incrementArrow",
    .decrementArrow: "decrementArrow",
    .timeline: "timeline",
    .ratingIndicator: "ratingIndicator",
    .valueIndicator: "valueIndicator",
    .splitGroup: "splitGroup",
    .splitter: "splitter",
    .relevanceIndicator: "relevanceIndicator",
    .colorWell: "colorWell",
    .helpTag: "helpTag",
    .matte: "matte",
    .dockItem: "dockItem",
    .ruler: "ruler",
    .rulerMarker: "rulerMarker",
    .grid: "grid",
    .levelIndicator: "levelIndicator",
    .cell: "cell",
    .layoutArea: "layoutArea",
    .layoutItem: "layoutItem",
    .handle: "handle",
    .stepper: "stepper",
    .tab: "tab",
    .touchBar: "touchBar",
    .statusItem: "statusItem",
]

private let elementTypeByName: [String: XCUIElement.ElementType] = {
    var mapping: [String: XCUIElement.ElementType] = [:]
    for (type, name) in elementTypeNames {
        mapping[name.lowercased()] = type
    }
    return mapping
}()
