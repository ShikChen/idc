# idc-cli Refactor (Round 2)

## Package.swift ✓

### TODO

- (No changes needed)

### Summary

- Clean after round 1

## Sources/idc/DescribeUI.swift ✓

### TODO

- (No changes needed)

### Summary

- Both imports used (ArgumentParser for CLI, Foundation for Data/JSONDecoder)

## Sources/idc/idc.swift ✓

### TODO

- (No changes needed)

### Summary

- Clean after round 1

## Sources/idc/Screenshot.swift ✓

### TODO

- (No changes needed)

### Summary

- Both imports used (ArgumentParser for CLI, Foundation for Data/URL/DateFormatter)

## Sources/idc/SelectorCompiler.swift ✓

### TODO

- [x] Remove unused `import Foundation`

### Summary

- Removed unused `import Foundation`

## Sources/idc/SelectorParser.swift ✓

### TODO

- (No changes needed)

### Summary

- Only imports Parsing (used throughout for parser combinators)

## Sources/idc/SelectorTypes.swift ✓

### TODO

- [x] Remove unused `import Foundation`

### Summary

- Removed unused `import Foundation`

## Sources/idc/ServerHealth.swift ✓

### TODO

- (No changes needed)

### Summary

- Both imports used (ArgumentParser for CLI, Foundation for Decodable)

## Sources/idc/ServerStart.swift ✓

### TODO

- (No changes needed)

### Summary

- All four imports used (ArgumentParser, Dispatch, Foundation, Subprocess)

## Sources/idc/Support.swift ✓

### TODO

- (No changes needed)

### Summary

- Both imports used (ArgumentParser for ValidationError, Foundation for URL/Data/JSON)

## Sources/idc/Tap.swift ✓

### TODO

- (No changes needed)

### Summary

- Both imports used (ArgumentParser for CLI, Foundation for JSONDecoder)

## Tests/idcTests/SelectorDSLTests.swift ✓

### TODO

- (No changes needed)

### Summary

- Both imports used (@testable import idc, XCTest)

## Tests/idcTests/TapTests.swift ✓

### TODO

- (No changes needed)

### Summary

- Both imports used (@testable import idc, XCTest)
