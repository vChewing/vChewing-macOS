// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - IME Menu Manager

// 因為選單部分的內容又臭又長，所以就單獨拉到一個檔案內管理了。

extension SessionCtl {
  // MARK: Public

  override public func menu() -> NSMenu {
    NSMenu().appendItems(self) {
      NSMenu.Item(verbatim: currentRAMUsageDescription)
      NSMenu.Item(
        verbatim: String(
          format: "Switch to %@ Input Mode".i18n,
          IMEApp.currentInputMode.reversed.localizedDescription
        )
      )?.act(#selector(switchInputMode(_:)))
        .hotkey(PrefMgr.shared.usingHotKeyInputMode ? "D" : "", mask: [.command, .control])
      NSMenu.Item("Per-Char Select Mode")?
        .act(#selector(toggleSCPCTypingMode(_:)))
        .state(PrefMgr.shared.useSCPCTypingMode)
        .hotkey(PrefMgr.shared.usingHotKeySCPC ? "P" : "", mask: [.command, .control])
      NSMenu.Item("Associated Phrases")?
        .act(#selector(toggleAssociatedPhrasesEnabled(_:)))
        .state(PrefMgr.shared.associatedPhrasesEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyAssociates ? "O" : "", mask: [.command, .control])
      NSMenu.Item("Edit Associated Phrases…")?
        .act(#selector(openAssociatedPhrases(_:)))
        .alternated()
        .hotkey(
          PrefMgr.shared.usingHotKeyAssociates ? "O" : "",
          mask: [.command, .option, .control]
        )
        .nulled(silentMode)
      NSMenu.Item("CIN Cassette Mode")?
        .act(#selector(toggleCassetteMode(_:)))
        .state(PrefMgr.shared.cassetteEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyCassette ? "I" : "", mask: [.command, .control])
      NSMenu.Item("CNS11643 Mode")?
        .act(#selector(toggleCNS11643Enabled(_:)))
        .state(PrefMgr.shared.cns11643Enabled)
        .hotkey(PrefMgr.shared.usingHotKeyCNS ? "L" : "", mask: [.command, .control])
      NSMenu.Item("Force KangXi Writing")?
        .act(#selector(toggleChineseConverter(_:)))
        .state(PrefMgr.shared.chineseConversionEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyKangXi ? "K" : "", mask: [.command, .control])
        .nulled(IMEApp.currentInputMode != .imeModeCHT)
      NSMenu.Item("JIS Shinjitai Output")?
        .act(#selector(toggleShiftJISShinjitaiOutput(_:)))
        .state(PrefMgr.shared.shiftJISShinjitaiOutputEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyJIS ? "J" : "", mask: [.command, .control])
        .nulled(IMEApp.currentInputMode != .imeModeCHT)
      NSMenu.Item("Currency Numeral Output")?
        .act(#selector(toggleCurrencyNumerals(_:)))
        .state(PrefMgr.shared.currencyNumeralsEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyCurrencyNumerals ? "M" : "", mask: [.command, .control])
      NSMenu.Item("Half-Width Punctuation Mode")?
        .act(#selector(toggleHalfWidthPunctuation(_:)))
        .state(PrefMgr.shared.halfWidthPunctuationEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyHalfWidthASCII ? "H" : "", mask: [.command, .control])
      NSMenu.Item("Use Phrase Replacement")?
        .act(#selector(togglePhraseReplacement(_:)))
        .state(PrefMgr.shared.phraseReplacementEnabled)
      NSMenu.Item("Edit Phrase Replacement Table…")?
        .act(#selector(openPhraseReplacement(_:)))
        .alternated().nulled(silentMode)
      NSMenu.Item("Symbol & Emoji Input")?
        .act(#selector(toggleSymbolEnabled(_:)))
        .state(PrefMgr.shared.symbolInputEnabled)
      NSMenu.Item("Edit User Symbol & Emoji Data…")?
        .act(#selector(openUserSymbols(_:)))
        .alternated().nulled(silentMode)

      NSMenu.Item.separator() // ---------------------
      NSMenu.Item("Open User Dictionary Folder")?
        .act(#selector(openUserDataFolder(_:)))
        .nulled(silentMode)
      NSMenu.Item("Open App Support Folder")?
        .act(#selector(openAppSupportFolderFromContainer(_:)))
        .alternated().nulled(silentMode)
      NSMenu.Item("Edit vChewing User Phrases…")?
        .act(#selector(openUserPhrases(_:)))
        .nulled(silentMode)
      NSMenu.Item("Reload User Phrases")?
        .act(#selector(reloadUserPhrasesData(_:)))
      NSMenu.Item("Edit Excluded Phrases…")?
        .act(#selector(openExcludedPhrases(_:)))
        .alternated().nulled(silentMode)
      NSMenu.Item(verbatim: "Reverse Lookup (Phonabets)".i18n.withEllipsis)?
        .act(#selector(callReverseLookupWindow(_:)))
        .hotkey(PrefMgr.shared.usingHotKeyRevLookup ? "/" : "", mask: [.command, .control])
      NSMenu.Item("Optimize Memorized Phrases")?
        .act(#selector(removeUnigramsFromPOM(_:)))
      NSMenu.Item("Clear Memorized Phrases")?
        .act(#selector(clearPOM(_:)))
        .alternated()

      NSMenu.Item.separator() // ---------------------
      if #unavailable(macOS 14) {
        NSMenu.Item("vChewing Preferences…")?
          .act(#selector(showPreferences(_:)))
          .nulled(silentMode)
      } else {
        NSMenu.Item(verbatim: "vChewing Preferences…".i18n + " (SwiftUI)")?
          .act(#selector(showSettingsSwiftUI(_:)))
          .nulled(silentMode)
        NSMenu.Item(verbatim: "vChewing Preferences…".i18n + " (AppKit)")?
          .act(#selector(showSettingsAppKit(_:)))
          .alternated().nulled(silentMode)
      }
      NSMenu.Item(verbatim: "Client Manager".i18n.withEllipsis)?
        .act(#selector(showClientListMgr(_:)))
        .nulled(silentMode)
      NSMenu.Item(verbatim: "Service Menu Editor".i18n.withEllipsis)?
        .act(#selector(showServiceMenuEditor(_:)))
        .alternated().nulled(silentMode)
      NSMenu.Item("Check for Updates…")?
        .act(#selector(checkForUpdate(_:)))
        .nulled(silentMode)
      NSMenu.Item("Reboot vChewing…")?
        .act(#selector(selfTerminate(_:)))
      NSMenu.Item("CheatSheet")?
        .act(#selector(showCheatSheet(_:)))
        .nulled(silentMode)
      NSMenu.Item("About vChewing…")?
        .act(#selector(showAbout(_:)))
        .nulled(silentMode)
      NSMenu.Item("Uninstall vChewing…")?
        .act(#selector(selfUninstall(_:)))
        .nulled(silentMode || !optionKeyPressed)
    }
  }

  @objc
  public func switchInputMode(_: Any? = nil) {
    core.toggleInputMode()
  }

  @objc
  override public func showPreferences(_: Any? = nil) {
    osCheck: if #available(macOS 14, *) {
      switch NSEvent.keyModifierFlags {
      case .option: break osCheck
      default: CtlSettingsUI.show()
      }
      NSApp.popup()
      return
    }
    CtlSettingsCocoa.show()
    NSApp.popup()
  }

  @objc
  public func showSettingsAppKit(_: Any? = nil) {
    CtlSettingsCocoa.show()
    NSApp.popup()
  }

  @available(macOS 14, *)
  @objc
  public func showSettingsSwiftUI(_: Any? = nil) {
    CtlSettingsUI.show()
    NSApp.popup()
  }

  @objc
  public func showCheatSheet(_: Any? = nil) {
    guard let url = Bundle.main.url(forResource: "shortcuts", withExtension: "html") else {
      return
    }
    FileOpenMethod.safari.open(url: url)
  }

  @objc
  public func showClientListMgr(_: Any? = nil) {
    CtlClientListMgr.show()
    NSApp.popup()
  }

  @objc
  public func showServiceMenuEditor(_: Any? = nil) {
    CtlServiceMenuEditor.show()
    NSApp.popup()
  }

  @objc
  public func toggleCassetteMode(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    if !PrefMgr.shared.cassetteEnabled,
       !LMMgr.checkCassettePathValidity(PrefMgr.shared.cassettePath) {
      asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
        IMEApp.buzz()
        let alert = NSAlert(error: "i18n:LMMgr.accessFailure.cassette.title".i18n)
        let informativeText =
          "i18n:LMMgr.accessFailure.cassette.description"
        alert.informativeText = informativeText.i18n
        let result = alert.runModal()
        NSApp.popup()
        if result == NSApplication.ModalResponse.alertFirstButtonReturn {
          LMMgr.resetCassettePath()
          PrefMgr.shared.cassetteEnabled = false
        }
      }
      return
    }
    Notifier.notify(
      message: "CIN Cassette Mode".i18n + "\n"
        + (
          PrefMgr.shared.cassetteEnabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
    if !core.inputMode.langModel.isCassetteDataLoaded {
      LMMgr.loadCassetteData()
    }
  }

  @objc
  public func toggleSCPCTypingMode(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Per-Char Select Mode".i18n + "\n"
        + (
          PrefMgr.shared.useSCPCTypingMode.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func toggleChineseConverter(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Force KangXi Writing".i18n + "\n"
        + (
          PrefMgr.shared.chineseConversionEnabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func toggleShiftJISShinjitaiOutput(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "JIS Shinjitai Output".i18n + "\n"
        + (
          PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func toggleCurrencyNumerals(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Currency Numeral Output".i18n + "\n"
        + (
          PrefMgr.shared.currencyNumeralsEnabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func toggleHalfWidthPunctuation(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Half-Width Punctuation Mode".i18n + "\n"
        + (
          PrefMgr.shared.halfWidthPunctuationEnabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func toggleCNS11643Enabled(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "CNS11643 Mode".i18n + "\n"
        + (
          PrefMgr.shared.cns11643Enabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func toggleSymbolEnabled(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Symbol & Emoji Input".i18n + "\n"
        + (
          PrefMgr.shared.symbolInputEnabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func toggleAssociatedPhrasesEnabled(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Associated Phrases".i18n + "\n"
        + (
          PrefMgr.shared.associatedPhrasesEnabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func togglePhraseReplacement(_: Any? = nil) {
    core.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Use Phrase Replacement".i18n + "\n"
        + (
          PrefMgr.shared.phraseReplacementEnabled.toggled()
            ? "NotificationSwitchON".i18n
            : "NotificationSwitchOFF".i18n
        )
    )
  }

  @objc
  public func selfUninstall(_: Any? = nil) {
    AppDelegate.shared.selfUninstall()
  }

  @objc
  public func selfTerminate(_: Any? = nil) {
    NSApp.popup()
    NSApp.terminate(nil)
  }

  @objc
  public func checkForUpdate(_: Any? = nil) {
    let bundleID = core.clientBundleIdentifier
    AppDelegate.shared.checkUpdate(forced: true) {
      bundleID == "com.apple.SecurityAgent"
    }
  }

  @objc
  public func openUserDataFolder(_: Any? = nil) {
    guard LMMgr.userDataFolderExists else { return }
    let url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
    FileOpenMethod.finder.open(url: url)
  }

  @objc
  public func openAppSupportFolderFromContainer(_: Any? = nil) {
    FileOpenMethod.finder.open(url: LMMgr.appSupportURL)
  }

  @objc
  public func openUserPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .thePhrases, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc
  public func openExcludedPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theFilter, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc
  public func openUserSymbols(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theSymbols, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc
  public func openPhraseReplacement(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theReplacements, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc
  public func openAssociatedPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theAssociates, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc
  public func reloadUserPhrasesData(_: Any? = nil) {
    LMMgr.initUserLangModels()
  }

  @objc
  public func callReverseLookupWindow(_: Any? = nil) {
    CtlRevLookupWindow.show()
  }

  @objc
  public func removeUnigramsFromPOM(_: Any? = nil) {
    LMMgr.removeUnigramsFromPerceptionOverrideModel(IMEApp.currentInputMode)
    LMMgr.removeUnigramsFromPerceptionOverrideModel(IMEApp.currentInputMode.reversed)
  }

  @objc
  public func clearPOM(_: Any? = nil) {
    LMMgr.clearPerceptionOverrideModelData(IMEApp.currentInputMode)
    LMMgr.clearPerceptionOverrideModelData(IMEApp.currentInputMode.reversed)
  }

  @objc
  public func showAbout(_: Any? = nil) {
    CtlAboutUI.show()
    NSApp.popup()
  }

  // MARK: Internal

  var optionKeyPressed: Bool { NSEvent.keyModifierFlags.contains(.option) }
  var silentMode: Bool { core.clientBundleIdentifier == "com.apple.SecurityAgent" }

  var currentRAMUsageDescription: String? {
    guard let currentMemorySizeInBytes = NSApplication.memoryFootprint else { return nil }
    let currentMemorySize: Double = (Double(currentMemorySizeInBytes) / 1_024 / 1_024)
      .rounded(toPlaces: 1)
    return "imeMenu.totalRAMUsed.labelHeader".i18n + " \(currentMemorySize)MB"
  }
}
