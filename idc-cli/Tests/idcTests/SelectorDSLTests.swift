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

    func testShorthandCaseSensitive() throws {
        let program = try compile(#"["Settings"]"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchIdentifier("Settings")
        ))
    }

    func testShorthandCaseInsensitive() throws {
        let program = try compile(#"["settings" i]"#)
        let predicate = "((identifier ==[c] \"settings\") OR (title ==[c] \"settings\") OR (label ==[c] \"settings\") OR (value ==[c] \"settings\") OR (placeholderValue ==[c] \"settings\"))"
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchPredicate(predicate)
        ))
    }

    func testAttrOperators() throws {
        let program = try compile(#"[label="OK"][label*="Add"][label^="Beg"][label$="End"][label~="^re.*" i]"#)
        let predicate = "(label == \"OK\") AND (label CONTAINS \"Add\") AND (label BEGINSWITH \"Beg\") AND (label ENDSWITH \"End\") AND (label MATCHES \"(?i)^re.*\")"
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchPredicate(predicate)
        ))
    }

    func testValueAndPlaceholderAlias() throws {
        let program = try compile(#"[value="123"][placeholder="hint"]"#)
        let predicate = "(value == \"123\") AND (placeholderValue == \"hint\")"
        XCTAssertEqual(program, plan(
            .descendants(type: "any"),
            .matchPredicate(predicate)
        ))
    }

    func testBoolFilters() throws {
        let enabled = try compile("[enabled]")
        XCTAssertEqual(enabled, plan(
            .descendants(type: "any"),
            .matchPredicate("(enabled == 1)")
        ))

        let disabled = try compile("[disabled]")
        XCTAssertEqual(disabled, plan(
            .descendants(type: "any"),
            .matchPredicate("(enabled == 0)")
        ))

        let enabledFalse = try compile("[enabled=false]")
        XCTAssertEqual(enabledFalse, plan(
            .descendants(type: "any"),
            .matchPredicate("(enabled == 0)")
        ))

        let notEnabled = try compile("[!enabled]")
        XCTAssertEqual(notEnabled, plan(
            .descendants(type: "any"),
            .matchPredicate("(enabled == 0)")
        ))

        let focused = try compile("[hasFocus]")
        XCTAssertEqual(focused, plan(
            .descendants(type: "any"),
            .matchPredicate("(hasFocus == 1)")
        ))
    }

    func testHasTypeOnly() throws {
        let program = try compile("cell:has(button)")
        XCTAssertEqual(program, plan(
            .descendants(type: "cell"),
            .containPredicate("(elementType == 9)")
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
        let predicate = "(elementType == 9) AND (label == \"OK\")"
        XCTAssertEqual(program, plan(
            .descendants(type: "cell"),
            .containPredicate(predicate)
        ))
    }

    func testIsAndNot() throws {
        let program = try compile(#"button:is(button[label="A"], button[label="B"])"#)
        let predicate = "(((elementType == 9) AND (label == \"A\")) OR ((elementType == 9) AND (label == \"B\")))"
        XCTAssertEqual(program, plan(
            .descendants(type: "button"),
            .matchPredicate(predicate)
        ))

        let notProgram = try compile("button:not([enabled])")
        XCTAssertEqual(notProgram, plan(
            .descendants(type: "button"),
            .matchPredicate("(NOT ((enabled == 1)))")
        ))
    }

    func testPredicateFilter() throws {
        let program = try compile(#"button:predicate("label BEGINSWITH 'OK'")"#)
        XCTAssertEqual(program, plan(
            .descendants(type: "button"),
            .matchPredicate("(label BEGINSWITH 'OK')")
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
            .matchPredicate("(label == \"A\\\"B\")")
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
