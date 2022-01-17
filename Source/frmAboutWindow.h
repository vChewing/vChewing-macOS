/* 
 *  frmAboutWindow.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import <Cocoa/Cocoa.h>

@interface frmAboutWindow : NSWindowController

+ (instancetype) defaultController;
- (void) showWithSender:(id)sender;

@property (nonatomic) IBOutlet NSTextField *appNameLabel;
@property (nonatomic) IBOutlet NSTextField *appVersionLabel;
@property (nonatomic) IBOutlet NSTextField *appCopyrightLabel;
@property (nonatomic) IBOutlet NSTextView *appEULAContent;

@end
