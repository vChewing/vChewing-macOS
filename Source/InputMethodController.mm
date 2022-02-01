/* 
 *  InputMethodController.mm
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#import "vChewingLM.h"
#import "InputMethodController.h"
#import "KeyHandler.h"
#import "LanguageModelManager.h"

using namespace std;
using namespace vChewing;

static const NSInteger kMinKeyLabelSize = 10;

VTCandidateController *gCurrentCandidateController = nil;

__attribute__((annotate("returns_localized_nsstring")))
static inline NSString *LocalizationNotNeeded(NSString *s) {
    return s;
}

@interface vChewingInputMethodController ()
{
	// the current text input client; we need to keep this when candidate panel is on
	id _currentCandidateClient;

	// a special deferred client for Terminal.app fix
	id _currentDeferredClient;

	KeyHandler *_keyHandler;
	InputState *_state;
}
@end

@interface vChewingInputMethodController (VTCandidateController) <VTCandidateControllerDelegate>
@end

@interface vChewingInputMethodController (KeyHandlerDelegate) <KeyHandlerDelegate>
@end

@interface vChewingInputMethodController (UI)
+ (VTHorizontalCandidateController *)horizontalCandidateController;
+ (VTVerticalCandidateController *)verticalCandidateController;
+ (TooltipController *)tooltipController;
- (void)_showTooltip:(NSString *)tooltip composingBuffer:(NSString *)composingBuffer cursorIndex:(NSInteger)cursorIndex client:(id)client;
- (void)_hideTooltip;
@end

@implementation vChewingInputMethodController

- (id)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)client
{
	// an instance is initialized whenever a text input client (a Mac app) requires
	// text input from an IME

	self = [super initWithServer:server delegate:delegate client:client];
	if (self) {
		_keyHandler = [[KeyHandler alloc] init];
		_keyHandler.delegate = self;
		_state = [[InputStateEmpty alloc] init];
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

    NSMenuItem *halfWidthPunctuationMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Half-Width Punctuation Mode", @"") action:@selector(toggleHalfWidthPunctuation:) keyEquivalent:@"H"];
    halfWidthPunctuationMenuItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;
    halfWidthPunctuationMenuItem.state = Preferences.halfWidthPunctuationEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    if (optionKeyPressed) {
        NSMenuItem *phaseReplacementMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Use Phrase Replacement", @"") action:@selector(togglePhraseReplacementEnabled:) keyEquivalent:@""];
        phaseReplacementMenuItem.state = Preferences.phraseReplacementEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    }

    [menu addItem:[NSMenuItem separatorItem]]; // ------------------------------

    [menu addItemWithTitle:NSLocalizedString(@"Edit User Phrases…", @"") action:@selector(openUserPhrases:) keyEquivalent:@""];
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

    // reset the state
    _currentDeferredClient = nil;
    _currentCandidateClient = nil;
	[_keyHandler clear];
	InputStateEmpty *empty = [[InputStateEmpty alloc] init];
	[self handleState:empty client:client];

	// checks and populates the default settings
	[_keyHandler syncWithPreferences];
	[(AppDelegate *) NSApp.delegate checkForUpdate];
}

- (void)deactivateServer:(id)client
{
	[_keyHandler clear];
	InputStateEmpty *empty = [[InputStateEmpty alloc] init];
	[self handleState:empty client:client];
	InputStateDeactivated *inactive = [[InputStateDeactivated alloc] init];
	[self handleState:inactive client:client];
}

- (void)setValue:(id)value forTag:(long)tag client:(id)sender
{
    NSString *newInputMode;

    if ([value isKindOfClass:[NSString class]] && [value isEqual:kBopomofoModeIdentifierCHS]) {
        newInputMode = kBopomofoModeIdentifierCHS;
    } else {
        newInputMode = kBopomofoModeIdentifierCHT;
    }
	
	if (![_keyHandler.inputMode isEqualToString:newInputMode]) {
		[[NSUserDefaults standardUserDefaults] synchronize];

		// Remember to override the keyboard layout again -- treat this as an activate event.
		NSString *basisKeyboardLayoutID = Preferences.basisKeyboardLayout;
		[sender overrideKeyboardWithKeyboardNamed:basisKeyboardLayoutID];
		[_keyHandler clear];
		_keyHandler.inputMode = newInputMode;
		InputState *empty = [[InputState alloc] init];
		[self handleState:empty client:sender];
	}

}

#pragma mark - IMKServerInput protocol methods

- (NSUInteger)recognizedEvents:(id)sender
{
	return NSEventMaskKeyDown | NSEventMaskFlagsChanged;
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)client
{
	if ([event type] == NSEventMaskFlagsChanged) {
		NSString *functionKeyKeyboardLayoutID = Preferences.functionKeyboardLayout;
		NSString *basisKeyboardLayoutID = Preferences.basisKeyboardLayout;

		// If no override is needed, just return NO.
		if ([functionKeyKeyboardLayoutID isEqualToString:basisKeyboardLayoutID]) {
			return NO;
		}

		// Function key pressed.
		BOOL includeShift = Preferences.functionKeyKeyboardLayoutOverrideIncludeShiftKey;
		if ((event.modifierFlags & ~NSEventModifierFlagShift) || ((event.modifierFlags & NSEventModifierFlagShift) && includeShift)) {
			// Override the keyboard layout and let the OS do its thing
			[client overrideKeyboardWithKeyboardNamed:functionKeyKeyboardLayoutID];
			return NO;
		}

		// Revert to the basis layout when the function key is released
		[client overrideKeyboardWithKeyboardNamed:basisKeyboardLayoutID];
		return NO;
	}

	NSRect textFrame = NSZeroRect;
	NSDictionary *attributes = nil;
	BOOL useVerticalMode = NO;

	@try {
		attributes = [client attributesForCharacterIndex:0 lineHeightRectangle:&textFrame];
		useVerticalMode = attributes[@"IMKTextOrientation"] && [attributes[@"IMKTextOrientation"] integerValue] == 0;
	}
	@catch (NSException *e) {
		// exception may raise while using Twitter.app's search filed.
	}

	if ([[client bundleIdentifier] isEqualToString:@"com.apple.Terminal"] && [NSStringFromClass([client class]) isEqualToString:@"IPMDServerClientWrapper"]) {
		// special handling for com.apple.Terminal
		_currentDeferredClient = client;
	}

	KeyHandlerInput *input = [[KeyHandlerInput alloc] initWithEvent:event isVerticalMode:useVerticalMode];
	BOOL result = [_keyHandler handleInput:input state:_state stateCallback:^(InputState *state) {
		[self handleState:state client:client];
	}           candidateSelectionCallback:^{
		NSLog(@"candidate window updated.");
	}                        errorCallback:^{
		[clsSFX beep];
	}];

	return result;
}

#pragma mark - States Handling

- (NSString *)_convertToKangXi:(NSString *)text
{
    if (!Preferences.chineseConversionEnabled) {
        return text; // 沒啟用的話就不要轉換。
    }
    // return [VXHanConvert convertToSimplifiedFrom:text]; // VXHanConvert 這個引擎有點落後了，不支援詞組轉換、且修改轉換表的過程很麻煩。
    // OpenCC 引擎別的都還好，就是有點肥。改日換成純 ObjC 的 OpenCC 實現方案。
    return [OpenCCBridge convertToKangXi:text];
}

- (void)_commitText:(NSString *)text client:(id)client
{
	NSString *buffer = [self _convertToKangXi:text];
	if (!buffer.length) {
		return;;
	}

	// if it's Terminal, we don't commit at the first call (the client of which will not be IPMDServerClientWrapper)
	// then we defer the update in the next runloop round -- so that the composing buffer is not
	// meaninglessly flushed, an annoying bug in Terminal.app since Mac OS X 10.5
	if ([[client bundleIdentifier] isEqualToString:@"com.apple.Terminal"] && ![NSStringFromClass([client class]) isEqualToString:@"IPMDServerClientWrapper"]) {
		if (_currentDeferredClient) {
			id currentDeferredClient = _currentDeferredClient;
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[currentDeferredClient insertText:buffer replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
			});
		}
		return;
	}
	[client insertText:buffer replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

- (void)handleState:(InputState *)newState client:(id)client
{
//    NSLog(@"new state: %@ / current state: %@", newState, _state);

	// We need to set the state to the member variable since the candidate
	// window need to read the candidates from it.
	InputState *previous = _state;
	_state = newState;

	if ([newState isKindOfClass:[InputStateDeactivated class]]) {
		[self _handleDeactivated:(InputStateDeactivated *) newState previous:previous client:client];
	} else if ([newState isKindOfClass:[InputStateEmpty class]]) {
		[self _handleEmpty:(InputStateEmpty *) newState previous:previous client:client];
	} else if ([newState isKindOfClass:[InputStateEmptyIgnoringPreviousState class]]) {
		[self _handleEmptyIgnoringPrevious:(InputStateEmptyIgnoringPreviousState *) newState previous:previous client:client];
	} else if ([newState isKindOfClass:[InputStateCommitting class]]) {
		[self _handleCommitting:(InputStateCommitting *) newState previous:previous client:client];
	} else if ([newState isKindOfClass:[InputStateInputting class]]) {
		[self _handleInputting:(InputStateInputting *) newState previous:previous client:client];
	} else if ([newState isKindOfClass:[InputStateMarking class]]) {
		[self _handleMarking:(InputStateMarking *) newState previous:previous client:client];
	} else if ([newState isKindOfClass:[InputStateChoosingCandidate class]]) {
		[self _handleChoosingCandidate:(InputStateChoosingCandidate *) newState previous:previous client:client];
	}
}

- (void)_handleDeactivated:(InputStateDeactivated *)state previous:(InputState *)previous client:(id)client
{
	// commit any residue in the composing buffer
	if ([previous isKindOfClass:[InputStateInputting class]]) {
		NSString *buffer = ((InputStateInputting *) previous).composingBuffer;
		[self _commitText:buffer client:client];
	}
	[client setMarkedText:@"" selectionRange:NSMakeRange(0, 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

	_currentDeferredClient = nil;
	_currentCandidateClient = nil;

	gCurrentCandidateController.delegate = nil;
	gCurrentCandidateController.visible = NO;
	[self _hideTooltip];
}

- (void)_handleEmpty:(InputStateEmpty *)state previous:(InputState *)previous client:(id)client
{
	// commit any residue in the composing buffer
	if ([previous isKindOfClass:[InputStateInputting class]]) {
		NSString *buffer = ((InputStateInputting *) previous).composingBuffer;
		[self _commitText:buffer client:client];
	}

	[client setMarkedText:@"" selectionRange:NSMakeRange(0, 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
	gCurrentCandidateController.visible = NO;
	[self _hideTooltip];
}

- (void)_handleEmptyIgnoringPrevious:(InputStateEmptyIgnoringPreviousState *)state previous:(InputState *)previous client:(id)client
{
	[client setMarkedText:@"" selectionRange:NSMakeRange(0, 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
	gCurrentCandidateController.visible = NO;
	[self _hideTooltip];
}

- (void)_handleCommitting:(InputStateCommitting *)state previous:(InputState *)previous client:(id)client
{
	NSString *poppedText = state.poppedText;
	[self _commitText:poppedText client:client];
	gCurrentCandidateController.visible = NO;
	[self _hideTooltip];
}

- (void)_handleInputting:(InputStateInputting *)state previous:(InputState *)previous client:(id)client
{
	NSString *poppedText = state.poppedText;
	if (poppedText.length) {
		[self _commitText:poppedText client:client];
	}

	NSUInteger cursorIndex = state.cursorIndex;
	NSAttributedString *attrString = state.attributedString;

	// the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
	// i.e. the client app needs to take care of where to put ths composing buffer
	[client setMarkedText:attrString selectionRange:NSMakeRange(cursorIndex, 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

	gCurrentCandidateController.visible = NO;
	[self _hideTooltip];
}

- (void)_handleMarking:(InputStateMarking *)state previous:(InputState *)previous client:(id)client
{
	NSUInteger cursorIndex = state.cursorIndex;
	NSAttributedString *attrString = state.attributedString;

	// the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
	// i.e. the client app needs to take care of where to put ths composing buffer
	[client setMarkedText:attrString selectionRange:NSMakeRange(cursorIndex, 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

	gCurrentCandidateController.visible = NO;
	if (state.tooltip.length) {
		[self _showTooltip:state.tooltip composingBuffer:state.composingBuffer cursorIndex:state.markerIndex client:client];
	} else {
		[self _hideTooltip];
	}
}

- (void)_handleChoosingCandidate:(InputStateChoosingCandidate *)state previous:(InputState *)previous client:(id)client
{
	NSUInteger cursorIndex = state.cursorIndex;
	NSAttributedString *attrString = state.attributedString;

	// the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
	// i.e. the client app needs to take care of where to put ths composing buffer
	[client setMarkedText:attrString selectionRange:NSMakeRange(cursorIndex, 0) replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

	if (![previous isKindOfClass:[InputStateChoosingCandidate class]]) {
		[self _showCandidateWindowWithState:state client:client];
	}
}

- (void)_showCandidateWindowWithState:(InputStateChoosingCandidate *)state client:(id)client
{
	// set the candidate panel style
	BOOL useVerticalMode = state.useVerticalMode;

	if (useVerticalMode) {
		gCurrentCandidateController = [vChewingInputMethodController verticalCandidateController];
	} else if (Preferences.useHorizontalCandidateList) {
		gCurrentCandidateController = [vChewingInputMethodController horizontalCandidateController];
	} else {
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
	NSString *candidateKeys = Preferences.candidateKeys;

	gCurrentCandidateController.keyLabelFont = klFontName ? [NSFont fontWithName:klFontName size:keyLabelSize] : [NSFont systemFontOfSize:keyLabelSize];
	gCurrentCandidateController.candidateFont = ctFontName ? [NSFont fontWithName:ctFontName size:textSize] : [NSFont systemFontOfSize:textSize];

	NSMutableArray *keyLabels = [@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9"] mutableCopy];

	if (candidateKeys.length > 1) {
		[keyLabels removeAllObjects];
		for (NSUInteger i = 0, c = candidateKeys.length; i < c; i++) {
			[keyLabels addObject:[candidateKeys substringWithRange:NSMakeRange(i, 1)]];
		}
	}

	gCurrentCandidateController.keyLabels = keyLabels;
	gCurrentCandidateController.delegate = self;
	[gCurrentCandidateController reloadData];
	_currentCandidateClient = client;

	NSRect lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);
	NSInteger cursor = state.cursorIndex;
	if (cursor == state.composingBuffer.length && cursor != 0) {
		cursor--;
	}

	// some apps (e.g. Twitter for Mac's search bar) handle this call incorrectly, hence the try-catch
	@try {
		[client attributesForCharacterIndex:cursor lineHeightRectangle:&lineHeightRect];
		if ((lineHeightRect.origin.x == 0) && (lineHeightRect.origin.y == 0) && (cursor > 0)) {
			cursor -= 1; // Zonble's UPR fix: "Corrects the selection range while using Shift + Arrow keys to add new phrases."
			[client attributesForCharacterIndex:cursor lineHeightRectangle:&lineHeightRect];
		}
	}
	@catch (NSException *exception) {
		NSLog(@"lineHeightRectangle %@", exception);
	}

	if (useVerticalMode) {
		[gCurrentCandidateController setWindowTopLeftPoint:NSMakePoint(lineHeightRect.origin.x + lineHeightRect.size.width + 4.0, lineHeightRect.origin.y - 4.0) bottomOutOfScreenAdjustmentHeight:lineHeightRect.size.height + 4.0];
	} else {
		[gCurrentCandidateController setWindowTopLeftPoint:NSMakePoint(lineHeightRect.origin.x, lineHeightRect.origin.y - 4.0) bottomOutOfScreenAdjustmentHeight:lineHeightRect.size.height + 4.0];
	}

	gCurrentCandidateController.visible = YES;
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
    [NotifierController notifyWithMessage:[NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"Half-Width Punctuation Mode", @""), @"\n", [Preferences toggleHalfWidthPunctuationEnabled] ? NSLocalizedString(@"NotificationSwitchON", @"") : NSLocalizedString(@"NotificationSwitchOFF", @"")] stay:NO];
}

- (void)togglePhraseReplacementEnabled:(id)sender
{
	if (_keyHandler.inputMode == kBopomofoModeIdentifierCHT){
		[LanguageModelManager languageModelCoreCHT]->setPhraseReplacementEnabled([Preferences togglePhraseReplacementEnabled]);
		
	} else {
		[LanguageModelManager languageModelCoreCHS]->setPhraseReplacementEnabled([Preferences togglePhraseReplacementEnabled]);
	}
}

- (void)toggleCNS11643Enabled:(id)sender
{
	if (_keyHandler.inputMode == kBopomofoModeIdentifierCHT){
		[LanguageModelManager languageModelCoreCHT]->setCNSEnabled([Preferences toggleCNS11643Enabled]);
	} else {
		[LanguageModelManager languageModelCoreCHS]->setCNSEnabled([Preferences toggleCNS11643Enabled]);
	}
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
	[(AppDelegate *) NSApp.delegate checkForUpdateForced:YES];
}

- (BOOL)_checkUserFiles
{
	if (![LanguageModelManager checkIfUserLanguageModelFilesExist]) {
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
    [self _openUserFile:[LanguageModelManager userPhrasesDataPath:_keyHandler.inputMode]];
}

- (void)openExcludedPhrases:(id)sender
{
    [self _openUserFile:[LanguageModelManager excludedPhrasesDataPath:_keyHandler.inputMode]];
}

- (void)openPhraseReplacement:(id)sender
{
    [self _openUserFile:[LanguageModelManager phraseReplacementDataPath:_keyHandler.inputMode]];
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
	if ([_state isKindOfClass:[InputStateChoosingCandidate class]]) {
		InputStateChoosingCandidate *state = (InputStateChoosingCandidate *) _state;
		return state.candidates.count;
	}
	return 0;
}

- (NSString *)candidateController:(VTCandidateController *)controller candidateAtIndex:(NSUInteger)index
{
	if ([_state isKindOfClass:[InputStateChoosingCandidate class]]) {
		InputStateChoosingCandidate *state = (InputStateChoosingCandidate *) _state;
		return state.candidates[index];
	}
	return @"";
}

- (void)candidateController:(VTCandidateController *)controller didSelectCandidateAtIndex:(NSUInteger)index
{
	gCurrentCandidateController.visible = NO;

	if ([_state isKindOfClass:[InputStateChoosingCandidate class]]) {
		InputStateChoosingCandidate *state = (InputStateChoosingCandidate *) _state;

		// candidate selected, override the node with selection
		string selectedValue = [state.candidates[index] UTF8String];
		[_keyHandler fixNodeWithValue:selectedValue];
		InputStateInputting *inputting = [_keyHandler _buildInputtingState];

		if (Preferences.useWinNT351BPMF) {
			[_keyHandler clear];
			InputStateCommitting *committing = [[InputStateCommitting alloc] initWithPoppedText:inputting.composingBuffer];
			[self handleState:committing client:_currentCandidateClient];
			InputStateEmpty *empty = [[InputStateEmpty alloc] init];
			[self handleState:empty client:_currentCandidateClient];
		} else {
			[self handleState:inputting client:_currentCandidateClient];
		}
	}
}

@end

#pragma mark - Implementation

@implementation vChewingInputMethodController (KeyHandlerDelegate)

- (nonnull VTCandidateController *)candidateControllerForKeyHandler:(nonnull KeyHandler *)keyHandler
{
	return gCurrentCandidateController;
}

- (BOOL)keyHandler:(nonnull KeyHandler *)keyHandler didRequestWriteUserPhraseWithState:(nonnull InputStateMarking *)state
{
	if (!state.validToWrite) {
		return NO;
	}
	NSString *userPhrase = state.userPhrase;
	return [LanguageModelManager writeUserPhrase:userPhrase inputMode:_keyHandler.inputMode];
	return YES;
}

- (void)keyHandler:(nonnull KeyHandler *)keyHandler didSelectCandidateAtIndex:(NSInteger)index candidateController:(nonnull VTCandidateController *)controller
{
	[self candidateController:gCurrentCandidateController didSelectCandidateAtIndex:index];
}

@end


@implementation vChewingInputMethodController (UI)

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

- (void)_showTooltip:(NSString *)tooltip composingBuffer:(NSString *)composingBuffer cursorIndex:(NSInteger)cursorIndex client:(id)client
{
	NSRect lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);

	NSUInteger cursor = (NSUInteger) cursorIndex;
	if (cursor == composingBuffer.length && cursor != 0) {
		cursor--;
	}

	// some apps (e.g. Twitter for Mac's search bar) handle this call incorrectly, hence the try-catch
	@try {
		[client attributesForCharacterIndex:cursor lineHeightRectangle:&lineHeightRect];
		if ((lineHeightRect.origin.x == 0) && (lineHeightRect.origin.y == 0) && (cursor > 0)) {
			cursor -= 1; // Zonble's UPR fix: "Corrects the selection range while using Shift + Arrow keys to add new phrases."
			[client attributesForCharacterIndex:cursor lineHeightRectangle:&lineHeightRect];
		}
	}
	@catch (NSException *exception) {
		NSLog(@"%@", exception);
	}

	[[vChewingInputMethodController tooltipController] showTooltip:tooltip atPoint:lineHeightRect.origin];
}

- (void)_hideTooltip
{
	if ([vChewingInputMethodController tooltipController].window.isVisible) {
		[[vChewingInputMethodController tooltipController] hide];
	}
}

@end
