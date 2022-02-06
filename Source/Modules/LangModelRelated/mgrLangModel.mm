
#import "mgrLangModel.h"
#import "mgrLangModel_Privates.h"
#import "vChewing-Swift.h"

using namespace std;
using namespace vChewing;

static const int kUserOverrideModelCapacity = 500;
static const double kObservedOverrideHalflife = 5400.0;  // 1.5 hr.

static vChewingLM gLangModelCHT;
static vChewingLM gLangModelCHS;
static UserOverrideModel gUserOverrideModel(kUserOverrideModelCapacity, kObservedOverrideHalflife);

static NSString *const kUserDataTemplateName = @"template-data";
static NSString *const kExcludedPhrasesvChewingTemplateName = @"template-exclude-phrases";
static NSString *const kExcludedPhrasesPlainBopomofoTemplateName = @"template-exclude-phrases-plain-bpmf";
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
    if ([mode isEqualToString:InputModeBopomofo]) {
        if (!gLangModelCHT.isDataModelLoaded()) {
            LTLoadLanguageModelFile(@"data-cht", gLangModelCHT);
        }
    }

    if ([mode isEqualToString:InputModePlainBopomofo]) {
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
    gLangModelCHT.loadUserPhrases([[self userPhrasesDataPathvChewing] UTF8String], [[self excludedPhrasesDataPathvChewing] UTF8String]);
    gLangModelCHS.loadUserPhrases(NULL, [[self excludedPhrasesDataPathPlainBopomofo] UTF8String]);
}

+ (void)loadUserPhraseReplacement
{
    gLangModelCHT.loadPhraseReplacementMap([[self phraseReplacementDataPathvChewing] UTF8String]);
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
    if (![self ensureFileExists:[self userPhrasesDataPathvChewing] populateWithTemplate:kUserDataTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    if (![self ensureFileExists:[self excludedPhrasesDataPathvChewing] populateWithTemplate:kExcludedPhrasesvChewingTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    if (![self ensureFileExists:[self excludedPhrasesDataPathPlainBopomofo] populateWithTemplate:kExcludedPhrasesPlainBopomofoTemplateName extension:kTemplateExtension]) {
        return NO;
    }
    if (![self ensureFileExists:[self phraseReplacementDataPathvChewing] populateWithTemplate:kPhraseReplacementTemplateName extension:kTemplateExtension]) {
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

+ (BOOL)writeUserPhrase:(NSString *)userPhrase
{
    if (![self checkIfUserLanguageModelFilesExist]) {
        return NO;
    }

    BOOL addLineBreakAtFront = NO;
    NSString *path = [self userPhrasesDataPathvChewing];

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

+ (NSString *)userPhrasesDataPathvChewing
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"userdata-cht.txt"];
}

+ (NSString *)excludedPhrasesDataPathvChewing
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"exclude-phrases-cht.txt"];
}

+ (NSString *)excludedPhrasesDataPathPlainBopomofo
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"exclude-phrases-chs.txt"];
}

+ (NSString *)phraseReplacementDataPathvChewing
{
    return [[self dataFolderPath] stringByAppendingPathComponent:@"phrases-replacement-cht.txt"];
}

 + (vChewingLM *)languageModelvChewing
{
    return &gLangModelCHT;
}

+ (vChewingLM *)languageModelPlainBopomofo
{
    return &gLangModelCHS;
}

+ (vChewing::UserOverrideModel *)userOverrideModel
{
    return &gUserOverrideModel;
}

+ (BOOL)phraseReplacementEnabled
{
    return gLangModelCHT.phraseReplacementEnabled();
}

+ (void)setPhraseReplacementEnabled:(BOOL)phraseReplacementEnabled
{
    gLangModelCHT.setPhraseReplacementEnabled(phraseReplacementEnabled);
}

@end
