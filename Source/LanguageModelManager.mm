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
#import "OVUTF8Helper.h"

using namespace std;
using namespace Taiyan::Gramambular;
using namespace vChewing;
using namespace OpenVanilla;

static const int kUserOverrideModelCapacity = 500;
static const double kObservedOverrideHalflife = 5400.0;  // 1.5 hr.
static NSString *kMD5HashCNSData = @"MD5HashCNSData";

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
    NSString *md5HashCNSData = [AWFileHash md5HashOfFileAtPath:[self cnsDataPath]];
    [[NSUserDefaults standardUserDefaults] setObject:md5HashCNSData forKey:kMD5HashCNSData];
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    if (!self.checkIfCNSDataExistAndHashMatched) {
        [self deployZipDataFile:@"UNICHARS"];
    }

    glanguageModelCoreCHT.loadCNSData([[self cnsDataPath] UTF8String]);
    glanguageModelCoreCHS.loadCNSData([[self cnsDataPath] UTF8String]);
}

+ (BOOL)checkIfCNSDataExistAndHashMatched
{
    if (![self checkIfUserDataFolderExists]) {
        NSLog(@"User Data Folder N/A.");
        return NO;
    }
    if (![self checkIfFileExist:[self cnsDataPath]]) {
        NSLog(@"Extracted CNS Data Not Found.");
        return NO;
    }
    if (![[AWFileHash md5HashOfFileAtPath:[self cnsDataPath]] isEqualToString: [[NSUserDefaults standardUserDefaults] objectForKey:kMD5HashCNSData]]) {
        NSLog(@"Existing CNS CSV Data Fingerprint: %@", [AWFileHash md5HashOfFileAtPath:[self cnsDataPath]]);
        NSLog(@"UserPlist CNS CSV Data Fingerprint: %@", [[NSUserDefaults standardUserDefaults] objectForKey:kMD5HashCNSData]);
        NSLog(@"Existing CNS CSV Data fingerprint mismatch, must be tampered since it gets extracted.");
        return NO;
    }
    return YES;
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

    NSString *path = [self userPhrasesDataPath:inputMode];

    NSMutableString *currentMarkedPhrase = [NSMutableString string];
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
