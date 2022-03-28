//
//  OjbCUtils.h
//  vChewing
//
//  Created by ShikiSuen on 2022/3/28.
//

#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "vChewing-Swift.h"

NS_ASSUME_NONNULL_BEGIN

@interface ObjCUtils : NSObject
+ (bool)keyboardSwitchCondition:(NSEvent *)event;
@end

NS_ASSUME_NONNULL_END
