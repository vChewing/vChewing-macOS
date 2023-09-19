#import "Preferences.h"

@implementation Preferences

-(void) mainViewDidLoad {
  [[self mainView] setFrameSize: NSMakeSize(420.0f, 330.0f)];
  [_lblDisclaimer sizeToFit];
  [_lblDisclaimer setFrameSize: NSMakeSize(384.0f, 296.0f)];
}

@end
