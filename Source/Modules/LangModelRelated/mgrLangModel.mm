// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "mgrLangModel.h"
#import "LMConsolidator.h"
#import "mgrLangModel_Privates.h"
#import "vChewing-Swift.h"

static const int kUserOverrideModelCapacity = 500;
static const double kObservedOverrideHalflife = 5400.0;

static vChewing::LMInstantiator gLangModelCHT;
static vChewing::LMInstantiator gLangModelCHS;
static vChewing::UserOverrideModel gUserOverrideModelCHT(kUserOverrideModelCapacity, kObservedOverrideHalflife);
static vChewing::UserOverrideModel gUserOverrideModelCHS(kUserOverrideModelCapacity, kObservedOverrideHalflife);

@implementation mgrLangModel

// 這個函數無法遷移至 Swift
static void LTLoadLanguageModelFile(NSString *filenameWithoutExtension, vChewing::LMInstantiator &lm)
{
    NSString *dataPath = [mgrLangModel getBundleDataPath:filenameWithoutExtension];
    lm.loadLanguageModel([dataPath UTF8String]);
}

// 這個函數無法遷移至 Swift
+ (void)loadDataModels
{
    if (!gLangModelCHT.isDataModelLoaded())
        LTLoadLanguageModelFile(@"data-cht", gLangModelCHT);
    if (!gLangModelCHT.isMiscDataLoaded())
        gLangModelCHT.loadMiscData([[self getBundleDataPath:@"data-zhuyinwen"] UTF8String]);
    if (!gLangModelCHT.isSymbolDataLoaded())
        gLangModelCHT.loadSymbolData([[self getBundleDataPath:@"data-symbols"] UTF8String]);
    if (!gLangModelCHT.isCNSDataLoaded())
        gLangModelCHT.loadCNSData([[self getBundleDataPath:@"char-kanji-cns"] UTF8String]);

    // -----------------
    if (!gLangModelCHS.isDataModelLoaded())
        LTLoadLanguageModelFile(@"data-chs", gLangModelCHS);
    if (!gLangModelCHS.isMiscDataLoaded())
        gLangModelCHS.loadMiscData([[self getBundleDataPath:@"data-zhuyinwen"] UTF8String]);
    if (!gLangModelCHS.isSymbolDataLoaded())
        gLangModelCHS.loadSymbolData([[self getBundleDataPath:@"data-symbols"] UTF8String]);
    if (!gLangModelCHS.isCNSDataLoaded())
        gLangModelCHS.loadCNSData([[self getBundleDataPath:@"char-kanji-cns"] UTF8String]);
}

// 這個函數無法遷移至 Swift
+ (void)loadDataModel:(InputMode)mode
{
    if ([mode isEqualToString:imeModeCHT])
    {
        if (!gLangModelCHT.isDataModelLoaded())
            LTLoadLanguageModelFile(@"data-cht", gLangModelCHT);
        if (!gLangModelCHT.isMiscDataLoaded())
            gLangModelCHT.loadMiscData([[self getBundleDataPath:@"data-zhuyinwen"] UTF8String]);
        if (!gLangModelCHT.isSymbolDataLoaded())
            gLangModelCHT.loadSymbolData([[self getBundleDataPath:@"data-symbols"] UTF8String]);
        if (!gLangModelCHT.isCNSDataLoaded())
            gLangModelCHT.loadCNSData([[self getBundleDataPath:@"char-kanji-cns"] UTF8String]);
    }

    if ([mode isEqualToString:imeModeCHS])
    {
        if (!gLangModelCHS.isDataModelLoaded())
            LTLoadLanguageModelFile(@"data-chs", gLangModelCHS);
        if (!gLangModelCHS.isMiscDataLoaded())
            gLangModelCHS.loadMiscData([[self getBundleDataPath:@"data-zhuyinwen"] UTF8String]);
        if (!gLangModelCHS.isSymbolDataLoaded())
            gLangModelCHS.loadSymbolData([[self getBundleDataPath:@"data-symbols"] UTF8String]);
        if (!gLangModelCHS.isCNSDataLoaded())
            gLangModelCHS.loadCNSData([[self getBundleDataPath:@"char-kanji-cns"] UTF8String]);
    }
}

// 這個函數無法遷移至 Swift
+ (void)loadUserPhrases
{
    gLangModelCHT.loadUserPhrases([[self userPhrasesDataPath:imeModeCHT] UTF8String],
                                  [[self excludedPhrasesDataPath:imeModeCHT] UTF8String]);
    gLangModelCHS.loadUserPhrases([[self userPhrasesDataPath:imeModeCHS] UTF8String],
                                  [[self excludedPhrasesDataPath:imeModeCHS] UTF8String]);
    gLangModelCHT.loadUserSymbolData([[self userSymbolDataPath:imeModeCHT] UTF8String]);
    gLangModelCHS.loadUserSymbolData([[self userSymbolDataPath:imeModeCHS] UTF8String]);
}

// 這個函數無法遷移至 Swift
+ (void)loadUserAssociatedPhrases
{
    gLangModelCHT.loadUserAssociatedPhrases([[self userAssociatedPhrasesDataPath:imeModeCHT] UTF8String]);
    gLangModelCHS.loadUserAssociatedPhrases([[self userAssociatedPhrasesDataPath:imeModeCHS] UTF8String]);
}

// 這個函數無法遷移至 Swift
+ (void)loadUserPhraseReplacement
{
    gLangModelCHT.loadPhraseReplacementMap([[self phraseReplacementDataPath:imeModeCHT] UTF8String]);
    gLangModelCHS.loadPhraseReplacementMap([[self phraseReplacementDataPath:imeModeCHS] UTF8String]);
}

// 這個函數無法遷移至 Swift
+ (BOOL)checkIfUserPhraseExist:(NSString *)userPhrase
                     inputMode:(InputMode)mode
                           key:(NSString *)key NS_SWIFT_NAME(checkIfUserPhraseExist(userPhrase:mode:key:))
{
    string unigramKey = string(key.UTF8String);
    vector<vChewing::Unigram> unigrams = [mode isEqualToString:imeModeCHT] ? gLangModelCHT.unigramsForKey(unigramKey)
                                                                           : gLangModelCHS.unigramsForKey(unigramKey);
    string userPhraseString = string(userPhrase.UTF8String);
    for (auto unigram : unigrams)
    {
        if (unigram.keyValue.value == userPhraseString)
        {
            return YES;
        }
    }
    return NO;
}

// 這個函數無法遷移至 Swift
+ (vChewing::LMInstantiator *)lmCHT
{
    return &gLangModelCHT;
}

// 這個函數無法遷移至 Swift
+ (vChewing::LMInstantiator *)lmCHS
{
    return &gLangModelCHS;
}

// 這個函數無法遷移至 Swift
+ (vChewing::UserOverrideModel *)userOverrideModelCHT
{
    return &gUserOverrideModelCHT;
}

// 這個函數無法遷移至 Swift
+ (vChewing::UserOverrideModel *)userOverrideModelCHS
{
    return &gUserOverrideModelCHS;
}

// 這個函數無法遷移至 Swift
+ (void)setPhraseReplacementEnabled:(BOOL)phraseReplacementEnabled
{
    gLangModelCHT.setPhraseReplacementEnabled(phraseReplacementEnabled);
    gLangModelCHS.setPhraseReplacementEnabled(phraseReplacementEnabled);
}

// 這個函數無法遷移至 Swift
+ (void)setCNSEnabled:(BOOL)cnsEnabled
{
    gLangModelCHT.setCNSEnabled(cnsEnabled);
    gLangModelCHS.setCNSEnabled(cnsEnabled);
}

// 這個函數無法遷移至 Swift
+ (void)setSymbolEnabled:(BOOL)symbolEnabled
{
    gLangModelCHT.setSymbolEnabled(symbolEnabled);
    gLangModelCHS.setSymbolEnabled(symbolEnabled);
}

@end
