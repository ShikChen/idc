# idc-cli Refactor

## Package.swift ✓

### TODO

- [x] Remove boilerplate comment on line 2
- [x] Remove template comments on lines 17-18

### Summary

- Removed redundant swift-tools-version explanation comment
- Removed template comments explaining what targets are

## Sources/idc/DescribeUI.swift ✓

### TODO

- [x] Use default parameter instead of wrapper function for `renderDescribeTree`
- [x] Remove unused `parent` parameter from `shouldFlattenNode`
- [x] Display `value` and `placeholderValue` in describe output when present

### Summary

- Consolidated `renderDescribeTree` overloads into single function with default `isRoot: Bool = true` parameter
- Removed unused `parent` parameter from `shouldFlattenNode` function signature
- Added display of `value` field (as formatted JSON) in describe output
- Added display of `placeholderValue` field in describe output
- Added `formatJSONValue` helper to render JSONValue enum as readable string

## Sources/idc/idc.swift ✓

### TODO

- [x] Remove template comments at top of file

### Summary

- Removed Swift/ArgumentParser documentation URL comments from file header

## Sources/idc/Screenshot.swift ✓

### TODO

- (No changes needed - file is already clean)

### Summary

- Reviewed file; no refactoring required
- Code is well-structured with clear responsibility
- Existing TODO comment is a valid future enhancement (simctl integration)

## Sources/idc/SelectorDSL.swift ✓

### TODO

- [x] Break long element type string into multiple lines for readability

### Summary

- Converted `elementTypeRawValues` from single-line multiline string to array literal
- Improved readability by breaking element types into multiple lines (~8 per line)
- Simplified dictionary construction (no longer needs `.split(separator: " ")`)

## Sources/idc/ServerHealth.swift ✓

### TODO

- (No changes needed - file is already clean)

### Summary

- Reviewed file; no refactoring required
- Code is minimal and well-structured

## Sources/idc/ServerStart.swift ✓

### TODO

- [x] Fix race condition in `ShutdownController.requestStop()` - stop request lost if called before `set()`

### Summary

- Fixed race condition where stop request was lost if SIGINT arrived before subprocess started
- `requestStop()` now sets `stopRequested = true` before returning when execution is nil

## Sources/idc/Support.swift ✓

### TODO

- [x] Use async URLSession API in `fetchData` instead of `withCheckedThrowingContinuation`

### Summary

- Simplified `fetchData` by using native async URLSession API
- Removed manual `withCheckedThrowingContinuation` wrapper
- Now consistent with `postJSON` which already uses async URLSession

## Sources/idc/Tap.swift ✓

### TODO

- (No changes needed - file is already clean)

### Summary

- Reviewed file; no refactoring required
- Code is well-structured with clear error handling and parsing logic

## Tests/idcTests/SelectorDSLTests.swift ✓

### TODO

- (No changes needed - file is already clean)

### Summary

- Reviewed file; no refactoring required
- Comprehensive test coverage with good use of helper functions
- Tests are well-organized and readable

## Tests/idcTests/TapTests.swift ✓

### TODO

- (No changes needed - file is already clean)

### Summary

- Reviewed file; no refactoring required
- Good coverage of point parsing edge cases

---

# Cross-File Refactoring

## Extract `validateUDID()` helper ✓

### TODO

- [x] Add `validateUDID()` function to `Support.swift`
- [x] Replace duplicated code in `DescribeUI.swift`
- [x] Replace duplicated code in `ServerHealth.swift`
- [x] Replace duplicated code in `Tap.swift`

### Summary

- Added `validateUDID(_ expectedUDID:timeout:)` helper to `Support.swift`
- Replaced 3 instances of duplicated UDID validation logic with single function call
- Each command now uses `try await validateUDID(udid, timeout: timeout)`

## Extract `serverUnreachableError()` helper

## Split SelectorDSL.swift into separate files
