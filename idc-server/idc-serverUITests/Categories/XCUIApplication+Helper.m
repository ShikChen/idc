#import "XCUIApplication+Helper.h"
#import "AXClientProxy.h"
#import "XCTestDaemonsProxy.h"

@implementation XCUIApplication (Helper)

+ (NSArray<NSDictionary<NSString *, id> *> *)appsInfoWithAxElements:(NSArray<id<XCAccessibilityElement>> *)axElements
{
    NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
    id<XCTestManager_ManagerInterface> proxy = [XCTestDaemonsProxy testRunnerProxy];
    for (id<XCAccessibilityElement> axElement in axElements) {
        NSMutableDictionary<NSString *, id> *appInfo = [NSMutableDictionary dictionary];
        pid_t pid = axElement.processIdentifier;
        appInfo[@"pid"] = @(pid);
        __block NSString *bundleId = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [proxy _XCT_requestBundleIDForPID:pid
                                    reply:^(NSString *bundleID, NSError *error) {
            if (error == nil) {
                bundleId = bundleID;
            } else {
                NSLog(@"Cannot request the bundle ID for process ID %d: %@", pid, error.localizedDescription);
            }
            dispatch_semaphore_signal(sem);
        }];
        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
        appInfo[@"bundleId"] = bundleId ?: @"unknownBundleId";
        [result addObject:appInfo.copy];
    }
    return result.copy;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)activeAppsInfo
{
    return [self appsInfoWithAxElements:[AXClientProxy.sharedClient activeApplications]];
}

@end
