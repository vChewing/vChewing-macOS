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

NSString *packagedComposedText;
NSInteger packagedCursorIndex;
NSString *packagedResultOfBefore;
NSString *packagedResultOfAfter;

// NON-SWIFTIFIABLE
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

// NON-SWIFTIFIABLE
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

// NON-SWIFTIFIABLE
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

@synthesize delegate = _delegate;

// NON-SWIFTIFIABLE DUE TO VARIABLE AVAILABLE ACCESSIBILITY RANGE.
// VARIABLE: "_inputMode"
- (NSString *)inputMode
{
    return _inputMode;
}

// NON-SWIFTIFIABLE
- (BOOL)isBuilderEmpty
{
    return (_builder->grid().width() == 0);
}

// NON-SWIFTIFIABLE DUE TO VARIABLE AVAILABLE ACCESSIBILITY RANGE.
// VARIABLE: "_inputMode"
- (void)setInputMode:(NSString *)value
{
    // 下面這句的「isKindOfClass」是做類型檢查，
    // 為了應對出現輸入法 plist 被改壞掉這樣的極端情況。
    BOOL isCHS = [value isKindOfClass:[NSString class]] && [value isEqual:imeModeCHS];

    // 緊接著將新的簡繁輸入模式提報給 ctlInputMethod:
    ctlInputMethod.currentInputMode = isCHS ? imeModeCHS : imeModeCHT;
    mgrPrefs.mostRecentInputMode = ctlInputMethod.currentInputMode;

    // 拿當前的 _inputMode 與 ctlInputMethod 的提報結果對比，不同的話則套用新設定：
    if (![_inputMode isEqualToString:ctlInputMethod.currentInputMode])
    {
        // Reinitiate language models if necessary
        [self setInputModesToLM:isCHS];

        // Synchronize the sub-languageModel state settings to the new LM.
        [self syncBaseLMPrefs];

        [self removeBuilderAndReset:YES];

        if (![self isPhoneticReadingBufferEmpty])
            [self clearPhoneticReadingBuffer];
    }
    _inputMode = ctlInputMethod.currentInputMode;
}

// NON-SWIFTIFIABLE: Required by an ObjC(pp)-based class.
- (void)dealloc
{ // clean up everything
    if (_bpmfReadingBuffer)
        delete _bpmfReadingBuffer;
    if (_builder)
        [self removeBuilderAndReset:NO];
}

// NON-SWIFTIFIABLE: Not placeable in swift extensions.
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
    NSInteger cursorIndex = [self getActualCandidateCursorIndex];
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
        if (nextPosition <= [self getBuilderLength])
            [self setBuilderCursorIndex:nextPosition];
    }
}

// NON-SWIFTIFIABLE
- (void)clear
{
    [self clearPhoneticReadingBuffer];
    _builder->clear();
    _walkedNodes.clear();
}

#pragma mark - States Building

// NON-SWIFTIFIABLE
- (void)packageBufferStateMaterials
{
    // We gather the data through this function, package it,
    // and sent it to our Swift extension to build the InputState.Inputting there.
    // Otherwise, ObjC++ always bugs for "expecting a type".

    // "updating the composing buffer" means to request the client to "refresh" the text input buffer
    // with our "composing text"
    NSMutableString *composingBuffer = [[NSMutableString alloc] init];
    NSInteger composedStringCursorIndex = 0;

    // we must do some Unicode codepoint counting to find the actual cursor location for the client
    // i.e. we need to take UTF-16 into consideration, for which a surrogate pair takes 2 UniChars
    // locations

    size_t readingCursorIndex = 0;
    size_t builderCursorIndex = [self getBuilderCursorIndex];

    NSString *resultOfBefore = @"";
    NSString *resultOfAfter = @"";

    for (std::vector<Gramambular::NodeAnchor>::iterator wi = _walkedNodes.begin(), we = _walkedNodes.end(); wi != we;
         ++wi)
    {
        if ((*wi).node)
        {
            std::string nodeStr = (*wi).node->currentKeyValue().value;
            NSString *valueString = [NSString stringWithUTF8String:nodeStr.c_str()];
            [composingBuffer appendString:valueString];

            NSArray<NSString *> *splited = [valueString split];
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
                            resultOfBefore =
                                [NSString stringWithUTF8String:_builder->readings()[builderCursorIndex].c_str()];
                        }
                        else if (builderCursorIndex >= _builder->readings().size())
                        {
                            resultOfAfter = [NSString
                                stringWithUTF8String:_builder->readings()[_builder->readings().size() - 1].c_str()];
                        }
                        else
                        {
                            resultOfBefore =
                                [NSString stringWithUTF8String:_builder->readings()[builderCursorIndex].c_str()];
                            resultOfAfter =
                                [NSString stringWithUTF8String:_builder->readings()[builderCursorIndex - 1].c_str()];
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

    packagedComposedText = composedText;
    packagedCursorIndex = cursorIndex;
    packagedResultOfBefore = resultOfBefore;
    packagedResultOfAfter = resultOfAfter;
}

// NON-SWIFTIFIABLE DUE TO VARIABLE AVAILABLE ACCESSIBILITY RANGE.
- (NSString *)getStrLocationResult:(BOOL)isAfter
{
    if (isAfter)
        return packagedResultOfAfter;
    else
        return packagedResultOfBefore;
}

// NON-SWIFTIFIABLE DUE TO VARIABLE AVAILABLE ACCESSIBILITY RANGE.
- (NSString *)getComposedText
{
    return packagedComposedText;
}

// NON-SWIFTIFIABLE DUE TO VARIABLE AVAILABLE ACCESSIBILITY RANGE.
- (NSInteger)getPackagedCursorIndex
{
    return packagedCursorIndex;
}

// NON-SWIFTIFIABLE
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

// NON-SWIFTIFIABLE
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

// NON-SWIFTIFIABLE
- (NSArray<NSString *> *)_currentReadings
{
    NSMutableArray<NSString *> *readingsArray = [[NSMutableArray alloc] init];
    std::vector<std::string> v = _builder->readings();
    for (std::vector<std::string>::iterator it_i = v.begin(); it_i != v.end(); ++it_i)
        [readingsArray addObject:[NSString stringWithUTF8String:it_i->c_str()]];
    return readingsArray;
}

// NON-SWIFTIFIABLE
- (NSArray<NSString *> *)buildAssociatePhraseArrayWithKey:(NSString *)key
{
    NSMutableArray<NSString *> *array = [NSMutableArray array];
    std::string cppKey = std::string(key.UTF8String);
    if (_languageModel->hasAssociatedPhrasesForKey(cppKey))
    {
        std::vector<std::string> phrases = _languageModel->associatedPhrasesForKey(cppKey);
        for (auto phrase : phrases)
        {
            NSString *item = [[NSString alloc] initWithUTF8String:phrase.c_str()];
            [array addObject:item];
        }
    }
    return array;
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

// ----

- (BOOL)ifLangModelHasUnigramsForKey:(NSString *)reading
{
    return _languageModel->hasUnigramsForKey((std::string)[reading UTF8String]);
}

- (void)insertReadingToBuilderAtCursor:(NSString *)reading
{
    _builder->insertReadingAtCursor((std::string)[reading UTF8String]);
}

- (void)dealWithOverrideModelSuggestions
{
    // 讓 grid 知道目前的游標候選字判定是前置還是後置
    _builder->grid().setHaninInputEnabled(!mgrPrefs.selectPhraseAfterCursorAsCandidate);
    // 這一整段都太 C++ 且只出現一次，就整個端過來了。
    // 拆開封裝的話，只會把問題搞得更麻煩而已。
    std::string overrideValue = (mgrPrefs.useSCPCTypingMode)
                                    ? ""
                                    : _userOverrideModel->suggest(_walkedNodes, [self getBuilderCursorIndex],
                                                                  [[NSDate date] timeIntervalSince1970]);

    if (!overrideValue.empty())
    {
        NSInteger cursorIndex = [self getActualCandidateCursorIndex];
        std::vector<Gramambular::NodeAnchor> nodes = _builder->grid().nodesCrossingOrEndingAt(cursorIndex);
        double highestScore = FindHighestScore(nodes, kEpsilon);
        _builder->grid().overrideNodeScoreForSelectedCandidate(cursorIndex, overrideValue,
                                                               static_cast<float>(highestScore));
    }
}

- (void)setBuilderCursorIndex:(NSInteger)value
{
    _builder->setCursorIndex(value);
}

- (NSInteger)getBuilderCursorIndex
{
    return _builder->cursorIndex();
}

- (NSInteger)getBuilderLength
{
    return _builder->length();
}

- (void)deleteBuilderReadingInFrontOfCursor
{
    _builder->deleteReadingBeforeCursor();
}

- (void)deleteBuilderReadingAfterCursor
{
    _builder->deleteReadingAfterCursor();
}

- (NSArray<NSString *> *)getCandidatesArray
{
    // 讓 grid 知道目前的游標候選字判定是前置還是後置
    _builder->grid().setHaninInputEnabled(!mgrPrefs.selectPhraseAfterCursorAsCandidate);

    NSMutableArray<NSString *> *candidatesArray = [[NSMutableArray alloc] init];

    NSInteger cursorIndex = [self getActualCandidateCursorIndex];
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
    return candidatesArray;
}

#pragma mark - 威注音認為有必要單獨拿出來處理的部分，交給 Swift 則有些困難。

- (BOOL)isPrintable:(UniChar)charCode
{
    return isprint(charCode);
}

@end
