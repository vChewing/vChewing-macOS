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

#import <Foundation/Foundation.h>
#import "KeyHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface mgrLangModel : NSObject

+ (void)loadDataModel:(InputMode)mode;
+ (void)loadUserPhrases;
+ (void)loadUserAssociatedPhrases;
+ (void)loadUserPhraseReplacement;
+ (void)setupDataModelValueConverter;
+ (BOOL)checkIfUserLanguageModelFilesExist;
+ (BOOL)checkIfUserDataFolderExists;

+ (BOOL)checkIfUserPhraseExist:(NSString *)userPhrase inputMode:(InputMode)mode key:(NSString *)key NS_SWIFT_NAME(checkIfUserPhraseExist(userPhrase:mode:key:));
+ (BOOL)writeUserPhrase:(NSString *)userPhrase inputMode:(InputMode)mode areWeDuplicating:(BOOL)areWeDuplicating;
+ (void)setPhraseReplacementEnabled:(BOOL)phraseReplacementEnabled;
+ (void)setCNSEnabled:(BOOL)cnsEnabled;
+ (void)setSymbolEnabled:(BOOL)symbolEnabled;

+ (NSString *)specifyBundleDataPath:(NSString *)filename;
+ (NSString *)userPhrasesDataPath:(InputMode)mode;
+ (NSString *)userSymbolDataPath:(InputMode)mode;
+ (NSString *)userAssociatedPhrasesDataPath:(InputMode)mode;
+ (NSString *)excludedPhrasesDataPath:(InputMode)mode;
+ (NSString *)phraseReplacementDataPath:(InputMode)mode;

@property (class, readonly, nonatomic) NSString *dataFolderPath;

@end

/// The following methods are merely for testing.
@interface mgrLangModel ()
+ (void)loadDataModels;
@end

NS_ASSUME_NONNULL_END
