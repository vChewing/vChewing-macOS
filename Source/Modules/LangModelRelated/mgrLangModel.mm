// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "mgrLangModel.h"
#import "mgrLangModel_Privates.h"
#import "vChewing-Swift.h"

using namespace std;
using namespace vChewing;

static const int kUserOverrideModelCapacity = 500;
static const double kObservedOverrideHalflife = 5400.0;

static vChewingLM gLangModelCHT;
static vChewingLM gLangModelCHS;
static UserOverrideModel gUserOverrideModelCHT(kUserOverrideModelCapacity, kObservedOverrideHalflife);
static UserOverrideModel gUserOverrideModelCHS(kUserOverrideModelCapacity, kObservedOverrideHalflife);

static NSString *const kUserDataTemplateName = @"template-data";
static NSString *const kExcludedPhrasesvChewingTemplateName = @"template-exclude-phrases";
static NSString *const kPhraseReplacementTemplateName = @"template-phrases-replacement";
static NSString *const kTemplateExtension = @".txt";

@implementation mgrLangModel

static void LTLoadLanguageModelFile(NSString *filenameWithoutExtension, vChewingLM &lm)
{
    Class cls = NSClassFromString(@"ctlInputMethod");
    NSString *dataPath = [[NSBundle bundleForClass:cls] pathForResource:filenameWithoutExtension ofType:@"txt"];
    lm.loadLanguageModel([dataPath UTF8String]);
}

static void LTLoadAssociatedPhrases(vChewingLM &lm)
{
    Class cls = NSClassFromString(@"ctlInputMethod");
    NSString *dataPath = [[NSBundle bundleForClass:cls] pathForResource:@"assPhrases" ofType:@"txt"];
    lm.loadAssociatedPhrases([dataPath UTF8String]);
}

+ (void)loadDataModels
{
    if (!gLangModelCHT.isDataModelLoaded()) {
        LTLoadLanguageModelFile(@"data-cht", gLangModelCHT);
    }
    if (!gLangModelCHS.isDataModelLoaded()) {
        LTLoadLanguageModelFile(@"data-chs", gLangModelCHS);
    }
    if (!gLangModelCHS.isAssociatedPhrasesLoaded()) {
        LTLoadAssociatedPhrases(gLangModelCHS);
    }
}

+ (void)loadDataModel:(InputMode)mode
{
    if ([mode isEqualToString:imeModeCHT]) {
        if (!gLangModelCHT.isDataModelLoaded()) {
            LTLoadLanguageModelFile(@"data-cht", gLangModelCHT);
        }
        if (!gLangModelCHT.isAssociatedPhrasesLoaded()) {
            LTLoadAssociatedPhrases(gLangModelCHT);
        }
    }

    if ([mode isEqualToString:imeModeCHS]) {
        if (!gLangModelCHS.isDataModelLoaded()) {
            LTLoadLanguageModelFile(@"data-chs", gLangModelCHS);
        }
        if (!gLangModelCHS.isAssociatedPhrasesLoaded()) {
            LTLoadAssociatedPhrases(gLangModelCHS);
        }
    }
}

+ (void)loadUserPhrases
{
    gLangModelCHT.loadUserPhrases([[self userPhrasesDataPath:imeModeCHT] UTF8String], [[self excludedPhrasesDataPath:imeModeCHT] UTF8String]);
    gLangModelCHS.loadUserPhrases([[self userPhrasesDataPath:imeModeCHS] UTF8String], [[self excludedPhrasesDataPath:imeModeCHS] UTF8String]);
}

+ (void)loadUserPhraseReplacement
{
    gLangModelCHT.loadPhraseReplacementMap([[self phraseReplacementDataPath:imeModeCHT] UTF8String]);
    gLangModelCHS.loadPhraseReplacementMap([[self phraseReplacementDataPath:imeModeCHS] UTF8String]);
}

+ (void)setupDataModelValueConverter
{
    auto converter = [] (string input) {
//        if (!Preferences.chineseConversionEnabled) {
//            return input;
//        }
//
//        if (Preferences.chineseConversionStyle == 0) {
//            return input;
//        }
//
//        NSString *text = [NSString stringWithUTF8String:input.c_str()];
//        if (Preferences.chineseConversionEngine == 1) {
//            text = [VXHanConvert convertToKangXiFrom:text];
//        }
//        else {
//            text = [OpenCCBridge convertToKangXi:text];
//        }
//        return string(text.UTF8String);
        return input;
    };

    gLangModelCHT.setExternalConverter(converter);
    gLangModelCHS.setExternalConverter(converter);
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

+ (BOOL)ensureFileExists:(NSString *)filePath populateWithTemplate:(NSString *)templateBasename extension:(NSString *)ext
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {

        NSURL *templateURL = [[NSBundle mainBundle] URLForResource:templateBasename withExtension:ext];
        NSData *templateData;
        if (templateURL) {
            templateData = [NSData dataWithContentsOfURL:templateURL];
        } else {
            templateData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
        }

        BOOL result = [templateData writeToFile:filePath atomically:YES];
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
    if (![self ensureFileExists:[self userPhrasesDataPath:imeModeCHS] populateWithTemplate:kUserDataTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    if (![self ensureFileExists:[self userPhrasesDataPath:imeModeCHT] populateWithTemplate:kUserDataTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    if (![self ensureFileExists:[self excludedPhrasesDataPath:imeModeCHS] populateWithTemplate:kExcludedPhrasesvChewingTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    if (![self ensureFileExists:[self excludedPhrasesDataPath:imeModeCHT] populateWithTemplate:kExcludedPhrasesvChewingTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    if (![self ensureFileExists:[self phraseReplacementDataPath:imeModeCHS] populateWithTemplate:kPhraseReplacementTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    if (![self ensureFileExists:[self phraseReplacementDataPath:imeModeCHT] populateWithTemplate:kPhraseReplacementTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    return YES;
}

+ (BOOL)checkIfUserPhraseExist:(NSString *)userPhrase key:(NSString *)key NS_SWIFT_NAME(checkIfExist(userPhrase:key:))
{
    string unigramKey = string(key.UTF8String);
    vector<Unigram> unigrams = gLangModelCHT.unigramsForKey(unigramKey);
    string userPhraseString = string(userPhrase.UTF8String);
    for (auto unigram: unigrams) {
        if (unigram.keyValue.value == userPhraseString) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)writeUserPhrase:(NSString *)userPhrase inputMode:(InputMode)mode;
{
    if (![self checkIfUserLanguageModelFilesExist]) {
        return NO;
    }

    BOOL addLineBreakAtFront = NO;
    NSString *path = [self userPhrasesDataPath:mode];

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
                    addLineBreakAtFront = YES;
                }
                [readFile closeFile];
            }
        }
    }

    NSMutableString *currentMarkedPhrase = [NSMutableString string];
    if (addLineBreakAtFront) {
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

//  We use FSEventStream to monitor the change of the user phrase folder,
//  so we don't have to load data here.
//  [self loadUserPhrases];
    return YES;
}

+ (NSString *)dataFolderPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDirectory, YES);
    NSString *appSupportPath = paths[0];
    NSString *userDictPath = [appSupportPath stringByAppendingPathComponent:@"vChewing"];
    return userDictPath;
}

+ (NSString *)userPhrasesDataPath:(InputMode)mode;
{
    NSString *fileName = [mode isEqualToString:imeModeCHT] ? @"userdata-cht.txt" : @"userdata-chs.txt";
    return [[self dataFolderPath] stringByAppendingPathComponent:fileName];
}

+ (NSString *)excludedPhrasesDataPath:(InputMode)mode;
{
    NSString *fileName = [mode isEqualToString:imeModeCHT] ? @"exclude-phrases-cht.txt" : @"exclude-phrases-chs.txt";
    return [[self dataFolderPath] stringByAppendingPathComponent:fileName];
}

+ (NSString *)phraseReplacementDataPath:(InputMode)mode;
{
    NSString *fileName = [mode isEqualToString:imeModeCHT] ? @"phrases-replacement-cht.txt" : @"phrases-replacement-chs.txt";
    return [[self dataFolderPath] stringByAppendingPathComponent:fileName];
}

 + (vChewingLM *)lmCHT
{
    return &gLangModelCHT;
}

+ (vChewingLM *)lmCHS
{
    return &gLangModelCHS;
}

+ (vChewing::UserOverrideModel *)userOverrideModelCHT
{
    return &gUserOverrideModelCHT;
}

+ (vChewing::UserOverrideModel *)userOverrideModelCHS
{
    return &gUserOverrideModelCHS;
}

+ (void)setPhraseReplacementEnabled:(BOOL)phraseReplacementEnabled
{
    gLangModelCHT.setPhraseReplacementEnabled(phraseReplacementEnabled);
    gLangModelCHS.setPhraseReplacementEnabled(phraseReplacementEnabled);
}

@end
