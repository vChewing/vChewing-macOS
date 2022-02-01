/*
 *  KeyHandler.h
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import <Foundation/Foundation.h>
#import <string>
#import "vChewing-Swift.h"

@class KeyHandlerInput;
@class InputState;
@class InputStateInputting;
@class InputStateMarking;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kBopomofoModeIdentifierCHS;
extern NSString *const kBopomofoModeIdentifierCHT;

@class KeyHandler;

@protocol KeyHandlerDelegate <NSObject>
- (VTCandidateController *)candidateControllerForKeyHandler:(KeyHandler *)keyHandler;
- (void)keyHandler:(KeyHandler *)keyHandler didSelectCandidateAtIndex:(NSInteger)index candidateController:(VTCandidateController *)controller;
- (BOOL)keyHandler:(KeyHandler *)keyHandler didRequestWriteUserPhraseWithState:(InputStateMarking *)state;
@end

@interface KeyHandler : NSObject

- (BOOL)handleInput:(KeyHandlerInput *)input
              state:(InputState *)state
      stateCallback:(void (^)(InputState *))stateCallback
candidateSelectionCallback:(void (^)(void))candidateSelectionCallback
      errorCallback:(void (^)(void))errorCallback;

- (void)syncWithPreferences;
- (void)fixNodeWithValue:(std::string)value;
- (void)clear;

- (InputStateInputting *)_buildInputtingState;

@property (strong, nonatomic) NSString *inputMode;
@property (weak, nonatomic) id <KeyHandlerDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
