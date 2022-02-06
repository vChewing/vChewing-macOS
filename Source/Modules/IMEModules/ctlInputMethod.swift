
import Cocoa
import InputMethodKit

extension Bool {
    var state: NSControl.StateValue {
        self ? .on : .off
    }
}

private let kMinKeyLabelSize: CGFloat = 10

private var gCurrentCandidateController: CandidateController?

@objc(ctlInputMethod)
class ctlInputMethod: IMKInputController {

    private static let horizontalCandidateController = HorizontalCandidateController()
    private static let verticalCandidateController = VerticalCandidateController()
    private static let tooltipController = TooltipController()

    // MARK: -

    private var currentCandidateClient: Any?
    private var currentDeferredClient: Any?

    private var keyHandler: KeyHandler = KeyHandler()
    private var state: InputState = InputState.Empty()

    // MARK: - IMKInputController methods

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        keyHandler.delegate = self
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Input Method Menu")
        menu.addItem(withTitle: NSLocalizedString("vChewing Preferences", comment: ""), action: #selector(showPreferences(_:)), keyEquivalent: "")

        let chineseConversionItem = menu.addItem(withTitle: NSLocalizedString("Chinese Conversion", comment: ""), action: #selector(toggleChineseConverter(_:)), keyEquivalent: "g")
        chineseConversionItem.keyEquivalentModifierMask = [.command, .control]
        chineseConversionItem.state = Preferences.chineseConversionEnabled.state

        let halfWidthPunctuationItem = menu.addItem(withTitle: NSLocalizedString("Use Half-Width Punctuations", comment: ""), action: #selector(toggleHalfWidthPunctuation(_:)), keyEquivalent: "h")
        halfWidthPunctuationItem.keyEquivalentModifierMask = [.command, .control]
        halfWidthPunctuationItem.state = Preferences.halfWidthPunctuationEnabled.state

        let inputMode = keyHandler.inputMode
        let optionKeyPressed = NSEvent.modifierFlags.contains(.option)

        if inputMode == .plainBopomofo {
            let associatedPhrasesItem = menu.addItem(withTitle: NSLocalizedString("Associated Phrases", comment: ""), action: #selector(toggleAssociatedPhrasesEnabled(_:)), keyEquivalent: "")
            associatedPhrasesItem.state = Preferences.associatedPhrasesEnabled.state
        }

        if inputMode == .bopomofo && optionKeyPressed {
            let phaseReplacementItem = menu.addItem(withTitle: NSLocalizedString("Use Phrase Replacement", comment: ""), action: #selector(togglePhraseReplacement(_:)), keyEquivalent: "")
            phaseReplacementItem.state = Preferences.phraseReplacementEnabled.state
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("User Phrases", comment: ""), action: nil, keyEquivalent: "")

        if inputMode == .plainBopomofo {
            menu.addItem(withTitle: NSLocalizedString("Edit Excluded Phrases", comment: ""), action: #selector(openExcludedPhrasesPlainBopomofo(_:)), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: NSLocalizedString("Edit User Phrases", comment: ""), action: #selector(openUserPhrases(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("Edit Excluded Phrases", comment: ""), action: #selector(openExcludedPhrasesvChewing(_:)), keyEquivalent: "")
            if optionKeyPressed {
                menu.addItem(withTitle: NSLocalizedString("Edit Phrase Replacement Table", comment: ""), action: #selector(openPhraseReplacementvChewing(_:)), keyEquivalent: "")
            }
        }

        menu.addItem(withTitle: NSLocalizedString("Reload User Phrases", comment: ""), action: #selector(reloadUserPhrases(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: NSLocalizedString("Check for Updates…", comment: ""), action: #selector(checkForUpdate(_:)), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("About vChewing…", comment: ""), action: #selector(showAbout(_:)), keyEquivalent: "")
        return menu
    }

    // MARK: - IMKStateSetting protocol methods

    override func activateServer(_ client: Any!) {
        UserDefaults.standard.synchronize()

        // Override the keyboard layout. Use US if not set.
        (client as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: Preferences.basisKeyboardLayout)
        // reset the state
        currentDeferredClient = nil
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
        let newInputMode = InputMode(rawValue: value as? String ?? InputMode.bopomofo.rawValue)
        mgrLangModel.loadDataModel(newInputMode)
        if keyHandler.inputMode != newInputMode {
            UserDefaults.standard.synchronize()
            // Remember to override the keyboard layout again -- treat this as an activate event.
            (client as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: Preferences.basisKeyboardLayout)
            keyHandler.clear()
            keyHandler.inputMode = newInputMode
            self.handle(state: .Empty(), client: client)
        }
    }

    // MARK: - IMKServerInput protocol methods

    override func recognizedEvents(_ sender: Any!) -> Int {
        let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
        return Int(events.rawValue)
    }

    override func handle(_ event: NSEvent!, client: Any!) -> Bool {
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

        if (client as? IMKTextInput)?.bundleIdentifier() == "com.apple.Terminal" &&
                   NSStringFromClass(client.self as! AnyClass) == "IPMDServerClientWrapper" {
            currentDeferredClient = client
        }

        let input = KeyHandlerInput(event: event, isVerticalMode: useVerticalMode)

        let result = keyHandler.handle(input: input, state: state) { newState in
            self.handle(state: newState, client: client)
        } errorCallback: {
            NSSound.beep()
        }
        return result
    }

    // MARK: - Menu Items

    @objc override func showPreferences(_ sender: Any?) {
        super.showPreferences(sender)
    }

    @objc func toggleChineseConverter(_ sender: Any?) {
        let enabled = Preferences.toggleChineseConversionEnabled()
        NotifierController.notify(message: enabled ? NSLocalizedString("Chinese conversion on", comment: "") : NSLocalizedString("Chinese conversion off", comment: ""))
    }

    @objc func toggleHalfWidthPunctuation(_ sender: Any?) {
        let enabled = Preferences.togglePhraseReplacementEnabled()
        NotifierController.notify(message: enabled ? NSLocalizedString("Half-width punctuation on", comment: "") : NSLocalizedString("Half-width punctuation off", comment: ""))
    }

    @objc func toggleAssociatedPhrasesEnabled(_ sender: Any?) {
        _ = Preferences.toggleAssociatedPhrasesEnabled()
    }

    @objc func togglePhraseReplacement(_ sender: Any?) {
        let enabled = Preferences.togglePhraseReplacementEnabled()
        mgrLangModel.phraseReplacementEnabled = enabled
    }

    @objc func checkForUpdate(_ sender: Any?) {
        (NSApp.delegate as? AppDelegate)?.checkForUpdate(forced: true)
    }

    private func open(userFileAt path: String) {
        func checkIfUserFilesExist() -> Bool {
            if !mgrLangModel.checkIfUserLanguageModelFilesExist() {
                let content = String(format: NSLocalizedString("Please check the permission of at \"%@\".", comment: ""), mgrLangModel.dataFolderPath)
                NonModalAlertWindowController.shared.show(title: NSLocalizedString("Unable to create the user phrase file.", comment: ""), content: content, confirmButtonTitle: NSLocalizedString("OK", comment: ""), cancelButtonTitle: nil, cancelAsDefault: false, delegate: nil)
                return false
            }
            return true
        }

        if !checkIfUserFilesExist() {
            return
        }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    @objc func openUserPhrases(_ sender: Any?) {
        open(userFileAt: mgrLangModel.userPhrasesDataPathvChewing)
    }

    @objc func openExcludedPhrasesPlainBopomofo(_ sender: Any?) {
        open(userFileAt: mgrLangModel.excludedPhrasesDataPathPlainBopomofo)
    }

    @objc func openExcludedPhrasesvChewing(_ sender: Any?) {
        open(userFileAt: mgrLangModel.excludedPhrasesDataPathvChewing)
    }

    @objc func openPhraseReplacementvChewing(_ sender: Any?) {
        open(userFileAt: mgrLangModel.phraseReplacementDataPathvChewing)
    }

    @objc func reloadUserPhrases(_ sender: Any?) {
        mgrLangModel.loadUserPhrases()
        mgrLangModel.loadUserPhraseReplacement()
    }

    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(sender)
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

        func convertToKangXiChineseIfRequired(_ text: String) -> String {
            if !Preferences.chineseConversionEnabled {
                return text
            }
            return OpenCCBridge.convertToKangXi(text) ?? ""
        }

        let buffer = convertToKangXiChineseIfRequired(text)
        if buffer.isEmpty {
            return
        }
        // if it's Terminal, we don't commit at the first call (the client of which will not be IPMDServerClientWrapper)
        // then we defer the update in the next runloop round -- so that the composing buffer is not
        // meaninglessly flushed, an annoying bug in Terminal.app since Mac OS X 10.5
        if (client as? IMKTextInput)?.bundleIdentifier() == "com.apple.Terminal" && NSStringFromClass(client.self as! AnyClass) != "IPMDServerClientWrapper" {
            let innerCurrentDeferredClient = currentDeferredClient
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
                (innerCurrentDeferredClient as? IMKTextInput)?.insertText(buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            }
        }
        (client as? IMKTextInput)?.insertText(buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }

    private func handle(state: InputState.Deactivated, previous: InputState, client: Any?) {
        currentDeferredClient = nil
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
            if let state = state as? InputState.ChoosingCandidate {
                return state.useVerticalMode
            } else if let state = state as? InputState.AssociatedPhrases {
                return state.useVerticalMode
            }
            return false
        }()

        if useVerticalMode {
            gCurrentCandidateController = ctlInputMethod.verticalCandidateController
        } else if Preferences.useHorizontalCandidateList {
            gCurrentCandidateController = ctlInputMethod.horizontalCandidateController
        } else {
            gCurrentCandidateController = ctlInputMethod.verticalCandidateController
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
        let keyLabelPrefix = state is InputState.AssociatedPhrases ? "⇧ " : ""
        gCurrentCandidateController?.keyLabels = keyLabels.map {
            CandidateKeyLabel(key: String($0), displayedText: keyLabelPrefix + String($0))
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

// MARK: -

extension ctlInputMethod: KeyHandlerDelegate {
    func candidateController(for keyHandler: KeyHandler) -> Any {
        gCurrentCandidateController ?? ctlInputMethod.verticalCandidateController
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
        mgrLangModel.writeUserPhrase(state.userPhrase)
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

            if keyHandler.inputMode == .plainBopomofo {
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
