#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (id _Nullable)perform:(IDCObjCBlock)block
          errorMessage:(NSString * _Nullable * _Nullable)errorMessage {
    @try {
        return block();
    } @catch (NSException *exception) {
        if (errorMessage) {
            *errorMessage = exception.reason ?: @"Objective-C exception.";
        }
        return nil;
    }
}

@end
