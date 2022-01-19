/* 
 *  InputMethodController.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "Mandarin.h"
#import "Gramambular.h"
#import "vChewingLM.h"
#import "UserOverrideModel.h"
#import "frmAboutWindow.h"

@interface vChewingInputMethodController : IMKInputController
{
@private
    // the reading buffer that takes user input
    Taiyan::Mandarin::BopomofoReadingBuffer* _bpmfReadingBuffer;

    // language model
    vChewing::vChewingLM *_languageModel;

    // user override model
    vChewing::UserOverrideModel *_userOverrideModel;
    
    // the grid (lattice) builder for the unigrams (and bigrams)
    Taiyan::Gramambular::BlockReadingBuilder* _builder;

    // latest walked path (trellis) using the Viterbi algorithm
    std::vector<Taiyan::Gramambular::NodeAnchor> _walkedNodes;

    // the latest composing buffer that is updated to the foreground app
    NSMutableString *_composingBuffer;
    NSInteger _latestReadingCursor;

    // the current text input client; we need to keep this when candidate panel is on
    id _currentCandidateClient;

    // a special deferred client for Terminal.app fix
    id _currentDeferredClient;
    
    // currently available candidates
    NSMutableArray *_candidates;

    // current input mode
    NSString *_inputMode;
}
@end
