//
//  OjbCUtils.m
//  vChewing
//
//  Created by ShikiSuen on 2022/3/28.
//

#import "ObjCUtils.h"

@implementation ObjCUtils

+ (bool)keyboardSwitchCondition:(NSEvent *)event {
    return ((event.modifierFlags & ~NSEventModifierFlagShift) || ((event.modifierFlags & NSEventModifierFlagShift) && mgrPrefs.functionKeyKeyboardLayoutOverrideIncludeShiftKey));
}

@end
