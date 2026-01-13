# Pitfalls

## SwiftUI accessibility identifier inheritance

When using SwiftUI containers with `.accessibilityElement(children: .contain)`, the **modifier order matters**.
If you apply `.accessibilityIdentifier(...)` _before_ `.accessibilityElement(children: .contain)`,
the identifier can be inherited by child elements in the AX tree.

Prefer:

```swift
view
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("root")
```

This prevents child elements from inheriting the container identifier.
