//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "frmAboutWindow.h"
#import <Foundation/Foundation.h> // @import Foundation;
@interface LanguageModelManager : NSObject
+ (void)loadDataModels;
+ (void)loadUserPhrasesModel;
@end
