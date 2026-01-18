import XCTest

struct TapService {
    private let maxAttempts = 5
    private let retryDelayNs: UInt64 = 200_000_000

    func resolve(_ request: TapRequest) async throws -> TapResponse {
        let executor = PlanExecutor()
        let hasSelector = request.plan != nil && request.plan?.pipeline.isEmpty == false
        if !hasSelector && request.at == nil {
            throw PlanError.invalidPlan("Missing selector or tap point.")
        }
        if let point = request.at {
            try validateTapPoint(point)
        }
        var lastError: Error?
        for attempt in 0 ..< maxAttempts {
            do {
                let tapped = try await MainActor.run { () -> TapElement? in
                    guard let app = RunningApp.getForegroundApp() else {
                        throw PlanError.invalidPlan("No foreground app found.")
                    }
                    let selected = hasSelector ? try executor.resolve(request.plan, from: app) : nil
                    try performTap(app: app, element: selected, point: request.at)
                    return selected.map { TapElement(from: $0) }
                }
                return TapResponse(selected: tapped)
            } catch let error as PlanError {
                lastError = error
                if case .noMatches = error, attempt < (maxAttempts - 1) {
                    try await Task.sleep(nanoseconds: retryDelayNs)
                    continue
                }
                throw error
            }
        }
        throw lastError ?? PlanError.noMatches
    }

    private func performTap(app: XCUIApplication, element: XCUIElement?, point: TapPoint?) throws {
        if let point {
            switch point.space {
            case .screen:
                let screenPoint = resolveScreenPoint(app: app, point: point.point)
                tapScreen(app: app, point: screenPoint)
            case .element:
                guard let element else {
                    throw PlanError.invalidPlan("Missing selector for element-local tap.")
                }
                tapElement(element: element, point: point.point)
            }
            return
        }

        guard let element else {
            throw PlanError.invalidPlan("Missing selector or tap point.")
        }
        tapElementSmart(element)
    }

    private func validateTapPoint(_ point: TapPoint) throws {
        try validatePointComponent(point.point.x)
        try validatePointComponent(point.point.y)
    }

    private func validatePointComponent(_ component: PointComponent) throws {
        guard component.value.isFinite else {
            throw PlanError.invalidPlan("Tap point must be finite.")
        }
    }

    private func tapElement(element: XCUIElement, point: PointSpec) {
        let size = element.frame.size
        let x = resolvePointComponent(point.x, size: size.width)
        let y = resolvePointComponent(point.y, size: size.height)
        let origin = element.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: x, dy: y)).tap()
    }

    private func tapScreen(app: XCUIApplication, point: CGPoint) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let offset = CGVector(
            dx: point.x - app.frame.minX,
            dy: point.y - app.frame.minY
        )
        origin.withOffset(offset).tap()
    }

    private func tapElementSmart(_ element: XCUIElement) {
        // SwiftUI Toggle exposes an outer switch element whose label area isn't tappable in UI tests.
        // Tap the innermost switch descendant to hit the actual UISwitch control.
        if element.elementType == .switch {
            let target = toggleTapTarget(for: element)
            target.tap()
            return
        }
        element.tap()
    }

    private func toggleTapTarget(for element: XCUIElement) -> XCUIElement {
        let candidates = element.descendants(matching: .switch).allElementsBoundByIndex
        guard !candidates.isEmpty else { return element }
        var best: XCUIElement = element
        var bestArea = CGFloat.greatestFiniteMagnitude
        for candidate in candidates {
            let frame = candidate.frame
            let area = frame.width * frame.height
            guard area > 0 else { continue }
            if area < bestArea {
                best = candidate
                bestArea = area
            }
        }
        return best
    }

    private func resolveScreenPoint(app: XCUIApplication, point: PointSpec) -> CGPoint {
        let size: CGSize
        if point.x.unit == .pct || point.y.unit == .pct {
            size = app.frame.size
        } else {
            size = .zero
        }
        let x = resolvePointComponent(point.x, size: size.width)
        let y = resolvePointComponent(point.y, size: size.height)
        return CGPoint(x: x, y: y)
    }

    private func resolvePointComponent(_ component: PointComponent, size: CGFloat) -> CGFloat {
        switch component.unit {
        case .pt:
            return component.value
        case .pct:
            return (component.value / 100.0) * size
        }
    }
}
