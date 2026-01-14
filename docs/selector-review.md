# Selector / Tap Review TODOs (Synthesized)

## Logic / Correctness
- [x] Verify bool predicate KVC keys (`enabled`/`selected` vs `isEnabled`/`isSelected`) and standardize mapping to avoid mismatches at runtime. (claude-old, gemini-new, gpt-new)
- (TODO) Eliminate/mitigate hardcoded `XCUIElement.ElementType` raw-value mapping in CLI, or add runtime validation to prevent mismatches; consider NSPredicate `withSubstitutionVariables` with server-provided `$type_*` substitutions. (claude-new, gpt-old, gpt-new)
- (TODO) Validate element type names in CLI compile (fail fast instead of server error). (gpt-new)
- (TODO) Clarify / fix whitespace semantics: whether `button [enabled]` is same step or descendant. Align parser & spec. (gpt-old)
- (TODO) Define behavior for empty/whitespace selector (e.g. error unless `--at`, or treat as root). Avoid implicit “tap app”. (gpt-old)
- (TODO) Decide semantics for `plan == nil` vs empty plan in server responses (matched/selected should reflect actual selection). (gpt-new)
- (TODO) Ensure query semantics for `query.descendants(...)` are documented and match intended behavior. (claude-new)
- (TODO) Ensure `:has()` / `:is()` usage rules are consistent (e.g., can `:has(button)` be type-only?). If allowed, update grammar/implementation. (implied by claude-old ambiguity)
- (TODO) Confirm `matching(identifier:)` / subscript semantics match Apple docs (identifier matches identifier/title/label/value/placeholder). (gpt-old)

## Error Handling / UX
- (TODO) Improve error messages for string/bool filters (e.g. `[label]` should say missing operator/value, `[label=true]` should say expects string). (gpt-new)
- (TODO) Make `:predicate(...)` failures user-friendly; optionally validate predicate format in CLI. (claude-new, gpt-old)
- (TODO) Protect server from `NSPredicate` format crashes (Obj‑C try/catch shim or disable raw predicate). (gpt-old, gpt-new)
- (TODO) Provide clear error for unknown ops (CLI newer than server). (claude-new)
- (TODO) Normalize error message style/capitalization and remove unused error cases. (claude-new, gpt-new)
- (TODO) Consider structured error positions for parse failures (line/column). (claude-old)

## Security / Robustness
- (TODO) Treat `:predicate(...)` and regex as “unsafe” or guard with limits (length caps, disallow expensive constructs) to avoid DoS. (gpt-old, gpt-new)
- (TODO) Cap selector length / pipeline length to prevent resource abuse. (claude-new, gpt-old)
- (TODO) Add server-side auth or bind to localhost only (avoid remote abuse). (gpt-new)

## Performance
- (TODO) Avoid `query.count` unless needed; use `firstMatch.exists` first and document negative-index cost. (claude-new, gpt-old, gpt-new)
- (TODO) Avoid `allElementsBoundByIndex` for smart tap if possible; prefer firstMatch or bounded search. (gemini-new, gpt-old, gpt-new)
- (TODO) Avoid screenshot for screen taps when not necessary; use `app.frame` or only when `%` is used. (gpt-old, gpt-new)
- (TODO) Optimize predicate string building to reduce intermediate allocations. (claude-new)
- (TODO) Address potential O(n^2) in `DescribeUI` flattening if still present. (gpt-new)

## Tap Point / Coordinate Semantics
- (TODO) Validate tap point inputs: NaN/Inf, percent bounds, and optional clamping rules. (gemini-new, gpt-old, gpt-new)
- (TODO) Decide whether percent >100 or negative is allowed; if not, enforce on CLI/server. (gemini-new, gpt-old, gpt-new)
- (TODO) Clarify `accessibilityActivationPoint` behavior: XCUI can’t read it; `.tap()` uses it. Document or expose via app debug if needed. (gemini-old)

## Server Behavior / API Contracts
- (TODO) Respect CLI timeout in server retry loop (make wait configurable). (gemini-new, gpt-new)
- (TODO) Retry logic should include foreground app discovery; handle race conditions or allow bundle id selection. (gemini-new, gpt-new)
- (TODO) Return HTTP status codes that distinguish invalid input vs not found vs server error. (gpt-new)
- (TODO) Validate plan version on server. (gpt-old, gpt-new)

## Spec / Grammar Completeness
- (TODO) Add missing grammar definitions (integer/digit/char/bool/attrName/boolAttr/elementTypeName). (claude-old)
- (TODO) Clarify ambiguity between `["text"]` and `[integer]` in grammar. (claude-old)
- (TODO) Explicitly state “one picker per step”. (claude-old)
- (TODO) Document when `matchTypeIdentifier` optimization is emitted and its constraints. (claude-old)

## Tests to Add / Expand
- (TODO) Add tests for negative index (`[-1]`, `[2]`), nested `:is` / `:not`, multiple `:has`, Unicode strings, empty string `""`, and shorthand inside `:has`. (claude-old, claude-new)
- (TODO) Add tests for whitespace semantics (e.g. `button [enabled]`, `cell :only button`, `cell :has(button)`). (gpt-old)
- (TODO) Add tests for invalid predicates to ensure server doesn’t crash and returns 400. (gpt-old)
- (TODO) Add tests for tap point validation (NaN/Inf/out-of-range). (gpt-old)
- (TODO) Add tests for plan version mismatch. (gpt-old)

## Maintainability / Structure
- (TODO) Deduplicate protocol/model types between CLI and server (shared module). (claude-new, gpt-old, gpt-new)
- (TODO) Replace cryptic typealias `P<T>` with clearer naming. (claude-new)
- (TODO) Add doc comments for public parser/compiler APIs. (claude-new)
- (TODO) Replace magic constants (retry count, sleep interval) with config or derived from timeout. (gpt-new)
