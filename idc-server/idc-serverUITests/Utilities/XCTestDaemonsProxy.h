#import <Foundation/Foundation.h>
#import "XCTestManager_ManagerInterface-Protocol.h"

@interface XCTestDaemonsProxy : NSObject

+ (id<XCTestManager_ManagerInterface>)testRunnerProxy;

@end
