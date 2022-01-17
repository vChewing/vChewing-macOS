/* 
 *  main.m
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "vChewing-Swift.h"

static NSString *const kConnectionName = @"vChewing_1_Connection";

int main(int argc, char *argv[])
{
    @autoreleasepool {

    // register and enable the input source (along with all its input modes)
    if (argc > 1 && !strcmp(argv[1], "install")) {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSURL *bundleURL = nil;
        if ([[NSBundle mainBundle] respondsToSelector:@selector(bundleURL)]) {
            // For Mac OS X 10.6+
            bundleURL = [[NSBundle mainBundle] bundleURL];
        }
        else {
            // For Mac OS X 10.5
            bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        }

        TISInputSourceRef inputSource = [InputSourceHelper inputSourceForInputSourceID:bundleID];

        // if this IME name is not found in the list of available IMEs
        if (!inputSource) {
            NSLog(@"Registering input source %@ at %@.", bundleID, [bundleURL absoluteString]);
            // then register
            BOOL status = [InputSourceHelper registerInputSource:bundleURL];

            if (!status) {
                NSLog(@"Fatal error: Cannot register input source %@ at %@.", bundleID, [bundleURL absoluteString]);
                return -1;
            }

            inputSource = [InputSourceHelper inputSourceForInputSourceID:bundleID];
            // if it still doesn't register successfully, bail.
            if (!inputSource) {
                NSLog(@"Fatal error: Cannot find input source %@ after registration.", bundleID);
                return -1;
            }
        }

        // if it's not enabled, just enabled it
        if (inputSource && ![InputSourceHelper inputSourceEnabled:inputSource]) {
            NSLog(@"Enabling input source %@ at %@.", bundleID, [bundleURL absoluteString]);
            BOOL status = [InputSourceHelper enableInputSource:inputSource];

            if (!status) {
                NSLog(@"Fatal error: Cannot enable input source %@.", bundleID);
                return -1;
            }
            if (![InputSourceHelper inputSourceEnabled:inputSource]){
                NSLog(@"Fatal error: Cannot enable input source %@.", bundleID);
                return -1;
            }
        }

        if (argc > 2 && !strcmp(argv[2], "--all")) {
            BOOL enabled = [InputSourceHelper enableAllInputModesForInputSourceBundleID:bundleID];
            if (enabled) {
                NSLog(@"All input sources enabled for %@", bundleID);
            }
            else {
                NSLog(@"Cannot enable all input sources for %@, but this is ignored", bundleID);
            }
        }

        return 0;
    }

    NSString *mainNibName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"NSMainNibFile"];
    if (!mainNibName) {
        NSLog(@"Fatal error: NSMainNibFile key not defined in Info.plist.");
        return -1;
    }

    BOOL loadResult = [[NSBundle mainBundle] loadNibNamed:mainNibName owner:[NSApplication sharedApplication] topLevelObjects:NULL];
    if (!loadResult) {
        NSLog(@"Fatal error: Cannot load %@.", mainNibName);
        return -1;
    }

    IMKServer *server = [[IMKServer alloc] initWithName:kConnectionName bundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
    if (!server) {
        NSLog(@"Fatal error: Cannot initialize input method server with connection %@.", kConnectionName);
        return -1;
    }

    [[NSApplication sharedApplication] run];
    }
    return 0;
}
