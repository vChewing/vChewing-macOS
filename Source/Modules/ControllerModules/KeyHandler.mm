// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "KeyHandler.h"
#import "Gramambular.h"
#import "LMInstantiator.h"
#import "Mandarin.h"
#import "UserOverrideModel.h"
#import "mgrLangModel_Privates.h"
#import "vChewing-Swift.h"
#import <string>

InputMode imeModeCHS = ctlInputMethod.kIMEModeCHS;
InputMode imeModeCHT = ctlInputMethod.kIMEModeCHT;
InputMode imeModeNULL = ctlInputMethod.kIMEModeNULL;

typedef vChewing::LMInstantiator BaseLM;
typedef vChewing::UserOverrideModel UserOverrideLM;
typedef Gramambular::BlockReadingBuilder BlockBuilder;
typedef Mandarin::BopomofoReadingBuffer PhoneticBuffer;

static const double kEpsilon = 0.000001;

static double FindHighestScore(const std::vector<Gramambular::NodeAnchor> &nodes, double epsilon)
{
    double highestScore = 0.0;
    for (auto ni = nodes.begin(), ne = nodes.end(); ni != ne; ++ni)
    {
        double score = ni->node->highestUnigramScore();
        if (score > highestScore)
            highestScore = score;
    }
    return highestScore + epsilon;
}

class NodeAnchorDescendingSorter
{
  public:
    bool operator()(const Gramambular::NodeAnchor &a, const Gramambular::NodeAnchor &b) const
    {
        return a.node->key().length() > b.node->key().length();
    }
};

// if DEBUG is defined, a DOT file (GraphViz format) will be written to the
// specified path every time the grid is walked
#if DEBUG
static NSString *const kGraphVizOutputfile = @"/tmp/vChewing-visualization.dot";
#endif

@implementation KeyHandler
{
    // the reading buffer that takes user input
    PhoneticBuffer *_bpmfReadingBuffer;

    // language model
    BaseLM *_languageModel;

    // user override model
    UserOverrideLM *_userOverrideModel;

    // the grid (lattice) builder for the unigrams (and bigrams)
    BlockBuilder *_builder;

    // latest walked path (trellis) using the Viterbi algorithm
    std::vector<Gramambular::NodeAnchor> _walkedNodes;

    NSString *_inputMode;
}

//@synthesize inputMode = _inputMode;
@synthesize delegate = _delegate;

- (NSString *)inputMode
{
    return _inputMode;
}

- (BOOL)isBuilderEmpty
{
    return (_builder->grid().width() == 0);
}

- (void)setInputMode:(NSString *)value
{
    // 下面這句的「isKindOfClass」是做類型檢查，
    // 為了應對出現輸入法 plist 被改壞掉這樣的極端情況。
    BOOL isCHS = [value isKindOfClass:[NSString class]] && [value isEqual:imeModeCHS];

    // 緊接著將新的簡繁輸入模式提報給 ctlInputMethod:
    ctlInputMethod.currentInputMode = isCHS ? imeModeCHS : imeModeCHT;

    // 拿當前的 _inputMode 與 ctlInputMethod 的提報結果對比，不同的話則套用新設定：
    if (![_inputMode isEqualToString:ctlInputMethod.currentInputMode])
    {
        _inputMode = ctlInputMethod.currentInputMode;

        // Reinitiate language models if necessary
        [self setInputModesToLM:isCHS];

        // Synchronize the sub-languageModel state settings to the new LM.
        [self syncBaseLMPrefs];

        [self removeBuilderAndReset:YES];

        if (![self isPhoneticReadingBufferEmpty])
            [self clearPhoneticReadingBuffer];
    }
}

- (void)dealloc
{ // clean up everything
    if (_bpmfReadingBuffer)
        delete _bpmfReadingBuffer;
    if (_builder)
        [self removeBuilderAndReset:NO];
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self ensurePhoneticParser];
        [self setInputMode:ctlInputMethod.currentInputMode];
    }
    return self;
}

// NON-SWIFTIFIABLE
- (void)fixNodeWithValue:(NSString *)value
{
    size_t cursorIndex = [self _actualCandidateCursorIndex];
    std::string stringValue(value.UTF8String);
    Gramambular::NodeAnchor selectedNode = _builder->grid().fixNodeSelectedCandidate(cursorIndex, stringValue);
    if (!mgrPrefs.useSCPCTypingMode)
    { // 不要針對逐字選字模式啟用臨時半衰記憶模型。
        // If the length of the readings and the characters do not match,
        // it often means it is a special symbol and it should not be stored
        // in the user override model.
        BOOL addToOverrideModel = YES;
        if (selectedNode.spanningLength != [value count])
            addToOverrideModel = NO;

        if (addToOverrideModel)
        {
            double score = selectedNode.node->scoreForCandidate(stringValue);
            if (score <= -12) // 威注音的 SymbolLM 的 Score 是 -12。
                addToOverrideModel = NO;
        }
        if (addToOverrideModel)
            _userOverrideModel->observe(_walkedNodes, cursorIndex, stringValue, [[NSDate date] timeIntervalSince1970]);
    }
    [self _walk];

    if (mgrPrefs.moveCursorAfterSelectingCandidate)
    {
        size_t nextPosition = 0;
        for (auto node : _walkedNodes)
        {
            if (nextPosition >= cursorIndex)
                break;
            nextPosition += node.spanningLength;
        }
        if (nextPosition <= _builder->length())
            _builder->setCursorIndex(nextPosition);
    }
}

// NON-SWIFTIFIABLE
- (void)clear
{
    [self clearPhoneticReadingBuffer];
    _builder->clear();
    _walkedNodes.clear();
}

- (std::string)_currentMandarinParser
{
    return std::string(mgrPrefs.mandarinParserName.UTF8String) + std::string("_");
}

// MARK: - Handling Input

- (BOOL)handleInput:(keyParser *)input
              state:(InputState *)inState
      stateCallback:(void (^)(InputState *))stateCallback
      errorCallback:(void (^)(void))errorCallback
{
    InputState *state = inState;
    UniChar charCode = input.charCode;
    vChewingEmacsKey emacsKey = input.emacsKey;

    // if the inputText is empty, it's a function key combination, we ignore it
    if (!input.inputText.length)
        return NO;

    // if the composing buffer is empty and there's no reading, and there is some function key combination, we ignore it
    BOOL isFunctionKey =
        ([input isCommandHold] || [input isOptionHotKey] || [input isNumericPad]) || [input isControlHotKey];
    if (![state isKindOfClass:[InputStateNotEmpty class]] &&
        ![state isKindOfClass:[InputStateAssociatedPhrases class]] && isFunctionKey)
        return NO;

    // Caps Lock processing: if Caps Lock is ON, temporarily disable bopomofo.
    // Note: Alphanumerical mode processing.
    if ([input isBackSpace] || [input isEnter] || [input isAbsorbedArrowKey] || [input isExtraChooseCandidateKey] ||
        [input isExtraChooseCandidateKeyReverse] || [input isCursorForward] || [input isCursorBackward])
    {
        // do nothing if backspace is pressed -- we ignore the key
    }
    else if ([input isCapsLockOn])
    {
        // process all possible combination, we hope.
        [self clear];
        InputStateEmpty *emptyState = [[InputStateEmpty alloc] init];
        stateCallback(emptyState);

        // When shift is pressed, don't do further processing, since it outputs capital letter anyway.
        if ([input isShiftHold])
            return NO;

        // if ASCII but not printable, don't use insertText:replacementRange: as many apps don't handle non-ASCII char
        // insertions.
        if (charCode < 0x80 && !isprint(charCode))
            return NO;

        // commit everything in the buffer.
        InputStateCommitting *committingState =
            [[InputStateCommitting alloc] initWithPoppedText:[input.inputText lowercaseString]];
        stateCallback(committingState);
        stateCallback(emptyState);

        return YES;
    }

    if ([input isNumericPad])
    {
        if (![input isLeft] && ![input isRight] && ![input isDown] && ![input isUp] && ![input isSpace] &&
            isprint(charCode))
        {
            [self clear];
            InputStateEmpty *emptyState = [[InputStateEmpty alloc] init];
            stateCallback(emptyState);
            InputStateCommitting *committing =
                [[InputStateCommitting alloc] initWithPoppedText:[input.inputText lowercaseString]];
            stateCallback(committing);
            stateCallback(emptyState);
            return YES;
        }
    }

    // MARK: Handle Candidates
    if ([state isKindOfClass:[InputStateChoosingCandidate class]])
        return [self _handleCandidateState:state input:input stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Handle Associated Phrases
    if ([state isKindOfClass:[InputStateAssociatedPhrases class]])
    {
        BOOL result = [self _handleCandidateState:state
                                            input:input
                                    stateCallback:stateCallback
                                    errorCallback:errorCallback];
        if (result)
            return YES;
        state = [[InputStateEmpty alloc] init];
        stateCallback(state);
    }

    // MARK: Handle Marking
    if ([state isKindOfClass:[InputStateMarking class]])
    {
        InputStateMarking *marking = (InputStateMarking *)state;
        if ([self _handleMarkingState:(InputStateMarking *)state
                                input:input
                        stateCallback:stateCallback
                        errorCallback:errorCallback])
            return YES;
        state = [marking convertToInputting];
        stateCallback(state);
    }

    bool composeReading = false;
    BOOL skipBpmfHandling = [input isReservedKey] || [input isControlHold] || [input isOptionHold];

    // MARK: Handle BPMF Keys

    // see if it's valid BPMF reading
    if (!skipBpmfHandling && [self chkKeyValidity:charCode])
    {
        [self combinePhoneticReadingBufferKey:charCode];

        // if we have a tone marker, we have to insert the reading to the
        // builder in other words, if we don't have a tone marker, we just
        // update the composing buffer
        composeReading = [self checkWhetherToneMarkerConfirmsPhoneticReadingBuffer];
        if (!composeReading)
        {
            InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
            stateCallback(inputting);
            return YES;
        }
    }

    // see if we have composition if Enter/Space is hit and buffer is not empty
    // we use "OR" conditioning so that the tone marker key is also taken into account
    composeReading |= (![self isPhoneticReadingBufferEmpty] && ([input isSpace] || [input isEnter]));
    if (composeReading)
    {
        // combine the reading
        std::string reading = [[self getSyllableCompositionFromPhoneticReadingBuffer] UTF8String];

        // see if we have an unigram for this
        if (!_languageModel->hasUnigramsForKey(reading))
        {
            [IME prtDebugIntel:@"B49C0979"];
            errorCallback();
            InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
            stateCallback(inputting);
            return YES;
        }

        // and insert it into the lattice
        _builder->insertReadingAtCursor(reading);

        // then walk the lattice
        NSString *poppedText = [self _popOverflowComposingTextAndWalk];

        // get user override model suggestion
        std::string overrideValue = (mgrPrefs.useSCPCTypingMode)
                                        ? ""
                                        : _userOverrideModel->suggest(_walkedNodes, _builder->cursorIndex(),
                                                                      [[NSDate date] timeIntervalSince1970]);

        if (!overrideValue.empty())
        {
            size_t cursorIndex = [self _actualCandidateCursorIndex];
            std::vector<Gramambular::NodeAnchor> nodes = _builder->grid().nodesCrossingOrEndingAt(cursorIndex);
            double highestScore = FindHighestScore(nodes, kEpsilon);
            _builder->grid().overrideNodeScoreForSelectedCandidate(cursorIndex, overrideValue,
                                                                   static_cast<float>(highestScore));
        }

        // then update the text
        [self clearPhoneticReadingBuffer];

        InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
        inputting.poppedText = poppedText;
        stateCallback(inputting);

        if (mgrPrefs.useSCPCTypingMode)
        {
            InputStateChoosingCandidate *choosingCandidates = [self _buildCandidateState:inputting
                                                                         useVerticalMode:input.useVerticalMode];
            if (choosingCandidates.candidates.count == 1)
            {
                [self clear];
                NSString *text = choosingCandidates.candidates.firstObject;
                InputStateCommitting *committing = [[InputStateCommitting alloc] initWithPoppedText:text];
                stateCallback(committing);

                if (!mgrPrefs.associatedPhrasesEnabled)
                {
                    InputStateEmpty *empty = [[InputStateEmpty alloc] init];
                    stateCallback(empty);
                }
                else
                {
                    InputStateAssociatedPhrases *associatedPhrases =
                        (InputStateAssociatedPhrases *)[self buildAssociatePhraseStateWithKey:text
                                                                              useVerticalMode:input.useVerticalMode];
                    if (associatedPhrases)
                        stateCallback(associatedPhrases);
                    else
                    {
                        InputStateEmpty *empty = [[InputStateEmpty alloc] init];
                        stateCallback(empty);
                    }
                }
            }
            else
                stateCallback(choosingCandidates);
        }

        // and tells the client that the key is consumed
        return YES;
    }

    // MARK: Calling candidate window using Space or Down or PageUp / PageDn.
    if ([self isPhoneticReadingBufferEmpty] && [state isKindOfClass:[InputStateNotEmpty class]] &&
        ([input isExtraChooseCandidateKey] || [input isExtraChooseCandidateKeyReverse] || [input isSpace] ||
         [input isPageDown] || [input isPageUp] || [input isTab] ||
         (input.useVerticalMode && ([input isVerticalModeOnlyChooseCandidateKey]))))
    {
        if ([input isSpace])
        {
            // if the spacebar is NOT set to be a selection key
            if ([input isShiftHold] || !mgrPrefs.chooseCandidateUsingSpace)
            {
                if (_builder->cursorIndex() >= _builder->length())
                {
                    NSString *composingBuffer = [(InputStateNotEmpty *)state composingBuffer];
                    if (composingBuffer.length)
                    {
                        InputStateCommitting *committing =
                            [[InputStateCommitting alloc] initWithPoppedText:composingBuffer];
                        stateCallback(committing);
                    }
                    [self clear];
                    InputStateCommitting *committing = [[InputStateCommitting alloc] initWithPoppedText:@" "];
                    stateCallback(committing);
                    InputStateEmpty *empty = [[InputStateEmpty alloc] init];
                    stateCallback(empty);
                }
                else if (_languageModel->hasUnigramsForKey(" "))
                {
                    _builder->insertReadingAtCursor(" ");
                    NSString *poppedText = [self _popOverflowComposingTextAndWalk];
                    InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
                    inputting.poppedText = poppedText;
                    stateCallback(inputting);
                }
                return YES;
            }
        }
        InputStateChoosingCandidate *choosingCandidates = [self _buildCandidateState:(InputStateNotEmpty *)state
                                                                     useVerticalMode:input.useVerticalMode];
        stateCallback(choosingCandidates);
        return YES;
    }

    // MARK: Esc
    if ([input isESC])
        return [self _handleEscWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Cursor backward
    if ([input isCursorBackward] || emacsKey == vChewingEmacsKeyBackward)
        return [self _handleBackwardWithState:state
                                        input:input
                                stateCallback:stateCallback
                                errorCallback:errorCallback];

    // MARK:  Cursor forward
    if ([input isCursorForward] || emacsKey == vChewingEmacsKeyForward)
        return [self _handleForwardWithState:state input:input stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Home
    if ([input isHome] || emacsKey == vChewingEmacsKeyHome)
        return [self _handleHomeWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: End
    if ([input isEnd] || emacsKey == vChewingEmacsKeyEnd)
        return [self _handleEndWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Ctrl+PgLf or Shift+PgLf
    if (([input isControlHold] || [input isShiftHold]) && ([input isOptionHold] && [input isLeft]))
        return [self _handleHomeWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Ctrl+PgRt or Shift+PgRt
    if (([input isControlHold] || [input isShiftHold]) && ([input isOptionHold] && [input isRight]))
        return [self _handleEndWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: AbsorbedArrowKey
    if ([input isAbsorbedArrowKey] || [input isExtraChooseCandidateKey] || [input isExtraChooseCandidateKeyReverse])
        return [self _handleAbsorbedArrowKeyWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Backspace
    if ([input isBackSpace])
        return [self _handleBackspaceWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Delete
    if ([input isDelete] || emacsKey == vChewingEmacsKeyDelete)
        return [self _handleDeleteWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Enter
    if ([input isEnter])
        return ([input isControlHold] && [input isCommandHold])
                   ? [self _handleCtrlCommandEnterWithState:state
                                              stateCallback:stateCallback
                                              errorCallback:errorCallback]
                   : [self _handleEnterWithState:state stateCallback:stateCallback errorCallback:errorCallback];

    // MARK: Punctuation list
    if ([input isSymbolMenuPhysicalKey] && ![input isShiftHold])
    {
        if (![input isOptionHold])
        {
            if (_languageModel->hasUnigramsForKey("_punctuation_list"))
            {
                if ([self isPhoneticReadingBufferEmpty])
                {
                    _builder->insertReadingAtCursor(string("_punctuation_list"));
                    NSString *poppedText = [self _popOverflowComposingTextAndWalk];
                    InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
                    inputting.poppedText = poppedText;
                    stateCallback(inputting);
                    InputStateChoosingCandidate *choosingCandidate = [self _buildCandidateState:inputting
                                                                                useVerticalMode:input.useVerticalMode];
                    stateCallback(choosingCandidate);
                }
                else
                { // If there is still unfinished bpmf reading, ignore the punctuation
                    [IME prtDebugIntel:@"17446655"];
                    errorCallback();
                }
                return YES;
            }
        }
        else
        {
            // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
            // 於是這裡用「模擬一次 Enter 鍵的操作」使其代為執行這個 commit buffer 的動作。
            [self _handleEnterWithState:state stateCallback:stateCallback errorCallback:errorCallback];

            SymbolNode *root = [SymbolNode root];
            InputStateSymbolTable *symbolState = [[InputStateSymbolTable alloc] initWithNode:root
                                                                             useVerticalMode:input.useVerticalMode];
            stateCallback(symbolState);
            return YES;
        }
    }

    // MARK: Punctuation
    // if nothing is matched, see if it's a punctuation key for current layout.

    std::string punctuationNamePrefix;

    if ([input isOptionHold])
        punctuationNamePrefix = std::string("_alt_punctuation_");
    else if ([input isControlHold])
        punctuationNamePrefix = std::string("_ctrl_punctuation_");
    else if (mgrPrefs.halfWidthPunctuationEnabled)
        punctuationNamePrefix = std::string("_half_punctuation_");
    else
        punctuationNamePrefix = std::string("_punctuation_");

    std::string parser = [self _currentMandarinParser];
    std::string customPunctuation = punctuationNamePrefix + parser + std::string(1, (char)charCode);
    if ([self _handlePunctuation:customPunctuation
                           state:state
               usingVerticalMode:input.useVerticalMode
                   stateCallback:stateCallback
                   errorCallback:errorCallback])
        return YES;

    // if nothing is matched, see if it's a punctuation key.
    std::string punctuation = punctuationNamePrefix + std::string(1, (char)charCode);
    if ([self _handlePunctuation:punctuation
                           state:state
               usingVerticalMode:input.useVerticalMode
                   stateCallback:stateCallback
                   errorCallback:errorCallback])
        return YES;

    // Lukhnos 這裡的處理反而會使得 Apple 倚天注音動態鍵盤佈局「敲不了半形大寫英文」的缺點曝露無疑，所以注釋掉。
    // 至於他試圖用這種處理來解決的上游 UPR293
    // 的問題，其實針對詞庫檔案的排序做點手腳就可以解決。威注音本來也就是這麼做的。
    if (/*[state isKindOfClass:[InputStateNotEmpty class]] && */ [input isUpperCaseASCIILetterKey])
    {
        std::string letter = std::string("_letter_") + std::string(1, (char)charCode);
        if ([self _handlePunctuation:letter
                               state:state
                   usingVerticalMode:input.useVerticalMode
                       stateCallback:stateCallback
                       errorCallback:errorCallback])
            return YES;
    }

    // still nothing, then we update the composing buffer (some app has strange behavior if we don't do this, "thinking"
    // the key is not actually consumed) 砍掉這一段會導致「F1-F12
    // 按鍵干擾組字區」的問題。暫時只能先恢復這段，且補上偵錯彙報機制，方便今後排查故障。
    if ([state isKindOfClass:[InputStateNotEmpty class]] || ![self isPhoneticReadingBufferEmpty])
    {
        [IME prtDebugIntel:[NSString
                               stringWithFormat:@"Blocked data: charCode: %c, keyCode: %c", charCode, input.keyCode]];
        [IME prtDebugIntel:@"A9BFF20E"];
        errorCallback();
        stateCallback(state);
        return YES;
    }

    return NO;
}

- (BOOL)_handleEscWithState:(InputState *)state
              stateCallback:(void (^)(InputState *))stateCallback
              errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    BOOL escToClearInputBufferEnabled = mgrPrefs.escToCleanInputBuffer;

    if (escToClearInputBufferEnabled)
    {
        // if the option is enabled, we clear everything including the composing
        // buffer, walked nodes and the reading.
        [self clear];
        InputStateEmptyIgnoringPreviousState *empty = [[InputStateEmptyIgnoringPreviousState alloc] init];
        stateCallback(empty);
    }
    else
    {
        // if reading is not empty, we cancel the reading; Apple's built-in
        // Zhuyin (and the erstwhile Hanin) has a default option that Esc
        // "cancels" the current composed character and revert it to
        // Bopomofo reading, in odds with the expectation of users from
        // other platforms

        if (![self isPhoneticReadingBufferEmpty])
        {
            [self clearPhoneticReadingBuffer];
            if (!_builder->length())
            {
                InputStateEmpty *empty = [[InputStateEmpty alloc] init];
                stateCallback(empty);
            }
            else
            {
                InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
                stateCallback(inputting);
            }
        }
    }
    return YES;
}

- (BOOL)_handleBackwardWithState:(InputState *)state
                           input:(keyParser *)input
                   stateCallback:(void (^)(InputState *))stateCallback
                   errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    if (![self isPhoneticReadingBufferEmpty])
    {
        [IME prtDebugIntel:@"6ED95318"];
        errorCallback();
        stateCallback(state);
        return YES;
    }

    InputStateInputting *currentState = (InputStateInputting *)state;

    if ([input isShiftHold])
    {
        // Shift + left
        if (currentState.cursorIndex > 0)
        {
            NSInteger previousPosition =
                [currentState.composingBuffer previousUtf16PositionFor:currentState.cursorIndex];
            InputStateMarking *marking = [[InputStateMarking alloc] initWithComposingBuffer:currentState.composingBuffer
                                                                                cursorIndex:currentState.cursorIndex
                                                                                markerIndex:previousPosition
                                                                                   readings:[self _currentReadings]];
            marking.tooltipForInputting = currentState.tooltip;
            stateCallback(marking);
        }
        else
        {
            [IME prtDebugIntel:@"D326DEA3"];
            errorCallback();
            stateCallback(state);
        }
    }
    else
    {
        if (_builder->cursorIndex() > 0)
        {
            _builder->setCursorIndex(_builder->cursorIndex() - 1);
            InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
            stateCallback(inputting);
        }
        else
        {
            [IME prtDebugIntel:@"7045E6F3"];
            errorCallback();
            stateCallback(state);
        }
    }
    return YES;
}

- (BOOL)_handleForwardWithState:(InputState *)state
                          input:(keyParser *)input
                  stateCallback:(void (^)(InputState *))stateCallback
                  errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    if (![self isPhoneticReadingBufferEmpty])
    {
        [IME prtDebugIntel:@"B3BA5257"];
        errorCallback();
        stateCallback(state);
        return YES;
    }

    InputStateInputting *currentState = (InputStateInputting *)state;

    if ([input isShiftHold])
    {
        // Shift + Right
        if (currentState.cursorIndex < currentState.composingBuffer.length)
        {
            NSInteger nextPosition = [currentState.composingBuffer nextUtf16PositionFor:currentState.cursorIndex];
            InputStateMarking *marking = [[InputStateMarking alloc] initWithComposingBuffer:currentState.composingBuffer
                                                                                cursorIndex:currentState.cursorIndex
                                                                                markerIndex:nextPosition
                                                                                   readings:[self _currentReadings]];
            marking.tooltipForInputting = currentState.tooltip;
            stateCallback(marking);
        }
        else
        {
            [IME prtDebugIntel:@"BB7F6DB9"];
            errorCallback();
            stateCallback(state);
        }
    }
    else
    {
        if (_builder->cursorIndex() < _builder->length())
        {
            _builder->setCursorIndex(_builder->cursorIndex() + 1);
            InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
            stateCallback(inputting);
        }
        else
        {
            [IME prtDebugIntel:@"A96AAD58"];
            errorCallback();
            stateCallback(state);
        }
    }

    return YES;
}

- (BOOL)_handleHomeWithState:(InputState *)state
               stateCallback:(void (^)(InputState *))stateCallback
               errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    if (![self isPhoneticReadingBufferEmpty])
    {
        [IME prtDebugIntel:@"ABC44080"];
        errorCallback();
        stateCallback(state);
        return YES;
    }

    if (_builder->cursorIndex())
    {
        _builder->setCursorIndex(0);
        InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
        stateCallback(inputting);
    }
    else
    {
        [IME prtDebugIntel:@"66D97F90"];
        errorCallback();
        stateCallback(state);
    }

    return YES;
}

- (BOOL)_handleEndWithState:(InputState *)state
              stateCallback:(void (^)(InputState *))stateCallback
              errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    if (![self isPhoneticReadingBufferEmpty])
    {
        [IME prtDebugIntel:@"9B69908D"];
        errorCallback();
        stateCallback(state);
        return YES;
    }

    if (_builder->cursorIndex() != _builder->length())
    {
        _builder->setCursorIndex(_builder->length());
        InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
        stateCallback(inputting);
    }
    else
    {
        [IME prtDebugIntel:@"9B69908E"];
        errorCallback();
        stateCallback(state);
    }

    return YES;
}

- (BOOL)_handleAbsorbedArrowKeyWithState:(InputState *)state
                           stateCallback:(void (^)(InputState *))stateCallback
                           errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    if (![self isPhoneticReadingBufferEmpty])
    {
        [IME prtDebugIntel:@"9B6F908D"];
        errorCallback();
    }
    stateCallback(state);
    return YES;
}

- (BOOL)_handleBackspaceWithState:(InputState *)state
                    stateCallback:(void (^)(InputState *))stateCallback
                    errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    if ([self isPhoneticReadingBufferEmpty])
    {
        if (_builder->cursorIndex())
        {
            _builder->deleteReadingBeforeCursor();
            [self _walk];
        }
        else
        {
            [IME prtDebugIntel:@"9D69908D"];
            errorCallback();
            stateCallback(state);
            return YES;
        }
    }
    else
        [self doBackSpaceToPhoneticReadingBuffer];

    if ([self isPhoneticReadingBufferEmpty] && !_builder->length())
    {
        InputStateEmptyIgnoringPreviousState *empty = [[InputStateEmptyIgnoringPreviousState alloc] init];
        stateCallback(empty);
    }
    else
    {
        InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
        stateCallback(inputting);
    }
    return YES;
}

- (BOOL)_handleDeleteWithState:(InputState *)state
                 stateCallback:(void (^)(InputState *))stateCallback
                 errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    if ([self isPhoneticReadingBufferEmpty])
    {
        if (_builder->cursorIndex() != _builder->length())
        {
            _builder->deleteReadingAfterCursor();
            [self _walk];
            InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
            if (!inputting.composingBuffer.length)
            {
                InputStateEmptyIgnoringPreviousState *empty = [[InputStateEmptyIgnoringPreviousState alloc] init];
                stateCallback(empty);
            }
            else
            {
                stateCallback(inputting);
            }
        }
        else
        {
            [IME prtDebugIntel:@"9B69938D"];
            errorCallback();
            stateCallback(state);
        }
    }
    else
    {
        [IME prtDebugIntel:@"9C69908D"];
        errorCallback();
        stateCallback(state);
    }

    return YES;
}

- (BOOL)_handleCtrlCommandEnterWithState:(InputState *)state
                           stateCallback:(void (^)(InputState *))stateCallback
                           errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    NSArray *readings = [self _currentReadings];
    NSString *composingBuffer = (IME.areWeUsingOurOwnPhraseEditor) ? [readings componentsJoinedByString:@"-"]
                                                                   : [readings componentsJoinedByString:@" "];

    [self clear];

    InputStateCommitting *committing = [[InputStateCommitting alloc] initWithPoppedText:composingBuffer];
    stateCallback(committing);
    InputStateEmpty *empty = [[InputStateEmpty alloc] init];
    stateCallback(empty);
    return YES;
}

- (BOOL)_handleEnterWithState:(InputState *)state
                stateCallback:(void (^)(InputState *))stateCallback
                errorCallback:(void (^)(void))errorCallback
{
    if (![state isKindOfClass:[InputStateInputting class]])
        return NO;

    [self clear];

    InputStateInputting *current = (InputStateInputting *)state;
    NSString *composingBuffer = current.composingBuffer;
    InputStateCommitting *committing = [[InputStateCommitting alloc] initWithPoppedText:composingBuffer];
    stateCallback(committing);
    InputStateEmpty *empty = [[InputStateEmpty alloc] init];
    stateCallback(empty);
    return YES;
}

- (BOOL)_handlePunctuation:(std::string)customPunctuation
                     state:(InputState *)state
         usingVerticalMode:(BOOL)useVerticalMode
             stateCallback:(void (^)(InputState *))stateCallback
             errorCallback:(void (^)(void))errorCallback
{
    if (!_languageModel->hasUnigramsForKey(customPunctuation))
        return NO;

    NSString *poppedText;
    if ([self isPhoneticReadingBufferEmpty])
    {
        _builder->insertReadingAtCursor(customPunctuation);
        poppedText = [self _popOverflowComposingTextAndWalk];
    }
    else
    { // If there is still unfinished bpmf reading, ignore the punctuation
        [IME prtDebugIntel:@"A9B69908D"];
        errorCallback();
        stateCallback(state);
        return YES;
    }

    InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
    inputting.poppedText = poppedText;
    stateCallback(inputting);

    if (mgrPrefs.useSCPCTypingMode && [self isPhoneticReadingBufferEmpty])
    {
        InputStateChoosingCandidate *candidateState = [self _buildCandidateState:inputting
                                                                 useVerticalMode:useVerticalMode];

        if ([candidateState.candidates count] == 1)
        {
            [self clear];
            InputStateCommitting *committing =
                [[InputStateCommitting alloc] initWithPoppedText:candidateState.candidates.firstObject];
            stateCallback(committing);
            InputStateEmpty *empty = [[InputStateEmpty alloc] init];
            stateCallback(empty);
        }
        else
            stateCallback(candidateState);
    }
    return YES;
}

- (BOOL)_handleMarkingState:(InputStateMarking *)state
                      input:(keyParser *)input
              stateCallback:(void (^)(InputState *))stateCallback
              errorCallback:(void (^)(void))errorCallback
{

    if ([input isESC])
    {
        InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
        stateCallback(inputting);
        return YES;
    }

    // Enter
    if ([input isEnter])
    {
        if (![self.delegate keyHandler:self didRequestWriteUserPhraseWithState:state])
        {
            [IME prtDebugIntel:@"5B69CC8D"];
            errorCallback();
            return YES;
        }
        InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
        stateCallback(inputting);
        return YES;
    }

    // Shift + left
    if (([input isCursorBackward] || input.emacsKey == vChewingEmacsKeyBackward) && ([input isShiftHold]))
    {
        NSUInteger index = state.markerIndex;
        if (index > 0)
        {
            index = [state.composingBuffer previousUtf16PositionFor:index];
            InputStateMarking *marking = [[InputStateMarking alloc] initWithComposingBuffer:state.composingBuffer
                                                                                cursorIndex:state.cursorIndex
                                                                                markerIndex:index
                                                                                   readings:state.readings];
            marking.tooltipForInputting = state.tooltipForInputting;

            if (marking.markedRange.length == 0)
            {
                InputState *inputting = [marking convertToInputting];
                stateCallback(inputting);
            }
            else
                stateCallback(marking);
        }
        else
        {
            [IME prtDebugIntel:@"1149908D"];
            errorCallback();
            stateCallback(state);
        }
        return YES;
    }

    // Shift + Right
    if (([input isCursorForward] || input.emacsKey == vChewingEmacsKeyForward) && ([input isShiftHold]))
    {
        NSUInteger index = state.markerIndex;
        if (index < state.composingBuffer.length)
        {
            index = [state.composingBuffer nextUtf16PositionFor:index];
            InputStateMarking *marking = [[InputStateMarking alloc] initWithComposingBuffer:state.composingBuffer
                                                                                cursorIndex:state.cursorIndex
                                                                                markerIndex:index
                                                                                   readings:state.readings];
            marking.tooltipForInputting = state.tooltipForInputting;
            if (marking.markedRange.length == 0)
            {
                InputState *inputting = [marking convertToInputting];
                stateCallback(inputting);
            }
            else
                stateCallback(marking);
        }
        else
        {
            [IME prtDebugIntel:@"9B51408D"];
            errorCallback();
            stateCallback(state);
        }
        return YES;
    }
    return NO;
}

- (BOOL)_handleCandidateState:(InputState *)state
                        input:(keyParser *)input
                stateCallback:(void (^)(InputState *))stateCallback
                errorCallback:(void (^)(void))errorCallback;
{
    NSString *inputText = input.inputText;
    UniChar charCode = input.charCode;
    ctlCandidate *ctlCandidateCurrent = [self.delegate ctlCandidateForKeyHandler:self];

    BOOL cancelCandidateKey = [input isBackSpace] || [input isESC] || [input isDelete] ||
                              (([input isCursorBackward] || [input isCursorForward]) && [input isShiftHold]);

    if (cancelCandidateKey)
    {
        if ([state isKindOfClass:[InputStateAssociatedPhrases class]])
        {
            [self clear];
            InputStateEmptyIgnoringPreviousState *empty = [[InputStateEmptyIgnoringPreviousState alloc] init];
            stateCallback(empty);
        }
        else if (mgrPrefs.useSCPCTypingMode)
        {
            [self clear];
            InputStateEmptyIgnoringPreviousState *empty = [[InputStateEmptyIgnoringPreviousState alloc] init];
            stateCallback(empty);
        }
        else if ([self isBuilderEmpty])
        {
            // 如果此時發現當前組字緩衝區為真空的情況的話，就將當前的組字緩衝區析構處理、強制重設輸入狀態。
            // 不然的話，一個本不該出現的真空組字緩衝區會使前後方向鍵與 BackSpace 鍵失靈。
            [self clear];
            InputStateEmptyIgnoringPreviousState *empty = [[InputStateEmptyIgnoringPreviousState alloc] init];
            stateCallback(empty);
        }
        else
        {
            InputStateInputting *inputting = (InputStateInputting *)[self buildInputtingState];
            stateCallback(inputting);
        }
        return YES;
    }

    if ([input isEnter])
    {
        if ([state isKindOfClass:[InputStateAssociatedPhrases class]])
        {
            [self clear];
            InputStateEmptyIgnoringPreviousState *empty = [[InputStateEmptyIgnoringPreviousState alloc] init];
            stateCallback(empty);
            return YES;
        }
        [self.delegate keyHandler:self
            didSelectCandidateAtIndex:ctlCandidateCurrent.selectedCandidateIndex
                         ctlCandidate:ctlCandidateCurrent];
        return YES;
    }

    if ([input isTab])
    {
        BOOL updated =
            mgrPrefs.specifyShiftTabKeyBehavior
                ? ([input isShiftHold] ? [ctlCandidateCurrent showPreviousPage] : [ctlCandidateCurrent showNextPage])
                : ([input isShiftHold] ? [ctlCandidateCurrent highlightPreviousCandidate]
                                       : [ctlCandidateCurrent highlightNextCandidate]);
        if (!updated)
        {
            [IME prtDebugIntel:@"9B691919"];
            errorCallback();
        }
        return YES;
    }

    if ([input isSpace])
    {
        BOOL updated = mgrPrefs.specifyShiftSpaceKeyBehavior
                           ? ([input isShiftHold] ? [ctlCandidateCurrent highlightNextCandidate]
                                                  : [ctlCandidateCurrent showNextPage])
                           : ([input isShiftHold] ? [ctlCandidateCurrent showNextPage]
                                                  : [ctlCandidateCurrent highlightNextCandidate]);
        if (!updated)
        {
            [IME prtDebugIntel:@"A11C781F"];
            errorCallback();
        }
        return YES;
    }

    if ([input isPageDown] || input.emacsKey == vChewingEmacsKeyNextPage)
    {
        BOOL updated = [ctlCandidateCurrent showNextPage];
        if (!updated)
        {
            [IME prtDebugIntel:@"9B691919"];
            errorCallback();
        }
        return YES;
    }

    if ([input isPageUp])
    {
        BOOL updated = [ctlCandidateCurrent showPreviousPage];
        if (!updated)
        {
            [IME prtDebugIntel:@"9569955D"];
            errorCallback();
        }
        return YES;
    }

    if ([input isLeft])
    {
        if ([ctlCandidateCurrent isKindOfClass:[ctlCandidateHorizontal class]])
        {
            BOOL updated = [ctlCandidateCurrent highlightPreviousCandidate];
            if (!updated)
            {
                [IME prtDebugIntel:@"1145148D"];
                errorCallback();
            }
        }
        else
        {
            BOOL updated = [ctlCandidateCurrent showPreviousPage];
            if (!updated)
            {
                [IME prtDebugIntel:@"1919810D"];
                errorCallback();
            }
        }
        return YES;
    }

    if (input.emacsKey == vChewingEmacsKeyBackward)
    {
        BOOL updated = [ctlCandidateCurrent highlightPreviousCandidate];
        if (!updated)
        {
            [IME prtDebugIntel:@"9B89308D"];
            errorCallback();
        }
        return YES;
    }

    if ([input isRight])
    {
        if ([ctlCandidateCurrent isKindOfClass:[ctlCandidateHorizontal class]])
        {
            BOOL updated = [ctlCandidateCurrent highlightNextCandidate];
            if (!updated)
            {
                [IME prtDebugIntel:@"9B65138D"];
                errorCallback();
            }
        }
        else
        {
            BOOL updated = [ctlCandidateCurrent showNextPage];
            if (!updated)
            {
                [IME prtDebugIntel:@"9244908D"];
                errorCallback();
            }
        }
        return YES;
    }

    if (input.emacsKey == vChewingEmacsKeyForward)
    {
        BOOL updated = [ctlCandidateCurrent highlightNextCandidate];
        if (!updated)
        {
            [IME prtDebugIntel:@"9B2428D"];
            errorCallback();
        }
        return YES;
    }

    if ([input isUp])
    {
        if ([ctlCandidateCurrent isKindOfClass:[ctlCandidateHorizontal class]])
        {
            BOOL updated = [ctlCandidateCurrent showPreviousPage];
            if (!updated)
            {
                [IME prtDebugIntel:@"9B614524"];
                errorCallback();
            }
        }
        else
        {
            BOOL updated = [ctlCandidateCurrent highlightPreviousCandidate];
            if (!updated)
            {
                [IME prtDebugIntel:@"ASD9908D"];
                errorCallback();
            }
        }
        return YES;
    }

    if ([input isDown])
    {
        if ([ctlCandidateCurrent isKindOfClass:[ctlCandidateHorizontal class]])
        {
            BOOL updated = [ctlCandidateCurrent showNextPage];
            if (!updated)
            {
                [IME prtDebugIntel:@"92B990DD"];
                errorCallback();
            }
        }
        else
        {
            BOOL updated = [ctlCandidateCurrent highlightNextCandidate];
            if (!updated)
            {
                [IME prtDebugIntel:@"6B99908D"];
                errorCallback();
            }
        }
        return YES;
    }

    if ([input isHome] || input.emacsKey == vChewingEmacsKeyHome)
    {
        if (ctlCandidateCurrent.selectedCandidateIndex == 0)
        {
            [IME prtDebugIntel:@"9B6EDE8D"];
            errorCallback();
        }
        else
            ctlCandidateCurrent.selectedCandidateIndex = 0;

        return YES;
    }

    NSArray *candidates;

    if ([state isKindOfClass:[InputStateChoosingCandidate class]])
        candidates = [(InputStateChoosingCandidate *)state candidates];
    else if ([state isKindOfClass:[InputStateAssociatedPhrases class]])
        candidates = [(InputStateAssociatedPhrases *)state candidates];

    if (!candidates)
        return NO;

    if (([input isEnd] || input.emacsKey == vChewingEmacsKeyEnd) && candidates.count > 0)
    {
        if (ctlCandidateCurrent.selectedCandidateIndex == candidates.count - 1)
        {
            [IME prtDebugIntel:@"9B69AAAD"];
            errorCallback();
        }
        else
            ctlCandidateCurrent.selectedCandidateIndex = candidates.count - 1;

        return YES;
    }

    if ([state isKindOfClass:[InputStateAssociatedPhrases class]])
    {
        if (![input isShiftHold])
            return NO;
    }

    NSInteger index = NSNotFound;
    NSString *match;
    if ([state isKindOfClass:[InputStateAssociatedPhrases class]])
        match = input.inputTextIgnoringModifiers;
    else
        match = inputText;

    for (NSUInteger j = 0, c = [ctlCandidateCurrent.keyLabels count]; j < c; j++)
    {
        VTCandidateKeyLabel *label = ctlCandidateCurrent.keyLabels[j];
        if ([match compare:label.key options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            index = j;
            break;
        }
    }

    if (index != NSNotFound)
    {
        NSUInteger candidateIndex = [ctlCandidateCurrent candidateIndexAtKeyLabelIndex:index];
        if (candidateIndex != NSUIntegerMax)
        {
            [self.delegate keyHandler:self didSelectCandidateAtIndex:candidateIndex ctlCandidate:ctlCandidateCurrent];
            return YES;
        }
    }

    if ([state isKindOfClass:[InputStateAssociatedPhrases class]])
        return NO;

    if (mgrPrefs.useSCPCTypingMode)
    {
        std::string punctuationNamePrefix;
        if ([input isOptionHold])
            punctuationNamePrefix = std::string("_alt_punctuation_");
        else if ([input isControlHold])
            punctuationNamePrefix = std::string("_ctrl_punctuation_");
        else if (mgrPrefs.halfWidthPunctuationEnabled)
            punctuationNamePrefix = std::string("_half_punctuation_");
        else
            punctuationNamePrefix = std::string("_punctuation_");

        std::string parser = [self _currentMandarinParser];
        std::string customPunctuation = punctuationNamePrefix + parser + std::string(1, (char)charCode);
        std::string punctuation = punctuationNamePrefix + std::string(1, (char)charCode);

        BOOL shouldAutoSelectCandidate = [self chkKeyValidity:charCode] ||
                                         _languageModel->hasUnigramsForKey(customPunctuation) ||
                                         _languageModel->hasUnigramsForKey(punctuation);

        if (!shouldAutoSelectCandidate && [input isUpperCaseASCIILetterKey])
        {
            std::string letter = std::string("_letter_") + std::string(1, (char)charCode);
            if (_languageModel->hasUnigramsForKey(letter))
                shouldAutoSelectCandidate = YES;
        }

        if (shouldAutoSelectCandidate)
        {
            NSUInteger candidateIndex = [ctlCandidateCurrent candidateIndexAtKeyLabelIndex:0];
            if (candidateIndex != NSUIntegerMax)
            {
                [self.delegate keyHandler:self
                    didSelectCandidateAtIndex:candidateIndex
                                 ctlCandidate:ctlCandidateCurrent];
                [self clear];
                InputStateEmptyIgnoringPreviousState *empty = [[InputStateEmptyIgnoringPreviousState alloc] init];
                stateCallback(empty);
                [self handleInput:input state:empty stateCallback:stateCallback errorCallback:errorCallback];
            }
            return YES;
        }
    }

    [IME prtDebugIntel:@"172A0F81"];
    errorCallback();
    return YES;
}

#pragma mark - States Building

- (InputStateInputting *)buildInputtingState
{
    // "updating the composing buffer" means to request the client to "refresh" the text input buffer
    // with our "composing text"
    NSMutableString *composingBuffer = [[NSMutableString alloc] init];
    NSInteger composedStringCursorIndex = 0;

    size_t readingCursorIndex = 0;
    size_t builderCursorIndex = _builder->cursorIndex();

    NSString *tooltip = @"";

    // we must do some Unicode codepoint counting to find the actual cursor location for the client
    // i.e. we need to take UTF-16 into consideration, for which a surrogate pair takes 2 UniChars
    // locations
    for (std::vector<Gramambular::NodeAnchor>::iterator wi = _walkedNodes.begin(), we = _walkedNodes.end(); wi != we;
         ++wi)
    {
        if ((*wi).node)
        {
            std::string nodeStr = (*wi).node->currentKeyValue().value;
            NSString *valueString = [NSString stringWithUTF8String:nodeStr.c_str()];
            [composingBuffer appendString:valueString];

            NSArray *splited = [valueString split];
            NSInteger codepointCount = splited.count;

            // this re-aligns the cursor index in the composed string
            // (the actual cursor on the screen) with the builder's logical
            // cursor (reading) cursor; each built node has a "spanning length"
            // (e.g. two reading blocks has a spanning length of 2), and we
            // accumulate those lengths to calculate the displayed cursor
            // index
            size_t spanningLength = (*wi).spanningLength;
            if (readingCursorIndex + spanningLength <= builderCursorIndex)
            {
                composedStringCursorIndex += [valueString length];
                readingCursorIndex += spanningLength;
            }
            else
            {
                if (codepointCount == spanningLength)
                {
                    for (size_t i = 0; i < codepointCount && readingCursorIndex < builderCursorIndex; i++)
                    {
                        composedStringCursorIndex += [splited[i] length];
                        readingCursorIndex++;
                    }
                }
                else
                {
                    if (readingCursorIndex < builderCursorIndex)
                    {
                        composedStringCursorIndex += [valueString length];
                        readingCursorIndex += spanningLength;
                        if (readingCursorIndex > builderCursorIndex)
                        {
                            readingCursorIndex = builderCursorIndex;
                        }
                        if (builderCursorIndex == 0)
                        {
                            tooltip = [NSString
                                stringWithFormat:NSLocalizedString(@"Cursor is before \"%@\".", @""),
                                                 [NSString stringWithUTF8String:_builder->readings()[builderCursorIndex]
                                                                                    .c_str()]];
                        }
                        else if (builderCursorIndex >= _builder->readings().size())
                        {
                            tooltip = [NSString
                                stringWithFormat:NSLocalizedString(@"Cursor is after \"%@\".", @""),
                                                 [NSString
                                                     stringWithUTF8String:_builder
                                                                              ->readings()[_builder->readings().size() -
                                                                                           1]
                                                                              .c_str()]];
                        }
                        else
                        {
                            tooltip = [NSString
                                stringWithFormat:NSLocalizedString(@"Cursor is between \"%@\" and \"%@\".", @""),
                                                 [NSString
                                                     stringWithUTF8String:_builder->readings()[builderCursorIndex - 1]
                                                                              .c_str()],
                                                 [NSString stringWithUTF8String:_builder->readings()[builderCursorIndex]
                                                                                    .c_str()]];
                        }
                    }
                }
            }
        }
    }

    // now we gather all the info, we separate the composing buffer to two parts, head and tail,
    // and insert the reading text (the Mandarin syllable) in between them;
    // the reading text is what the user is typing
    NSString *head = [composingBuffer substringToIndex:composedStringCursorIndex];
    NSString *reading = [self getCompositionFromPhoneticReadingBuffer];
    NSString *tail = [composingBuffer substringFromIndex:composedStringCursorIndex];
    NSString *composedText = [head stringByAppendingString:[reading stringByAppendingString:tail]];
    NSInteger cursorIndex = composedStringCursorIndex + [reading length];

    InputStateInputting *newState = [[InputStateInputting alloc] initWithComposingBuffer:composedText
                                                                             cursorIndex:cursorIndex];
    newState.tooltip = tooltip;
    return newState;
}

- (void)_walk
{
    // retrieve the most likely trellis, i.e. a Maximum Likelihood Estimation
    // of the best possible Mandarin characters given the input syllables,
    // using the Viterbi algorithm implemented in the Gramambular library
    Gramambular::Walker walker(&_builder->grid());

    // the reverse walk traces the trellis from the end
    _walkedNodes = walker.reverseWalk(_builder->grid().width());

    // then we reverse the nodes so that we get the forward-walked nodes
    reverse(_walkedNodes.begin(), _walkedNodes.end());

    // if DEBUG is defined, a GraphViz file is written to kGraphVizOutputfile
#if DEBUG
    std::string dotDump = _builder->grid().dumpDOT();
    NSString *dotStr = [NSString stringWithUTF8String:dotDump.c_str()];
    NSError *error = nil;

    BOOL __unused success = [dotStr writeToFile:kGraphVizOutputfile
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:&error];
#endif
}

- (NSString *)_popOverflowComposingTextAndWalk
{
    // in an ideal world, we can as well let the user type forever,
    // but because the Viterbi algorithm has a complexity of O(N^2),
    // the walk will become slower as the number of nodes increase,
    // therefore we need to auto-commit overflown texts which usually
    // lose their influence over the whole MLE anyway -- so that when
    // the user type along, the already composed text in the rear side
    // of the buffer will be committed (i.e. "popped out").

    NSString *poppedText = @"";
    NSInteger composingBufferSize = mgrPrefs.composingBufferSize;

    if (_builder->grid().width() > (size_t)composingBufferSize)
    {
        if (_walkedNodes.size() > 0)
        {
            Gramambular::NodeAnchor &anchor = _walkedNodes[0];
            poppedText = [NSString stringWithUTF8String:anchor.node->currentKeyValue().value.c_str()];
            _builder->removeHeadReadings(anchor.spanningLength);
        }
    }

    [self _walk];
    return poppedText;
}

- (InputStateChoosingCandidate *)_buildCandidateState:(InputStateNotEmpty *)currentState
                                      useVerticalMode:(BOOL)useVerticalMode
{
    NSMutableArray *candidatesArray = [[NSMutableArray alloc] init];

    size_t cursorIndex = [self _actualCandidateCursorIndex];
    std::vector<Gramambular::NodeAnchor> nodes = _builder->grid().nodesCrossingOrEndingAt(cursorIndex);

    // sort the nodes, so that longer nodes (representing longer phrases) are placed at the top of the candidate list
    stable_sort(nodes.begin(), nodes.end(), NodeAnchorDescendingSorter());

    // then use the C++ trick to retrieve the candidates for each node at/crossing the cursor
    for (std::vector<Gramambular::NodeAnchor>::iterator ni = nodes.begin(), ne = nodes.end(); ni != ne; ++ni)
    {
        const std::vector<Gramambular::KeyValuePair> &candidates = (*ni).node->candidates();
        for (std::vector<Gramambular::KeyValuePair>::const_iterator ci = candidates.begin(), ce = candidates.end();
             ci != ce; ++ci)
            [candidatesArray addObject:[NSString stringWithUTF8String:(*ci).value.c_str()]];
    }

    InputStateChoosingCandidate *state =
        [[InputStateChoosingCandidate alloc] initWithComposingBuffer:currentState.composingBuffer
                                                         cursorIndex:currentState.cursorIndex
                                                          candidates:candidatesArray
                                                     useVerticalMode:useVerticalMode];
    return state;
}

// NON-SWIFTIFIABLE
- (size_t)_actualCandidateCursorIndex
{
    size_t cursorIndex = _builder->cursorIndex();
    // MS Phonetics IME style, phrase is *after* the cursor, i.e. cursor is always *before* the phrase
    if ((mgrPrefs.selectPhraseAfterCursorAsCandidate && (cursorIndex < _builder->length())) || !cursorIndex)
        ++cursorIndex;

    return cursorIndex;
}

// NON-SWIFTIFIABLE
- (NSArray *)_currentReadings
{
    NSMutableArray *readingsArray = [[NSMutableArray alloc] init];
    std::vector<std::string> v = _builder->readings();
    for (std::vector<std::string>::iterator it_i = v.begin(); it_i != v.end(); ++it_i)
        [readingsArray addObject:[NSString stringWithUTF8String:it_i->c_str()]];
    return readingsArray;
}

// NON-SWIFTIFIABLE
- (nullable InputState *)buildAssociatePhraseStateWithKey:(NSString *)key useVerticalMode:(BOOL)useVerticalMode
{
    std::string cppKey = std::string(key.UTF8String);
    if (_languageModel->hasAssociatedPhrasesForKey(cppKey))
    {
        std::vector<std::string> phrases = _languageModel->associatedPhrasesForKey(cppKey);
        NSMutableArray<NSString *> *array = [NSMutableArray array];
        for (auto phrase : phrases)
        {
            NSString *item = [[NSString alloc] initWithUTF8String:phrase.c_str()];
            [array addObject:item];
        }
        InputStateAssociatedPhrases *associatedPhrases =
            [[InputStateAssociatedPhrases alloc] initWithCandidates:array useVerticalMode:useVerticalMode];
        return associatedPhrases;
    }
    return nil;
}

#pragma mark - 必須用 ObjCpp 處理的部分: Mandarin

- (BOOL)chkKeyValidity:(UniChar)charCode
{
    return _bpmfReadingBuffer->isValidKey((char)charCode);
}

- (BOOL)isPhoneticReadingBufferEmpty
{
    return _bpmfReadingBuffer->isEmpty();
}

- (void)clearPhoneticReadingBuffer
{
    _bpmfReadingBuffer->clear();
}

- (void)combinePhoneticReadingBufferKey:(UniChar)charCode
{
    _bpmfReadingBuffer->combineKey((char)charCode);
}

- (BOOL)checkWhetherToneMarkerConfirmsPhoneticReadingBuffer
{
    return _bpmfReadingBuffer->hasToneMarker();
}

- (NSString *)getSyllableCompositionFromPhoneticReadingBuffer
{
    return [NSString stringWithUTF8String:_bpmfReadingBuffer->syllable().composedString().c_str()];
}

- (void)doBackSpaceToPhoneticReadingBuffer
{
    _bpmfReadingBuffer->backspace();
}

- (NSString *)getCompositionFromPhoneticReadingBuffer
{
    return [NSString stringWithUTF8String:_bpmfReadingBuffer->composedString().c_str()];
}

- (void)ensurePhoneticParser
{
    if (_bpmfReadingBuffer)
    {
        switch (mgrPrefs.mandarinParser)
        {
        case MandarinParserOfStandard:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::StandardLayout());
            break;
        case MandarinParserOfEten:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::ETenLayout());
            break;
        case MandarinParserOfHsu:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::HsuLayout());
            break;
        case MandarinParserOfEen26:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::ETen26Layout());
            break;
        case MandarinParserOfIBM:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::IBMLayout());
            break;
        case MandarinParserOfMiTAC:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::MiTACLayout());
            break;
        case MandarinParserOfFakeSeigyou:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::FakeSeigyouLayout());
            break;
        case MandarinParserOfHanyuPinyin:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::HanyuPinyinLayout());
            break;
        default:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::StandardLayout());
            mgrPrefs.mandarinParser = MandarinParserOfStandard;
        }
    }
    else
    {
        _bpmfReadingBuffer = new Mandarin::BopomofoReadingBuffer(Mandarin::BopomofoKeyboardLayout::StandardLayout());
    }
}

#pragma mark - 必須用 ObjCpp 處理的部分: Gramambular 等

- (void)removeBuilderAndReset:(BOOL)shouldReset
{
    if (_builder)
    {
        delete _builder;
        if (shouldReset)
            [self createNewBuilder];
    }
    else if (shouldReset)
        [self createNewBuilder];
}

- (void)createNewBuilder
{
    _builder = new Gramambular::BlockReadingBuilder(_languageModel);
    // Each Mandarin syllable is separated by a hyphen.
    _builder->setJoinSeparator("-");
}

- (void)setInputModesToLM:(BOOL)isCHS
{
    _languageModel = isCHS ? [mgrLangModel lmCHS] : [mgrLangModel lmCHT];
    _userOverrideModel = isCHS ? [mgrLangModel userOverrideModelCHS] : [mgrLangModel userOverrideModelCHT];
}

- (void)syncBaseLMPrefs
{
    if (_languageModel)
    {
        _languageModel->setPhraseReplacementEnabled(mgrPrefs.phraseReplacementEnabled);
        _languageModel->setSymbolEnabled(mgrPrefs.symbolInputEnabled);
        _languageModel->setCNSEnabled(mgrPrefs.cns11643Enabled);
    }
}

#pragma mark - 威注音認為有必要單獨拿出來處理的部分。

@end
