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
#import "SSZipArchive.h"

NS_ASSUME_NONNULL_BEGIN

@interface LanguageModelManager : NSObject

+ (void)loadDataModels;
+ (void)deployZipDataFile:(NSString *)filenameWithoutExtension;
+ (void)loadCNSData;
+ (BOOL)checkIfCNSDataExistAndHashMatched;
+ (void)loadUserPhrases;
+ (void)loadUserPhraseReplacement;
+ (BOOL)checkIfUserLanguageModelFilesExist;
+ (BOOL)writeUserPhrase:(NSString *)userPhrase inputMode:(NSString *)inputMode;
+ (NSString *)userPhrasesDataPath:(NSString *)inputMode;
+ (NSString *)excludedPhrasesDataPath:(NSString *)inputMode;
+ (NSString *)phraseReplacementDataPath:(NSString *)inputMode;
+ (NSString *)cnsDataPath;

@property (class, readonly, nonatomic) NSString *dataFolderPath;
@property (class, readonly, nonatomic) vChewing::vChewingLM *languageModelCoreCHT;
@property (class, readonly, nonatomic) vChewing::vChewingLM *languageModelCoreCHS;
@property (class, readonly, nonatomic) vChewing::UserOverrideModel *userOverrideModelCHT;
@property (class, readonly, nonatomic) vChewing::UserOverrideModel *userOverrideModelCHS;
@end

NS_ASSUME_NONNULL_END
