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

            var predicateParts: [PredicateFormat] = []

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
                    predicateParts.append(PredicateFormat(format: value, args: []))
                case let .isMatch(steps):
                    try predicateParts.append(predicateForIs(steps))
                case let .not(step):
                    try predicateParts.append(predicateForNot(step))
                case let .has(step):
                    try pipeline.append(compileHas(step))
                }
            }

            if !predicateParts.isEmpty {
                let combined = and(predicateParts)
                pipeline.append(.matchPredicate(format: combined.format, args: combined.args))
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
        return .containPredicate(format: predicate.format, args: predicate.args)
    }

    private func predicateForIs(_ steps: [SimpleStep]) throws -> PredicateFormat {
        let parts = try steps.map { try predicateForSimpleStep($0) }
        return or(parts)
    }

    private func predicateForNot(_ step: SimpleStep) throws -> PredicateFormat {
        let predicate = try predicateForSimpleStep(step)
        return PredicateFormat(format: "NOT (\(predicate.format))", args: predicate.args)
    }

    private func predicateForSimpleStep(_ step: SimpleStep) throws -> PredicateFormat {
        var parts: [PredicateFormat] = []
        if let typeName = step.type {
            guard elementTypeNames.contains(typeName.lowercased()) else {
                throw SelectorCompileError.invalidType(typeName)
            }
            parts.append(PredicateFormat(format: "elementType == %@", args: [.elementType(typeName)]))
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
                parts.append(PredicateFormat(format: value, args: []))
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

        return and(parts)
    }

    private func predicateForString(field: StringField, match: StringMatch, value: String, caseFlag: CaseFlag) -> PredicateFormat {
        let modifier = caseFlag == .i ? "[c]" : ""
        let format = "\(field.rawValue) \(match.rawValue)\(modifier) %@"
        return PredicateFormat(format: format, args: [.string(value)])
    }

    private func predicateForBool(field: BoolField, value: Bool) -> PredicateFormat {
        PredicateFormat(format: "\(field.rawValue) == %@", args: [.bool(value)])
    }

    private func predicateForShorthand(_ value: String, caseFlag: CaseFlag) -> PredicateFormat {
        let modifier = caseFlag == .i ? "[c]" : ""
        let fields = ["identifier", "title", "label", "value", "placeholderValue"]
        let format = fields.map { "(\($0) ==\(modifier) %@)" }.joined(separator: " OR ")
        let args = Array(repeating: PredicateArg.string(value), count: fields.count)
        return PredicateFormat(format: format, args: args)
    }

    private func and(_ parts: [PredicateFormat]) -> PredicateFormat {
        PredicateFormat(
            format: parts.map { "(\($0.format))" }.joined(separator: " AND "),
            args: parts.flatMap(\.args)
        )
    }

    private func or(_ parts: [PredicateFormat]) -> PredicateFormat {
        PredicateFormat(
            format: parts.map { "(\($0.format))" }.joined(separator: " OR "),
            args: parts.flatMap(\.args)
        )
    }
}

private struct PredicateFormat: Equatable {
    let format: String
    let args: [PredicateArg]
}

private let elementTypeNames: Set<String> = [
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
