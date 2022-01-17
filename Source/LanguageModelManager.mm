//
// LanguageModelManager.mm
//
// Copyright (c) 2021-2022 The vChewing Project.
// Copyright (c) 2011-2022 The OpenVanilla Project.
//
// Contributors:
//     Weizhong Yang (@zonble) @ OpenVanilla
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

#import "LanguageModelManager.h"
#import <fstream>
#import <iostream>
#import <set>
#import "OVStringHelper.h"
#import "OVUTF8Helper.h"

using namespace std;
using namespace Formosa::Gramambular;
using namespace vChewing;
using namespace OpenVanilla;

static const int kUserOverrideModelCapacity = 500;
static const double kObservedOverrideHalflife = 5400.0;  // 1.5 hr.

vChewingLM gLanguageModelBopomofo;
vChewingLM gLanguageModelSimpBopomofo;
UserOverrideModel gUserOverrideModel(kUserOverrideModelCapacity, kObservedOverrideHalflife);

@implementation LanguageModelManager

static void LTLoadLanguageModelFile(NSString *filenameWithoutExtension, vChewingLM &lm)
{
    Class cls = NSClassFromString(@"vChewingInputMethodController");
    NSString *dataPath = [[NSBundle bundleForClass:cls] pathForResource:filenameWithoutExtension ofType:@"txt"];
    lm.loadLanguageModel([dataPath UTF8String]);
}

+ (void)loadDataModels
{
    LTLoadLanguageModelFile(@"data-cht", gLanguageModelBopomofo);
    LTLoadLanguageModelFile(@"data-chs", gLanguageModelSimpBopomofo);
}

+ (void)loadUserPhrases
{
    gLanguageModelBopomofo.loadUserPhrases([[self userPhrasesDataPathBopomofo] UTF8String], [[self excludedPhrasesDataPathBopomofo] UTF8String]);
    gLanguageModelSimpBopomofo.loadUserPhrases(NULL, [[self excludedPhrasesDataPathSimpBopomofo] UTF8String]);
}

+ (void)loadUserPhraseReplacement
{
    gLanguageModelBopomofo.loadPhraseReplacementMap([[self phraseReplacementDataPathBopomofo] UTF8String]);
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
    if (![self checkIfFileExist:[self userPhrasesDataPathBopomofo]]) {
        return NO;
    }
    if (![self checkIfFileExist:[self excludedPhrasesDataPathBopomofo]]) {
        return NO;
    }
    if (![self checkIfFileExist:[self excludedPhrasesDataPathSimpBopomofo]]) {
        return NO;
    }
    if (![self checkIfFileExist:[self phraseReplacementDataPathBopomofo]]) {
        return NO;
    }
    return YES;
}

+ (BOOL)writeUserPhrase:(NSString *)userPhrase
{
    if (![self checkIfUserLanguageModelFilesExist]) {
        return NO;
    }

    BOOL shuoldAddLineBreakAtFront = NO;
    NSString *path = [self userPhrasesDataPathBopomofo];

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

+ (NSString *)userPhrasesDataPathBopomofo
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"data-cht.txt"];
}

+ (NSString *)excludedPhrasesDataPathBopomofo
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"exclude-phrases.txt"];
}

+ (NSString *)excludedPhrasesDataPathSimpBopomofo
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"exclude-phrases-plain-bpmf.txt"];
}

+ (NSString *)phraseReplacementDataPathBopomofo
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"phrases-replacement.txt"];
}

 + (vChewingLM *)languageModelBopomofo
{
    return &gLanguageModelBopomofo;
}

+ (vChewingLM *)languageModelSimpBopomofo
{
    return &gLanguageModelSimpBopomofo;
}

+ (vChewing::UserOverrideModel *)userOverrideModel
{
    return &gUserOverrideModel;
}

@end
