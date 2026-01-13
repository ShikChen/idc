import XCTest

struct RunningApp {
    static func getForegroundApp() -> XCUIApplication? {
        let runningAppIds = XCUIApplication.activeAppsInfo().compactMap { $0["bundleId"] as? String }
        let filtered = runningAppIds.filter {
            $0 != "com.apple.springboard" && !$0.hasSuffix(".xctrunner")
        }
        let candidates = filtered.isEmpty ? runningAppIds : filtered
        for bundleId in candidates {
            let app = XCUIApplication(bundleIdentifier: bundleId)
            if app.state == XCUIApplication.State.runningForeground {
                return app
            }
        }
        if candidates.count == 1, let bundleId = candidates.first {
            return XCUIApplication(bundleIdentifier: bundleId)
        }
        return nil
    }
}
