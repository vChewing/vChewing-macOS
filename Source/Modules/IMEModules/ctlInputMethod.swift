// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa
import InputMethodKit

private extension Bool {
    var state: NSControl.StateValue {
        self ? .on : .off
    }
}

private let kMinKeyLabelSize: CGFloat = 10

private var gCurrentCandidateController: CandidateController?

private extension CandidateController {
    static let horizontal = HorizontalCandidateController()
    static let vertical = VerticalCandidateController()
}

@objc(ctlInputMethod)
class ctlInputMethod: IMKInputController {

    private static let tooltipController = TooltipController()

    // MARK: -

    private var currentCandidateClient: Any?

    private var keyHandler: KeyHandler = KeyHandler()
    private var state: InputState = InputState.Empty()

    // 想讓 keyHandler 能夠被外界調查狀態與參數的話，就得對 keyHandler 做常態處理。
    // 這樣 InputState 可以藉由這個 ctlInputMethod 了解到當前的輸入模式是簡體中文還是繁體中文。
    // 然而，要是直接對 keyHandler 做常態處理的話，反而會導致 keyHandlerInput 無法協同處理。
    // 所以才需要「currentKeyHandler」這個假 keyHandler。
    // 這個「currentKeyHandler」僅用來讓其他模組知道當前的輸入模式是什麼模式，除此之外別無屌用。
    static var currentKeyHandler: KeyHandler = KeyHandler()

    // MARK: - IMKInputController methods

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        keyHandler.delegate = self
    }

    override func menu() -> NSMenu! {
        let optionKeyPressed = NSEvent.modifierFlags.contains(.option)

        let menu = NSMenu(title: "Input Method Menu")

        let useSCPCTypingModeItem = menu.addItem(withTitle: NSLocalizedString("Per-Char Select Mode", comment: ""), action: #selector(toggleSCPCTypingMode(_:)), keyEquivalent: "P")
        useSCPCTypingModeItem.keyEquivalentModifierMask = [.command, .control]
        useSCPCTypingModeItem.state = Preferences.useSCPCTypingMode.state

        let useCNS11643SupportItem = menu.addItem(withTitle: NSLocalizedString("CNS11643 Mode", comment: ""), action: #selector(toggleCNS11643Enabled(_:)), keyEquivalent: "L")
        useCNS11643SupportItem.keyEquivalentModifierMask = [.command, .control]
        useCNS11643SupportItem.state = Preferences.cns11643Enabled.state

        if keyHandler.inputMode == InputMode.imeModeCHT {
            let chineseConversionItem = menu.addItem(withTitle: NSLocalizedString("Force KangXi Writing", comment: ""), action: #selector(toggleChineseConverter(_:)), keyEquivalent: "K")
            chineseConversionItem.keyEquivalentModifierMask = [.command, .control]
            chineseConversionItem.state = Preferences.chineseConversionEnabled.state

            let shiftJISConversionItem = menu.addItem(withTitle: NSLocalizedString("JIS Shinjitai Output", comment: ""), action: #selector(toggleShiftJISShinjitaiOutput(_:)), keyEquivalent: "J")
            shiftJISConversionItem.keyEquivalentModifierMask = [.command, .control]
            shiftJISConversionItem.state = Preferences.shiftJISShinjitaiOutputEnabled.state
        }
        
        let halfWidthPunctuationItem = menu.addItem(withTitle: NSLocalizedString("Half-Width Punctuation Mode", comment: ""), action: #selector(toggleHalfWidthPunctuation(_:)), keyEquivalent: "H")
        halfWidthPunctuationItem.keyEquivalentModifierMask = [.command, .control]
        halfWidthPunctuationItem.state = Preferences.halfWidthPunctuationEnabled.state

        let userAssociatedPhrasesItem = menu.addItem(withTitle: NSLocalizedString("Per-Char Associated Phrases", comment: ""), action: #selector(toggleAssociatedPhrasesEnabled(_:)), keyEquivalent: "O")
        userAssociatedPhrasesItem.keyEquivalentModifierMask = [.command, .control]
        userAssociatedPhrasesItem.state = Preferences.associatedPhrasesEnabled.state

        let alphaNumericalModeItem = menu.addItem(withTitle: NSLocalizedString("Alphanumerical Input Mode", comment: ""), action: #selector(toggleAlphanumericalModeEnabled(_:)), keyEquivalent: "I")
        alphaNumericalModeItem.keyEquivalentModifierMask = [.command, .control]
        alphaNumericalModeItem.state = Preferences.isAlphanumericalModeEnabled.state

        if optionKeyPressed {
            let phaseReplacementItem = menu.addItem(withTitle: NSLocalizedString("Use Phrase Replacement", comment: ""), action: #selector(togglePhraseReplacement(_:)), keyEquivalent: "")
            phaseReplacementItem.state = Preferences.phraseReplacementEnabled.state
        }

        menu.addItem(NSMenuItem.separator()) // ---------------------

        menu.addItem(withTitle: NSLocalizedString("Open User Data Folder", comment: ""), action: #selector(openUserDataFolder(_:)), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Edit User Phrases…", comment: ""), action: #selector(openUserPhrases(_:)), keyEquivalent: "")

        if optionKeyPressed {
            menu.addItem(withTitle: NSLocalizedString("Edit Excluded Phrases", comment: ""), action: #selector(openExcludedPhrases(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("Edit Phrase Replacement Table…", comment: ""), action: #selector(openPhraseReplacement(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("Edit Associated Phrases…", comment: ""), action: #selector(openAssociatedPhrases(_:)), keyEquivalent: "")
        }

        if (optionKeyPressed || !Preferences.shouldAutoReloadUserDataFiles) {
            menu.addItem(withTitle: NSLocalizedString("Reload User Phrases", comment: ""), action: #selector(reloadUserPhrases(_:)), keyEquivalent: "")
        }

        menu.addItem(NSMenuItem.separator()) // ---------------------

        menu.addItem(withTitle: NSLocalizedString("vChewing Preferences…", comment: ""), action: #selector(showPreferences(_:)), keyEquivalent: "")
        if !optionKeyPressed {
            menu.addItem(withTitle: NSLocalizedString("Check for Updates…", comment: ""), action: #selector(checkForUpdate(_:)), keyEquivalent: "")
        }
        menu.addItem(withTitle: NSLocalizedString("About vChewing…", comment: ""), action: #selector(showAbout(_:)), keyEquivalent: "")
        if optionKeyPressed {
            menu.addItem(withTitle: NSLocalizedString("Reboot vChewing…", comment: ""), action: #selector(selfTerminate(_:)), keyEquivalent: "")
        }
        return menu
    }

    // MARK: - IMKStateSetting protocol methods

    override func activateServer(_ client: Any!) {
        UserDefaults.standard.synchronize()

        // Override the keyboard layout. Use US if not set.
        (client as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: Preferences.basisKeyboardLayout)
        // reset the state
        currentCandidateClient = nil

        keyHandler.clear()
        keyHandler.syncWithPreferences()
        self.handle(state: .Empty(), client: client)
        (NSApp.delegate as? AppDelegate)?.checkForUpdate()
    }

    override func deactivateServer(_ client: Any!) {
        keyHandler.clear()
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
        if keyHandler.inputMode != newInputMode {
            UserDefaults.standard.synchronize()
            // Remember to override the keyboard layout again -- treat this as an activate event.
            (client as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: Preferences.basisKeyboardLayout)
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

        if (Preferences.isAlphanumericalModeEnabled) {
            (client as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: Preferences.functionKeyboardLayout)
            return false
        }

        if event.type == .flagsChanged {
            let functionKeyKeyboardLayoutID = Preferences.functionKeyboardLayout
            let basisKeyboardLayoutID = Preferences.basisKeyboardLayout

            if functionKeyKeyboardLayoutID == basisKeyboardLayoutID {
                return false
            }

            let includeShift = Preferences.functionKeyKeyboardLayoutOverrideIncludeShiftKey
            let notShift = NSEvent.ModifierFlags(rawValue: ~(NSEvent.ModifierFlags.shift.rawValue))
            if event.modifierFlags.contains(notShift) ||
                       (event.modifierFlags.contains(.shift) && includeShift) {
                (client as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: functionKeyKeyboardLayoutID)
                return false
            }
            (client as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: basisKeyboardLayoutID)
            return false
        }

        var textFrame = NSRect.zero
        let attributes: [AnyHashable: Any]? = (client as? IMKTextInput)?.attributes(forCharacterIndex: 0, lineHeightRectangle: &textFrame)
        let useVerticalMode = (attributes?["IMKTextOrientation"] as? NSNumber)?.intValue == 0 || false

        if (client as? IMKTextInput)?.bundleIdentifier() == "org.atelierInmu.vChewing.vChewingPhraseEditor" {
            ctlInputMethod.areWeUsingOurOwnPhraseEditor = true
        } else {
            ctlInputMethod.areWeUsingOurOwnPhraseEditor = false
        }

        let input = KeyHandlerInput(event: event, isVerticalMode: useVerticalMode)

        let result = keyHandler.handle(input: input, state: state) { newState in
            self.handle(state: newState, client: client)
        } errorCallback: {
            clsSFX.beep()
        }
        return result
    }

    // MARK: - Menu Items

    @objc override func showPreferences(_ sender: Any?) {
        (NSApp.delegate as? AppDelegate)?.showPreferences()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleSCPCTypingMode(_ sender: Any?) {
        NotifierController.notify(message: String(format: "%@%@%@", NSLocalizedString("Per-Char Select Mode", comment: ""), "\n", Preferences.toggleSCPCTypingModeEnabled() ? NSLocalizedString("NotificationSwitchON", comment: "") : NSLocalizedString("NotificationSwitchOFF", comment: "")))
    }

    @objc func toggleChineseConverter(_ sender: Any?) {
        NotifierController.notify(message: String(format: "%@%@%@", NSLocalizedString("Force KangXi Writing", comment: ""), "\n", Preferences.toggleChineseConversionEnabled() ? NSLocalizedString("NotificationSwitchON", comment: "") : NSLocalizedString("NotificationSwitchOFF", comment: "")))
    }

    @objc func toggleShiftJISShinjitaiOutput(_ sender: Any?) {
        NotifierController.notify(message: String(format: "%@%@%@", NSLocalizedString("JIS Shinjitai Output", comment: ""), "\n", Preferences.toggleShiftJISShinjitaiOutputEnabled() ? NSLocalizedString("NotificationSwitchON", comment: "") : NSLocalizedString("NotificationSwitchOFF", comment: "")))
    }

    @objc func toggleHalfWidthPunctuation(_ sender: Any?) {
        NotifierController.notify(message: String(format: "%@%@%@", NSLocalizedString("Half-Width Punctuation Mode", comment: ""), "\n", Preferences.toggleHalfWidthPunctuationEnabled() ? NSLocalizedString("NotificationSwitchON", comment: "") : NSLocalizedString("NotificationSwitchOFF", comment: "")))
    }

    @objc func toggleCNS11643Enabled(_ sender: Any?) {
        mgrLangModel.setCNSEnabled(Preferences.toggleCNS11643Enabled())
        NotifierController.notify(message: String(format: "%@%@%@", NSLocalizedString("CNS11643 Mode", comment: ""), "\n", Preferences.cns11643Enabled ? NSLocalizedString("NotificationSwitchON", comment: "") : NSLocalizedString("NotificationSwitchOFF", comment: "")))
    }

    @objc func toggleAssociatedPhrasesEnabled(_ sender: Any?) {
        NotifierController.notify(message: String(format: "%@%@%@", NSLocalizedString("Per-Char Associated Phrases", comment: ""), "\n", Preferences.toggleAssociatedPhrasesEnabled() ? NSLocalizedString("NotificationSwitchON", comment: "") : NSLocalizedString("NotificationSwitchOFF", comment: "")))
    }

    @objc func toggleAlphanumericalModeEnabled(_ sender: Any?) {
        Preferences.toggleAlphanumericalModeEnabled()
    }

    @objc func togglePhraseReplacement(_ sender: Any?) {
        mgrLangModel.setPhraseReplacementEnabled(Preferences.togglePhraseReplacementEnabled())
    }

    @objc func selfTerminate(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc func checkForUpdate(_ sender: Any?) {
        (NSApp.delegate as? AppDelegate)?.checkForUpdate(forced: true)
    }

    private func open(userFileAt path: String) {
        func checkIfUserFilesExist() -> Bool {
            if !mgrLangModel.checkIfUserLanguageModelFilesExist() {
                let content = String(format: NSLocalizedString("Please check the permission at \"%@\".", comment: ""), mgrLangModel.dataFolderPath)
                ctlNonModalAlertWindow.shared.show(title: NSLocalizedString("Unable to create the user phrase file.", comment: ""), content: content, confirmButtonTitle: NSLocalizedString("OK", comment: ""), cancelButtonTitle: nil, cancelAsDefault: false, delegate: nil)
                return false
            }
            return true
        }

        if !checkIfUserFilesExist() {
            return
        }
        NSWorkspace.shared.openFile(path, withApplication: "vChewingPhraseEditor")
    }

    @objc func openUserPhrases(_ sender: Any?) {
        open(userFileAt: mgrLangModel.userPhrasesDataPath(keyHandler.inputMode))
    }

    @objc func openUserDataFolder(_ sender: Any?) {
        if !mgrLangModel.checkIfUserDataFolderExists() {
            return
        }
        NSWorkspace.shared.openFile(mgrLangModel.dataFolderPath, withApplication: "Finder")
    }

    @objc func openExcludedPhrases(_ sender: Any?) {
        open(userFileAt: mgrLangModel.excludedPhrasesDataPath(keyHandler.inputMode))
    }

    @objc func openPhraseReplacement(_ sender: Any?) {
        open(userFileAt: mgrLangModel.phraseReplacementDataPath(keyHandler.inputMode))
    }

    @objc func openAssociatedPhrases(_ sender: Any?) {
        open(userFileAt: mgrLangModel.userAssociatedPhrasesDataPath(keyHandler.inputMode))
    }

    @objc func reloadUserPhrases(_ sender: Any?) {
        mgrLangModel.loadUserPhrases()
        mgrLangModel.loadUserPhraseReplacement()
    }

    @objc func showAbout(_ sender: Any?) {
        (NSApp.delegate as? AppDelegate)?.showAbout()
        NSApp.activate(ignoringOtherApps: true)
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
                if !Preferences.chineseConversionEnabled && Preferences.shiftJISShinjitaiOutputEnabled {
                    return vChewingKanjiConverter.cnvTradToJIS(text)
                }
                if Preferences.chineseConversionEnabled && !Preferences.shiftJISShinjitaiOutputEnabled {
                    return vChewingKanjiConverter.cnvTradToKangXi(text)
                }
                // 本來這兩個開關不該同時開啟的，但萬一被開啟了的話就這樣處理：
                if Preferences.chineseConversionEnabled && Preferences.shiftJISShinjitaiOutputEnabled {
                    return vChewingKanjiConverter.cnvTradToJIS(text)
                }
                // if (!Preferences.chineseConversionEnabled && !Preferences.shiftJISShinjitaiOutputEnabled) || (keyHandler.inputMode != InputMode.imeModeCHT);
                return text
            }
            return text
        }

        let buffer = kanjiConversionIfRequired(text)
        if buffer.isEmpty {
            return
        }
        (client as? IMKTextInput)?.insertText(buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }

    private func handle(state: InputState.Deactivated, previous: InputState, client: Any?) {
        currentCandidateClient = nil

        gCurrentCandidateController?.delegate = nil
        gCurrentCandidateController?.visible = false
        hideTooltip()

        if let previous = previous as? InputState.NotEmpty {
            commit(text: previous.composingBuffer, client: client)
        }
        (client as? IMKTextInput)?.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
    }

    private func handle(state: InputState.Empty, previous: InputState, client: Any?) {
        gCurrentCandidateController?.visible = false
        hideTooltip()

        guard let client = client as? IMKTextInput else {
            return
        }

        if let previous = previous as? InputState.NotEmpty {
            commit(text: previous.composingBuffer, client: client)
        }
        client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
    }

    private func handle(state: InputState.EmptyIgnoringPreviousState, previous: InputState, client: Any!) {
        gCurrentCandidateController?.visible = false
        hideTooltip()

        guard let client = client as? IMKTextInput else {
            return
        }

        client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
    }

    private func handle(state: InputState.Committing, previous: InputState, client: Any?) {
        gCurrentCandidateController?.visible = false
        hideTooltip()

        guard let client = client as? IMKTextInput else {
            return
        }

        let poppedText = state.poppedText
        if !poppedText.isEmpty {
            commit(text: poppedText, client: client)
        }
        client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
    }

    private func handle(state: InputState.Inputting, previous: InputState, client: Any?) {
        gCurrentCandidateController?.visible = false
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
        client.setMarkedText(state.attributedString, selectionRange: NSMakeRange(Int(state.cursorIndex), 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
        if !state.tooltip.isEmpty {
            show(tooltip: state.tooltip, composingBuffer: state.composingBuffer, cursorIndex: state.cursorIndex, client: client)
        }
    }

    private func handle(state: InputState.Marking, previous: InputState, client: Any?) {
        gCurrentCandidateController?.visible = false
        guard let client = client as? IMKTextInput else {
            hideTooltip()
            return
        }

        // the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
        // i.e. the client app needs to take care of where to put this composing buffer
        client.setMarkedText(state.attributedString, selectionRange: NSMakeRange(Int(state.cursorIndex), 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        if state.tooltip.isEmpty {
            hideTooltip()
        } else {
            show(tooltip: state.tooltip, composingBuffer: state.composingBuffer, cursorIndex: state.markerIndex, client: client)
        }
    }

    private func handle(state: InputState.ChoosingCandidate, previous: InputState, client: Any?) {
        hideTooltip()
        guard let client = client as? IMKTextInput else {
            gCurrentCandidateController?.visible = false
            return
        }

        // the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
        // i.e. the client app needs to take care of where to put this composing buffer
        client.setMarkedText(state.attributedString, selectionRange: NSMakeRange(Int(state.cursorIndex), 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
        show(candidateWindowWith: state, client: client)
    }

    private func handle(state: InputState.AssociatedPhrases, previous: InputState, client: Any?) {
        hideTooltip()
        guard let client = client as? IMKTextInput else {
            gCurrentCandidateController?.visible = false
            return
        }
        client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
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
        
        gCurrentCandidateController?.delegate = nil

        if useVerticalMode {
            gCurrentCandidateController = .vertical
        } else if Preferences.useHorizontalCandidateList {
            gCurrentCandidateController = .horizontal
        } else {
            gCurrentCandidateController = .vertical
        }

        // set the attributes for the candidate panel (which uses NSAttributedString)
        let textSize = Preferences.candidateListTextSize
        let keyLabelSize = max(textSize / 2, kMinKeyLabelSize)

        func font(name: String?, size: CGFloat) -> NSFont {
            if let name = name {
                return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
            }
            return NSFont.systemFont(ofSize: size)
        }

        gCurrentCandidateController?.keyLabelFont = font(name: Preferences.candidateKeyLabelFontName, size: keyLabelSize)
        gCurrentCandidateController?.candidateFont = font(name: Preferences.candidateTextFontName, size: textSize)

        let candidateKeys = Preferences.candidateKeys
        let keyLabels = candidateKeys.count > 4 ? Array(candidateKeys) : Array(Preferences.defaultCandidateKeys)
        let keyLabelSuffix = state is InputState.AssociatedPhrases ? "^" : ""
        gCurrentCandidateController?.keyLabels = keyLabels.map {
            CandidateKeyLabel(key: String($0), displayedText: String($0) + keyLabelSuffix)
        }

        gCurrentCandidateController?.delegate = self
        gCurrentCandidateController?.reloadData()
        currentCandidateClient = client

        gCurrentCandidateController?.visible = true

        var lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0)
        var cursor: Int = 0

        if let state = state as? InputState.ChoosingCandidate {
            cursor = Int(state.cursorIndex)
            if cursor == state.composingBuffer.count && cursor != 0 {
                cursor -= 1
            }
        }

        while lineHeightRect.origin.x == 0 && lineHeightRect.origin.y == 0 && cursor >= 0 {
            (client as? IMKTextInput)?.attributes(forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect)
            cursor -= 1
        }

        if useVerticalMode {
            gCurrentCandidateController?.set(windowTopLeftPoint: NSMakePoint(lineHeightRect.origin.x + lineHeightRect.size.width + 4.0, lineHeightRect.origin.y - 4.0), bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0)
        } else {
            gCurrentCandidateController?.set(windowTopLeftPoint: NSMakePoint(lineHeightRect.origin.x, lineHeightRect.origin.y - 4.0), bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0)
        }
    }

    private func show(tooltip: String, composingBuffer: String, cursorIndex: UInt, client: Any!) {
        var lineHeightRect = NSMakeRect(0.0, 0.0, 16.0, 16.0)
        var cursor: Int = Int(cursorIndex)
        if cursor == composingBuffer.count && cursor != 0 {
            cursor -= 1
        }
        while lineHeightRect.origin.x == 0 && lineHeightRect.origin.y == 0 && cursor >= 0 {
            (client as? IMKTextInput)?.attributes(forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect)
            cursor -= 1
        }
        ctlInputMethod.tooltipController.show(tooltip: tooltip, at: lineHeightRect.origin)
    }

    private func hideTooltip() {
        ctlInputMethod.tooltipController.hide()
    }
}

// MARK: - 開關判定當前應用究竟是？

@objc extension ctlInputMethod {
    @objc static var areWeUsingOurOwnPhraseEditor: Bool = false
}

// MARK: -

extension ctlInputMethod: KeyHandlerDelegate {
    func candidateController(for keyHandler: KeyHandler) -> Any {
        gCurrentCandidateController ?? .vertical
    }

    func keyHandler(_ keyHandler: KeyHandler, didSelectCandidateAt index: Int, candidateController controller: Any) {
        if let controller = controller as? CandidateController {
            self.candidateController(controller, didSelectCandidateAtIndex: UInt(index))
        }
    }

    func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputState) -> Bool {
        guard let state = state as? InputState.Marking else {
            return false
        }
        if !state.validToWrite {
            return false
        }
        mgrLangModel.writeUserPhrase(state.userPhrase, inputMode: keyHandler.inputMode, areWeDuplicating: state.chkIfUserPhraseExists)
        return true
    }
}

// MARK: -

extension ctlInputMethod: CandidateControllerDelegate {
    func candidateCountForController(_ controller: CandidateController) -> UInt {
        if let state = state as? InputState.ChoosingCandidate {
            return UInt(state.candidates.count)
        } else if let state = state as? InputState.AssociatedPhrases {
            return UInt(state.candidates.count)
        }
        return 0
    }

    func candidateController(_ controller: CandidateController, candidateAtIndex index: UInt) -> String {
        if let state = state as? InputState.ChoosingCandidate {
            return state.candidates[Int(index)]
        } else if let state = state as? InputState.AssociatedPhrases {
            return state.candidates[Int(index)]
        }
        return ""
    }

    func candidateController(_ controller: CandidateController, didSelectCandidateAtIndex index: UInt) {
        let client = currentCandidateClient

        if let state = state as? InputState.SymbolTable,
           let node = state.node.children?[Int(index)] {
            if let children = node.children, !children.isEmpty {
                self.handle(state: .SymbolTable(node: node, useVerticalMode: state.useVerticalMode), client: currentCandidateClient)
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

            if Preferences.useSCPCTypingMode {
                keyHandler.clear()
                let composingBuffer = inputting.composingBuffer
                handle(state: .Committing(poppedText: composingBuffer), client: client)
                if Preferences.associatedPhrasesEnabled,
                   let associatePhrases = keyHandler.buildAssociatePhraseState(withKey: composingBuffer, useVerticalMode: state.useVerticalMode) as? InputState.AssociatedPhrases {
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
            handle(state: .Committing(poppedText: selectedValue), client: currentCandidateClient)
            if Preferences.associatedPhrasesEnabled,
               let associatePhrases = keyHandler.buildAssociatePhraseState(withKey: selectedValue, useVerticalMode: state.useVerticalMode) as? InputState.AssociatedPhrases {
                self.handle(state: associatePhrases, client: client)
            } else {
                handle(state: .Empty(), client: client)
            }
        }
    }
}

