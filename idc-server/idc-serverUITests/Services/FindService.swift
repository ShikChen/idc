import XCTest

struct FindService {
    func resolve(_ request: FindRequest) async throws -> FindResponse {
        let executor = PlanExecutor()
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
            let node = try executor.resolveNode(plan, from: app)
            switch node {
            case let .element(element):
                guard element.exists else {
                    return FindResponse(matches: [], truncated: false)
                }
                let snapshot = try element.snapshot()
                return FindResponse(matches: [FindElement(from: snapshot)], truncated: false)
            case let .query(query):
                var matches: [FindElement] = []
                matches.reserveCapacity(limit)
                for index in 0 ..< limit {
                    let element = query.element(boundBy: index)
                    guard element.exists else { break }
                    let snapshot = try element.snapshot()
                    matches.append(FindElement(from: snapshot))
                }
                let extraExists = query.element(boundBy: limit).exists
                return FindResponse(matches: matches, truncated: extraExists)
            }
        }
    }
}
