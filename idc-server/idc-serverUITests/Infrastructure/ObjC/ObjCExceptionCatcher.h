#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^IDCObjCBlock)(void);

@interface ObjCExceptionCatcher : NSObject
+ (id _Nullable)perform:(IDCObjCBlock)block
          errorMessage:(NSString * _Nullable * _Nullable)errorMessage;
@end

NS_ASSUME_NONNULL_END
