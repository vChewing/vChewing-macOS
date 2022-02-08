
#import <Foundation/Foundation.h>

@class KeyHandlerInput;
@class InputState;

NS_ASSUME_NONNULL_BEGIN

typedef NSString *const InputMode NS_TYPED_ENUM;
extern InputMode imeModeCHT;
extern InputMode imeModeCHS;
extern InputMode imeModeNULL;

@class KeyHandler;

@protocol KeyHandlerDelegate <NSObject>
- (id)candidateControllerForKeyHandler:(KeyHandler *)keyHandler;
- (void)keyHandler:(KeyHandler *)keyHandler didSelectCandidateAtIndex:(NSInteger)index candidateController:(id)controller;
- (BOOL)keyHandler:(KeyHandler *)keyHandler didRequestWriteUserPhraseWithState:(InputState *)state;
@end

@interface KeyHandler : NSObject

- (BOOL)handleInput:(KeyHandlerInput *)input
              state:(InputState *)state
      stateCallback:(void (^)(InputState *))stateCallback
      errorCallback:(void (^)(void))errorCallback NS_SWIFT_NAME(handle(input:state:stateCallback:errorCallback:));

- (void)syncWithPreferences;
- (void)fixNodeWithValue:(NSString *)value NS_SWIFT_NAME(fixNode(value:));
- (void)clear;

- (InputState *)buildInputtingState;
- (nullable InputState *)buildAssociatePhraseStateWithKey:(NSString *)key useVerticalMode:(BOOL)useVerticalMode;

@property (strong, nonatomic) InputMode inputMode;
@property (weak, nonatomic) id <KeyHandlerDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
