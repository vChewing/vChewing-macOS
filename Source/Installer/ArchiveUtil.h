/* 
 *  ArchiveUtil.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import <Foundation/Foundation.h>

@interface ArchiveUtil : NSObject {
    NSString *_appName;
    NSString *_targetAppBundleName;
}
- (instancetype _Nonnull)initWithAppName:(NSString *_Nonnull)name
                     targetAppBundleName:(NSString *_Nonnull)invalidAppBundleName;

// Returns YES if (1) a zip file under
// Resources/NotarizedArchives/$_appName-$bundleVersion.zip exists, and (2) if
// Resources/$_invalidAppBundleName does not exist.
- (BOOL)validateIfNotarizedArchiveExists;

- (NSString *_Nullable)unzipNotarizedArchive;
@end
