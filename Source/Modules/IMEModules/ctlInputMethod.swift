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

import Cocoa
import InputMethodKit

private let kMinKeyLabelSize: CGFloat = 10

private var ctlCandidateCurrent: ctlCandidate?

extension ctlCandidate {
	fileprivate static let horizontal = ctlCandidateHorizontal()
	fileprivate static let vertical = ctlCandidateVertical()
}

@objc(ctlInputMethod)
class ctlInputMethod: IMKInputController {

	@objc static let kIMEModeCHS = "org.atelierInmu.inputmethod.vChewing.IMECHS"
	@objc static let kIMEModeCHT = "org.atelierInmu.inputmethod.vChewing.IMECHT"
	@objc static let kIMEModeNULL = "org.atelierInmu.inputmethod.vChewing.IMENULL"

	@objc static var areWeDeleting = false

	private static let tooltipController = TooltipController()

	// MARK: -

	private var currentClient: Any?

	private var keyHandler: KeyHandler = KeyHandler()
	private var state: InputState = InputState.Empty()

	// 想讓 keyHandler 能夠被外界調查狀態與參數的話，就得對 keyHandler 做常態處理。
	// 這樣 InputState 可以藉由這個 ctlInputMethod 了解到當前的輸入模式是簡體中文還是繁體中文。
	// 然而，要是直接對 keyHandler 做常態處理的話，反而會導致 keyParser 無法協同處理。
	// 所以才需要「currentKeyHandler」這個假 keyHandler。
	// 這個「currentKeyHandler」僅用來讓其他模組知道當前的輸入模式是什麼模式，除此之外別無屌用。
	static var currentKeyHandler: KeyHandler = KeyHandler()
	@objc static var currentInputMode = ""

	// MARK: - Keyboard Layout Specifier

	@objc func setKeyLayout() {
		let client = client().self as IMKTextInput
		client.overrideKeyboard(withKeyboardNamed: mgrPrefs.basicKeyboardLayout)
	}

	// MARK: - IMKInputController methods

	override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
		super.init(server: server, delegate: delegate, client: inputClient)
		keyHandler.delegate = self
	}

	// MARK: - KeyHandler Reset Command

	func resetKeyHandler() {
		if let currentClient = currentClient {
			keyHandler.clear()
			self.handle(state: InputState.Empty(), client: currentClient)
		}
	}

	// MARK: - IMKStateSetting protocol methods

	override func activateServer(_ client: Any!) {
		UserDefaults.standard.synchronize()

		// Override the keyboard layout to the basic one.
		setKeyLayout()
		// reset the state
		currentClient = client

		keyHandler.clear()
		keyHandler.syncWithPreferences()
		self.handle(state: .Empty(), client: client)
		(NSApp.delegate as? AppDelegate)?.checkForUpdate()
	}

	override func deactivateServer(_ client: Any!) {
		keyHandler.clear()
		currentClient = nil
		self.handle(state: .Empty(), client: client)
		self.handle(state: .Deactivated(), client: client)
	}

	override func setValue(_ value: Any!, forTag tag: Int, client: Any!) {
		var newInputMode = InputMode(rawValue: value as? String ?? InputMode.imeModeNULL.rawValue)
		switch newInputMode {
			case InputMode.imeModeCHS:
				newInputMode = InputMode.imeModeCHS
			case InputMode.imeModeCHT:
				newInputMode = InputMode.imeModeCHT
			default:
				newInputMode = InputMode.imeModeNULL
		}
		mgrLangModel.loadDataModel(newInputMode)

		// Remember to override the keyboard layout again -- treat this as an activate event.
		setKeyLayout()

		if keyHandler.inputMode != newInputMode {
			UserDefaults.standard.synchronize()
			keyHandler.clear()
			keyHandler.inputMode = newInputMode
			self.handle(state: .Empty(), client: client)
		}

		// 讓外界知道目前的簡繁體輸入模式。
		ctlInputMethod.currentKeyHandler.inputMode = keyHandler.inputMode
	}

	// MARK: - IMKServerInput protocol methods

	override func recognizedEvents(_ sender: Any!) -> Int {
		let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
		return Int(events.rawValue)
	}

	override func handle(_ event: NSEvent!, client: Any!) -> Bool {

		// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 KeyHandler 內修復。
		// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
		// 同時注意：必須在 event.type == .flagsChanged 結尾插入 return false，
		// 否則，每次處理這種判斷時都會觸發 NSInternalInconsistencyException。
		if event.type == .flagsChanged {
			return false
		}

		// 準備修飾鍵，用來判定是否需要利用就地新增語彙時的 Enter 鍵來砍詞。
		ctlInputMethod.areWeDeleting = event.modifierFlags.contains([.shift, .command])

		var textFrame = NSRect.zero
		let attributes: [AnyHashable: Any]? = (client as? IMKTextInput)?.attributes(
			forCharacterIndex: 0, lineHeightRectangle: &textFrame)
		let useVerticalMode =
			(attributes?["IMKTextOrientation"] as? NSNumber)?.intValue == 0 || false

		if (client as? IMKTextInput)?.bundleIdentifier()
			== "org.atelierInmu.vChewing.vChewingPhraseEditor"
		{
			IME.areWeUsingOurOwnPhraseEditor = true
		} else {
			IME.areWeUsingOurOwnPhraseEditor = false
		}

		let input = keyParser(event: event, isVerticalMode: useVerticalMode)

		let result = keyHandler.handle(input: input, state: state) { newState in
			self.handle(state: newState, client: client)
		} errorCallback: {
			clsSFX.beep()
		}
		return result
	}
}

// MARK: - State Handling

extension ctlInputMethod {

	private func handle(state newState: InputState, client: Any?) {
		let previous = state
		state = newState

		if let newState = newState as? InputState.Deactivated {
			handle(state: newState, previous: previous, client: client)
		} else if let newState = newState as? InputState.Empty {
			handle(state: newState, previous: previous, client: client)
		} else if let newState = newState as? InputState.EmptyIgnoringPreviousState {
			handle(state: newState, previous: previous, client: client)
		} else if let newState = newState as? InputState.Committing {
			handle(state: newState, previous: previous, client: client)
		} else if let newState = newState as? InputState.Inputting {
			handle(state: newState, previous: previous, client: client)
		} else if let newState = newState as? InputState.Marking {
			handle(state: newState, previous: previous, client: client)
		} else if let newState = newState as? InputState.ChoosingCandidate {
			handle(state: newState, previous: previous, client: client)
		} else if let newState = newState as? InputState.AssociatedPhrases {
			handle(state: newState, previous: previous, client: client)
		}
	}

	private func commit(text: String, client: Any!) {

		func kanjiConversionIfRequired(_ text: String) -> String {
			if keyHandler.inputMode == InputMode.imeModeCHT {
				if !mgrPrefs.chineseConversionEnabled && mgrPrefs.shiftJISShinjitaiOutputEnabled {
					return vChewingKanjiConverter.cnvTradToJIS(text)
				}
				if mgrPrefs.chineseConversionEnabled && !mgrPrefs.shiftJISShinjitaiOutputEnabled {
					return vChewingKanjiConverter.cnvTradToKangXi(text)
				}
				// 本來這兩個開關不該同時開啟的，但萬一被開啟了的話就這樣處理：
				if mgrPrefs.chineseConversionEnabled && mgrPrefs.shiftJISShinjitaiOutputEnabled {
					return vChewingKanjiConverter.cnvTradToJIS(text)
				}
				// if (!mgrPrefs.chineseConversionEnabled && !mgrPrefs.shiftJISShinjitaiOutputEnabled) || (keyHandler.inputMode != InputMode.imeModeCHT);
				return text
			}
			return text
		}

		let buffer = kanjiConversionIfRequired(text)
		if buffer.isEmpty {
			return
		}
		(client as? IMKTextInput)?.insertText(
			buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
	}

	private func handle(state: InputState.Deactivated, previous: InputState, client: Any?) {
		currentClient = nil

		ctlCandidateCurrent?.delegate = nil
		ctlCandidateCurrent?.visible = false
		hideTooltip()

		if let previous = previous as? InputState.NotEmpty {
			commit(text: previous.composingBuffer, client: client)
		}
		(client as? IMKTextInput)?.setMarkedText(
			"", selectionRange: NSMakeRange(0, 0),
			replacementRange: NSMakeRange(NSNotFound, NSNotFound))
	}

	private func handle(state: InputState.Empty, previous: InputState, client: Any?) {
		ctlCandidateCurrent?.visible = false
		hideTooltip()

		guard let client = client as? IMKTextInput else {
			return
		}

		if let previous = previous as? InputState.NotEmpty {
			commit(text: previous.composingBuffer, client: client)
		}
		client.setMarkedText(
			"", selectionRange: NSMakeRange(0, 0),
			replacementRange: NSMakeRange(NSNotFound, NSNotFound))
	}

	private func handle(
		state: InputState.EmptyIgnoringPreviousState, previous: InputState, client: Any!
	) {
		ctlCandidateCurrent?.visible = false
		hideTooltip()

		guard let client = client as? IMKTextInput else {
			return
		}

		client.setMarkedText(
			"", selectionRange: NSMakeRange(0, 0),
			replacementRange: NSMakeRange(NSNotFound, NSNotFound))
	}

	private func handle(state: InputState.Committing, previous: InputState, client: Any?) {
		ctlCandidateCurrent?.visible = false
		hideTooltip()

		guard let client = client as? IMKTextInput else {
			return
		}

		let poppedText = state.poppedText
		if !poppedText.isEmpty {
			commit(text: poppedText, client: client)
		}
		client.setMarkedText(
			"", selectionRange: NSMakeRange(0, 0),
			replacementRange: NSMakeRange(NSNotFound, NSNotFound))
	}

	private func handle(state: InputState.Inputting, previous: InputState, client: Any?) {
		ctlCandidateCurrent?.visible = false
		hideTooltip()

		guard let client = client as? IMKTextInput else {
			return
		}

		let poppedText = state.poppedText
		if !poppedText.isEmpty {
			commit(text: poppedText, client: client)
		}

		// the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
		// i.e. the client app needs to take care of where to put this composing buffer
		client.setMarkedText(
			state.attributedString, selectionRange: NSMakeRange(Int(state.cursorIndex), 0),
			replacementRange: NSMakeRange(NSNotFound, NSNotFound))
		if !state.tooltip.isEmpty {
			show(
				tooltip: state.tooltip, composingBuffer: state.composingBuffer,
				cursorIndex: state.cursorIndex, client: client)
		}
	}

	private func handle(state: InputState.Marking, previous: InputState, client: Any?) {
		ctlCandidateCurrent?.visible = false
		guard let client = client as? IMKTextInput else {
			hideTooltip()
			return
		}

		// the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
		// i.e. the client app needs to take care of where to put this composing buffer
		client.setMarkedText(
			state.attributedString, selectionRange: NSMakeRange(Int(state.cursorIndex), 0),
			replacementRange: NSMakeRange(NSNotFound, NSNotFound))

		if state.tooltip.isEmpty {
			hideTooltip()
		} else {
			show(
				tooltip: state.tooltip, composingBuffer: state.composingBuffer,
				cursorIndex: state.markerIndex, client: client)
		}
	}

	private func handle(state: InputState.ChoosingCandidate, previous: InputState, client: Any?) {
		hideTooltip()
		guard let client = client as? IMKTextInput else {
			ctlCandidateCurrent?.visible = false
			return
		}

		// the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
		// i.e. the client app needs to take care of where to put this composing buffer
		client.setMarkedText(
			state.attributedString, selectionRange: NSMakeRange(Int(state.cursorIndex), 0),
			replacementRange: NSMakeRange(NSNotFound, NSNotFound))
		show(candidateWindowWith: state, client: client)
	}

	private func handle(state: InputState.AssociatedPhrases, previous: InputState, client: Any?) {
		hideTooltip()
		guard let client = client as? IMKTextInput else {
			ctlCandidateCurrent?.visible = false
			return
		}
		client.setMarkedText(
			"", selectionRange: NSMakeRange(0, 0),
			replacementRange: NSMakeRange(NSNotFound, NSNotFound))
		show(candidateWindowWith: state, client: client)
	}
}

// MARK: -

extension ctlInputMethod {

	private func show(candidateWindowWith state: InputState, client: Any!) {
		let useVerticalMode: Bool = {
			var useVerticalMode = false
			var candidates: [String] = []
			if let state = state as? InputState.ChoosingCandidate {
				useVerticalMode = state.useVerticalMode
				candidates = state.candidates
			} else if let state = state as? InputState.AssociatedPhrases {
				useVerticalMode = state.useVerticalMode
				candidates = state.candidates
			}
			if useVerticalMode == true {
				return true
			}
			candidates.sort {
				return $0.count > $1.count
			}
			// If there is a candidate which is too long, we use the vertical
			// candidate list window automatically.
			if candidates.first?.count ?? 0 > 8 {
				// return true // 禁用這一項。威注音回頭會換候選窗格。
			}
			return false
		}()

		ctlCandidateCurrent?.delegate = nil

		if useVerticalMode {
			ctlCandidateCurrent = .vertical
		} else if mgrPrefs.useHorizontalCandidateList {
			ctlCandidateCurrent = .horizontal
		} else {
			ctlCandidateCurrent = .vertical
		}

		// set the attributes for the candidate panel (which uses NSAttributedString)
		let textSize = mgrPrefs.candidateListTextSize
		let keyLabelSize = max(textSize / 2, kMinKeyLabelSize)

		func labelFont(name: String?, size: CGFloat) -> NSFont {
			if let name = name {
				return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
			}
			return NSFont.systemFont(ofSize: size)
		}

		func candidateFont(name: String?, size: CGFloat) -> NSFont {
			let currentMUIFont =
				(keyHandler.inputMode == InputMode.imeModeCHS)
				? "Sarasa Term Slab SC" : "Sarasa Term Slab TC"
			var finalReturnFont =
				NSFont(name: currentMUIFont, size: size) ?? NSFont.systemFont(ofSize: size)
			// 對更紗黑體的依賴到 macOS 11 Big Sur 為止。macOS 12 Monterey 開始則依賴系統內建的函數使用蘋方來處理。
			if #available(macOS 12.0, *) { finalReturnFont = NSFont.systemFont(ofSize: size) }
			if let name = name {
				return NSFont(name: name, size: size) ?? finalReturnFont
			}
			return finalReturnFont
		}

		ctlCandidateCurrent?.keyLabelFont = labelFont(
			name: mgrPrefs.candidateKeyLabelFontName, size: keyLabelSize)
		ctlCandidateCurrent?.candidateFont = candidateFont(
			name: mgrPrefs.candidateTextFontName, size: textSize)

		let candidateKeys = mgrPrefs.candidateKeys
		let keyLabels =
			candidateKeys.count > 4 ? Array(candidateKeys) : Array(mgrPrefs.defaultCandidateKeys)
		let keyLabelSuffix = state is InputState.AssociatedPhrases ? "^" : ""
		ctlCandidateCurrent?.keyLabels = keyLabels.map {
			CandidateKeyLabel(key: String($0), displayedText: String($0) + keyLabelSuffix)
		}

		ctlCandidateCurrent?.delegate = self
		ctlCandidateCurrent?.reloadData()
		currentClient = client

		ctlCandidateCurrent?.visible = true

		var lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0)
		var cursor: Int = 0

		if let state = state as? InputState.ChoosingCandidate {
			cursor = Int(state.cursorIndex)
			if cursor == state.composingBuffer.count && cursor != 0 {
				cursor -= 1
			}
		}

		while lineHeightRect.origin.x == 0 && lineHeightRect.origin.y == 0 && cursor >= 0 {
			(client as? IMKTextInput)?.attributes(
				forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect)
			cursor -= 1
		}

		if useVerticalMode {
			ctlCandidateCurrent?.set(
				windowTopLeftPoint: NSMakePoint(
					lineHeightRect.origin.x + lineHeightRect.size.width + 4.0,
					lineHeightRect.origin.y - 4.0),
				bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0)
		} else {
			ctlCandidateCurrent?.set(
				windowTopLeftPoint: NSMakePoint(
					lineHeightRect.origin.x, lineHeightRect.origin.y - 4.0),
				bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0)
		}
	}

	private func show(tooltip: String, composingBuffer: String, cursorIndex: UInt, client: Any!) {
		var lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0)
		var cursor: Int = Int(cursorIndex)
		if cursor == composingBuffer.count && cursor != 0 {
			cursor -= 1
		}
		while lineHeightRect.origin.x == 0 && lineHeightRect.origin.y == 0 && cursor >= 0 {
			(client as? IMKTextInput)?.attributes(
				forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect)
			cursor -= 1
		}
		ctlInputMethod.tooltipController.show(tooltip: tooltip, at: lineHeightRect.origin)
	}

	private func hideTooltip() {
		ctlInputMethod.tooltipController.hide()
	}
}

// MARK: -

extension ctlInputMethod: KeyHandlerDelegate {
	func ctlCandidate(for keyHandler: KeyHandler) -> Any {
		ctlCandidateCurrent ?? .vertical
	}

	func keyHandler(
		_ keyHandler: KeyHandler, didSelectCandidateAt index: Int,
		ctlCandidate controller: Any
	) {
		if let controller = controller as? ctlCandidate {
			self.ctlCandidate(controller, didSelectCandidateAtIndex: UInt(index))
		}
	}

	func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputState)
		-> Bool
	{
		guard let state = state as? InputState.Marking else {
			return false
		}
		if !state.validToWrite {
			return false
		}
		let refInputModeReversed: InputMode =
			(keyHandler.inputMode == InputMode.imeModeCHT)
			? InputMode.imeModeCHS : InputMode.imeModeCHT
		mgrLangModel.writeUserPhrase(
			state.userPhrase, inputMode: keyHandler.inputMode,
			areWeDuplicating: state.chkIfUserPhraseExists,
			areWeDeleting: ctlInputMethod.areWeDeleting)
		mgrLangModel.writeUserPhrase(
			state.userPhraseConverted, inputMode: refInputModeReversed,
			areWeDuplicating: false,
			areWeDeleting: ctlInputMethod.areWeDeleting)
		return true
	}
}

// MARK: -

extension ctlInputMethod: ctlCandidateDelegate {
	func candidateCountForController(_ controller: ctlCandidate) -> UInt {
		if let state = state as? InputState.ChoosingCandidate {
			return UInt(state.candidates.count)
		} else if let state = state as? InputState.AssociatedPhrases {
			return UInt(state.candidates.count)
		}
		return 0
	}

	func ctlCandidate(_ controller: ctlCandidate, candidateAtIndex index: UInt)
		-> String
	{
		if let state = state as? InputState.ChoosingCandidate {
			return state.candidates[Int(index)]
		} else if let state = state as? InputState.AssociatedPhrases {
			return state.candidates[Int(index)]
		}
		return ""
	}

	func ctlCandidate(_ controller: ctlCandidate, didSelectCandidateAtIndex index: UInt) {
		let client = currentClient

		if let state = state as? InputState.SymbolTable,
			let node = state.node.children?[Int(index)]
		{
			if let children = node.children, !children.isEmpty {
				self.handle(
					state: .SymbolTable(node: node, useVerticalMode: state.useVerticalMode),
					client: currentClient)
			} else {
				self.handle(state: .Committing(poppedText: node.title), client: client)
				self.handle(state: .Empty(), client: client)
			}
			return
		}

		if let state = state as? InputState.ChoosingCandidate {
			let selectedValue = state.candidates[Int(index)]
			keyHandler.fixNode(value: selectedValue)

			guard let inputting = keyHandler.buildInputtingState() as? InputState.Inputting else {
				return
			}

			if mgrPrefs.useSCPCTypingMode {
				keyHandler.clear()
				let composingBuffer = inputting.composingBuffer
				handle(state: .Committing(poppedText: composingBuffer), client: client)
				if mgrPrefs.associatedPhrasesEnabled,
					let associatePhrases = keyHandler.buildAssociatePhraseState(
						withKey: composingBuffer, useVerticalMode: state.useVerticalMode)
						as? InputState.AssociatedPhrases
				{
					self.handle(state: associatePhrases, client: client)
				} else {
					handle(state: .Empty(), client: client)
				}
			} else {
				handle(state: inputting, client: client)
			}
			return
		}

		if let state = state as? InputState.AssociatedPhrases {
			let selectedValue = state.candidates[Int(index)]
			handle(state: .Committing(poppedText: selectedValue), client: currentClient)
			if mgrPrefs.associatedPhrasesEnabled,
				let associatePhrases = keyHandler.buildAssociatePhraseState(
					withKey: selectedValue, useVerticalMode: state.useVerticalMode)
					as? InputState.AssociatedPhrases
			{
				self.handle(state: associatePhrases, client: client)
			} else {
				handle(state: .Empty(), client: client)
			}
		}
	}
}
