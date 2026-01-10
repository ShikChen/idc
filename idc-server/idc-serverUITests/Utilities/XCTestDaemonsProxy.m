#import "XCTestDaemonsProxy.h"
#import <XCTest/XCTest.h>

@interface XCTRunnerDaemonSession : NSObject
+ (instancetype)sharedSession;
@property(readonly) id<XCTestManager_ManagerInterface> daemonProxy;
@end

@implementation XCTestDaemonsProxy

+ (id<XCTestManager_ManagerInterface>)testRunnerProxy
{
    static id<XCTestManager_ManagerInterface> proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [self retrieveTestRunnerProxy];
    });
    return proxy;
}

+ (id<XCTestManager_ManagerInterface>)retrieveTestRunnerProxy
{
    return ((XCTRunnerDaemonSession *)[XCTRunnerDaemonSession sharedSession]).daemonProxy;
}

@end
