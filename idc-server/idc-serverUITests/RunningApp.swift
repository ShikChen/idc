import XCTest

struct RunningApp {
    static func getForegroundApp() -> XCUIApplication? {
        let runningAppIds = XCUIApplication.activeAppsInfo().compactMap { $0["bundleId"] as? String }
        if runningAppIds.count == 1, let bundleId = runningAppIds.first {
            return XCUIApplication(bundleIdentifier: bundleId)
        }
        for bundleId in runningAppIds {
            let app = XCUIApplication(bundleIdentifier: bundleId)
            if app.state == XCUIApplication.State.runningForeground {
                return app
            }
        }
        return nil
    }
}
