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

extension Bool {
  fileprivate var state: NSControl.StateValue {
    self ? .on : .off
  }
}

// MARK: - IME Menu Manager

// 因為選單部分的內容又臭又長，所以就單獨拉到一個檔案內管理了。

extension ctlInputMethod {
  override func menu() -> NSMenu! {
    let optionKeyPressed = NSEvent.modifierFlags.contains(.option)

    let menu = NSMenu(title: "Input Method Menu")

    let useSCPCTypingModeItem = menu.addItem(
      withTitle: NSLocalizedString("Per-Char Select Mode", comment: ""),
      action: #selector(toggleSCPCTypingMode(_:)), keyEquivalent: mgrPrefs.usingHotKeySCPC ? "P" : ""
    )
    useSCPCTypingModeItem.keyEquivalentModifierMask = [.command, .control]
    useSCPCTypingModeItem.state = mgrPrefs.useSCPCTypingMode.state

    let userAssociatedPhrasesItem = menu.addItem(
      withTitle: NSLocalizedString("Per-Char Associated Phrases", comment: ""),
      action: #selector(toggleAssociatedPhrasesEnabled(_:)), keyEquivalent: mgrPrefs.usingHotKeyAssociates ? "O" : ""
    )
    userAssociatedPhrasesItem.keyEquivalentModifierMask = [.command, .control]
    userAssociatedPhrasesItem.state = mgrPrefs.associatedPhrasesEnabled.state

    let useCNS11643SupportItem = menu.addItem(
      withTitle: NSLocalizedString("CNS11643 Mode", comment: ""),
      action: #selector(toggleCNS11643Enabled(_:)), keyEquivalent: mgrPrefs.usingHotKeyCNS ? "L" : ""
    )
    useCNS11643SupportItem.keyEquivalentModifierMask = [.command, .control]
    useCNS11643SupportItem.state = mgrPrefs.cns11643Enabled.state

    if IME.getInputMode() == InputMode.imeModeCHT {
      let chineseConversionItem = menu.addItem(
        withTitle: NSLocalizedString("Force KangXi Writing", comment: ""),
        action: #selector(toggleChineseConverter(_:)), keyEquivalent: mgrPrefs.usingHotKeyKangXi ? "K" : ""
      )
      chineseConversionItem.keyEquivalentModifierMask = [.command, .control]
      chineseConversionItem.state = mgrPrefs.chineseConversionEnabled.state

      let shiftJISConversionItem = menu.addItem(
        withTitle: NSLocalizedString("JIS Shinjitai Output", comment: ""),
        action: #selector(toggleShiftJISShinjitaiOutput(_:)), keyEquivalent: mgrPrefs.usingHotKeyJIS ? "J" : ""
      )
      shiftJISConversionItem.keyEquivalentModifierMask = [.command, .control]
      shiftJISConversionItem.state = mgrPrefs.shiftJISShinjitaiOutputEnabled.state
    }

    let currencyNumeralsItem = menu.addItem(
      withTitle: NSLocalizedString("Currency Numeral Output", comment: ""),
      action: #selector(toggleCurrencyNumerals(_:)), keyEquivalent: mgrPrefs.usingHotKeyCurrencyNumerals ? "M" : ""
    )
    currencyNumeralsItem.keyEquivalentModifierMask = [.command, .control]
    currencyNumeralsItem.state = mgrPrefs.currencyNumeralsEnabled.state

    let halfWidthPunctuationItem = menu.addItem(
      withTitle: NSLocalizedString("Half-Width Punctuation Mode", comment: ""),
      action: #selector(toggleHalfWidthPunctuation(_:)), keyEquivalent: mgrPrefs.usingHotKeyHalfWidthASCII ? "H" : ""
    )
    halfWidthPunctuationItem.keyEquivalentModifierMask = [.command, .control]
    halfWidthPunctuationItem.state = mgrPrefs.halfWidthPunctuationEnabled.state

    if optionKeyPressed || mgrPrefs.phraseReplacementEnabled {
      let phaseReplacementItem = menu.addItem(
        withTitle: NSLocalizedString("Use Phrase Replacement", comment: ""),
        action: #selector(togglePhraseReplacement(_:)), keyEquivalent: ""
      )
      phaseReplacementItem.state = mgrPrefs.phraseReplacementEnabled.state
    }

    if optionKeyPressed {
      let toggleSymbolInputItem = menu.addItem(
        withTitle: NSLocalizedString("Symbol & Emoji Input", comment: ""),
        action: #selector(toggleSymbolEnabled(_:)), keyEquivalent: ""
      )
      toggleSymbolInputItem.state = mgrPrefs.symbolInputEnabled.state
    }

    menu.addItem(NSMenuItem.separator())  // ---------------------

    menu.addItem(
      withTitle: NSLocalizedString("Open User Data Folder", comment: ""),
      action: #selector(openUserDataFolder(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("Edit User Phrases…", comment: ""),
      action: #selector(openUserPhrases(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("Edit Excluded Phrases…", comment: ""),
      action: #selector(openExcludedPhrases(_:)), keyEquivalent: ""
    )

    if optionKeyPressed || mgrPrefs.associatedPhrasesEnabled {
      menu.addItem(
        withTitle: NSLocalizedString("Edit Associated Phrases…", comment: ""),
        action: #selector(openAssociatedPhrases(_:)), keyEquivalent: ""
      )
    }

    if optionKeyPressed {
      menu.addItem(
        withTitle: NSLocalizedString("Edit Phrase Replacement Table…", comment: ""),
        action: #selector(openPhraseReplacement(_:)), keyEquivalent: ""
      )
      menu.addItem(
        withTitle: NSLocalizedString("Edit User Symbol & Emoji Data…", comment: ""),
        action: #selector(openUserSymbols(_:)), keyEquivalent: ""
      )
    }

    if optionKeyPressed || !mgrPrefs.shouldAutoReloadUserDataFiles {
      menu.addItem(
        withTitle: NSLocalizedString("Reload User Phrases", comment: ""),
        action: #selector(reloadUserPhrasesData(_:)), keyEquivalent: ""
      )
    }

    menu.addItem(NSMenuItem.separator())  // ---------------------

    menu.addItem(
      withTitle: NSLocalizedString("Optimize Memorized Phrases", comment: ""),
      action: #selector(removeUnigramsFromUOM(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("Clear Memorized Phrases", comment: ""),
      action: #selector(clearUOM(_:)), keyEquivalent: ""
    )

    menu.addItem(NSMenuItem.separator())  // ---------------------

    if optionKeyPressed {
      menu.addItem(
        withTitle: NSLocalizedString("vChewing Preferences…", comment: ""),
        action: #selector(showLegacyPreferences(_:)), keyEquivalent: ""
      )
    } else {
      menu.addItem(
        withTitle: NSLocalizedString("vChewing Preferences…", comment: ""),
        action: #selector(showPreferences(_:)), keyEquivalent: ""
      )
      menu.addItem(
        withTitle: NSLocalizedString("Check for Updates…", comment: ""),
        action: #selector(checkForUpdate(_:)), keyEquivalent: ""
      )
    }
    menu.addItem(
      withTitle: NSLocalizedString("Reboot vChewing…", comment: ""),
      action: #selector(selfTerminate(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("About vChewing…", comment: ""),
      action: #selector(showAbout(_:)), keyEquivalent: ""
    )
    if optionKeyPressed {
      menu.addItem(
        withTitle: NSLocalizedString("Uninstall vChewing…", comment: ""),
        action: #selector(selfUninstall(_:)), keyEquivalent: ""
      )
    }

    // NSMenu 會阻止任何修飾鍵狀態切換訊號傳回輸入法，所以咱們在此重設鍵盤佈局。
    setKeyLayout()

    return menu
  }

  // MARK: - IME Menu Items

  @objc override func showPreferences(_: Any?) {
    if #available(macOS 11.0, *) {
      NSApp.setActivationPolicy(.accessory)
      ctlPrefUI.shared.controller.show(preferencePane: Preferences.PaneIdentifier(rawValue: "General"))
      ctlPrefUI.shared.controller.window?.level = .floating
    } else {
      showPrefWindowTraditional()
    }
  }

  @objc func showLegacyPreferences(_: Any?) {
    showPrefWindowTraditional()
  }

  private func showPrefWindowTraditional() {
    (NSApp.delegate as? AppDelegate)?.showPreferences()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func toggleSCPCTypingMode(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("Per-Char Select Mode", comment: ""), "\n",
        mgrPrefs.toggleSCPCTypingModeEnabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func toggleChineseConverter(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("Force KangXi Writing", comment: ""), "\n",
        mgrPrefs.toggleChineseConversionEnabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func toggleShiftJISShinjitaiOutput(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("JIS Shinjitai Output", comment: ""), "\n",
        mgrPrefs.toggleShiftJISShinjitaiOutputEnabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func toggleCurrencyNumerals(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("Currency Numeral Output", comment: ""), "\n",
        mgrPrefs.toggleCurrencyNumeralsEnabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func toggleHalfWidthPunctuation(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("Half-Width Punctuation Mode", comment: ""),
        "\n",
        mgrPrefs.toggleHalfWidthPunctuationEnabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func toggleCNS11643Enabled(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("CNS11643 Mode", comment: ""), "\n",
        mgrPrefs.toggleCNS11643Enabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func toggleSymbolEnabled(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("Symbol & Emoji Input", comment: ""), "\n",
        mgrPrefs.toggleSymbolInputEnabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func toggleAssociatedPhrasesEnabled(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("Per-Char Associated Phrases", comment: ""),
        "\n",
        mgrPrefs.toggleAssociatedPhrasesEnabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func togglePhraseReplacement(_: Any?) {
    resetKeyHandler()
    NotifierController.notify(
      message: String(
        format: "%@%@%@", NSLocalizedString("Use Phrase Replacement", comment: ""), "\n",
        mgrPrefs.togglePhraseReplacementEnabled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: "")
      ))
  }

  @objc func selfUninstall(_: Any?) {
    (NSApp.delegate as? AppDelegate)?.selfUninstall()
  }

  @objc func selfTerminate(_: Any?) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.terminate(nil)
  }

  @objc func checkForUpdate(_: Any?) {
    (NSApp.delegate as? AppDelegate)?.checkForUpdate(forced: true)
  }

  @objc func openUserDataFolder(_: Any?) {
    if !mgrLangModel.userDataFolderExists {
      return
    }
    NSWorkspace.shared.openFile(
      mgrLangModel.dataFolderPath(isDefaultFolder: false), withApplication: "Finder"
    )
  }

  @objc func openUserPhrases(_: Any?) {
    IME.openPhraseFile(fromURL: mgrLangModel.userPhrasesDataURL(IME.getInputMode()))
    if NSEvent.modifierFlags.contains(.option) {
      IME.openPhraseFile(fromURL: mgrLangModel.userPhrasesDataURL(IME.getInputMode(isReversed: true)))
    }
  }

  @objc func openExcludedPhrases(_: Any?) {
    IME.openPhraseFile(fromURL: mgrLangModel.userFilteredDataURL(IME.getInputMode()))
    if NSEvent.modifierFlags.contains(.option) {
      IME.openPhraseFile(fromURL: mgrLangModel.userFilteredDataURL(IME.getInputMode(isReversed: true)))
    }
  }

  @objc func openUserSymbols(_: Any?) {
    IME.openPhraseFile(fromURL: mgrLangModel.userSymbolDataURL(IME.getInputMode()))
    if NSEvent.modifierFlags.contains(.option) {
      IME.openPhraseFile(fromURL: mgrLangModel.userSymbolDataURL(IME.getInputMode(isReversed: true)))
    }
  }

  @objc func openPhraseReplacement(_: Any?) {
    IME.openPhraseFile(fromURL: mgrLangModel.userReplacementsDataURL(IME.getInputMode()))
    if NSEvent.modifierFlags.contains(.option) {
      IME.openPhraseFile(fromURL: mgrLangModel.userReplacementsDataURL(IME.getInputMode(isReversed: true)))
    }
  }

  @objc func openAssociatedPhrases(_: Any?) {
    IME.openPhraseFile(fromURL: mgrLangModel.userAssociatesDataURL(IME.getInputMode()))
    if NSEvent.modifierFlags.contains(.option) {
      IME.openPhraseFile(
        fromURL: mgrLangModel.userAssociatesDataURL(IME.getInputMode(isReversed: true)))
    }
  }

  @objc func reloadUserPhrasesData(_: Any?) {
    IME.initLangModels(userOnly: true)
  }

  @objc func removeUnigramsFromUOM(_: Any?) {
    mgrLangModel.removeUnigramsFromUserOverrideModel(IME.getInputMode())
    if NSEvent.modifierFlags.contains(.option) {
      mgrLangModel.removeUnigramsFromUserOverrideModel(IME.getInputMode(isReversed: true))
    }
  }

  @objc func clearUOM(_: Any?) {
    mgrLangModel.clearUserOverrideModelData(IME.getInputMode())
    if NSEvent.modifierFlags.contains(.option) {
      mgrLangModel.clearUserOverrideModelData(IME.getInputMode(isReversed: true))
    }
  }

  @objc func showAbout(_: Any?) {
    (NSApp.delegate as? AppDelegate)?.showAbout()
    NSApp.activate(ignoringOtherApps: true)
  }
}
