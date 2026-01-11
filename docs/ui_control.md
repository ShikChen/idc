# UI Control DSL + CLI Spec (Draft)

This document defines the selector DSL and CLI behavior for `idc tap`.

## Selector DSL v0.5 (CSS-like)

### 1) Grammar

```
selector := step (combinator step)* [selection]
combinator := " " | ">"
step := type filter* pseudo*
type := elementTypeName | any
```

- Space (` `) means **descendants**.
- `>` means **children**.
- No `app.` prefix. All selectors start from the foreground app.
- `type` is **case-insensitive**.
- `any` means no type constraint.

### 2) Filters (AND, inside `[...]`)

```
["text"]                  // shorthand
[label="..."]             // exact
[label*="..."]            // contains
[label^="..."]            // begins with
[label$="..."]            // ends with
[label~="regex"]          // regex (MATCHES)

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

[n]                       // index (0-based, -1 = last)
```

**Shorthand `["text"]`**  
Matches any one of: `identifier`, `title`, `label`, `value`, or `placeholderValue` (exact match).

### 3) Pseudo-classes

```
:has(selector)            // contains descendant
:is(selector, selector)   // OR
:not(selector)            // NOT
```

### 4) Frame filter

```
[frame*=(x,y)]            // frame contains point (screen points)
[frame*=(70%,40%)]        // screen-normalized
```

- `*=` means "contains".
- `%` uses screen-normalized coordinates (0–100%).
- `frame` is **post-filtered** after query resolution.
- An epsilon (0.5pt) is applied to avoid boundary rounding issues.

### 5) Selection

```
:only
```

- Requires a unique match (otherwise 409).
- Without `:only`, the **default behavior is first match**, same as other filters.

### 6) Examples

```
button[label="OK"]
navigationBar > button[label*="Add"]
any["Settings"]
cell:has(button[label*="Download"])
cell[frame*=(50%,50%)]
button[label~="^Add .*"]
button:is([label="A"], [label="B"])
button:not([enabled])
```

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
- `[n]` selects by index (0-based; `-1` = last).
- `value` is matched as a **string** (non-string values are stringified).
