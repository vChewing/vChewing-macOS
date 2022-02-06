
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
@property (class, readonly, nonatomic) NSString *userPhrasesDataPathvChewing;
@property (class, readonly, nonatomic) NSString *excludedPhrasesDataPathvChewing;
@property (class, readonly, nonatomic) NSString *excludedPhrasesDataPathPlainBopomofo;
@property (class, readonly, nonatomic) NSString *phraseReplacementDataPathvChewing;
@property (class, assign, nonatomic) BOOL phraseReplacementEnabled;

@end

/// The following methods are merely for testing.
@interface mgrLangModel ()
+ (void)loadDataModels;
@end

NS_ASSUME_NONNULL_END
