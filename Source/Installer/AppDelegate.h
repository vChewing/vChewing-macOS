/* 
 *  AppDelegate.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import <Cocoa/Cocoa.h>
#import "ArchiveUtil.h"

@interface AppDelegate : NSWindowController <NSApplicationDelegate>
{
@protected
    ArchiveUtil *_archiveUtil;
    NSString *_installingVersion;
    BOOL _upgrading;
    NSButton *__weak _installButton;
    NSButton *__weak _cancelButton;
    NSTextView *__unsafe_unretained _textView;
    NSWindow *__weak _progressSheet;
    NSProgressIndicator *__weak _progressIndicator;
    NSDate *_translocationRemovalStartTime;
    NSInteger _currentVersionNumber;
}
- (IBAction)agreeAndInstallAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

@property (weak) IBOutlet NSButton *installButton;
@property (weak) IBOutlet NSButton *cancelButton;    
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSWindow *progressSheet;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic) IBOutlet NSTextField *appNameLabel;
@property (nonatomic) IBOutlet NSTextField *appVersionLabel;
@property (nonatomic) IBOutlet NSTextField *appCopyrightLabel;
@property (nonatomic) IBOutlet NSTextView *appEULAContent;
@end
