/* 
 *  frmAboutWindow.m
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import "frmAboutWindow.h"


@implementation frmAboutWindow
@synthesize appNameLabel;
@synthesize appVersionLabel;
@synthesize appCopyrightLabel;
@synthesize appEULAContent;

+ (instancetype) defaultController {
    
    static id staticInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        staticInstance = [[self alloc] init];
    });
    
    return staticInstance;
}


#pragma mark - Initialization


- (instancetype) init {
    return [super initWithWindowNibName:@"frmAboutWindow" owner:self];
}


#pragma mark - NSWindowController


- (void) windowDidLoad {
    
    [super windowDidLoad];
    [self.window standardWindowButton:NSWindowCloseButton].hidden = true;
    [self.window standardWindowButton:NSWindowMiniaturizeButton].hidden = true;
    [self.window standardWindowButton:NSWindowZoomButton].hidden = true;
    [self updateInfo];
}

- (void) updateInfo {

    NSString *installingVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleVersionKey];
    NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

    NSDictionary* localizedInfoDictionary = [[NSBundle mainBundle] localizedInfoDictionary];
    
    self.appNameLabel.stringValue      = [localizedInfoDictionary objectForKey:@"CFBundleName"];
    self.appVersionLabel.stringValue   = [NSString stringWithFormat:@"%@ Build %@", versionString, installingVersion];
    self.appCopyrightLabel.stringValue = [localizedInfoDictionary objectForKey:@"NSHumanReadableCopyright"];
    self.appEULAContent.string = [localizedInfoDictionary objectForKey:@"CFEULAContent"];
}

- (void) showWithSender:(id)sender {
}

@end
