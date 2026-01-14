@testable import idc
import XCTest

final class SelectorDSLTests: XCTestCase {
    private func parse(_ input: String) throws -> SelectorAST {
        var parser = SelectorParser(input)
        return try parser.parseSelector()
    }

    private func compile(_ input: String) throws -> ExecutionPlan {
        let selector = try parse(input)
        return try SelectorCompiler().compile(selector)
    }

    private func plan(_ ops: ExecutionOp...) -> ExecutionPlan {
        ExecutionPlan(pipeline: ops)
    }

    private func arg(_ value: String) -> PredicateArg {
        .string(value)
    }

    private func arg(_ value: Bool) -> PredicateArg {
        .bool(value)
    }

    private func arg(_ value: Double) -> PredicateArg {
        .number(value)
    }

    private func typeArg(_ value: String) -> PredicateArg {
        .elementType(value)
    }

    func testEmptySelector() throws {
        let program = try compile("")
        XCTAssertEqual(program, plan())
    }

    func testTypeOnly() throws {
        let program = try compile("button")
        XCTAssertEqual(program, plan(.descendants(type: "button")))
    }

    func testCombinators() throws {
        let program = try compile("toolbar > button")
        XCTAssertEqual(program, plan(
            .descendants(type: "toolbar"),
            .children(type: "button")
        ))
    }

    func testDescendantCombinator() throws {
        let program = try compile("toolbar button")
        XCTAssertEqual(program, plan(
            .descendants(type: "toolbar"),
            .descendants(type: "button")
        ))
    }

    func testDescendantWithoutType() throws {
        let program = try compile(#"toolbar ["OK"]"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "toolbar"),
            .descendants(type: "any"),
            .matchIdentifier("OK")
        ))
    }

    func testShorthandCaseSensitive() throws {
        let program = try compile(#"["Settings"]"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchIdentifier("Settings")
        ))
    }

    func testShorthandCaseInsensitive() throws {
        let program = try compile(#"["settings" i]"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchPredicate(
                format: "((identifier ==[c] %@) OR (title ==[c] %@) OR (label ==[c] %@) OR (value ==[c] %@) OR (placeholderValue ==[c] %@))",
                args: [
                    arg("settings"), arg("settings"), arg("settings"), arg("settings"), arg("settings"),
                ]
            )
        ))
    }

    func testAttrOperators() throws {
        let program = try compile(#"[label="OK"][label*="Add"][label^="Beg"][label$="End"][label~="^re.*" i]"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchPredicate(
                format: "(label == %@) AND (label CONTAINS %@) AND (label BEGINSWITH %@) AND (label ENDSWITH %@) AND (label MATCHES[c] %@)",
                args: [
                    arg("OK"), arg("Add"), arg("Beg"), arg("End"), arg("^re.*"),
                ]
            )
        ))
    }

    func testValueAndPlaceholderAlias() throws {
        let program = try compile(#"[value="123"][placeholder="hint"]"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchPredicate(
                format: "(value == %@) AND (placeholderValue == %@)",
                args: [arg("123"), arg("hint")]
            )
        ))
    }

    func testBoolFilters() throws {
        let enabled = try compile("[enabled]")
        XCTAssertEqual(enabled, plan(
            .descendants(type: "any"),
            .matchPredicate(format: "(isEnabled == %@)", args: [arg(true)])
        ))

        let disabled = try compile("[disabled]")
        XCTAssertEqual(disabled, plan(
            .descendants(type: "any"),
            .matchPredicate(format: "(isEnabled == %@)", args: [arg(false)])
        ))

        let enabledFalse = try compile("[enabled=false]")
        XCTAssertEqual(enabledFalse, plan(
            .descendants(type: "any"),
            .matchPredicate(format: "(isEnabled == %@)", args: [arg(false)])
        ))

        let notEnabled = try compile("[!enabled]")
        XCTAssertEqual(notEnabled, plan(
            .descendants(type: "any"),
            .matchPredicate(format: "(isEnabled == %@)", args: [arg(false)])
        ))

        let focused = try compile("[hasFocus]")
        XCTAssertEqual(focused, plan(
            .descendants(type: "any"),
            .matchPredicate(format: "(hasFocus == %@)", args: [arg(true)])
        ))

        let selected = try compile("[selected]")
        XCTAssertEqual(selected, plan(
            .descendants(type: "any"),
            .matchPredicate(format: "(isSelected == %@)", args: [arg(true)])
        ))
    }

    func testHasTypeOnly() throws {
        let program = try compile("cell:has(button)")
        XCTAssertEqual(program, plan(
            .descendants(type: "cell"),
            .containPredicate(format: "(elementType == %@)", args: [typeArg("button")])
        ))
    }

    func testHasTypeAndShorthand() throws {
        let program = try compile(#"cell:has(button["OK"])"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "cell"),
            .containTypeIdentifier(type: "button", value: "OK")
        ))
    }

    func testHasTypeAndFilter() throws {
        let program = try compile(#"cell:has(button[label="OK"])"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "cell"),
            .containPredicate(
                format: "(elementType == %@) AND (label == %@)",
                args: [typeArg("button"), arg("OK")]
            )
        ))
    }

    func testIsAndNot() throws {
        let program = try compile(#"button:is(button[label="A"], button[label="B"])"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "button"),
            .matchPredicate(
                format: "(((elementType == %@) AND (label == %@)) OR ((elementType == %@) AND (label == %@)))",
                args: [typeArg("button"), arg("A"), typeArg("button"), arg("B")]
            )
        ))

        let notProgram = try compile("button:not([enabled])")
        XCTAssertEqual(notProgram, plan(
            .descendants(type: "button"),
            .matchPredicate(format: "(NOT ((isEnabled == %@)))", args: [arg(true)])
        ))
    }

    func testPredicateFilter() throws {
        let program = try compile(#"button:predicate("label BEGINSWITH 'OK'")"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "button"),
            .matchPredicate(format: "(label BEGINSWITH 'OK')", args: [])
        ))
    }

    func testPickersInMiddle() throws {
        let program = try compile("cell:only button")
        XCTAssertEqual(program, plan(
            .descendants(type: "cell"),
            .pickOnly,
            .descendants(type: "button")
        ))

        let indexed = try compile("cell[2] button")
        XCTAssertEqual(indexed, plan(
            .descendants(type: "cell"),
            .pickIndex(2),
            .descendants(type: "button")
        ))
    }

    func testStringEscapes() throws {
        let program = try compile(#"[label="A\"B"]"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchPredicate(format: "(label == %@)", args: [arg("A\"B")])
        ))
    }

    func testErrors() {
        XCTAssertThrowsError(try parse("> button"))
        XCTAssertThrowsError(try parse("button >"))
        XCTAssertThrowsError(try parse("[0]"))
        XCTAssertThrowsError(try parse(":only"))
        XCTAssertThrowsError(try parse("cell:only[0]"))
        XCTAssertThrowsError(try parse("cell:has(button > label)"))
        XCTAssertThrowsError(try parse("button:is(button > label)"))
        XCTAssertThrowsError(try parse(#"["text" x]"#))
    }
}
