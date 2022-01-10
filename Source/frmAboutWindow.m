//
//  frmAboutWindow.m
//  Tile Map Editor
//
//  Created & Original Rights by Nicolás Miari on 2016/02/11.
//  Patched by Hiraku Wang and Shiki Suen for the vChewing Project.
//  Released under MIT License.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.

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

    [self updateInfo];

    // If you add more custom subviews to display additional information about
    // your app, configure them here
}

- (void) updateInfo {
    NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSDictionary* localizedInfoDictionary = [[NSBundle mainBundle] localizedInfoDictionary];
    
    self.appNameLabel.stringValue      = [localizedInfoDictionary objectForKey:@"CFBundleName"];
    self.appVersionLabel.stringValue   = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    self.appCopyrightLabel.stringValue = [localizedInfoDictionary objectForKey:@"NSHumanReadableCopyright"];
    self.appEULAContent.string = [localizedInfoDictionary objectForKey:@"CFEULAContent"];
}

- (void) showWithSender:(id)sender {
    // FIXME: updating the strings every time is a temporary workaround
    [self updateInfo];
    [self.window orderFront:sender];
}

@end
