#import <Foundation/Foundation.h>

@protocol XCTestManager_ManagerInterface <NSObject>

- (void)_XCT_requestBundleIDForPID:(int)pid
                             reply:(void (^)(NSString *bundleID, NSError *error))reply;

@end
