// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import NotifierUI
import Preferences

extension Bool {
  fileprivate var state: NSControl.StateValue {
    self ? .on : .off
  }
}

// MARK: - IME Menu Manager

// 因為選單部分的內容又臭又長，所以就單獨拉到一個檔案內管理了。

extension SessionCtl {
  override func menu() -> NSMenu! {
    let optionKeyPressed = NSEvent.modifierFlags.contains(.option)

    let menu = NSMenu(title: "Input Method Menu")

    let useSCPCTypingModeItem = menu.addItem(
      withTitle: NSLocalizedString("Per-Char Select Mode", comment: ""),
      action: #selector(toggleSCPCTypingMode(_:)), keyEquivalent: PrefMgr.shared.usingHotKeySCPC ? "P" : ""
    )
    useSCPCTypingModeItem.keyEquivalentModifierMask = [.command, .control]
    useSCPCTypingModeItem.state = PrefMgr.shared.useSCPCTypingMode.state

    let userAssociatedPhrasesItem = menu.addItem(
      withTitle: NSLocalizedString("Per-Char Associated Phrases", comment: ""),
      action: #selector(toggleAssociatedPhrasesEnabled(_:)),
      keyEquivalent: PrefMgr.shared.usingHotKeyAssociates ? "O" : ""
    )
    userAssociatedPhrasesItem.keyEquivalentModifierMask = [.command, .control]
    userAssociatedPhrasesItem.state = PrefMgr.shared.associatedPhrasesEnabled.state

    let useCNS11643SupportItem = menu.addItem(
      withTitle: NSLocalizedString("CNS11643 Mode", comment: ""),
      action: #selector(toggleCNS11643Enabled(_:)), keyEquivalent: PrefMgr.shared.usingHotKeyCNS ? "L" : ""
    )
    useCNS11643SupportItem.keyEquivalentModifierMask = [.command, .control]
    useCNS11643SupportItem.state = PrefMgr.shared.cns11643Enabled.state

    if IMEApp.currentInputMode == .imeModeCHT {
      let chineseConversionItem = menu.addItem(
        withTitle: NSLocalizedString("Force KangXi Writing", comment: ""),
        action: #selector(toggleChineseConverter(_:)), keyEquivalent: PrefMgr.shared.usingHotKeyKangXi ? "K" : ""
      )
      chineseConversionItem.keyEquivalentModifierMask = [.command, .control]
      chineseConversionItem.state = PrefMgr.shared.chineseConversionEnabled.state

      let shiftJISConversionItem = menu.addItem(
        withTitle: NSLocalizedString("JIS Shinjitai Output", comment: ""),
        action: #selector(toggleShiftJISShinjitaiOutput(_:)), keyEquivalent: PrefMgr.shared.usingHotKeyJIS ? "J" : ""
      )
      shiftJISConversionItem.keyEquivalentModifierMask = [.command, .control]
      shiftJISConversionItem.state = PrefMgr.shared.shiftJISShinjitaiOutputEnabled.state
    }

    let currencyNumeralsItem = menu.addItem(
      withTitle: NSLocalizedString("Currency Numeral Output", comment: ""),
      action: #selector(toggleCurrencyNumerals(_:)),
      keyEquivalent: PrefMgr.shared.usingHotKeyCurrencyNumerals ? "M" : ""
    )
    currencyNumeralsItem.keyEquivalentModifierMask = [.command, .control]
    currencyNumeralsItem.state = PrefMgr.shared.currencyNumeralsEnabled.state

    let halfWidthPunctuationItem = menu.addItem(
      withTitle: NSLocalizedString("Half-Width Punctuation Mode", comment: ""),
      action: #selector(toggleHalfWidthPunctuation(_:)),
      keyEquivalent: PrefMgr.shared.usingHotKeyHalfWidthASCII ? "H" : ""
    )
    halfWidthPunctuationItem.keyEquivalentModifierMask = [.command, .control]
    halfWidthPunctuationItem.state = PrefMgr.shared.halfWidthPunctuationEnabled.state

    if optionKeyPressed || PrefMgr.shared.phraseReplacementEnabled {
      let phaseReplacementItem = menu.addItem(
        withTitle: NSLocalizedString("Use Phrase Replacement", comment: ""),
        action: #selector(togglePhraseReplacement(_:)), keyEquivalent: ""
      )
      phaseReplacementItem.state = PrefMgr.shared.phraseReplacementEnabled.state
    }

    if optionKeyPressed {
      let toggleSymbolInputItem = menu.addItem(
        withTitle: NSLocalizedString("Symbol & Emoji Input", comment: ""),
        action: #selector(toggleSymbolEnabled(_:)), keyEquivalent: ""
      )
      toggleSymbolInputItem.state = PrefMgr.shared.symbolInputEnabled.state
    }

    menu.addItem(NSMenuItem.separator())  // ---------------------

    menu.addItem(
      withTitle: NSLocalizedString("Open User Dictionary Folder", comment: ""),
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

    if optionKeyPressed || PrefMgr.shared.associatedPhrasesEnabled {
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

    if optionKeyPressed || !PrefMgr.shared.shouldAutoReloadUserDataFiles {
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

    menu.addItem(
      withTitle: NSLocalizedString("vChewing Preferences…", comment: ""),
      action: #selector(showPreferences(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("Client Manager", comment: "") + "…",
      action: #selector(showClientListMgr(_:)), keyEquivalent: ""
    )
    if !optionKeyPressed {
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
    menu.addItem(
      withTitle: NSLocalizedString("CheatSheet", comment: "") + "…",
      action: #selector(showCheatSheet(_:)), keyEquivalent: ""
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
}

// MARK: - IME Menu Items

extension SessionCtl {
  @objc override func showPreferences(_: Any?) {
    if #unavailable(macOS 10.15) {
      showLegacyPreferences()
    } else if NSEvent.modifierFlags.contains(.option) {
      showLegacyPreferences()
    } else {
      NSApp.setActivationPolicy(.accessory)
      ctlPrefUI.shared.controller.show(preferencePane: Preferences.PaneIdentifier(rawValue: "General"))
      ctlPrefUI.shared.controller.window?.level = .statusBar
    }
  }

  func showLegacyPreferences() {
    (NSApp.delegate as? AppDelegate)?.showPreferences()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func showCheatSheet(_: Any?) {
    guard let url = Bundle.main.url(forResource: "shortcuts", withExtension: "html") else { return }
    DispatchQueue.main.async {
      NSWorkspace.shared.openFile(url.path, withApplication: "Safari")
    }
  }

  @objc func showClientListMgr(_: Any?) {
    (NSApp.delegate as? AppDelegate)?.showClientListMgr()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func toggleSCPCTypingMode(_: Any? = nil) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("Per-Char Select Mode", comment: "") + "\n"
        + (PrefMgr.shared.useSCPCTypingMode.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleChineseConverter(_: Any?) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("Force KangXi Writing", comment: "") + "\n"
        + (PrefMgr.shared.chineseConversionEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleShiftJISShinjitaiOutput(_: Any?) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("JIS Shinjitai Output", comment: "") + "\n"
        + (PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleCurrencyNumerals(_: Any?) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("Currency Numeral Output", comment: "") + "\n"
        + (PrefMgr.shared.currencyNumeralsEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleHalfWidthPunctuation(_: Any?) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("Half-Width Punctuation Mode", comment: "") + "\n"
        + (PrefMgr.shared.halfWidthPunctuationEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleCNS11643Enabled(_: Any?) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("CNS11643 Mode", comment: "") + "\n"
        + (PrefMgr.shared.cns11643Enabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleSymbolEnabled(_: Any?) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("Symbol & Emoji Input", comment: "") + "\n"
        + (PrefMgr.shared.symbolInputEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleAssociatedPhrasesEnabled(_: Any?) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("Per-Char Associated Phrases", comment: "") + "\n"
        + (PrefMgr.shared.associatedPhrasesEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func togglePhraseReplacement(_: Any?) {
    resetKeyHandler()
    Notifier.notify(
      message: NSLocalizedString("Use Phrase Replacement", comment: "") + "\n"
        + (PrefMgr.shared.phraseReplacementEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func selfUninstall(_: Any?) {
    (NSApp.delegate as? AppDelegate)?.selfUninstall()
  }

  @objc func selfTerminate(_: Any?) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.terminate(nil)
  }

  @objc func checkForUpdate(_: Any?) {
    (NSApp.delegate as? AppDelegate)?.updateSputnik.checkForUpdate(forced: true, url: kUpdateInfoSourceURL)
  }

  @objc func openUserDataFolder(_: Any?) {
    if !LMMgr.userDataFolderExists {
      return
    }
    NSWorkspace.shared.openFile(
      LMMgr.dataFolderPath(isDefaultFolder: false), withApplication: "Finder"
    )
  }

  @objc func openUserPhrases(_: Any?) {
    LMMgr.openPhraseFile(fromURL: LMMgr.userPhrasesDataURL(IMEApp.currentInputMode))
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.openPhraseFile(fromURL: LMMgr.userPhrasesDataURL(IMEApp.currentInputMode.reversed))
    }
  }

  @objc func openExcludedPhrases(_: Any?) {
    LMMgr.openPhraseFile(fromURL: LMMgr.userFilteredDataURL(IMEApp.currentInputMode))
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.openPhraseFile(fromURL: LMMgr.userFilteredDataURL(IMEApp.currentInputMode.reversed))
    }
  }

  @objc func openUserSymbols(_: Any?) {
    LMMgr.openPhraseFile(fromURL: LMMgr.userSymbolDataURL(IMEApp.currentInputMode))
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.openPhraseFile(fromURL: LMMgr.userSymbolDataURL(IMEApp.currentInputMode.reversed))
    }
  }

  @objc func openPhraseReplacement(_: Any?) {
    LMMgr.openPhraseFile(fromURL: LMMgr.userReplacementsDataURL(IMEApp.currentInputMode))
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.openPhraseFile(fromURL: LMMgr.userReplacementsDataURL(IMEApp.currentInputMode.reversed))
    }
  }

  @objc func openAssociatedPhrases(_: Any?) {
    LMMgr.openPhraseFile(fromURL: LMMgr.userAssociatesDataURL(IMEApp.currentInputMode))
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.openPhraseFile(
        fromURL: LMMgr.userAssociatesDataURL(IMEApp.currentInputMode.reversed))
    }
  }

  @objc func reloadUserPhrasesData(_: Any?) {
    LMMgr.initUserLangModels()
  }

  @objc func removeUnigramsFromUOM(_: Any?) {
    LMMgr.removeUnigramsFromUserOverrideModel(IMEApp.currentInputMode)
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.removeUnigramsFromUserOverrideModel(IMEApp.currentInputMode.reversed)
    }
  }

  @objc func clearUOM(_: Any?) {
    LMMgr.clearUserOverrideModelData(IMEApp.currentInputMode)
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.clearUserOverrideModelData(IMEApp.currentInputMode.reversed)
    }
  }

  @objc func showAbout(_: Any?) {
    (NSApp.delegate as? AppDelegate)?.showAbout()
    NSApp.activate(ignoringOtherApps: true)
  }
}
