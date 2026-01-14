// MARK: - Compiler

struct SelectorCompiler {
    func compile(_ selector: SelectorAST) throws -> ExecutionPlan {
        guard !selector.steps.isEmpty else {
            return ExecutionPlan(pipeline: [])
        }

        var pipeline: [ExecutionOp] = []

        for step in selector.steps {
            let axisOp = axisOperation(step: step)
            pipeline.append(axisOp)

            var filters = step.filters

            if let typeName = step.type,
               filters.count == 1,
               case let .shorthand(value, caseFlag) = filters[0],
               caseFlag == .s
            {
                pipeline.removeLast()
                pipeline.append(axisOperation(step: step, overrideType: "any"))
                pipeline.append(.matchTypeIdentifier(type: typeName, value: value))
                filters.removeAll()
            }

            var predicateParts: [String] = []

            for filter in filters {
                switch filter {
                case let .shorthand(value, caseFlag):
                    if caseFlag == .s {
                        pipeline.append(.matchIdentifier(value))
                    } else {
                        predicateParts.append(predicateForShorthand(value, caseFlag: caseFlag))
                    }
                case let .attrString(field, match, value, caseFlag):
                    predicateParts.append(predicateForString(field: field, match: match, value: value, caseFlag: caseFlag))
                case let .attrBool(field, value):
                    predicateParts.append(predicateForBool(field: field, value: value))
                case let .predicate(value):
                    predicateParts.append(value)
                case let .isMatch(steps):
                    try predicateParts.append(predicateForIs(steps))
                case let .not(step):
                    try predicateParts.append(predicateForNot(step))
                case let .has(step):
                    try pipeline.append(compileHas(step))
                }
            }

            if !predicateParts.isEmpty {
                let combined = predicateParts
                    .map { "(\($0))" }
                    .joined(separator: " AND ")
                pipeline.append(.matchPredicate(combined))
            }

            if let pick = step.pick {
                switch pick {
                case let .index(value):
                    pipeline.append(.pickIndex(value))
                case .only:
                    pipeline.append(.pickOnly)
                }
            }
        }

        return ExecutionPlan(pipeline: pipeline)
    }

    private func axisOperation(step: SelectorStep, overrideType: String? = nil) -> ExecutionOp {
        let typeValue = overrideType ?? step.type ?? "any"
        switch step.axis {
        case .descendant:
            return .descendants(type: typeValue)
        case .child:
            return .children(type: typeValue)
        }
    }

    private func compileHas(_ step: SimpleStep) throws -> ExecutionOp {
        if let typeName = step.type,
           step.filters.count == 1,
           case let .shorthand(value, caseFlag) = step.filters[0],
           caseFlag == .s
        {
            return .containTypeIdentifier(type: typeName, value: value)
        }
        let predicate = try predicateForSimpleStep(step)
        return .containPredicate(predicate)
    }

    private func predicateForIs(_ steps: [SimpleStep]) throws -> String {
        let parts = try steps.map { try predicateForSimpleStep($0) }
        return parts.map { "(\($0))" }.joined(separator: " OR ")
    }

    private func predicateForNot(_ step: SimpleStep) throws -> String {
        let predicate = try predicateForSimpleStep(step)
        return "NOT (\(predicate))"
    }

    private func predicateForSimpleStep(_ step: SimpleStep) throws -> String {
        var parts: [String] = []
        if let typeName = step.type {
            guard let raw = elementTypeRawValue(typeName) else {
                throw SelectorCompileError.invalidType(typeName)
            }
            parts.append("elementType == \(raw)")
        }

        for filter in step.filters {
            switch filter {
            case let .shorthand(value, caseFlag):
                parts.append(predicateForShorthand(value, caseFlag: caseFlag))
            case let .attrString(field, match, value, caseFlag):
                parts.append(predicateForString(field: field, match: match, value: value, caseFlag: caseFlag))
            case let .attrBool(field, value):
                parts.append(predicateForBool(field: field, value: value))
            case let .predicate(value):
                parts.append(value)
            case let .isMatch(steps):
                try parts.append(predicateForIs(steps))
            case let .not(step):
                try parts.append(predicateForNot(step))
            case .has:
                throw SelectorCompileError.invalidSelector(":has is not allowed inside simpleStep")
            }
        }

        guard !parts.isEmpty else {
            throw SelectorCompileError.invalidSelector("simpleStep must have type or filters")
        }

        return parts.map { "(\($0))" }.joined(separator: " AND ")
    }

    private func predicateForString(field: StringField, match: StringMatch, value: String, caseFlag: CaseFlag) -> String {
        let modifier = caseFlag == .i ? "[c]" : ""
        let literal = predicateStringLiteral(value)
        return "\(field.rawValue) \(match.rawValue)\(modifier) \(literal)"
    }

    private func predicateForBool(field: BoolField, value: Bool) -> String {
        "\(field.rawValue) == \(value)"
    }

    private func predicateForShorthand(_ value: String, caseFlag: CaseFlag) -> String {
        let modifier = caseFlag == .i ? "[c]" : ""
        let literal = predicateStringLiteral(value)
        let fields = ["identifier", "title", "label", "value", "placeholderValue"]
        let parts = fields.map { "\($0) ==\(modifier) \(literal)" }
        return parts.map { "(\($0))" }.joined(separator: " OR ")
    }

    private func predicateStringLiteral(_ value: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(value.count)
        for char in value {
            switch char {
            case "\\": escaped.append("\\\\")
            case "\"": escaped.append("\\\"")
            case "\n": escaped.append("\\n")
            case "\r": escaped.append("\\r")
            case "\t": escaped.append("\\t")
            default: escaped.append(char)
            }
        }
        return "\"\(escaped)\""
    }

    private func elementTypeRawValue(_ name: String) -> Int? {
        return elementTypeRawValues[name.lowercased()]
    }
}

private let elementTypeRawValues: [String: Int] = {
    // Order matches XCUIElement.ElementType raw values.
    let names = [
        "any", "other", "application", "group", "window", "sheet", "drawer",
        "alert", "dialog", "button", "radiobutton", "radiogroup", "checkbox",
        "disclosuretriangle", "popupbutton", "combobox", "menubutton",
        "toolbarbutton", "popover", "keyboard", "key", "navigationbar",
        "tabbar", "tabgroup", "toolbar", "statusbar", "table", "tablerow",
        "tablecolumn", "outline", "outlinerow", "browser", "collectionview",
        "slider", "pageindicator", "progressindicator", "activityindicator",
        "segmentedcontrol", "picker", "pickerwheel", "switch", "toggle",
        "link", "image", "icon", "searchfield", "scrollview", "scrollbar",
        "statictext", "textfield", "securetextfield", "datepicker", "textview",
        "menu", "menuitem", "menubar", "menubaritem", "map", "webview",
        "incrementarrow", "decrementarrow", "timeline", "ratingindicator",
        "valueindicator", "splitgroup", "splitter", "relevanceindicator",
        "colorwell", "helptag", "matte", "dockitem", "ruler", "rulermarker",
        "grid", "levelindicator", "cell", "layoutarea", "layoutitem", "handle",
        "stepper", "tab", "touchbar", "statusitem",
    ]
    return Dictionary(uniqueKeysWithValues: names.enumerated().map { ($0.element, $0.offset) })
}()
