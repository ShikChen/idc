#import <Foundation/Foundation.h>

@protocol XCAccessibilityElement <NSObject>

@property(readonly) id payload;
@property(readonly) int processIdentifier;
@property(readonly) const struct __AXUIElement *AXUIElement;
@property(readonly, getter=isNative) BOOL native;

+ (id)elementWithAXUIElement:(struct __AXUIElement *)arg1;
+ (id)elementWithProcessIdentifier:(int)arg1;
+ (id)deviceElement;
+ (id)mockElementWithProcessIdentifier:(int)arg1 payload:(id)arg2;
+ (id)mockElementWithProcessIdentifier:(int)arg1;

- (id)initWithMockProcessIdentifier:(int)arg1 payload:(id)arg2;
- (id)initWithAXUIElement:(struct __AXUIElement *)arg1;
- (id)init;

@end
