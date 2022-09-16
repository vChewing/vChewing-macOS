#import <InputMethodKit/InputMethodKit.h>

@interface IMKCandidates(vChewing) {}

- (unsigned long long)windowLevel API_AVAILABLE(macosx(10.14));
- (void)setWindowLevel:(unsigned long long)level API_AVAILABLE(macosx(10.14));
- (BOOL)handleKeyboardEvent:(NSEvent *)event API_AVAILABLE(macosx(10.14));
- (void)setFontSize:(double)fontSize API_AVAILABLE(macosx(10.14));

@end
