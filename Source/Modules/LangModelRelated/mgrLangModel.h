
#import <Foundation/Foundation.h>
#import "KeyHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface mgrLangModel : NSObject

+ (void)loadDataModel:(InputMode)mode;
+ (void)loadUserPhrases;
+ (void)loadUserPhraseReplacement;
+ (void)setupDataModelValueConverter;
+ (BOOL)checkIfUserLanguageModelFilesExist;

+ (BOOL)checkIfUserPhraseExist:(NSString *)userPhrase key:(NSString *)key NS_SWIFT_NAME(checkIfExist(userPhrase:key:));
+ (BOOL)writeUserPhrase:(NSString *)userPhrase;

@property (class, readonly, nonatomic) NSString *dataFolderPath;
@property (class, readonly, nonatomic) NSString *userPhrasesDataPathCHT;
@property (class, readonly, nonatomic) NSString *userPhrasesDataPathCHS;
@property (class, readonly, nonatomic) NSString *excludedPhrasesDataPathCHT;
@property (class, readonly, nonatomic) NSString *excludedPhrasesDataPathCHS;
@property (class, readonly, nonatomic) NSString *phraseReplacementDataPathCHT;
@property (class, readonly, nonatomic) NSString *phraseReplacementDataPathCHS;
@property (class, assign, nonatomic) BOOL phraseReplacementEnabled;

@end

/// The following methods are merely for testing.
@interface mgrLangModel ()
+ (void)loadDataModels;
@end

NS_ASSUME_NONNULL_END
