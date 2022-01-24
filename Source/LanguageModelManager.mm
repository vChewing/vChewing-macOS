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

// input modes
static NSString *const kBopomofoModeIdentifierCHT = @"org.atelierInmu.inputmethod.vChewing.TradBopomofo";
static NSString *const kBopomofoModeIdentifierCHS = @"org.atelierInmu.inputmethod.vChewing.SimpBopomofo";

@implementation LanguageModelManager

+ (void)deployZipDataFile:(NSString *)filenameWithoutExtension
{
    Class cls = NSClassFromString(@"vChewingInputMethodController");
    NSString *zipPath = [[NSBundle bundleForClass:cls] pathForResource:filenameWithoutExtension ofType:@"zip"];
    NSString *destinationPath = [self dataFolderPath];
    [SSZipArchive unzipFileAtPath:zipPath toDestination:destinationPath];
}

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

+ (void)loadCNSData
{
    glanguageModelCoreCHT.loadCNSData([[self cnsDataPath] UTF8String]);
    glanguageModelCoreCHS.loadCNSData([[self cnsDataPath] UTF8String]);
}

+ (void)loadUserPhrases
{
    glanguageModelCoreCHT.loadUserPhrases([[self userPhrasesDataPath:kBopomofoModeIdentifierCHT] UTF8String], [[self excludedPhrasesDataPath:kBopomofoModeIdentifierCHT] UTF8String]);
	glanguageModelCoreCHS.loadUserPhrases([[self userPhrasesDataPath:kBopomofoModeIdentifierCHS] UTF8String], [[self excludedPhrasesDataPath:kBopomofoModeIdentifierCHS] UTF8String]);
}

+ (void)loadUserPhraseReplacement
{
    glanguageModelCoreCHT.loadPhraseReplacementMap([[self phraseReplacementDataPath:kBopomofoModeIdentifierCHT] UTF8String]);
	glanguageModelCoreCHS.loadPhraseReplacementMap([[self phraseReplacementDataPath:kBopomofoModeIdentifierCHS] UTF8String]);
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
    if (![self checkIfFileExist:[self userPhrasesDataPath:kBopomofoModeIdentifierCHT]]) {
        return NO;
    }
    if (![self checkIfFileExist:[self excludedPhrasesDataPath:kBopomofoModeIdentifierCHT]]) {
        return NO;
    }
    if (![self checkIfFileExist:[self phraseReplacementDataPath:kBopomofoModeIdentifierCHT]]) {
        return NO;
    }
	if (![self checkIfFileExist:[self userPhrasesDataPath:kBopomofoModeIdentifierCHS]]) {
		return NO;
	}
	if (![self checkIfFileExist:[self excludedPhrasesDataPath:kBopomofoModeIdentifierCHS]]) {
		return NO;
	}
	if (![self checkIfFileExist:[self phraseReplacementDataPath:kBopomofoModeIdentifierCHS]]) {
		return NO;
	}
	return YES;
}

+ (BOOL)writeUserPhrase:(NSString *)userPhrase inputMode:(NSString *)inputMode
{
    if (![self checkIfUserLanguageModelFilesExist]) {
        return NO;
    }

    BOOL shouldAddLineBreakAtFront = NO;
    NSString *path = [self userPhrasesDataPath:inputMode];

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
                    shouldAddLineBreakAtFront = YES;
                }
                [readFile closeFile];
            }
        }
    }

    NSMutableString *currentMarkedPhrase = [NSMutableString string];
    if (shouldAddLineBreakAtFront) {
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

+ (NSString *)userPhrasesDataPath:(NSString *)inputMode
{
    NSString *fileName = [inputMode isEqualToString:kBopomofoModeIdentifierCHT] ? @"userdata-cht.txt" : @"userdata-chs.txt";
    return [[self dataFolderPath] stringByAppendingPathComponent:fileName];
}

+ (NSString *)excludedPhrasesDataPath:(NSString *)inputMode
{
    NSString *fileName = [inputMode isEqualToString:kBopomofoModeIdentifierCHT] ? @"exclude-phrases-cht.txt" : @"exclude-phrases-chs.txt";
    return [[self dataFolderPath] stringByAppendingPathComponent:fileName];
}

+ (NSString *)phraseReplacementDataPath:(NSString *)inputMode
{
    NSString *fileName = [inputMode isEqualToString:kBopomofoModeIdentifierCHT] ? @"phrases-replacement-cht.txt" : @"phrases-replacement-chs.txt";
    return [[self dataFolderPath] stringByAppendingPathComponent:fileName];
}

+ (NSString *)cnsDataPath
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"UNICHARS.csv"];
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
