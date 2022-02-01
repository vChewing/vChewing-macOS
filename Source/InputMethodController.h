/* 
 *  InputMethodController.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "vChewing-Swift.h"

@interface vChewingInputMethodController : IMKInputController
- (void)handleState:(InputState *)newState client:(id)client;
@end
