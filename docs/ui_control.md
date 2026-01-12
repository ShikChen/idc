# UI Control DSL + CLI Spec (Draft)

This document defines the selector DSL and CLI behavior for `idc tap`.

## Selector DSL v0.5 (CSS-like)

### 1) Grammar

```
selector := step (combinator step)*
combinator := " " | ">"
step := [type] filter* pseudo*
pseudo := ":has(...)" | ":is(...)" | ":not(...)" | ":only"
type := elementTypeName
```

- Space (` `) means **descendants**.
- `>` means **children**.
- `type` is **case-insensitive**.
- `type` is optional. If omitted, it implies no type constraint.

### 2) Filters (AND, inside `[...]`)

```
["text"]                  // shorthand (case-sensitive)
["text" i]                // shorthand (case-insensitive)
["text" s]                // explicit case-sensitive
[label="..."]             // exact
[label*="..."]            // contains
[label^="..."]            // begins with
[label$="..."]            // ends with
[label~="regex"]          // regex (MATCHES)
[label="..." i]           // case-insensitive
[label="..." s]           // explicit case-sensitive

[identifier="..."]
[title="..."]

[value="..."]             // value is string-only matching
[value*="..."]
[value~="regex"]

[placeholder="..."]
[placeholder*="..."]
[placeholder~="regex"]

[enabled] / [!enabled]
[selected] / [!selected]
[focused] / [!focused]

[n]                       // index (0-based, negative allowed; -1 = last)
```

**Shorthand `["text"]`**  
Matches any one of: `identifier`, `title`, `label`, `value`, or `placeholderValue` (exact match).

**Case sensitivity**  
String filters are **case-sensitive by default**. Use `i` to enable case-insensitive matching and `s` to force case-sensitive.

**Bool aliases**  
- `enabled` / `isEnabled`
- `selected` / `isSelected`
- `focused` / `hasFocus`
- `disabled` is an alias for `!enabled`

### 3) Pseudo-classes

```
:has(selector)            // contains descendant
:is(selector, selector)   // OR
:not(selector)            // NOT
:only                    // unique match at this step
```

`:is()` and `:not()` follow CSS-like semantics: the selector is evaluated relative to the **current element** and may include combinators.
`:only` applies at the point it appears and can be used inside `:has()` / `:is()` / `:not()`.

### 4) Frame filter

```
[frame*=(x,y)]            // frame contains point (screen points)
[frame*=(70%,40%)]        // screen-normalized
[frame*=(100,20%)]        // mixed units
```

- `*=` means "contains".
- `%` uses screen-normalized coordinates (0–100%).
- `frame` is **post-filtered** after query resolution.
- An epsilon (0.5pt) is applied to avoid boundary rounding issues.

### 5) Uniqueness

- `:only` requires a unique match at its position (otherwise 409).
- For actions that require a single element, the default is **first match**.

### 6) Examples

```
button[label="OK"]
navigationBar > button[label*="Add"]
[label="Settings"]
["settings" i]
cell:has(button[label*="Download"])
cell[frame*=(50%,50%)]
button[label~="^Add .*"]
button:is([label="A"], [label="B"])
button:not([enabled])
[disabled]
```

---

## Opcode Spec (compiled form)

The CLI compiles a selector into a JSON opcode program. The server interprets it.

### Shape

```json
{
  "version": 1,
  "steps": [
    {
      "axis": "descendantOrSelf" | "descendant" | "child",
      "ops": [ /* Op[] in-order */ ]
    }
  ]
}
```

- First step uses `descendantOrSelf` so the root can match.
- Space combinator uses `descendant`.
- `>` uses `child`.

### Ops

#### 1) type

```json
{ "op": "type", "value": "button" }
```

```swift
query = query.matching(type)
```

#### 2) subscript (shorthand)

```json
{ "op": "subscript", "value": "Settings", "case": "s" }
```

```swift
let modifier = caseFlag == .i ? "[c]" : ""
let format = "identifier ==\(modifier) %@ OR title ==\(modifier) %@ OR label ==\(modifier) %@ OR value ==\(modifier) %@ OR placeholderValue ==\(modifier) %@"
let p = NSPredicate(format: format, text, text, text, text, text)
query = query.matching(p)
```

#### 3) attrString

```json
{ "op": "attrString", "field": "label", "match": "contains", "value": "Add", "case": "i" }
```

```swift
let modifier = caseFlag == .i ? "[c]" : ""
let format: String
switch match {
case .eq:       format = "%K ==\(modifier) %@"
case .contains: format = "%K CONTAINS\(modifier) %@"
case .begins:   format = "%K BEGINSWITH\(modifier) %@"
case .ends:     format = "%K ENDSWITH\(modifier) %@"
case .regex:    format = "%K MATCHES %@"
}
let rhs = (match == .regex && caseFlag == .i) ? "(?i)" + value : value
p = NSPredicate(format: format, field, rhs)
query = query.matching(p)
```

#### 4) attrBool

```json
{ "op": "attrBool", "field": "isEnabled", "value": true }
```

```swift
let p = NSPredicate(format: "%K == %@", field, NSNumber(value: value))
query = query.matching(p)
```

#### 5) index

```json
{ "op": "index", "value": -2 }
```

```swift
let resolved = resolveIndex(value, count: query.count)
elements = resolved == nil ? [] : [query.element(boundBy: resolved!)]
```

#### 6) only

```json
{ "op": "only" }
```

```swift
guard elements.count == 1 else { throw IDCError.notUnique }
```

#### 7) frame

```json
{
  "op": "frame",
  "match": "contains",
  "point": { "x": { "value": 100, "unit": "pt" }, "y": { "value": 20, "unit": "pct" } }
}
```

```swift
let p = resolvePoint(point, screenSize: screenSize)
let frame = element.frame.insetBy(dx: -0.5, dy: -0.5)
return frame.contains(p)
```

#### 8) has

```json
{ "op": "has", "selector": { "steps": [ ... ] } }
```

```swift
return !resolve(selector, from: element, anchor: .descendant).isEmpty
```

#### 9) is

```json
{ "op": "is", "selectors": [ { "steps": [ ... ] }, ... ] }
```

```swift
return selectors.contains { !resolve($0, from: element, anchor: .self).isEmpty }
```

#### 10) not

```json
{ "op": "not", "selector": { "steps": [ ... ] } }
```

```swift
return resolve(selector, from: element, anchor: .self).isEmpty
```

### Notes

- `case` uses `"s"` (case-sensitive, default) or `"i"` (case-insensitive).
- `disabled` compiles to `attrBool(isEnabled=false)`.
- `focused` is an alias of `hasFocus`, `enabled` -> `isEnabled`, `selected` -> `isSelected`.
- `subscript` uses NSPredicate to honor `case`.
- `has` uses a descendant anchor; `is`/`not` use a self anchor (implicit, not in opcode).

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
