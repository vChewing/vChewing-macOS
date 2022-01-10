//
// AppDelegate.h
//
// Copyright (c) 2021-2022 The vChewing Project.
// Copyright (c) 2011-2022 The OpenVanilla Project.
//
// Contributors:
//     Mengjuei Hsieh (@mjhsieh) @ OpenVanilla
//     Weizhong Yang (@zonble) @ OpenVanilla
//     Lukhnos Liu (@lukhnos) @ OpenVanilla
//     Hiraku Wang (@hirakujira) @ vChewing
//     Shiki Suen (@ShikiSuen) @ vChewing
//
// Based on the Syrup Project and the Formosana Library
// by Lukhnos Liu (@lukhnos).
// 
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#import <Cocoa/Cocoa.h>
#import "frmAboutWindow.h"

@class PreferencesWindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>
{
@private
    NSURLConnection *_updateCheckConnection;
    BOOL _currentUpdateCheckIsForced;
    NSMutableData *_receivingData;
    NSURL *_updateNextStepURL;
    PreferencesWindowController *_preferencesWindowController;
    frmAboutWindow *_aboutWindowController;
}

- (void)checkForUpdate;
- (void)checkForUpdateForced:(BOOL)forced;
- (void)showPreferences;
- (void)showAbout;

@property (weak, nonatomic) IBOutlet NSWindow *window;
@end
