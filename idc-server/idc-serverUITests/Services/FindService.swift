import XCTest

struct FindService {
    func resolve(_ request: FindRequest) async throws -> FindResponse {
        let executor = SnapshotPlanExecutor()
        let limit = request.limit ?? 20
        guard limit > 0 else {
            throw PlanError.invalidPlan("Limit must be greater than 0.")
        }
        guard let plan = request.plan, !plan.pipeline.isEmpty else {
            throw PlanError.invalidPlan("Missing selector.")
        }
        return try await MainActor.run {
            guard let app = RunningApp.getForegroundApp() else {
                throw PlanError.invalidPlan("No foreground app found.")
            }
            let rootSnapshot = try app.snapshot()
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
}
