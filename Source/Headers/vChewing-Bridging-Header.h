#import <InputMethodKit/InputMethodKit.h>

@interface IMKCandidates(vChewing) {}

- (unsigned long long)windowLevel;
- (void)setWindowLevel:(unsigned long long)level;
- (BOOL)handleKeyboardEvent:(NSEvent *)event;
- (void)setFontSize:(double)fontSize;

@end
