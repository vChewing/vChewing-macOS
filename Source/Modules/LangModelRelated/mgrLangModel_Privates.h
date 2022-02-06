
#import "mgrLangModel.h"
#import "UserOverrideModel.h"
#import "vChewingLM.h"

NS_ASSUME_NONNULL_BEGIN

@interface mgrLangModel ()
@property (class, readonly, nonatomic) vChewing::vChewingLM *lmCHT;
@property (class, readonly, nonatomic) vChewing::vChewingLM *lmCHS;
@property (class, readonly, nonatomic) vChewing::UserOverrideModel *userOverrideModelCHT;
@property (class, readonly, nonatomic) vChewing::UserOverrideModel *userOverrideModelCHS;
@end

NS_ASSUME_NONNULL_END
