import XCTest
@testable import idc

final class SelectorDSLTests: XCTestCase {
    private func parse(_ input: String) throws -> SelectorProgram {
        var parser = SelectorParser(input)
        return try parser.parseSelector()
    }

    func testTypeAndAttr() throws {
        let program = try parse(#"button[label="OK"]"#)
        XCTAssertEqual(program.steps.count, 1)
        XCTAssertEqual(program.steps[0].axis, .descendantOrSelf)
        XCTAssertEqual(program.steps[0].ops, [
            .type("button"),
            .attrString(field: .label, match: .eq, value: "OK", caseFlag: .s)
        ])
    }

    func testCaseInsensitiveAttr() throws {
        let program = try parse(#"button[label="ok" i]"#)
        XCTAssertEqual(program.steps[0].ops, [
            .type("button"),
            .attrString(field: .label, match: .eq, value: "ok", caseFlag: .i)
        ])
    }

    func testSubscript() throws {
        let program = try parse(#"["Settings"]"#)
        XCTAssertEqual(program.steps[0].ops, [
            .subscriptValue("Settings", .s)
        ])
    }

    func testSubscriptCaseFlags() throws {
        let insensitive = try parse(#"["settings" i]"#)
        XCTAssertEqual(insensitive.steps[0].ops, [
            .subscriptValue("settings", .i)
        ])
        let sensitive = try parse(#"["Settings" s]"#)
        XCTAssertEqual(sensitive.steps[0].ops, [
            .subscriptValue("Settings", .s)
        ])
    }

    func testDisabledAlias() throws {
        let program = try parse("[disabled]")
        XCTAssertEqual(program.steps[0].ops, [
            .attrBool(field: .isEnabled, value: false)
        ])
    }

    func testBoolAliasesAndNegation() throws {
        let enabled = try parse("[isEnabled]")
        XCTAssertEqual(enabled.steps[0].ops, [
            .attrBool(field: .isEnabled, value: true)
        ])
        let selected = try parse("[isSelected]")
        XCTAssertEqual(selected.steps[0].ops, [
            .attrBool(field: .isSelected, value: true)
        ])
        let focused = try parse("[hasFocus]")
        XCTAssertEqual(focused.steps[0].ops, [
            .attrBool(field: .hasFocus, value: true)
        ])
        let focusedAlias = try parse("[focused]")
        XCTAssertEqual(focusedAlias.steps[0].ops, [
            .attrBool(field: .hasFocus, value: true)
        ])
        let notEnabled = try parse("[!enabled]")
        XCTAssertEqual(notEnabled.steps[0].ops, [
            .attrBool(field: .isEnabled, value: false)
        ])
        let notFocused = try parse("[!focused]")
        XCTAssertEqual(notFocused.steps[0].ops, [
            .attrBool(field: .hasFocus, value: false)
        ])
        let negated = try parse("[!selected]")
        XCTAssertEqual(negated.steps[0].ops, [
            .attrBool(field: .isSelected, value: false)
        ])
    }

    func testNegativeIndex() throws {
        let program = try parse("cell[-2]")
        XCTAssertEqual(program.steps[0].ops, [
            .type("cell"),
            .index(-2)
        ])
    }

    func testStringFieldsAndMatches() throws {
        let program = try parse(#"[identifier="id"][identifier^="id"][title="Title"][title$="End"][value="foo"][value~="^foo.*"][placeholder="hint"][placeholder*="hin"][placeholder~="^hi"][placeholderValue="hint2"]"#)
        XCTAssertEqual(program.steps[0].ops, [
            .attrString(field: .identifier, match: .eq, value: "id", caseFlag: .s),
            .attrString(field: .identifier, match: .begins, value: "id", caseFlag: .s),
            .attrString(field: .title, match: .eq, value: "Title", caseFlag: .s),
            .attrString(field: .title, match: .ends, value: "End", caseFlag: .s),
            .attrString(field: .value, match: .eq, value: "foo", caseFlag: .s),
            .attrString(field: .value, match: .regex, value: "^foo.*", caseFlag: .s),
            .attrString(field: .placeholderValue, match: .eq, value: "hint", caseFlag: .s),
            .attrString(field: .placeholderValue, match: .contains, value: "hin", caseFlag: .s),
            .attrString(field: .placeholderValue, match: .regex, value: "^hi", caseFlag: .s),
            .attrString(field: .placeholderValue, match: .eq, value: "hint2", caseFlag: .s),
        ])
    }

    func testCaseInsensitiveAttrFlag() throws {
        let program = try parse(#"[label="Ok" i]"#)
        XCTAssertEqual(program.steps[0].ops, [
            .attrString(field: .label, match: .eq, value: "Ok", caseFlag: .i)
        ])
        let explicit = try parse(#"[label="Ok" s]"#)
        XCTAssertEqual(explicit.steps[0].ops, [
            .attrString(field: .label, match: .eq, value: "Ok", caseFlag: .s)
        ])
    }

    func testRegexCaseFlag() throws {
        let program = try parse(#"[label~="^add.*" i]"#)
        XCTAssertEqual(program.steps[0].ops, [
            .attrString(field: .label, match: .regex, value: "^add.*", caseFlag: .i)
        ])
    }

    func testFrameMixedUnits() throws {
        let program = try parse("[frame*=(100,20%)]")
        XCTAssertEqual(program.steps[0].ops, [
            .frame(
                match: .contains,
                point: PointSpec(
                    x: PointComponent(value: 100, unit: .pt),
                    y: PointComponent(value: 20, unit: .pct)
                )
            )
        ])
    }

    func testFrameUnits() throws {
        let points = try parse("[frame*=(10,20)]")
        XCTAssertEqual(points.steps[0].ops, [
            .frame(
                match: .contains,
                point: PointSpec(
                    x: PointComponent(value: 10, unit: .pt),
                    y: PointComponent(value: 20, unit: .pt)
                )
            )
        ])
        let percent = try parse("[frame*=(70%,40%)]")
        XCTAssertEqual(percent.steps[0].ops, [
            .frame(
                match: .contains,
                point: PointSpec(
                    x: PointComponent(value: 70, unit: .pct),
                    y: PointComponent(value: 40, unit: .pct)
                )
            )
        ])
    }

    func testCombinators() throws {
        let program = try parse(#"navigationBar > button[label*="Add"]"#)
        XCTAssertEqual(program.steps.count, 2)
        XCTAssertEqual(program.steps[0].axis, .descendantOrSelf)
        XCTAssertEqual(program.steps[1].axis, .child)
        XCTAssertEqual(program.steps[0].ops, [
            .type("navigationbar")
        ])
        XCTAssertEqual(program.steps[1].ops, [
            .type("button"),
            .attrString(field: .label, match: .contains, value: "Add", caseFlag: .s)
        ])
    }

    func testDescendantCombinator() throws {
        let program = try parse("toolbar button")
        XCTAssertEqual(program.steps.count, 2)
        XCTAssertEqual(program.steps[0].axis, .descendantOrSelf)
        XCTAssertEqual(program.steps[1].axis, .descendant)
        XCTAssertEqual(program.steps[0].ops, [
            .type("toolbar")
        ])
        XCTAssertEqual(program.steps[1].ops, [
            .type("button")
        ])
    }

    func testHas() throws {
        let program = try parse(#"cell:has(button[label="OK"])"#)
        XCTAssertEqual(program.steps.count, 1)
        let nested = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .type("button"),
                .attrString(field: .label, match: .eq, value: "OK", caseFlag: .s)
            ])
        ])
        XCTAssertEqual(program.steps[0].ops, [
            .type("cell"),
            .has(nested)
        ])
    }

    func testHasWithCombinator() throws {
        let program = try parse(#"cell:has(> button[label="OK"])"#)
        let nested = SelectorProgram(steps: [
            SelectorStep(axis: .child, ops: [
                .type("button"),
                .attrString(field: .label, match: .eq, value: "OK", caseFlag: .s)
            ])
        ])
        XCTAssertEqual(program.steps[0].ops, [
            .type("cell"),
            .has(nested)
        ])
    }

    func testIs() throws {
        let program = try parse(#"button:is([label="A"],[label="B"])"#)
        XCTAssertEqual(program.steps.count, 1)
        let first = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .label, match: .eq, value: "A", caseFlag: .s)
            ])
        ])
        let second = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrString(field: .label, match: .eq, value: "B", caseFlag: .s)
            ])
        ])
        XCTAssertEqual(program.steps[0].ops, [
            .type("button"),
            .isMatch([first, second])
        ])
    }

    func testIsWithCombinator() throws {
        let program = try parse("cell:is(> button, > switch)")
        let first = SelectorProgram(steps: [
            SelectorStep(axis: .child, ops: [
                .type("button")
            ])
        ])
        let second = SelectorProgram(steps: [
            SelectorStep(axis: .child, ops: [
                .type("switch")
            ])
        ])
        XCTAssertEqual(program.steps[0].ops, [
            .type("cell"),
            .isMatch([first, second])
        ])
    }

    func testNot() throws {
        let program = try parse(#"button:not([enabled])"#)
        let nested = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .attrBool(field: .isEnabled, value: true)
            ])
        ])
        XCTAssertEqual(program.steps[0].ops, [
            .type("button"),
            .not(nested)
        ])
    }

    func testOnlyOrdering() throws {
        let program = try parse("cell:only[0]")
        XCTAssertEqual(program.steps[0].ops, [
            .type("cell"),
            .only,
            .index(0)
        ])
    }

    func testOnlyInsideHas() throws {
        let program = try parse("cell:has(button:only)")
        let nested = SelectorProgram(steps: [
            SelectorStep(axis: .descendantOrSelf, ops: [
                .type("button"),
                .only
            ])
        ])
        XCTAssertEqual(program.steps[0].ops, [
            .type("cell"),
            .has(nested)
        ])
    }
}
