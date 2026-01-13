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

## Sources/idc/ServerHealth.swift

## Sources/idc/ServerStart.swift

## Sources/idc/Support.swift

## Sources/idc/Tap.swift

## Tests/idcTests/SelectorDSLTests.swift

## Tests/idcTests/TapTests.swift
