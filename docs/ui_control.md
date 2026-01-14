# UI Control DSL + CLI Spec

This document defines the selector DSL and CLI behavior for `idc tap`.

## Selector DSL v0.6 (Query-or-Element, CSS-like)

### 1) Grammar (EBNF)

```
selector := step (combinator step)*
combinator := " " | ">"
step := (type filter* | filter+) pick?

type := elementTypeName

filter := attrFilter | textFilter | hasFilter | isFilter | notFilter | predicateFilter
pick := indexPick | onlyPick

attrFilter := "[" attrName attrOp string caseFlag? "]"
            | "[" boolAttr ("=" bool)? "]"
            | "[!" boolAttr "]"
textFilter := "[" string caseFlag? "]"
hasFilter := ":has(" simpleStep ")"
isFilter := ":is(" simpleStep ("," simpleStep)* ")"
notFilter := ":not(" simpleStep ")"
predicateFilter := ":predicate(" string ")"

indexPick := "[" integer "]"
onlyPick := ":only"

simpleStep := type simpleFilter* | simpleFilter+
simpleFilter := attrFilter | textFilter | isFilter | notFilter | predicateFilter

caseFlag := "i" | "s"
string := '"' (char | escape)* '"'
escape := "\\" ("\"" | "\\" | "n" | "t" | "r")
```

- Space (` `) means **descendants**.
- `>` means **children**.
- `type` is **case-insensitive**.
- `type` is optional. If omitted, it implies no type constraint.

### 2) Evaluation model (Query-or-Element)

Each step produces either:

- a **query** (`XCUIElementQuery`), or
- a **single element** (`XCUIElement`) when `:only` or `[index]` is used.

Steps after a picker operate relative to that selected element.
If the final selector resolves to a query, `idc tap` uses the **first match**.

### 3) String filters

**Shorthand**

```
["text"]
["text" i]
["text" s]
```

Matches any one of: `identifier`, `title`, `label`, `value`, or `placeholderValue` (exact match).

**Attribute filters**

```
[label="..."]
[label*="..."]
[label^="..."]
[label$="..."]
[label~="regex"]

[identifier="..."]
[title="..."]
[value="..."]
[placeholderValue="..."]
[placeholder="..."]   // alias for placeholderValue
```

- Operators: `=` (exact), `*=` (contains), `^=` (begins), `$=` (ends), `~=` (regex)
- Case sensitivity: default **case-sensitive**; add `i` for case-insensitive, `s` to force case-sensitive.
- `value` is matched as a **string** (non-string values are stringified).
- All filters inside the same step are ANDed into a single predicate.

**String escaping**

- Strings use double quotes.
- Escape sequences: `\"`, `\\`, `\n`, `\t`, `\r`.

### 4) Bool filters

```
[enabled]
[enabled=false]
[!enabled]

[disabled]      // alias for !enabled
```

**Bool aliases**

- `enabled` / `isEnabled`
- `selected` / `isSelected`
- `focused` / `hasFocus`
- `disabled` is an alias for `!enabled`

### 5) Pseudo-classes

```
:has(simpleStep)         // contains descendant
:is(simpleStep, ...)     // OR
:not(simpleStep)         // NOT
:predicate("...")        // raw NSPredicate
:only                    // unique match at this step
```

**simpleStep** = one step with optional type + filters, **no combinators** and **no pickers**.
Type-only `simpleStep` is allowed (example: `:has(button)`).

Semantics:

- `:is(...)` ORs the predicates of its `simpleStep` list.
- `:not(...)` negates the predicate of its `simpleStep`.
- `:has(...)` matches elements that contain a descendant matching `simpleStep`.
- `:predicate(...)` injects raw NSPredicate into the current step.

### 6) Pickers

```
[n]                       // index (0-based, negative allowed; -1 = last)
:only                     // unique match at this step
```

`[n]` / `:only` converts a query into a single element for subsequent steps.

### 7) Root

An empty selector targets the **foreground app**.

### 8) Examples

```
button[label="OK"]
navigationBar > button[label*="Add"]
[label="Settings"]
["settings" i]
cell:has(button[label*="Download"])
button:is(button[label="A"], button[label="B"])
button:not(button[enabled])
[disabled]
cell[2] button
button:only
```

---

## XCUIElementQuery method coverage (selector equivalents)

### Creating new queries

- `children(matching: type)`
  - `parent > type`

- `descendants(matching: type)`
  - `parent type`

- `matching(identifier:)`
  - `["text"]` (exact, case-sensitive shorthand)

- `matching(type, identifier:)`
  - `type["text"]` (exact, case-sensitive shorthand)

- `matching(NSPredicate)`
  - Any attribute filter, `:is(...)`, `:not(...)`, `:predicate(...)` (not matched by the shorthand APIs)

- `containing(NSPredicate)`
  - `A:has(simpleStep)`

- `containing(type, identifier:)`
  - `A:has(type["text"])` (exact, case-sensitive shorthand)

### Accessing matched elements

- `count`
  - used by negative index

- `element(boundBy:)` / `element(at:)`
  - `[index]`

- `element` (single element)
  - `:only` or any action that requires a single element

- `element(matching: NSPredicate)`
  - `:only` with predicate-only filters

- `subscript(String)`
  - `type["text"]` or `["text"]` (exact, case-sensitive shorthand)

---

## Compilation rules (high level)

- **Steps** compile to either a query or a single element.
- **Filters** in a step are combined into a single NSPredicate (AND).
- `:is()` compiles to OR predicate over its simpleSteps.
- `:not()` compiles to NOT predicate of its simpleStep.
- `:predicate("...")` injects raw NSPredicate.
- `:has(simpleStep)` compiles to `containing(NSPredicate)`.

Whenever possible, use specialized XCUI APIs:

- `matching(identifier:)` for shorthand `["text"]` (exact, case-sensitive)
- `matching(type, identifier:)` for `type["text"]` (exact, case-sensitive)
- `containing(type, identifier:)` for `type:has(type["text"])` (exact, case-sensitive)

All other cases use `matching(NSPredicate)`.

---

## Implementation notes

- `:only` should **not** use `query.element`, because it fails the XCTest on non-unique results.
- Prefer `firstMatch.exists` + `element(boundBy: 1).exists` to enforce uniqueness without full `count`.

---

## Execution Plan (server-ready opcode)

The CLI compiles a selector into a JSON plan that maps 1:1 to XCUI method calls.
The server executes the plan without re-parsing DSL semantics.

### Shape

```json
{
  "version": 3,
  "pipeline": [
    { "op": "descendants", "type": "any" },
    { "op": "matchIdentifier", "value": "Settings" },
    {
      "op": "matchPredicate",
      "format": "label == %@",
      "args": [{ "kind": "string", "value": "OK" }]
    },
    { "op": "children", "type": "button" },
    { "op": "pickIndex", "value": -1 }
  ]
}
```

### Ops

- `descendants` / `children`
  - Input: Element or Query
  - Output: Query

- `matchIdentifier`
  - `matching(identifier:)`

- `matchTypeIdentifier`
  - `matching(type, identifier:)`

- `matchPredicate`
  - `matching(NSPredicate(format:argumentArray:))`
  - `format` uses `%@` placeholders, `args` is ordered to match them
  - `args.kind: elementType` is resolved on the server to the enum raw value
  - `:predicate("...")` compiles to `format` with empty `args`

- `containPredicate`
  - `containing(NSPredicate(format:argumentArray:))`

- `containTypeIdentifier`
  - `containing(type, identifier:)`

- `pickIndex`
  - `element(boundBy:)` (negative index uses `count` first)

- `pickOnly`
  - preferred: `firstMatch.exists` + `element(boundBy: 1).exists`

---

## CLI Spec: `idc tap`

### Syntax

```
idc tap <selector?> [--at <point>] [--udid <udid>] [--timeout <seconds>]
```

- `<selector?>` is optional. If omitted, `--at` is required.
- `--at` format: `x,y` or `x%,y%`
  - When **selector is present**, `--at` is **element-local**.
  - When **selector is absent**, `--at` is **screen coordinates**.

### Examples

```
idc tap 'button[label="OK"]'
idc tap 'button[label="OK"]' --at 50%,50%
idc tap 'cell:has(button[label*="Add"])' --at 10,12
idc tap --at 100,200
```

### Notes

- `:only` enforces uniqueness.
- `[n]` selects by index (0-based; negative allowed, `-1` = last).
- `value` is matched as a **string** (non-string values are stringified).
- In XCUI APIs, parameters named `identifier` also match any of these identifying properties (not just `identifier`).
