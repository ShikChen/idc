import XCTest

struct FindService {
    func resolve(_ request: FindRequest) async throws -> FindResponse {
        let live = request.live ?? false
        let executor = SnapshotPlanExecutor()
        let limit = request.limit ?? 20
        guard limit > 0 else {
            throw PlanError.invalidPlan("Limit must be greater than 0.")
        }
        guard let plan = request.plan, !plan.pipeline.isEmpty else {
            throw PlanError.invalidPlan("Missing selector.")
        }
        if live {
            let (snapshots, truncated) = try await MainActor.run { () -> ([XCUIElementSnapshot], Bool) in
                guard let app = RunningApp.getForegroundApp() else {
                    throw PlanError.invalidPlan("No foreground app found.")
                }
                let liveExecutor = PlanExecutor()
                let node = try liveExecutor.resolveNode(plan, from: app)
                switch node {
                case let .element(element):
                    guard element.exists else { return ([], false) }
                    return try ([element.snapshot()], false)
                case let .query(query):
                    let elements = query.allElementsBoundByIndex
                    let snapshots = try elements.prefix(limit).map { try $0.snapshot() }
                    let truncated = elements.count > limit
                    return (snapshots, truncated)
                }
            }
            let matches = snapshots.map { FindElement(from: $0) }
            return FindResponse(matches: matches, truncated: truncated)
        }

        let rootSnapshot = try await MainActor.run { () -> XCUIElementSnapshot in
            guard let app = RunningApp.getForegroundApp() else {
                throw PlanError.invalidPlan("No foreground app found.")
            }
            return try app.snapshot()
        }
        let node = try executor.resolveNode(plan, from: rootSnapshot)
        switch node {
        case let .element(snapshot):
            return FindResponse(matches: [FindElement(from: snapshot)], truncated: false)
        case let .query(query):
            let limited = query.prefix(limit)
            let matches = limited.map { FindElement(from: $0) }
            let truncated = query.count > limit
            return FindResponse(matches: matches, truncated: truncated)
        }
    }
}
