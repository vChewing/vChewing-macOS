/* 
 *  LanguageModelManager.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import <Foundation/Foundation.h>
#import "FastLM.h"
#import "UserOverrideModel.h"
#import "vChewingLM.h"

NS_ASSUME_NONNULL_BEGIN

@interface LanguageModelManager : NSObject

+ (void)loadDataModels;
+ (void)loadUserPhrases;
+ (void)loadUserPhraseReplacement;
+ (BOOL)checkIfUserLanguageModelFilesExist;
+ (BOOL)writeUserPhrase:(NSString *)userPhrase;

@property (class, readonly, nonatomic) NSString *dataFolderPath;
@property (class, readonly, nonatomic) NSString *userPhrasesDataPathBopomofo;
@property (class, readonly, nonatomic) NSString *excludedPhrasesDataPathBopomofo;
@property (class, readonly, nonatomic) NSString *excludedPhrasesDataPathSimpBopomofo;
@property (class, readonly, nonatomic) NSString *phraseReplacementDataPathBopomofo;
@property (class, readonly, nonatomic) vChewing::vChewingLM *languageModelCoreCHT;
@property (class, readonly, nonatomic) vChewing::vChewingLM *languageModelCoreCHS;
@property (class, readonly, nonatomic) vChewing::UserOverrideModel *userOverrideModel;
@end

NS_ASSUME_NONNULL_END
