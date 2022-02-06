
#import "mgrLangModel.h"
#import "UserOverrideModel.h"
#import "vChewingLM.h"

NS_ASSUME_NONNULL_BEGIN

@interface mgrLangModel ()
@property (class, readonly, nonatomic) vChewing::vChewingLM *languageModelvChewing;
@property (class, readonly, nonatomic) vChewing::vChewingLM *languageModelPlainBopomofo;
@property (class, readonly, nonatomic) vChewing::UserOverrideModel *userOverrideModel;
@end

NS_ASSUME_NONNULL_END
