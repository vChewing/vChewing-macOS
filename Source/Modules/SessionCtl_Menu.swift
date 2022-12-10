// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import LangModelAssembly
import MenuBuilder
import NotifierUI
import SSPreferences
import UpdateSputnik

extension Bool {
  fileprivate var state: NSControl.StateValue {
    self ? .on : .off
  }
}

// MARK: - IME Menu Manager

// 因為選單部分的內容又臭又長，所以就單獨拉到一個檔案內管理了。

extension SessionCtl {
  var optionKeyPressed: Bool { NSEvent.modifierFlags.contains(.option) }

  override public func menu() -> NSMenu! {
    .init {
      MenuItem("Per-Char Select Mode").state(PrefMgr.shared.useSCPCTypingMode.state)
        .shortcut(PrefMgr.shared.usingHotKeySCPC ? "P" : "", holding: [.command, .control])
        .action(#selector(self.toggleSCPCTypingMode(_:)))
      MenuItem("Per-Char Associated Phrases").state(PrefMgr.shared.associatedPhrasesEnabled.state)
        .action(#selector(self.toggleAssociatedPhrasesEnabled(_:)))
        .shortcut(PrefMgr.shared.usingHotKeyAssociates ? "O" : "", holding: [.command, .control])
      MenuItem("CIN Cassette Mode").state(PrefMgr.shared.cassetteEnabled.state)
        .action(#selector(self.toggleCassetteMode(_:)))
        .shortcut(PrefMgr.shared.usingHotKeyCassette ? "I" : "", holding: [.command, .control])
      MenuItem("CNS11643 Mode").state(PrefMgr.shared.cns11643Enabled.state)
        .action(#selector(self.toggleCNS11643Enabled(_:)))
        .shortcut(PrefMgr.shared.usingHotKeyCNS ? "L" : "", holding: [.command, .control])
      if IMEApp.currentInputMode == .imeModeCHT {
        MenuItem("Force KangXi Writing").state(PrefMgr.shared.chineseConversionEnabled.state)
          .action(#selector(self.toggleChineseConverter(_:)))
          .shortcut(PrefMgr.shared.usingHotKeyKangXi ? "K" : "", holding: [.command, .control])
        MenuItem("JIS Shinjitai Output").state(PrefMgr.shared.shiftJISShinjitaiOutputEnabled.state)
          .action(#selector(self.toggleShiftJISShinjitaiOutput(_:)))
          .shortcut(PrefMgr.shared.usingHotKeyJIS ? "J" : "", holding: [.command, .control])
      }
      MenuItem("Currency Numeral Output").state(PrefMgr.shared.currencyNumeralsEnabled.state)
        .action(#selector(self.toggleCurrencyNumerals(_:)))
        .shortcut(PrefMgr.shared.usingHotKeyCurrencyNumerals ? "M" : "", holding: [.command, .control])
      MenuItem("Half-Width Punctuation Mode").state(PrefMgr.shared.halfWidthPunctuationEnabled.state)
        .action(#selector(self.toggleHalfWidthPunctuation(_:)))
        .shortcut(PrefMgr.shared.usingHotKeyHalfWidthASCII ? "H" : "", holding: [.command, .control])
      if optionKeyPressed || PrefMgr.shared.phraseReplacementEnabled {
        MenuItem("Use Phrase Replacement").state(PrefMgr.shared.phraseReplacementEnabled.state)
          .action(#selector(self.togglePhraseReplacement(_:)))
      }
      if optionKeyPressed {
        MenuItem("Symbol & Emoji Input").state(PrefMgr.shared.symbolInputEnabled.state)
          .action(#selector(self.toggleSymbolEnabled(_:)))
      }

      SeparatorItem()  // ------------------

      MenuItem("Open User Dictionary Folder").action(#selector(self.openUserDataFolder(_:)))
      MenuItem("Edit vChewing User Phrases…").action(#selector(self.openUserPhrases(_:)))
      MenuItem("Edit Excluded Phrases…").action(#selector(self.openExcludedPhrases(_:)))
      if optionKeyPressed || PrefMgr.shared.associatedPhrasesEnabled {
        MenuItem("Edit Associated Phrases…").action(#selector(self.openAssociatedPhrases(_:)))
      }
      if optionKeyPressed {
        MenuItem("Edit Phrase Replacement Table…").action(#selector(self.openPhraseReplacement(_:)))
        MenuItem("Edit User Symbol & Emoji Data…").action(#selector(self.openUserSymbols(_:)))
      }
      if optionKeyPressed || !PrefMgr.shared.shouldAutoReloadUserDataFiles {
        MenuItem("Reload User Phrases").action(#selector(self.reloadUserPhrasesData(_:)))
      }
      MenuItem(verbatim: "Reverse Lookup (Phonabets)".localized.withEllipsis).action(
        #selector(self.callReverseLookupWindow(_:)))

      SeparatorItem()  // ------------------

      MenuItem("Optimize Memorized Phrases").action(#selector(self.removeUnigramsFromUOM(_:)))
      MenuItem("Clear Memorized Phrases").action(#selector(self.clearUOM(_:)))

      SeparatorItem()  // ------------------

      MenuItem("vChewing Preferences…").action(#selector(self.showPreferences(_:)))
      MenuItem(verbatim: "Client Manager".localized.withEllipsis).action(#selector(self.showClientListMgr(_:)))
      if !optionKeyPressed {
        MenuItem("Check for Updates…").action(#selector(self.checkForUpdate(_:)))
      }
      MenuItem("Reboot vChewing…").action(#selector(self.selfTerminate(_:)))
      MenuItem("About vChewing…").action(#selector(self.showAbout(_:)))
      MenuItem(verbatim: "CheatSheet".localized.withEllipsis).action(#selector(self.showCheatSheet(_:)))
      if optionKeyPressed {
        MenuItem("Uninstall vChewing…").action(#selector(self.selfUninstall(_:)))
      }
    }
  }
}

// MARK: - IME Menu Items

extension SessionCtl {
  @objc public override func showPreferences(_: Any? = nil) {
    if #unavailable(macOS 10.15) {
      CtlPrefWindow.show()
    } else if NSEvent.modifierFlags.contains(.option) {
      CtlPrefWindow.show()
    } else {
      CtlPrefUI.shared.controller.show(preferencePane: SSPreferences.PaneIdentifier(rawValue: "General"))
      CtlPrefUI.shared.controller.window?.level = .statusBar
      CtlPrefUI.shared.controller.window?.setPosition(vertical: .top, horizontal: .right, padding: 20)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc public func showCheatSheet(_: Any? = nil) {
    guard let url = Bundle.main.url(forResource: "shortcuts", withExtension: "html") else { return }
    DispatchQueue.main.async {
      NSWorkspace.shared.openFile(url.path, withApplication: "Safari")
    }
  }

  @objc public func showClientListMgr(_: Any? = nil) {
    CtlClientListMgr.show()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc public func toggleCassetteMode(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    if !PrefMgr.shared.cassetteEnabled, !LMMgr.checkCassettePathValidity(PrefMgr.shared.cassettePath) {
      DispatchQueue.main.async {
        IMEApp.buzz()
        let alert = NSAlert(error: NSLocalizedString("Path invalid or file access error.", comment: ""))
        alert.informativeText = NSLocalizedString(
          "Please reconfigure the cassette path to a valid one before enabling this mode.", comment: ""
        )
        let result = alert.runModal()
        NSApp.activate(ignoringOtherApps: true)
        if result == NSApplication.ModalResponse.alertFirstButtonReturn {
          LMMgr.resetCassettePath()
          PrefMgr.shared.cassetteEnabled = false
        }
      }
      return
    }
    Notifier.notify(
      message: NSLocalizedString("CIN Cassette Mode", comment: "") + "\n"
        + (PrefMgr.shared.cassetteEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
    if !LMMgr.currentLM.isCassetteDataLoaded {
      LMMgr.loadCassetteData()
    }
  }

  @objc public func toggleSCPCTypingMode(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Per-Char Select Mode", comment: "") + "\n"
        + (PrefMgr.shared.useSCPCTypingMode.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func toggleChineseConverter(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Force KangXi Writing", comment: "") + "\n"
        + (PrefMgr.shared.chineseConversionEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func toggleShiftJISShinjitaiOutput(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("JIS Shinjitai Output", comment: "") + "\n"
        + (PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func toggleCurrencyNumerals(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Currency Numeral Output", comment: "") + "\n"
        + (PrefMgr.shared.currencyNumeralsEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func toggleHalfWidthPunctuation(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Half-Width Punctuation Mode", comment: "") + "\n"
        + (PrefMgr.shared.halfWidthPunctuationEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func toggleCNS11643Enabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("CNS11643 Mode", comment: "") + "\n"
        + (PrefMgr.shared.cns11643Enabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func toggleSymbolEnabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Symbol & Emoji Input", comment: "") + "\n"
        + (PrefMgr.shared.symbolInputEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func toggleAssociatedPhrasesEnabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Per-Char Associated Phrases", comment: "") + "\n"
        + (PrefMgr.shared.associatedPhrasesEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func togglePhraseReplacement(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Use Phrase Replacement", comment: "") + "\n"
        + (PrefMgr.shared.phraseReplacementEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc public func selfUninstall(_: Any? = nil) {
    (NSApp.delegate as? AppDelegate)?.selfUninstall()
  }

  @objc public func selfTerminate(_: Any? = nil) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.terminate(nil)
  }

  @objc public func checkForUpdate(_: Any? = nil) {
    UpdateSputnik.shared.checkForUpdate(forced: true, url: kUpdateInfoSourceURL)
  }

  @objc public func openUserDataFolder(_: Any? = nil) {
    if !LMMgr.userDataFolderExists {
      return
    }
    NSWorkspace.shared.openFile(
      LMMgr.dataFolderPath(isDefaultFolder: false), withApplication: "Finder"
    )
  }

  @objc public func openUserPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .thePhrases, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc public func openExcludedPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theFilter, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc public func openUserSymbols(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theSymbols, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc public func openPhraseReplacement(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theReplacements, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc public func openAssociatedPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theAssociates, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc public func reloadUserPhrasesData(_: Any? = nil) {
    LMMgr.initUserLangModels()
  }

  @objc public func callReverseLookupWindow(_: Any? = nil) {
    CtlRevLookupWindow.show()
  }

  @objc public func removeUnigramsFromUOM(_: Any? = nil) {
    LMMgr.removeUnigramsFromUserOverrideModel(IMEApp.currentInputMode)
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.removeUnigramsFromUserOverrideModel(IMEApp.currentInputMode.reversed)
    }
  }

  @objc public func clearUOM(_: Any? = nil) {
    LMMgr.clearUserOverrideModelData(IMEApp.currentInputMode)
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.clearUserOverrideModelData(IMEApp.currentInputMode.reversed)
    }
  }

  @objc public func showAbout(_: Any? = nil) {
    CtlAboutWindow.show()
    NSApp.activate(ignoringOtherApps: true)
  }
}
