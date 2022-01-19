/* 
 *  LanguageModelManager.mm
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import "LanguageModelManager.h"
#import <fstream>
#import <iostream>
#import <set>
#import "OVStringHelper.h"
#import "OVUTF8Helper.h"

using namespace std;
using namespace Taiyan::Gramambular;
using namespace vChewing;
using namespace OpenVanilla;

static const int kUserOverrideModelCapacity = 500;
static const double kObservedOverrideHalflife = 5400.0;  // 1.5 hr.

vChewingLM glanguageModelCoreCHT;
vChewingLM glanguageModelCoreCHS;
UserOverrideModel gUserOverrideModelCHS(kUserOverrideModelCapacity, kObservedOverrideHalflife);
UserOverrideModel gUserOverrideModelCHT(kUserOverrideModelCapacity, kObservedOverrideHalflife);

@implementation LanguageModelManager

static void LTLoadLanguageModelFile(NSString *filenameWithoutExtension, vChewingLM &lm)
{
    Class cls = NSClassFromString(@"vChewingInputMethodController");
    NSString *dataPath = [[NSBundle bundleForClass:cls] pathForResource:filenameWithoutExtension ofType:@"txt"];
    lm.loadLanguageModel([dataPath UTF8String]);
}

+ (void)loadDataModels
{
    LTLoadLanguageModelFile(@"data-cht", glanguageModelCoreCHT);
    LTLoadLanguageModelFile(@"data-chs", glanguageModelCoreCHS);
}

+ (void)loadUserPhrases
{
    glanguageModelCoreCHT.loadUserPhrases([[self userPhrasesDataPathCHT] UTF8String], [[self excludedPhrasesDataPathCHT] UTF8String]);
	glanguageModelCoreCHS.loadUserPhrases([[self userPhrasesDataPathCHS] UTF8String], [[self excludedPhrasesDataPathCHS] UTF8String]);
}

+ (void)loadUserPhraseReplacement
{
    glanguageModelCoreCHT.loadPhraseReplacementMap([[self phraseReplacementDataPathCHT] UTF8String]);
	glanguageModelCoreCHS.loadPhraseReplacementMap([[self phraseReplacementDataPathCHS] UTF8String]);
}

+ (BOOL)checkIfUserDataFolderExists
{
    NSString *folderPath = [self dataFolderPath];
    BOOL isFolder = NO;
    BOOL folderExist = [[NSFileManager defaultManager] fileExistsAtPath:folderPath isDirectory:&isFolder];
    if (folderExist && !isFolder) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:folderPath error:&error];
        if (error) {
            NSLog(@"Failed to remove folder %@", error);
            return NO;
        }
        folderExist = NO;
    }
    if (!folderExist) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Failed to create folder %@", error);
            return NO;
        }
    }
    return YES;
}

+ (BOOL)checkIfFileExist:(NSString *)filePath
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        BOOL result = [[@"" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:filePath atomically:YES];
        if (!result) {
            NSLog(@"Failed to write file");
            return NO;
        }
    }
    return YES;
}

+ (BOOL)checkIfUserLanguageModelFilesExist
{
    if (![self checkIfUserDataFolderExists]) {
        return NO;
    }
    if (![self checkIfFileExist:[self userPhrasesDataPathCHT]]) {
        return NO;
    }
    if (![self checkIfFileExist:[self excludedPhrasesDataPathCHT]]) {
        return NO;
    }
    if (![self checkIfFileExist:[self phraseReplacementDataPathCHT]]) {
        return NO;
    }
	if (![self checkIfFileExist:[self userPhrasesDataPathCHS]]) {
		return NO;
	}
	if (![self checkIfFileExist:[self excludedPhrasesDataPathCHS]]) {
		return NO;
	}
	if (![self checkIfFileExist:[self phraseReplacementDataPathCHS]]) {
		return NO;
	}
	return YES;
}

+ (BOOL)writeUserPhraseCHT:(NSString *)userPhrase
{
    if (![self checkIfUserLanguageModelFilesExist]) {
        return NO;
    }

    BOOL shuoldAddLineBreakAtFront = NO;
    NSString *path = [self userPhrasesDataPathCHT];

    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
        unsigned long long fileSize = [attr fileSize];
        if (!error && fileSize) {
            NSFileHandle *readFile = [NSFileHandle fileHandleForReadingAtPath:path];
            if (readFile) {
                [readFile seekToFileOffset:fileSize - 1];
                NSData *data = [readFile readDataToEndOfFile];
                const void *bytes = [data bytes];
                if (*(char *)bytes != '\n') {
                    shuoldAddLineBreakAtFront = YES;
                }
                [readFile closeFile];
            }
        }
    }

    NSMutableString *currentMarkedPhrase = [NSMutableString string];
    if (shuoldAddLineBreakAtFront) {
        [currentMarkedPhrase appendString:@"\n"];
    }
    [currentMarkedPhrase appendString:userPhrase];
    [currentMarkedPhrase appendString:@"\n"];

    NSFileHandle *writeFile = [NSFileHandle fileHandleForUpdatingAtPath:path];
    if (!writeFile) {
        return NO;
    }
    [writeFile seekToEndOfFile];
    NSData *data = [currentMarkedPhrase dataUsingEncoding:NSUTF8StringEncoding];
    [writeFile writeData:data];
    [writeFile closeFile];

    [self loadUserPhrases];
    return YES;
}

+ (BOOL)writeUserPhraseCHS:(NSString *)userPhrase
{
	if (![self checkIfUserLanguageModelFilesExist]) {
		return NO;
	}

	BOOL shuoldAddLineBreakAtFront = NO;
	NSString *path = [self userPhrasesDataPathCHS];

	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSError *error = nil;
		NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
		unsigned long long fileSize = [attr fileSize];
		if (!error && fileSize) {
			NSFileHandle *readFile = [NSFileHandle fileHandleForReadingAtPath:path];
			if (readFile) {
				[readFile seekToFileOffset:fileSize - 1];
				NSData *data = [readFile readDataToEndOfFile];
				const void *bytes = [data bytes];
				if (*(char *)bytes != '\n') {
					shuoldAddLineBreakAtFront = YES;
				}
				[readFile closeFile];
			}
		}
	}

	NSMutableString *currentMarkedPhrase = [NSMutableString string];
	if (shuoldAddLineBreakAtFront) {
		[currentMarkedPhrase appendString:@"\n"];
	}
	[currentMarkedPhrase appendString:userPhrase];
	[currentMarkedPhrase appendString:@"\n"];

	NSFileHandle *writeFile = [NSFileHandle fileHandleForUpdatingAtPath:path];
	if (!writeFile) {
		return NO;
	}
	[writeFile seekToEndOfFile];
	NSData *data = [currentMarkedPhrase dataUsingEncoding:NSUTF8StringEncoding];
	[writeFile writeData:data];
	[writeFile closeFile];

	[self loadUserPhrases];
	return YES;
}

+ (NSString *)dataFolderPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDirectory, YES);
    NSString *appSupportPath = [paths objectAtIndex:0];
    NSString *userDictPath = [appSupportPath stringByAppendingPathComponent:@"vChewing"];
    return userDictPath;
}

+ (NSString *)userPhrasesDataPathCHT
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"userdata-cht.txt"];
}

+ (NSString *)userPhrasesDataPathCHS
{
	return [[self dataFolderPath] stringByAppendingPathComponent:@"userdata-chs.txt"];
}

+ (NSString *)excludedPhrasesDataPathCHT
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"exclude-phrases-cht.txt"];
}

+ (NSString *)excludedPhrasesDataPathCHS
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"exclude-phrases-chs.txt"];
}

+ (NSString *)phraseReplacementDataPathCHT
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"phrases-replacement-cht.txt"];
}

+ (NSString *)phraseReplacementDataPathCHS
{
	return [[self dataFolderPath] stringByAppendingPathComponent:@"phrases-replacement-chs.txt"];
}

 + (vChewingLM *)languageModelCoreCHT
{
    return &glanguageModelCoreCHT;
}

+ (vChewingLM *)languageModelCoreCHS
{
    return &glanguageModelCoreCHS;
}

+ (vChewing::UserOverrideModel *)userOverrideModelCHT
{
    return &gUserOverrideModelCHT;
}

+ (vChewing::UserOverrideModel *)userOverrideModelCHS
{
	return &gUserOverrideModelCHS;
}

@end
