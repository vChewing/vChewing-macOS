/* 
 *  ArchiveUtil.m
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import "ArchiveUtil.h"

@implementation ArchiveUtil
- (instancetype)initWithAppName:(NSString *)name
            targetAppBundleName:(NSString *)targetAppBundleName {
    self = [super init];
    if (self) {
        _appName = name;
        _targetAppBundleName = targetAppBundleName;
    }
    return self;
}

- (void)delloc {
    _appName = nil;
    _targetAppBundleName = nil;
}

- (BOOL)validateIfNotarizedArchiveExists {
    NSString *resourePath = [[NSBundle mainBundle] resourcePath];
    NSString *devModeAppBundlePath =
        [resourePath stringByAppendingPathComponent:_targetAppBundleName];

    NSArray<NSString *> *notarizedArchivesContent =
        [[NSFileManager defaultManager] subpathsAtPath:[self notarizedArchivesPath]];
    NSInteger count = [notarizedArchivesContent count];
    BOOL notarizedArchiveExists =
        [[NSFileManager defaultManager] fileExistsAtPath:[self notarizedArchive]];
    BOOL devModeAppBundleExists =
        [[NSFileManager defaultManager] fileExistsAtPath:devModeAppBundlePath];

    if (count > 0) {
        // Not a valid distribution package.
        if (count != 1 || !notarizedArchiveExists || devModeAppBundleExists) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setAlertStyle:NSAlertStyleInformational];
            [alert setMessageText:@"Internal Error"];
            [alert
                setInformativeText:
                    [NSString stringWithFormat:@"devMode installer, expected archive name: %@, "
                                               @"archive exists: %d, devMode app bundle exists: %d",
                                               [self notarizedArchive], notarizedArchiveExists,
                                               devModeAppBundleExists]];
            [alert addButtonWithTitle:@"Terminate"];
            [alert runModal];

            [[NSApplication sharedApplication] terminate:nil];
        } else {
            return YES;
        }
    }

    if (!devModeAppBundleExists) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert setMessageText:@"Internal Error"];
        [alert
            setInformativeText:[NSString stringWithFormat:@"Dev target bundle does not exist: %@",
                                                          devModeAppBundlePath]];
        [alert addButtonWithTitle:@"Terminate"];
        [alert runModal];
        [[NSApplication sharedApplication] terminate:nil];
    }

    // Notarized archive does not exist, but it's ok.
    return NO;
}

- (NSString *)unzipNotarizedArchive {
    if (![self validateIfNotarizedArchiveExists]) {
        return nil;
    }

    NSString *tempFilePath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSArray *arguments = @[ [self notarizedArchive], @"-d", tempFilePath ];

    NSTask *unzipTask = [[NSTask alloc] init];
    [unzipTask setLaunchPath:@"/usr/bin/unzip"];
    [unzipTask setCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]];
    [unzipTask setArguments:arguments];
    [unzipTask launch];
    [unzipTask waitUntilExit];

    NSAssert(unzipTask.terminationStatus == 0, @"Must successfully unzipped");

    NSString *result = [tempFilePath stringByAppendingPathComponent:_targetAppBundleName];
    NSAssert([[NSFileManager defaultManager] fileExistsAtPath:result],
             @"App bundle must be unzipped at %@", result);
    return result;
}

- (NSString *)notarizedArchivesPath {
    NSString *resourePath = [[NSBundle mainBundle] resourcePath];
    NSString *notarizedArchivesPath =
        [resourePath stringByAppendingPathComponent:@"NotarizedArchives"];
    return notarizedArchivesPath;
}

- (NSString *)notarizedArchive {
    NSString *bundleVersion =
        [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleVersionKey];
    NSString *notarizedArchiveBasename =
        [NSString stringWithFormat:@"%@-r%@.zip", _appName, bundleVersion];
    NSString *notarizedArchive =
        [[self notarizedArchivesPath] stringByAppendingPathComponent:notarizedArchiveBasename];
    return notarizedArchive;
}
@end
