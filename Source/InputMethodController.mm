/* 
 *  InputMethodController.mm
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import "InputMethodController.h"
#import <fstream>
#import <iostream>
#import <set>
#import "OVUTF8Helper.h"
#import "LanguageModelManager.h"
#import "vChewing-Swift.h"

// C++ namespace usages
using namespace std;
using namespace Taiyan::Mandarin;
using namespace Taiyan::Gramambular;
using namespace vChewing;
using namespace OpenVanilla;

static const NSInteger kMinKeyLabelSize = 10;

// input modes
static NSString *const kBopomofoModeIdentifierCHT = @"org.atelierInmu.inputmethod.vChewing.TradBopomofo";
static NSString *const kBopomofoModeIdentifierCHS = @"org.atelierInmu.inputmethod.vChewing.SimpBopomofo";

// key code enums
enum {
    kEnterKeyCode = 76,
    kUpKeyCode = 126,
    kDownKeyCode = 125,
    kLeftKeyCode = 123,
    kRightKeyCode = 124,
    kPageUpKeyCode = 116,
    kPageDownKeyCode = 121,
    kHomeKeyCode = 115,
    kEndKeyCode = 119,
    kDeleteKeyCode = 117
};

VTCandidateController *gCurrentCandidateController = nil;

// if DEBUG is defined, a DOT file (GraphViz format) will be written to the
// specified path everytime the grid is walked
#if DEBUG
static NSString *const kGraphVizOutputfile = @"/tmp/vChewing-visualization.dot";
#endif

// https://clang-analyzer.llvm.org/faq.html
__attribute__((annotate("returns_localized_nsstring")))
static inline NSString *LocalizationNotNeeded(NSString *s) {
    return s;
}

@interface vChewingInputMethodController (VTCandidateController) <VTCandidateControllerDelegate>
@end

// sort helper
class NodeAnchorDescendingSorter
{
public:
    bool operator()(const NodeAnchor& a, const NodeAnchor &b) const {
        return a.node->key().length() > b.node->key().length();
    }
};

static const double kEpsilon = 0.000001;

static double FindHighestScore(const vector<NodeAnchor>& nodes, double epsilon) {
    double highestScore = 0.0;
    for (auto ni = nodes.begin(), ne = nodes.end(); ni != ne; ++ni) {
        double score = ni->node->highestUnigramScore();
        if (score > highestScore) {
            highestScore = score;
        }
    }
    return highestScore + epsilon;
}

@implementation vChewingInputMethodController
- (void)dealloc
{
    // clean up everything
    if (_bpmfReadingBuffer) {
        delete _bpmfReadingBuffer;
    }

    if (_builder) {
        delete _builder;
    }
    // the two client pointers are weak pointers (i.e. we don't retain them)
    // therefore we don't do anything about it
}

- (id)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)client
{
    // an instance is initialized whenever a text input client (a Mac app) requires
    // text input from an IME

    self = [super initWithServer:server delegate:delegate client:client];
    if (self) {
        _candidates = [[NSMutableArray alloc] init];

        // create the reading buffer
        _bpmfReadingBuffer = new BopomofoReadingBuffer(BopomofoKeyboardLayout::StandardLayout());

        // create the lattice builder
        _languageModel = [LanguageModelManager languageModelCoreCHT];
        _languageModel->setPhraseReplacementEnabled(Preferences.phraseReplacementEnabled);
        _languageModel->setCNSEnabled(Preferences.cns11643Enabled);
        _userOverrideModel = [LanguageModelManager userOverrideModelCHT];

        _builder = new BlockReadingBuilder(_languageModel);

        // each Mandarin syllable is separated by a hyphen
        _builder->setJoinSeparator("-");

        // create the composing buffer
        _composingBuffer = [[NSMutableString alloc] init];

        _inputMode = kBopomofoModeIdentifierCHT;
    }

    return self;
}

- (NSMenu *)menu
{
    // Define the case which ALT / Option key is pressed.
    BOOL optionKeyPressed = [[NSEvent class] respondsToSelector:@selector(modifierFlags)] && ([NSEvent modifierFlags] & NSEventModifierFlagOption);

    // a menu instance (autoreleased) is requested every time the user click on the input menu
    NSMenu *menu = [[NSMenu alloc] initWithTitle:LocalizationNotNeeded(@"Input Method Menu")];

    NSMenuItem *useWinNT351BPMFMenuItem = [menu addItemWithTitle:NSLocalizedString(@"NT351 BPMF EMU", @"") action:@selector(toggleWinNT351BPMFMode:) keyEquivalent:@"P"];
    useWinNT351BPMFMenuItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;
    useWinNT351BPMFMenuItem.state = Preferences.useWinNT351BPMF ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *useCNS11643SupportMenuItem = [menu addItemWithTitle:NSLocalizedString(@"CNS11643 Mode", @"") action:@selector(toggleCNS11643Enabled:) keyEquivalent:@"L"];
    useCNS11643SupportMenuItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;
    useCNS11643SupportMenuItem.state = Preferences.cns11643Enabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *chineseConversionMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Force KangXi Writing", @"") action:@selector(toggleChineseConverter:) keyEquivalent:@"K"];
    chineseConversionMenuItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;
    chineseConversionMenuItem.state = Preferences.chineseConversionEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *halfWidthPunctuationMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Use Half-Width Punctuations", @"") action:@selector(toggleHalfWidthPunctuation:) keyEquivalent:@""];
    halfWidthPunctuationMenuItem.state = Preferences.halfWidthPunctuationEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    if (optionKeyPressed) {
        NSMenuItem *phaseReplacementMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Use Phrase Replacement", @"") action:@selector(togglePhraseReplacementEnabled:) keyEquivalent:@""];
        phaseReplacementMenuItem.state = Preferences.phraseReplacementEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    }

    [menu addItem:[NSMenuItem separatorItem]]; // ------------------------------

    [menu addItemWithTitle:NSLocalizedString(@"Edit User Phrases", @"") action:@selector(openUserPhrases:) keyEquivalent:@""];
    if (optionKeyPressed) {
        [menu addItemWithTitle:NSLocalizedString(@"Edit Excluded Phrases", @"") action:@selector(openExcludedPhrases:) keyEquivalent:@""];
        [menu addItemWithTitle:NSLocalizedString(@"Edit Phrase Replacement Table", @"") action:@selector(openPhraseReplacement:) keyEquivalent:@""];
    }

    if (optionKeyPressed || !Preferences.shouldAutoReloadUserDataFiles) {
        [menu addItemWithTitle:NSLocalizedString(@"Reload User Phrases", @"") action:@selector(reloadUserPhrases:) keyEquivalent:@""];
    }
    
    [menu addItem:[NSMenuItem separatorItem]]; // ------------------------------

    [menu addItemWithTitle:NSLocalizedString(@"vChewing Preferences", @"") action:@selector(showPreferences:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Check for Updates…", @"") action:@selector(checkForUpdate:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"About vChewing…", @"") action:@selector(showAbout:) keyEquivalent:@""];
    if (optionKeyPressed) {
        [menu addItemWithTitle:NSLocalizedString(@"Reboot vChewing…", @"") action:@selector(selfTerminate:) keyEquivalent:@""];
    }
    return menu;
}

#pragma mark - IMKStateSetting protocol methods

- (void)activateServer:(id)client
{
    // Write missing OOBE user plist entries.
    [Preferences setMissingDefaults];
    
    // Read user plist.
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Override the keyboard layout. Use US if not set.
    NSString *basisKeyboardLayoutID = Preferences.basisKeyboardLayout;
    [client overrideKeyboardWithKeyboardNamed:basisKeyboardLayoutID];

    // Load UserPhrases // 這裡今後需要改造成「驗證檔案指紋、根據驗證結果判定是否需要重新讀入」的形式。
    if (Preferences.shouldAutoReloadUserDataFiles) {
        [self reloadUserPhrases:(id)nil];
    }

    // reset the state
    _currentDeferredClient = nil;
    _currentCandidateClient = nil;
    _builder->clear();
    _walkedNodes.clear();
    [_composingBuffer setString:@""];

    // checks and populates the default settings
    switch (Preferences.keyboardLayout) {
        case KeyboardLayoutStandard:
            _bpmfReadingBuffer->setKeyboardLayout(BopomofoKeyboardLayout::StandardLayout());
            break;
        case KeyboardLayoutEten:
            _bpmfReadingBuffer->setKeyboardLayout(BopomofoKeyboardLayout::ETenLayout());
            break;
        case KeyboardLayoutHsu:
            _bpmfReadingBuffer->setKeyboardLayout(BopomofoKeyboardLayout::HsuLayout());
            break;
        case KeyboardLayoutEten26:
            _bpmfReadingBuffer->setKeyboardLayout(BopomofoKeyboardLayout::ETen26Layout());
            break;
        case KeyboardLayoutHanyuPinyin:
            _bpmfReadingBuffer->setKeyboardLayout(BopomofoKeyboardLayout::HanyuPinyinLayout());
            break;
        case KeyboardLayoutIBM:
            _bpmfReadingBuffer->setKeyboardLayout(BopomofoKeyboardLayout::IBMLayout());
            break;
        default:
            _bpmfReadingBuffer->setKeyboardLayout(BopomofoKeyboardLayout::StandardLayout());
            Preferences.keyboardLayout = KeyboardLayoutStandard;
    }

    [(AppDelegate *)[NSApp delegate] checkForUpdate];
}

- (void)deactivateServer:(id)client
{
    // clean up reading buffer residues
    if (!_bpmfReadingBuffer->isEmpty()) {
        _bpmfReadingBuffer->clear();
        [client setMarkedText:@"" selectionRange:NSMakeRange(0, 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }

    // commit any residue in the composing buffer
    [self commitComposition:client];

    _currentDeferredClient = nil;
    _currentCandidateClient = nil;

    gCurrentCandidateController.delegate = nil;
    gCurrentCandidateController.visible = NO;
    [_candidates removeAllObjects];

    [self _hideTooltip];
}

- (void)setValue:(id)value forTag:(long)tag client:(id)sender
{
    NSString *newInputMode;
    vChewingLM *newLanguageModel;
    UserOverrideModel *newUserOverrideModel;

    if ([value isKindOfClass:[NSString class]] && [value isEqual:kBopomofoModeIdentifierCHS]) {
        newInputMode = kBopomofoModeIdentifierCHS;
        newLanguageModel = [LanguageModelManager languageModelCoreCHS];
        newUserOverrideModel = [LanguageModelManager userOverrideModelCHS];
    } else {
        newInputMode = kBopomofoModeIdentifierCHT;
        newLanguageModel = [LanguageModelManager languageModelCoreCHT];
        newUserOverrideModel = [LanguageModelManager userOverrideModelCHT];
    }

    // 自 Preferences 模組讀入自訂語彙置換功能開關狀態。
    newLanguageModel->setPhraseReplacementEnabled(Preferences.phraseReplacementEnabled);

    // 自 Preferences 模組讀取全字庫模式開關狀態。
    newLanguageModel->setCNSEnabled(Preferences.cns11643Enabled);
    
    // Only apply the changes if the value is changed
    if (![_inputMode isEqualToString:newInputMode]) {
        [[NSUserDefaults standardUserDefaults] synchronize];

        // Remember to override the keyboard layout again -- treat this as an activate eventy
        NSString *basisKeyboardLayoutID = Preferences.basisKeyboardLayout;
        [sender overrideKeyboardWithKeyboardNamed:basisKeyboardLayoutID];

        _inputMode = newInputMode;
        _languageModel = newLanguageModel;
        _userOverrideModel = newUserOverrideModel;

        if (!_bpmfReadingBuffer->isEmpty()) {
            _bpmfReadingBuffer->clear();
            [self updateClientComposingBuffer:sender];
        }

        if ([_composingBuffer length] > 0) {
            [self commitComposition:sender];
        }

        if (_builder) {
            delete _builder;
            _builder = new BlockReadingBuilder(_languageModel);
            _builder->setJoinSeparator("-");
        }
    }
}

#pragma mark - IMKServerInput protocol methods

- (NSString *)_convertToKangXi:(NSString *)text
{
    // return [VXHanConvert convertToSimplifiedFrom:text]; // VXHanConvert 這個引擎有點落後了，不支援詞組轉換、且修改轉換表的過程很麻煩。
    // OpenCC 引擎別的都還好，就是有點肥。改日換成純 ObjC 的 OpenCC 實現方案。
    return [OpenCCBridge convertToKangXi:text];
}

- (void)commitComposition:(id)client
{
    // if it's Terminal, we don't commit at the first call (the client of which will not be IPMDServerClientWrapper)
    // then we defer the update in the next runloop round -- so that the composing buffer is not
    // meaninglessly flushed, an annoying bug in Terminal.app since Mac OS X 10.5
    if ([[client bundleIdentifier] isEqualToString:@"com.apple.Terminal"] && ![NSStringFromClass([client class]) isEqualToString:@"IPMDServerClientWrapper"]) {
        if (_currentDeferredClient) {
            [self performSelector:@selector(updateClientComposingBuffer:) withObject:_currentDeferredClient afterDelay:0.0];
        }
        return;
    }

    // Chinese conversion.
    NSString *buffer = _composingBuffer;

    if (Preferences.chineseConversionEnabled) {
        buffer = [self _convertToKangXi:_composingBuffer];
    }

    // commit the text, clear the state
    [client insertText:buffer replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    _builder->clear();
    _walkedNodes.clear();
    [_composingBuffer setString:@""];
    gCurrentCandidateController.visible = NO;
    [_candidates removeAllObjects];
    [self _hideTooltip];
}

NS_INLINE size_t min(size_t a, size_t b) { return a < b ? a : b; }
NS_INLINE size_t max(size_t a, size_t b) { return a > b ? a : b; }

// TODO: bug #28 is more likely to live in this method.
- (void)updateClientComposingBuffer:(id)client
{
    // "updating the composing buffer" means to request the client to "refresh" the text input buffer
    // with our "composing text"

    [_composingBuffer setString:@""];
    NSInteger composedStringCursorIndex = 0;

    size_t readingCursorIndex = 0;
    size_t builderCursorIndex = _builder->cursorIndex();

    // we must do some Unicode codepoint counting to find the actual cursor location for the client
    // i.e. we need to take UTF-16 into consideration, for which a surrogate pair takes 2 UniChars
    // locations
    for (vector<NodeAnchor>::iterator wi = _walkedNodes.begin(), we = _walkedNodes.end() ; wi != we ; ++wi) {
        if ((*wi).node) {
            string nodeStr = (*wi).node->currentKeyValue().value;
            vector<string> codepoints = OVUTF8Helper::SplitStringByCodePoint(nodeStr);
            size_t codepointCount = codepoints.size();

            NSString *valueString = [NSString stringWithUTF8String:nodeStr.c_str()];
            [_composingBuffer appendString:valueString];

            // this re-aligns the cursor index in the composed string
            // (the actual cursor on the screen) with the builder's logical
            // cursor (reading) cursor; each built node has a "spanning length"
            // (e.g. two reading blocks has a spanning length of 2), and we
            // accumulate those lengthes to calculate the displayed cursor
            // index
            size_t spanningLength = (*wi).spanningLength;
            if (readingCursorIndex + spanningLength <= builderCursorIndex) {
                composedStringCursorIndex += [valueString length];
                readingCursorIndex += spanningLength;
            }
            else {
                for (size_t i = 0; i < codepointCount && readingCursorIndex < builderCursorIndex; i++) {
                    composedStringCursorIndex += [[NSString stringWithUTF8String:codepoints[i].c_str()] length];
                    readingCursorIndex++;
                }
            }
        }
    }

    // now we gather all the info, we separate the composing buffer to two parts, head and tail,
    // and insert the reading text (the Mandarin syllable) in between them;
    // the reading text is what the user is typing
    NSString *head = [_composingBuffer substringToIndex:composedStringCursorIndex];
    NSString *reading = [NSString stringWithUTF8String:_bpmfReadingBuffer->composedString().c_str()];
    NSString *tail = [_composingBuffer substringFromIndex:composedStringCursorIndex];
    NSString *composedText = [head stringByAppendingString:[reading stringByAppendingString:tail]];
    NSInteger cursorIndex = composedStringCursorIndex + [reading length];

    if (_bpmfReadingBuffer->isEmpty() && _builder->markerCursorIndex() != SIZE_MAX) {
        // if there is a marked range, we need to tear the string into three parts.
        NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:composedText];
        size_t begin = min(_builder->markerCursorIndex(), _builder->cursorIndex());
        size_t end = max(_builder->markerCursorIndex(), _builder->cursorIndex());
        [attrString setAttributes:@{
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
            NSMarkedClauseSegmentAttributeName: @0
        } range:NSMakeRange(0, begin)];
        [attrString setAttributes:@{
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleThick),
            NSMarkedClauseSegmentAttributeName: @1
        } range:NSMakeRange(begin, end - begin)];
        [attrString setAttributes:@{
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
            NSMarkedClauseSegmentAttributeName: @2
        } range:NSMakeRange(end, [composedText length] - end)];
        // the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
        // i.e. the client app needs to take care of where to put ths composing buffer
        [client setMarkedText:attrString selectionRange:NSMakeRange((NSInteger)_builder->markerCursorIndex(), 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        _latestReadingCursor = (NSInteger)_builder->markerCursorIndex();
        [self _showCurrentMarkedTextTooltipWithClient:client];
    }
    else {
        // we must use NSAttributedString so that the cursor is visible --
        // can't just use NSString
        NSDictionary *attrDict = @{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                                   NSMarkedClauseSegmentAttributeName: @0};
        NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:composedText attributes:attrDict];

        // the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
        // i.e. the client app needs to take care of where to put ths composing buffer
        [client setMarkedText:attrString selectionRange:NSMakeRange(cursorIndex, 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        _latestReadingCursor = cursorIndex;
        [self _hideTooltip];
    }
}

- (void)walk
{
    // retrieve the most likely trellis, i.e. a Maximum Likelihood Estimation
    // of the best possible Mandarain characters given the input syllables,
    // using the Viterbi algorithm implemented in the Gramambular library
    Walker walker(&_builder->grid());

    // the reverse walk traces the trellis from the end
    _walkedNodes = walker.reverseWalk(_builder->grid().width());

    // then we reverse the nodes so that we get the forward-walked nodes
    reverse(_walkedNodes.begin(), _walkedNodes.end());

    // if DEBUG is defined, a GraphViz file is written to kGraphVizOutputfile
#if DEBUG
    string dotDump = _builder->grid().dumpDOT();
    NSString *dotStr = [NSString stringWithUTF8String:dotDump.c_str()];
    NSError *error = nil;

    BOOL __unused success = [dotStr writeToFile:kGraphVizOutputfile atomically:YES encoding:NSUTF8StringEncoding error:&error];
#endif
}

- (void)popOverflowComposingTextAndWalk:(id)client
{
    // in an ideal world, we can as well let the user type forever,
    // but because the Viterbi algorithm has a complexity of O(N^2),
    // the walk will become slower as the number of nodes increase,
    // therefore we need to "pop out" overflown text -- they usually
    // lose their influence over the whole MLE anyway -- so tht when
    // the user type along, the already composed text at front will
    // be popped out

    NSInteger composingBufferSize = Preferences.composingBufferSize;

    if (_builder->grid().width() > (size_t)composingBufferSize) {
        if (_walkedNodes.size() > 0) {
            NodeAnchor &anchor = _walkedNodes[0];
            NSString *popedText = [NSString stringWithUTF8String:anchor.node->currentKeyValue().value.c_str()];
            // Chinese conversion.
            BOOL chineseConversionEnabled = Preferences.chineseConversionEnabled;
            if (chineseConversionEnabled) {
                popedText = [self _convertToKangXi:popedText];
            }
            [client insertText:popedText replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
            _builder->removeHeadReadings(anchor.spanningLength);
        }
    }

    [self walk];
}

- (void)beep
{
    // use the vChewing beep.
    [clsSFX beep];
}

- (string)_currentLayout
{
    NSString *keyboardLayoutName = Preferences.keyboardLayoutName;
    string layout = string(keyboardLayoutName.UTF8String) + string("_");
    return layout;
}

- (BOOL)handleInputText:(NSString*)inputText key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)client
{
    NSRect textFrame = NSZeroRect;
    NSDictionary *attributes = nil;

    bool composeReading = false;
    BOOL useVerticalMode = NO;

    @try {
        attributes = [client attributesForCharacterIndex:0 lineHeightRectangle:&textFrame];
        useVerticalMode = [attributes objectForKey:@"IMKTextOrientation"] && [[attributes objectForKey:@"IMKTextOrientation"] integerValue] == 0;
    }
    @catch (NSException *e) {
        // exception may raise while using Twitter.app's search filed.
    }

    NSInteger cursorForwardKey = useVerticalMode ? kDownKeyCode : kRightKeyCode;
    NSInteger cursorBackwardKey = useVerticalMode ? kUpKeyCode : kLeftKeyCode;
    NSInteger extraChooseCandidateKey = useVerticalMode ? kLeftKeyCode : kDownKeyCode;
    NSInteger absorbedArrowKey = useVerticalMode ? kRightKeyCode : kUpKeyCode;
    NSInteger verticalModeOnlyChooseCandidateKey = useVerticalMode ? absorbedArrowKey : 0;

    // get the unicode character code
    UniChar charCode = [inputText length] ? [inputText characterAtIndex:0] : 0;

    vChewingEmacsKey emacsKey = [EmacsKeyHelper detectWithCharCode:charCode flags:flags];

    if ([[client bundleIdentifier] isEqualToString:@"com.apple.Terminal"] && [NSStringFromClass([client class]) isEqualToString:@"IPMDServerClientWrapper"]) {
        // special handling for com.apple.Terminal
        _currentDeferredClient = client;
    }

    // if the inputText is empty, it's a function key combination, we ignore it
    if (![inputText length]) {
        return NO;
    }

    // if the composing buffer is empty and there's no reading, and there is some function key combination, we ignore it
    if (![_composingBuffer length] &&
            _bpmfReadingBuffer->isEmpty() &&
            ((flags & NSEventModifierFlagCommand) || (flags & NSEventModifierFlagControl) || (flags & NSEventModifierFlagOption) || (flags & NSEventModifierFlagNumericPad))) {
            return NO;
        }

    // Caps Lock processing : if Caps Lock is on, temporarily disable bopomofo.
    if (charCode == 8 || charCode == 13 || keyCode == absorbedArrowKey || keyCode == extraChooseCandidateKey || keyCode == cursorForwardKey || keyCode == cursorBackwardKey) {
        // do nothing if backspace is pressed -- we ignore the key
    }
    else if (flags & NSAlphaShiftKeyMask) {
        // process all possible combination, we hope.
        if ([_composingBuffer length]) {
            [self commitComposition:client];
        }

        // first commit everything in the buffer.
        if (flags & NSEventModifierFlagShift) {
            return NO;
        }

        // if ASCII but not printable, don't use insertText:replacementRange: as many apps don't handle non-ASCII char insertions.
        if (charCode < 0x80 && !isprint(charCode)) {
            return NO;
        }

        // when shift is pressed, don't do further processing, since it outputs capital letter anyway.
        NSString *popedText = [inputText lowercaseString];
        [client insertText:popedText replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        return YES;
    }

    if (flags & NSEventModifierFlagNumericPad) {
        if (keyCode != kLeftKeyCode && keyCode != kRightKeyCode && keyCode != kDownKeyCode && keyCode != kUpKeyCode && charCode != 32 && isprint(charCode)) {
            if ([_composingBuffer length]) {
                [self commitComposition:client];
            }

            NSString *popedText = [inputText lowercaseString];
            [client insertText:popedText replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
            return YES;
        }
    }

    // if we have candidate, it means we need to pass the event to the candidate handler
    if ([_candidates count]) {
        return [self _handleCandidateEventWithInputText:inputText charCode:charCode keyCode:keyCode emacsKey:(vChewingEmacsKey)emacsKey];
    }

    // If we have marker index.
    if (_builder->markerCursorIndex() != SIZE_MAX) {
        // ESC
        if (charCode == 27) {
            _builder->setMarkerCursorIndex(SIZE_MAX);
            [self updateClientComposingBuffer:client];
            return YES;
        }
        // Enter
        if (charCode == 13) {
            if ([self _writeUserPhrase]) {
                _builder->setMarkerCursorIndex(SIZE_MAX);
            }
            else {
                [self beep];
            }
            [self updateClientComposingBuffer:client];
            return YES;
        }
        // Shift + left
        if ((keyCode == cursorBackwardKey || emacsKey == vChewingEmacsKeyBackward)
            && (flags & NSEventModifierFlagShift)) {
            if (_builder->markerCursorIndex() > 0) {
                _builder->setMarkerCursorIndex(_builder->markerCursorIndex() - 1);
            }
            else {
                [self beep];
            }
            [self updateClientComposingBuffer:client];
            return YES;
        }
        // Shift + Right
        if ((keyCode == cursorForwardKey || emacsKey == vChewingEmacsKeyForward)
             && (flags & NSEventModifierFlagShift)) {
            if (_builder->markerCursorIndex() < _builder->length()) {
                _builder->setMarkerCursorIndex(_builder->markerCursorIndex() + 1);
            }
            else {
                [self beep];
            }
            [self updateClientComposingBuffer:client];
            return YES;
        }

        _builder->setMarkerCursorIndex(SIZE_MAX);
    }

    // see if it's valid BPMF reading
    if (_bpmfReadingBuffer->isValidKey((char)charCode)) {
        _bpmfReadingBuffer->combineKey((char)charCode);

        // if we have a tone marker, we have to insert the reading to the
        // builder in other words, if we don't have a tone marker, we just
        // update the composing buffer
        composeReading = _bpmfReadingBuffer->hasToneMarker();
        if (!composeReading) {
            [self updateClientComposingBuffer:client];
            return YES;
        }
    }

    // see if we have composition if Enter/Space is hit and buffer is not empty
    // this is bit-OR'ed so that the tone marker key is also taken into account
    composeReading |= (!_bpmfReadingBuffer->isEmpty() && (charCode == 32 || charCode == 13));
    if (composeReading) {
        // combine the reading
        string reading = _bpmfReadingBuffer->syllable().composedString();

        // see if we have a unigram for this
        if (!_languageModel->hasUnigramsForKey(reading)) {
            [self beep];
            [self updateClientComposingBuffer:client];
            return YES;
        }

        // and insert it into the lattice
        _builder->insertReadingAtCursor(reading);

        // then walk the lattice
        [self popOverflowComposingTextAndWalk:client];

        // get user override model suggestion
        string overrideValue = _userOverrideModel->suggest(_walkedNodes, _builder->cursorIndex(), [[NSDate date] timeIntervalSince1970]);

        if (!overrideValue.empty()) {
            size_t cursorIndex = [self actualCandidateCursorIndex];
            vector<NodeAnchor> nodes = _builder->grid().nodesCrossingOrEndingAt(cursorIndex);
            double highestScore = FindHighestScore(nodes, kEpsilon);
            _builder->grid().overrideNodeScoreForSelectedCandidate(cursorIndex, overrideValue, highestScore);
        }

        // then update the text
        _bpmfReadingBuffer->clear();
        [self updateClientComposingBuffer:client];
        
        // 模擬 WINNT 351 ㄅ半注音，就是每個漢字都自動要選字的那種注音。
        // 嚴格來講不能算純正的ㄅ半注音，畢竟候選字的順序不可能會像當年那樣了。
        // 如果簡體中文用戶不知道ㄅ半注音是什麼的話，拿全拼輸入法來比喻恐怕比較恰當。
        if (Preferences.useWinNT351BPMF) {
            [self _showCandidateWindowUsingVerticalMode:useVerticalMode client:client];
        }
        
        // and tells the client that the key is consumed
        return YES;
    }

    // keyCode 125 = Down, charCode 32 = Space
    if (_bpmfReadingBuffer->isEmpty() && [_composingBuffer length] > 0 && (keyCode == extraChooseCandidateKey || charCode == 32 || (useVerticalMode && (keyCode == verticalModeOnlyChooseCandidateKey)))) {
        if (charCode == 32) {
            // if the spacebar is NOT set to be a selection key
            if ((flags & NSEventModifierFlagShift) != 0 || !Preferences.chooseCandidateUsingSpace) {
                if (_builder->cursorIndex() >= _builder->length()) {
                    [_composingBuffer appendString:@" "];
                    [self commitComposition:client];
                    _bpmfReadingBuffer->clear();
                }
                else if (_languageModel->hasUnigramsForKey(" ")) {
                    _builder->insertReadingAtCursor(" ");
                    [self popOverflowComposingTextAndWalk:client];
                    [self updateClientComposingBuffer:client];
                }
                return YES;

            }
        }
        [self _showCandidateWindowUsingVerticalMode:useVerticalMode client:client];
        return YES;
    }

    // Esc
    if (charCode == 27) {
        BOOL escToClearInputBufferEnabled = Preferences.escToCleanInputBuffer;

        if (escToClearInputBufferEnabled) {
            // if the optioon is enabled, we clear everythiong including the composing
            // buffer, walked nodes and the reading.
            if (![_composingBuffer length]) {
                return NO;
            }
            _bpmfReadingBuffer->clear();
            _builder->clear();
            _walkedNodes.clear();
            [_composingBuffer setString:@""];
        }
        else {
            // if reading is not empty, we cancel the reading; Apple's built-in
            // Zhuyin (and the erstwhile Hanin) has a default option that Esc
            // "cancels" the current composed character and revert it to
            // Bopomofo reading, in odds with the expectation of users from
            // other platforms

            if (_bpmfReadingBuffer->isEmpty()) {
                // no nee to beep since the event is deliberately triggered by user

                if (![_composingBuffer length]) {
                    return NO;
                }
            }
            else {
                _bpmfReadingBuffer->clear();
            }
        }

        [self updateClientComposingBuffer:client];
        return YES;
    }

    // handle cursor backward
    if (keyCode == cursorBackwardKey || emacsKey == vChewingEmacsKeyBackward) {
        if (!_bpmfReadingBuffer->isEmpty()) {
            [self beep];
        }
        else {
            if (![_composingBuffer length]) {
                return NO;
            }

            if (flags & NSEventModifierFlagShift) {
                // Shift + left
                if (_builder->cursorIndex() > 0) {
                    _builder->setMarkerCursorIndex(_builder->cursorIndex() - 1);
                }
                else {
                    [self beep];
                }
            } else {
                if (_builder->cursorIndex() > 0) {
                    _builder->setCursorIndex(_builder->cursorIndex() - 1);
                }
                else {
                    [self beep];
                }
            }
        }

        [self updateClientComposingBuffer:client];
        return YES;
    }

    // handle cursor forward
    if (keyCode == cursorForwardKey || emacsKey == vChewingEmacsKeyForward) {
        if (!_bpmfReadingBuffer->isEmpty()) {
            [self beep];
        }
        else {
            if (![_composingBuffer length]) {
                return NO;
            }

            if (flags & NSEventModifierFlagShift) {
                // Shift + Right
                if (_builder->cursorIndex() < _builder->length()) {
                    _builder->setMarkerCursorIndex(_builder->cursorIndex() + 1);
                } else {
                    [self beep];
                }
            } else {
                if (_builder->cursorIndex() < _builder->length()) {
                    _builder->setCursorIndex(_builder->cursorIndex() + 1);
                }
                else {
                    [self beep];
                }
            }
        }

        [self updateClientComposingBuffer:client];
        return YES;
    }

    if (keyCode == kHomeKeyCode || emacsKey == vChewingEmacsKeyHome) {
        if (!_bpmfReadingBuffer->isEmpty()) {
            [self beep];
        }
        else {
            if (![_composingBuffer length]) {
                return NO;
            }

            if (_builder->cursorIndex()) {
                _builder->setCursorIndex(0);
            }
            else {
                [self beep];
            }
        }

        [self updateClientComposingBuffer:client];
        return YES;
    }

    if (keyCode == kEndKeyCode || emacsKey == vChewingEmacsKeyEnd) {
        if (!_bpmfReadingBuffer->isEmpty()) {
            [self beep];
        }
        else {
            if (![_composingBuffer length]) {
                return NO;
            }

            if (_builder->cursorIndex() != _builder->length()) {
                _builder->setCursorIndex(_builder->length());
            }
            else {
                [self beep];
            }
        }

        [self updateClientComposingBuffer:client];
        return YES;
    }

    if (keyCode == absorbedArrowKey || keyCode == extraChooseCandidateKey) {
        if (!_bpmfReadingBuffer->isEmpty()) {
            [self beep];
        }
        [self updateClientComposingBuffer:client];
        return YES;
    }

    // Backspace
    if (charCode == 8) {
        if (_bpmfReadingBuffer->isEmpty()) {
            if (![_composingBuffer length]) {
                return NO;
            }

            if (_builder->cursorIndex()) {
                _builder->deleteReadingBeforeCursor();
                [self walk];
            }
            else {
                [self beep];
            }
        }
        else {
            _bpmfReadingBuffer->backspace();
        }

        [self updateClientComposingBuffer:client];
        return YES;
    }

    // Delete
    if (keyCode == kDeleteKeyCode || emacsKey == vChewingEmacsKeyDelete) {
        if (_bpmfReadingBuffer->isEmpty()) {
            if (![_composingBuffer length]) {
                return NO;
            }

            if (_builder->cursorIndex() != _builder->length()) {
                _builder->deleteReadingAfterCursor();
                [self walk];
            }
            else {
                [self beep];
            }
        }
        else {
            [self beep];
        }

        [self updateClientComposingBuffer:client];
        return YES;
    }

    // Enter
    if (charCode == 13) {
        if (![_composingBuffer length]) {
            return NO;
        }

        [self commitComposition:client];
        return YES;
    }

    // punctuation list
    if ((char)charCode == '`') {
        if (_languageModel->hasUnigramsForKey(string("_punctuation_list"))) {
            if (_bpmfReadingBuffer->isEmpty()) {
                _builder->insertReadingAtCursor(string("_punctuation_list"));
                [self popOverflowComposingTextAndWalk:client];
                [self _showCandidateWindowUsingVerticalMode:useVerticalMode client:client];
            }
            else { // If there is still unfinished bpmf reading, ignore the punctuation
                [self beep];
            }
            [self updateClientComposingBuffer:client];
            return YES;
        }
    }

    // if nothing is matched, see if it's a punctuation key for current layout.
    string layout = [self _currentLayout];
    string punctuationNamePrefix = Preferences.halfWidthPunctuationEnabled ? string("_half_punctuation_"): string("_punctuation_");
    string customPunctuation = punctuationNamePrefix + layout + string(1, (char)charCode);
    if ([self _handlePunctuation:customPunctuation usingVerticalMode:useVerticalMode client:client]) {
        return YES;
    }

    // if nothing is matched, see if it's a punctuation key.
    string punctuation = punctuationNamePrefix + string(1, (char)charCode);
    if ([self _handlePunctuation:punctuation usingVerticalMode:useVerticalMode client:client]) {
        return YES;
    }

    if ((char)charCode >= 'A' && (char)charCode <= 'Z') {
        if ([_composingBuffer length]) {
            string letter = string("_letter_") + string(1, (char)charCode);
            if ([self _handlePunctuation:letter usingVerticalMode:useVerticalMode client:client]) {
                return YES;
            }
        }
    }
    
    // still nothing, then we update the composing buffer (some app has
    // strange behavior if we don't do this, "thinking" the key is not
    // actually consumed)
    if ([_composingBuffer length] || !_bpmfReadingBuffer->isEmpty()) {
        [self beep];
        [self updateClientComposingBuffer:client];
        return YES;
    }

    return NO;
}

- (BOOL)_handlePunctuation:(string)customPunctuation usingVerticalMode:(BOOL)useVerticalMode client:(id)client
{
    if (_languageModel->hasUnigramsForKey(customPunctuation)) {
        if (_bpmfReadingBuffer->isEmpty()) {
            _builder->insertReadingAtCursor(customPunctuation);
            [self popOverflowComposingTextAndWalk:client];
        }
        else { // If there is still unfinished bpmf reading, ignore the punctuation
            [self beep];
        }
        [self updateClientComposingBuffer:client];

        if (Preferences.useWinNT351BPMF && _bpmfReadingBuffer->isEmpty()) {
            [self collectCandidates];
            if ([_candidates count] == 1) {
                [self commitComposition:client];
            }
            else {
                [self _showCandidateWindowUsingVerticalMode:useVerticalMode client:client];
            }
        }
        return YES;
    }
    return NO;
}

- (BOOL)_handleCandidateEventWithInputText:(NSString *)inputText charCode:(UniChar)charCode keyCode:(NSUInteger)keyCode emacsKey:(vChewingEmacsKey)emacsKey
{
    BOOL cancelCandidateKey =
    (charCode == 27) ||
    (Preferences.useWinNT351BPMF &&
     (charCode == 8 || keyCode == kDeleteKeyCode));

    if (cancelCandidateKey) {
        gCurrentCandidateController.visible = NO;
        [_candidates removeAllObjects];

        if (Preferences.useWinNT351BPMF) {
            _builder->clear();
            _walkedNodes.clear();
            [_composingBuffer setString:@""];
        }
        [self updateClientComposingBuffer:_currentCandidateClient];
        return YES;
    }
    else if (charCode == 13 || keyCode == kEnterKeyCode) {
        [self candidateController:gCurrentCandidateController didSelectCandidateAtIndex:gCurrentCandidateController.selectedCandidateIndex];
        return YES;
    }
    else if (charCode == 32 || keyCode == kPageDownKeyCode || emacsKey == vChewingEmacsKeyNextPage) {
        BOOL updated = [gCurrentCandidateController showNextPage];
        if (!updated) {
            [self beep];
        }
        [self updateClientComposingBuffer:_currentCandidateClient];
        return YES;
    }
    else if (keyCode == kPageUpKeyCode) {
        BOOL updated = [gCurrentCandidateController showPreviousPage];
        if (!updated) {
            [self beep];
        }
        [self updateClientComposingBuffer:_currentCandidateClient];
        return YES;
    }
    else if (keyCode == kLeftKeyCode) {
        if ([gCurrentCandidateController isKindOfClass:[VTHorizontalCandidateController class]]) {
            BOOL updated = [gCurrentCandidateController highlightPreviousCandidate];
            if (!updated) {
                [self beep];
            }
            [self updateClientComposingBuffer:_currentCandidateClient];
            return YES;
        }
        else {
            BOOL updated = [gCurrentCandidateController showPreviousPage];
            if (!updated) {
                [self beep];
            }
            [self updateClientComposingBuffer:_currentCandidateClient];
            return YES;
        }
    }
    else if (emacsKey == vChewingEmacsKeyBackward) {
        BOOL updated = [gCurrentCandidateController highlightPreviousCandidate];
        if (!updated) {
            [self beep];
        }
        [self updateClientComposingBuffer:_currentCandidateClient];
        return YES;
    }
    else if (keyCode == kRightKeyCode) {
        if ([gCurrentCandidateController isKindOfClass:[VTHorizontalCandidateController class]]) {
            BOOL updated = [gCurrentCandidateController highlightNextCandidate];
            if (!updated) {
                [self beep];
            }
            [self updateClientComposingBuffer:_currentCandidateClient];
            return YES;
        }
        else {
            BOOL updated = [gCurrentCandidateController showNextPage];
            if (!updated) {
                [self beep];
            }
            [self updateClientComposingBuffer:_currentCandidateClient];
            return YES;
        }
    }
    else if (emacsKey == vChewingEmacsKeyForward) {
        BOOL updated = [gCurrentCandidateController highlightNextCandidate];
        if (!updated) {
            [self beep];
        }
        [self updateClientComposingBuffer:_currentCandidateClient];
        return YES;
    }
    else if (keyCode == kUpKeyCode) {
        if ([gCurrentCandidateController isKindOfClass:[VTHorizontalCandidateController class]]) {
            BOOL updated = [gCurrentCandidateController showPreviousPage];
            if (!updated) {
                [self beep];
            }
            [self updateClientComposingBuffer:_currentCandidateClient];
            return YES;
        }
        else {
            BOOL updated = [gCurrentCandidateController highlightPreviousCandidate];
            if (!updated) {
                [self beep];
            }
            [self updateClientComposingBuffer:_currentCandidateClient];
            return YES;
        }
    }
    else if (keyCode == kDownKeyCode) {
        if ([gCurrentCandidateController isKindOfClass:[VTHorizontalCandidateController class]]) {
            BOOL updated = [gCurrentCandidateController showNextPage];
            if (!updated) {
                [self beep];
            }
            [self updateClientComposingBuffer:_currentCandidateClient];
            return YES;
        }
        else {
            BOOL updated = [gCurrentCandidateController highlightNextCandidate];
            if (!updated) {
                [self beep];
            }
            [self updateClientComposingBuffer:_currentCandidateClient];
            return YES;
        }
    }
    else if (keyCode == kHomeKeyCode || emacsKey == vChewingEmacsKeyHome) {
        if (gCurrentCandidateController.selectedCandidateIndex == 0) {
            [self beep];

        }
        else {
            gCurrentCandidateController.selectedCandidateIndex = 0;
        }

        [self updateClientComposingBuffer:_currentCandidateClient];
        return YES;
    }
    else if ((keyCode == kEndKeyCode || emacsKey == vChewingEmacsKeyEnd) && [_candidates count] > 0) {
        if (gCurrentCandidateController.selectedCandidateIndex == [_candidates count] - 1) {
            [self beep];
        }
        else {
            gCurrentCandidateController.selectedCandidateIndex = [_candidates count] - 1;
        }

        [self updateClientComposingBuffer:_currentCandidateClient];
        return YES;
    }
    else {
        NSInteger index = NSNotFound;
        for (NSUInteger j = 0, c = [gCurrentCandidateController.keyLabels count]; j < c; j++) {
            if ([inputText compare:[gCurrentCandidateController.keyLabels objectAtIndex:j] options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                index = j;
                break;
            }
        }

        [gCurrentCandidateController.keyLabels indexOfObject:inputText];
        if (index != NSNotFound) {
            NSUInteger candidateIndex = [gCurrentCandidateController candidateIndexAtKeyLabelIndex:index];
            if (candidateIndex != NSUIntegerMax) {
                [self candidateController:gCurrentCandidateController didSelectCandidateAtIndex:candidateIndex];
                return YES;
            }
        }

        if (Preferences.useWinNT351BPMF) {
            string layout = [self _currentLayout];
            string customPunctuation = string("_punctuation_") + layout + string(1, (char)charCode);
            string punctuation = string("_punctuation_") + string(1, (char)charCode);

            BOOL shouldAutoSelectCandidate = _bpmfReadingBuffer->isValidKey((char)charCode) || _languageModel->hasUnigramsForKey(customPunctuation) ||
            _languageModel->hasUnigramsForKey(punctuation);

            if (shouldAutoSelectCandidate) {
                NSUInteger candidateIndex = [gCurrentCandidateController candidateIndexAtKeyLabelIndex:0];
                if (candidateIndex != NSUIntegerMax) {
                    [self candidateController:gCurrentCandidateController didSelectCandidateAtIndex:candidateIndex];
                    return [self handleInputText:inputText key:keyCode modifiers:0 client:_currentCandidateClient];
                }
            }
        }

        [self beep];
        [self updateClientComposingBuffer:_currentCandidateClient];
        return YES;
    }
}

- (NSUInteger)recognizedEvents:(id)sender
{
    return NSKeyDownMask | NSFlagsChangedMask;
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)client
{
    if ([event type] == NSFlagsChanged) {
        NSString *functionKeyKeyboardLayoutID = Preferences.functionKeyboardLayout;
        NSString *basisKeyboardLayoutID = Preferences.basisKeyboardLayout;

        // If no override is needed, just return NO.
        if ([functionKeyKeyboardLayoutID isEqualToString:basisKeyboardLayoutID]) {
            return NO;
        }

        // Function key pressed.
        BOOL includeShift = Preferences.functionKeyKeyboardLayoutOverrideIncludeShiftKey;
        if (([event modifierFlags] & ~NSEventModifierFlagShift) || (([event modifierFlags] & NSEventModifierFlagShift) && includeShift)) {
            // Override the keyboard layout and let the OS do its thing
            [client overrideKeyboardWithKeyboardNamed:functionKeyKeyboardLayoutID];
            return NO;
        }

        // Revert back to the basis layout when the function key is released
        [client overrideKeyboardWithKeyboardNamed:basisKeyboardLayoutID];
        return NO;
    }

    NSString *inputText = [event characters];
    NSInteger keyCode = [event keyCode];
    NSUInteger flags = [event modifierFlags];
    return [self handleInputText:inputText key:keyCode modifiers:flags client:client];
}

#pragma mark - Private methods

+ (VTHorizontalCandidateController *)horizontalCandidateController
{
    static VTHorizontalCandidateController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VTHorizontalCandidateController alloc] init];
    });
    return instance;
}

+ (VTVerticalCandidateController *)verticalCandidateController
{
    static VTVerticalCandidateController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VTVerticalCandidateController alloc] init];
    });
    return instance;
}

+ (TooltipController *)tooltipController
{
    static TooltipController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TooltipController alloc] init];
    });
    return instance;
}

- (void)collectCandidates
{
    // returns the candidate
    [_candidates removeAllObjects];

    size_t cursorIndex = [self actualCandidateCursorIndex];
    vector<NodeAnchor> nodes = _builder->grid().nodesCrossingOrEndingAt(cursorIndex);

    // sort the nodes, so that longer nodes (representing longer phrases) are placed at the top of the candidate list
    stable_sort(nodes.begin(), nodes.end(), NodeAnchorDescendingSorter());

    // then use the C++ trick to retrieve the candidates for each node at/crossing the cursor
    for (vector<NodeAnchor>::iterator ni = nodes.begin(), ne = nodes.end(); ni != ne; ++ni) {
        const vector<KeyValuePair>& candidates = (*ni).node->candidates();
        for (vector<KeyValuePair>::const_iterator ci = candidates.begin(), ce = candidates.end(); ci != ce; ++ci) {
            [_candidates addObject:[NSString stringWithUTF8String:(*ci).value.c_str()]];
        }
    }
}

- (size_t)actualCandidateCursorIndex
{
    size_t cursorIndex = _builder->cursorIndex();
    if (Preferences.selectPhraseAfterCursorAsCandidate) {
        // MS Phonetics IME style, phrase is *after* the cursor, i.e. cursor is always *before* the phrase
        if (cursorIndex < _builder->length()) {
            ++cursorIndex;
        }
    }
    else {
        if (!cursorIndex) {
            ++cursorIndex;
        }
    }

    return cursorIndex;
}

- (void)_showCandidateWindowUsingVerticalMode:(BOOL)useVerticalMode client:(id)client
{
    // set the candidate panel style

    if (useVerticalMode) {
        gCurrentCandidateController = [vChewingInputMethodController verticalCandidateController];
    }
    else if (Preferences.useHorizontalCandidateList) {
        gCurrentCandidateController = [vChewingInputMethodController horizontalCandidateController];
    }
    else {
        gCurrentCandidateController = [vChewingInputMethodController verticalCandidateController];
    }

    // set the attributes for the candidate panel (which uses NSAttributedString)
    NSInteger textSize = Preferences.candidateListTextSize;

    NSInteger keyLabelSize = textSize / 2;
    if (keyLabelSize < kMinKeyLabelSize) {
        keyLabelSize = kMinKeyLabelSize;
    }

    NSString *ctFontName = Preferences.candidateTextFontName;
    NSString *klFontName = Preferences.candidateKeyLabelFontName;
    NSString *ckeys = Preferences.candidateKeys;

    gCurrentCandidateController.keyLabelFont = klFontName ? [NSFont fontWithName:klFontName size:keyLabelSize] : [NSFont systemFontOfSize:keyLabelSize];
    gCurrentCandidateController.candidateFont = ctFontName ? [NSFont fontWithName:ctFontName size:textSize] : [NSFont systemFontOfSize:textSize];

    NSMutableArray *keyLabels = [NSMutableArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", nil];

    if ([ckeys length] > 1) {
        [keyLabels removeAllObjects];
        for (NSUInteger i = 0, c = [ckeys length]; i < c; i++) {
            [keyLabels addObject:[ckeys substringWithRange:NSMakeRange(i, 1)]];
        }
    }

    gCurrentCandidateController.keyLabels = keyLabels;
    [self collectCandidates];

    if (Preferences.useWinNT351BPMF && [_candidates count] == 1) {
        [self commitComposition:client];
        return;
    }

    gCurrentCandidateController.delegate = self;
    [gCurrentCandidateController reloadData];

    // update the composing text, set the client
    [self updateClientComposingBuffer:client];
    _currentCandidateClient = client;

    NSRect lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);

    NSInteger cursor = _latestReadingCursor;
    if (cursor == [_composingBuffer length] && cursor != 0) {
        cursor--;
    }

    // some apps (e.g. Twitter for Mac's search bar) handle this call incorrectly, hence the try-catch
    @try {
        [client attributesForCharacterIndex:cursor lineHeightRectangle:&lineHeightRect];
    }
    @catch (NSException *exception) {
        NSLog(@"lineHeightRectangle %@", exception);
    }

    if (useVerticalMode) {
        [gCurrentCandidateController setWindowTopLeftPoint:NSMakePoint(lineHeightRect.origin.x + lineHeightRect.size.width + 4.0, lineHeightRect.origin.y - 4.0) bottomOutOfScreenAdjustmentHeight:lineHeightRect.size.height + 4.0];
    }
    else {
        [gCurrentCandidateController setWindowTopLeftPoint:NSMakePoint(lineHeightRect.origin.x, lineHeightRect.origin.y - 4.0) bottomOutOfScreenAdjustmentHeight:lineHeightRect.size.height + 4.0];
    }

    gCurrentCandidateController.visible = YES;
}

#pragma mark - User phrases

- (NSString *)_currentMarkedText
{
    if (_builder->markerCursorIndex() < 0) {
        return @"";
    }
    if (!_bpmfReadingBuffer->isEmpty()) {
        return @"";
    }

    size_t begin = min(_builder->markerCursorIndex(), _builder->cursorIndex());
    size_t end = max(_builder->markerCursorIndex(), _builder->cursorIndex());
    // A phrase should contain at least two characters.
    if (end - begin < 1) {
        return @"";
    }

    NSRange range = NSMakeRange((NSInteger)begin, (NSInteger)(end - begin));
    NSString *selectedText = [_composingBuffer substringWithRange:range];
    return selectedText;
}

- (NSString *)_currentMarkedTextAndReadings
{
    if (_builder->markerCursorIndex() < 0) {
        return @"";
    }
    if (!_bpmfReadingBuffer->isEmpty()) {
        return @"";
    }

    size_t begin = min(_builder->markerCursorIndex(), _builder->cursorIndex());
    size_t end = max(_builder->markerCursorIndex(), _builder->cursorIndex());
    // A phrase should contain at least two characters.
    if (end - begin < 2) {
        return @"";
    }
    if (end - begin > Preferences.maxCandidateLength) {
        return @"";
    }

    NSRange range = NSMakeRange((NSInteger)begin, (NSInteger)(end - begin));
    NSString *selectedText = [_composingBuffer substringWithRange:range];
    NSMutableString *string = [[NSMutableString alloc] init];
    [string appendString:selectedText];
    [string appendString:@" "];
    NSMutableArray *readingsArray = [[NSMutableArray alloc] init];
    vector<std::string> v = _builder->readingsAtRange(begin, end);
    for(vector<std::string>::iterator it_i=v.begin(); it_i!=v.end(); ++it_i) {
        [readingsArray addObject:[NSString stringWithUTF8String:it_i->c_str()]];
    }
    [string appendString:[readingsArray componentsJoinedByString:@"-"]];
    return string;
}

- (BOOL)_writeUserPhrase
{
    NSString *currentMarkedPhrase = [self _currentMarkedTextAndReadings];
    if (![currentMarkedPhrase length]) {
        [self beep];
        return NO;
    }
    
    return [LanguageModelManager writeUserPhrase:currentMarkedPhrase inputMode:_inputMode];
}

- (void)_showCurrentMarkedTextTooltipWithClient:(id)client
{
    NSString *text = [self _currentMarkedText];
    NSInteger length = text.length;
    if (!length) {
        [self _hideTooltip];
    }
    else if (Preferences.phraseReplacementEnabled) {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"⚠︎ Phrase replacement mode enabled, interfering user phrase entry.", @""), text];
        [self _showTooltip:message client:client];
    }
    else if (length < 2) {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" length must ≥ 2 for a user phrase.", @""), text];
        [self _showTooltip:message client:client];
    }
    else if (length > Preferences.maxCandidateLength) {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" length too long for a user phrase.", @""), text];
        [self _showTooltip:message client:client];
    }
    else {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" selected. ENTER to add user phrase.", @""), text];
        [self _showTooltip:message client:client];
    }
}

- (void)_showTooltip:(NSString *)tooltip client:(id)client
{
    NSRect lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);

    NSInteger cursor = _latestReadingCursor;
    if (cursor == [_composingBuffer length] && cursor != 0) {
        cursor--;
    }

    // some apps (e.g. Twitter for Mac's search bar) handle this call incorrectly, hence the try-catch
    @try {
        [client attributesForCharacterIndex:cursor lineHeightRectangle:&lineHeightRect];
    }
    @catch (NSException *exception) {
        NSLog(@"lineHeightRectangle %@", exception);
    }

    [[vChewingInputMethodController tooltipController] showTooltip:tooltip atPoint:lineHeightRect.origin];
}

- (void)_hideTooltip
{
    if ([vChewingInputMethodController tooltipController].window.isVisible) {
        [[vChewingInputMethodController tooltipController] hide];
    }
}

#pragma mark - Misc menu items

- (void)showPreferences:(id)sender
{
    // Write missing OOBE user plist entries.
    [Preferences setMissingDefaults];

    // show the preferences panel, and also make the IME app itself the focus
    if ([IMKInputController instancesRespondToSelector:@selector(showPreferences:)]) {
        [super showPreferences:sender];
    } else {
        [(AppDelegate *)[NSApp delegate] showPreferences];
    }
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (void)toggleWinNT351BPMFMode:(id)sender
{
    [NotifierController notifyWithMessage:[NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"NT351 BPMF EMU", @""), @"\n", [Preferences toggleWinNT351BPMFEnabled] ? NSLocalizedString(@"NotificationSwitchON", @"") : NSLocalizedString(@"NotificationSwitchOFF", @"")] stay:NO];
}

- (void)toggleChineseConverter:(id)sender
{
    [NotifierController notifyWithMessage:[NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"Force KangXi Writing", @""), @"\n", [Preferences toggleChineseConversionEnabled] ? NSLocalizedString(@"NotificationSwitchON", @"") : NSLocalizedString(@"NotificationSwitchOFF", @"")] stay:NO];
}

- (void)toggleHalfWidthPunctuation:(id)sender
{
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-result"
    [Preferences toggleHalfWidthPunctuationEnabled];
#pragma GCC diagnostic pop
}

- (void)togglePhraseReplacementEnabled:(id)sender
{
    if (_inputMode == kBopomofoModeIdentifierCHT) {
        BOOL enabled = [Preferences togglePhraseReplacementEnabled];
        vChewingLM *lm = [LanguageModelManager languageModelCoreCHT];
        lm->setPhraseReplacementEnabled(enabled);
    } else {
        BOOL enabled = [Preferences togglePhraseReplacementEnabled];
        vChewingLM *lm = [LanguageModelManager languageModelCoreCHS];
        lm->setPhraseReplacementEnabled(enabled);
    }
}

- (void)toggleCNS11643Enabled:(id)sender
{
    _languageModel->setCNSEnabled([Preferences toggleCNS11643Enabled]);
    // 注意上面這一行已經動過開關了，所以接下來就不要 toggle。
    [NotifierController notifyWithMessage:[NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"CNS11643 Mode", @""), @"\n", [Preferences cns11643Enabled] ? NSLocalizedString(@"NotificationSwitchON", @"") : NSLocalizedString(@"NotificationSwitchOFF", @"")] stay:NO];
}

- (void)selfTerminate:(id)sender
{
    NSLog(@"vChewing App self-terminated on request.");
    [NSApplication.sharedApplication terminate:nil];
}

- (void)checkForUpdate:(id)sender
{
    [(AppDelegate *)[[NSApplication sharedApplication] delegate] checkForUpdateForced:YES];
}

- (BOOL)_checkUserFiles
{
    if (![LanguageModelManager checkIfUserLanguageModelFilesExist] ) {
        NSString *content = [NSString stringWithFormat:NSLocalizedString(@"Please check the permission of at \"%@\".", @""), [LanguageModelManager dataFolderPath]];
        [[NonModalAlertWindowController sharedInstance] showWithTitle:NSLocalizedString(@"Unable to create the user phrase file.", @"") content:content confirmButtonTitle:NSLocalizedString(@"OK", @"") cancelButtonTitle:nil cancelAsDefault:NO delegate:nil];
        return NO;
    }

    return YES;
}

- (void)_openUserFile:(NSString *)path
{
    if (![self _checkUserFiles]) {
        return;
    }
    [[NSWorkspace sharedWorkspace] openFile:path withApplication:@"TextEdit"];
}

- (void)openUserPhrases:(id)sender
{
    [self _openUserFile:[LanguageModelManager userPhrasesDataPath:_inputMode]];
}

- (void)openExcludedPhrases:(id)sender
{
    [self _openUserFile:[LanguageModelManager excludedPhrasesDataPath:_inputMode]];
}

- (void)openPhraseReplacement:(id)sender
{
    [self _openUserFile:[LanguageModelManager phraseReplacementDataPath:_inputMode]];
}

- (void)reloadUserPhrases:(id)sender
{
    [LanguageModelManager loadUserPhrases];
    [LanguageModelManager loadUserPhraseReplacement];
}

- (void)showAbout:(id)sender
{
    // show the About window, and also make the IME app itself the focus
    [(AppDelegate *)[NSApp delegate] showAbout];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

@end

#pragma mark - Voltaire

@implementation vChewingInputMethodController (VTCandidateController)

- (NSUInteger)candidateCountForController:(VTCandidateController *)controller
{
    return [_candidates count];
}

- (NSString *)candidateController:(VTCandidateController *)controller candidateAtIndex:(NSUInteger)index
{
    return [_candidates objectAtIndex:index];
}

- (void)candidateController:(VTCandidateController *)controller didSelectCandidateAtIndex:(NSUInteger)index
{
    gCurrentCandidateController.visible = NO;

    // candidate selected, override the node with selection
    string selectedValue = [[_candidates objectAtIndex:index] UTF8String];

    size_t cursorIndex = [self actualCandidateCursorIndex];
    _builder->grid().fixNodeSelectedCandidate(cursorIndex, selectedValue);
    if (!Preferences.useWinNT351BPMF) {
        _userOverrideModel->observe(_walkedNodes, cursorIndex, selectedValue, [[NSDate date] timeIntervalSince1970]);
    }

    [_candidates removeAllObjects];

    [self walk];
    [self updateClientComposingBuffer:_currentCandidateClient];

    if (Preferences.useWinNT351BPMF) {
        [self commitComposition:_currentCandidateClient];
        return;
    }
}

@end

