// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - IME Menu Sputnik

extension SessionCtl {
  public func makeMenu() -> NSMenu {
    let currentInputMode = IMEApp.currentInputMode
    return NSMenu().appendItems(self) {
      if #unavailable(macOS 14) {
        NSMenu.Item("i18n:Menu.vChewingSettings")?
          .act(#selector(showPreferences(_:)))
          .nulled(silentMode)
      } else {
        NSMenu.Item(verbatim: "i18n:Menu.vChewingSettings".i18n + " (SwiftUI)")?
          .act(#selector(showSettingsSwiftUI(_:)))
          .nulled(silentMode)
        NSMenu.Item(verbatim: "i18n:Menu.vChewingSettings".i18n + " (AppKit)")?
          .act(#selector(showSettingsAppKit(_:)))
          .alternated().nulled(silentMode)
      }
      NSMenu.Item(verbatim: currentRAMUsageDescription)
      NSMenu.Item("i18n:Menu.SponsorTheDevelopment")?
        .act(#selector(sponsorTheDevelopment(_:)))
      NSMenu.Item.separator() // ---------------------
      NSMenu.Item(
        verbatim: String(
          format: "i18n:InputMode.SwitchToInputMode:%@".i18n,
          currentInputMode.reversed.localizedDescription
        )
      )?.act(#selector(switchInputMode(_:)))
        .hotkey(PrefMgr.shared.usingHotKeyInputMode ? "D" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeySCPC.shortTitle")?
        .act(#selector(toggleSCPCTypingMode(_:)))
        .state(PrefMgr.shared.useSCPCTypingMode)
        .hotkey(PrefMgr.shared.usingHotKeySCPC ? "P" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeyAssociates.shortTitle")?
        .act(#selector(toggleAssociatedPhrasesEnabled(_:)))
        .state(PrefMgr.shared.associatedPhrasesEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyAssociates ? "O" : "", mask: [.command, .control])
      NSMenu.Item("i18n:Menu.EditAssociatedPhrases")?
        .act(#selector(openAssociatedPhrases(_:)))
        .alternated()
        .hotkey(
          PrefMgr.shared.usingHotKeyAssociates ? "O" : "",
          mask: [.command, .option, .control]
        )
        .nulled(silentMode)
      NSMenu.Item("i18n:UserDef.kUsingHotKeyRevLookup.shortTitle")?
        .act(#selector(toggleCassetteMode(_:)))
        .state(PrefMgr.shared.cassetteEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyCassette ? "I" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeyCNS.shortTitle")?
        .act(#selector(toggleCNS11643Enabled(_:)))
        .state(PrefMgr.shared.cns11643Enabled)
        .hotkey(PrefMgr.shared.usingHotKeyCNS ? "L" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeyKangXi.shortTitle")?
        .act(#selector(toggleChineseConverter(_:)))
        .state(PrefMgr.shared.chineseConversionEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyKangXi ? "K" : "", mask: [.command, .control])
        .nulled(currentInputMode != .imeModeCHT)
      NSMenu.Item("i18n:UserDef.kUsingHotKeyHalfWidthASCII.shortTitle")?
        .act(#selector(toggleShiftJISShinjitaiOutput(_:)))
        .state(PrefMgr.shared.shiftJISShinjitaiOutputEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyJIS ? "J" : "", mask: [.command, .control])
        .nulled(currentInputMode != .imeModeCHT)
      NSMenu.Item("i18n:UserDef.kUsingHotKeyCassette.shortTitle")?
        .act(#selector(toggleCurrencyNumerals(_:)))
        .state(PrefMgr.shared.currencyNumeralsEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyCurrencyNumerals ? "M" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeyCurrencyNumerals.shortTitle")?
        .act(#selector(toggleHalfWidthPunctuation(_:)))
        .state(PrefMgr.shared.halfWidthPunctuationEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyHalfWidthASCII ? "H" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kPhraseReplacementEnabled.shortTitle")?
        .act(#selector(togglePhraseReplacement(_:)))
        .state(PrefMgr.shared.phraseReplacementEnabled)
      NSMenu.Item("i18n:Menu.EditPhraseReplacementTable")?
        .act(#selector(openPhraseReplacement(_:)))
        .alternated().nulled(silentMode)
      NSMenu.Item("i18n:Menu.SymbolEmojiInput")?
        .act(#selector(toggleSymbolEnabled(_:)))
        .state(PrefMgr.shared.symbolInputEnabled)
      NSMenu.Item("i18n:Menu.EditUserSymbolEmojiData")?
        .act(#selector(openUserSymbols(_:)))
        .alternated().nulled(silentMode)

      NSMenu.Item.separator() // ---------------------
      NSMenu.Item("i18n:Menu.OpenUserDictionaryFolder")?
        .act(#selector(openUserDataFolder(_:)))
        .nulled(silentMode)
      NSMenu.Item("i18n:Menu.OpenAppSupportFolder")?
        .act(#selector(openAppSupportFolderFromContainer(_:)))
        .alternated().nulled(silentMode)
      NSMenu.Item("i18n:Menu.EditVChewingUserPhrases")?
        .act(#selector(openUserPhrases(_:)))
        .nulled(silentMode)
      NSMenu.Item("i18n:Menu.ReloadUserPhrases")?
        .act(#selector(reloadUserPhrasesData(_:)))
      NSMenu.Item("i18n:Menu.EditExcludedPhrases")?
        .act(#selector(openExcludedPhrases(_:)))
        .alternated().nulled(silentMode)
      NSMenu.Item(verbatim: "i18n:UserDef.kUsingHotKeyJIS.shortTitle".i18n.withEllipsis)?
        .act(#selector(callReverseLookupWindow(_:)))
        .hotkey(PrefMgr.shared.usingHotKeyRevLookup ? "/" : "", mask: [.command, .control])
      NSMenu.Item("i18n:Menu.OptimizeMemorizedPhrases")?
        .act(#selector(removeUnigramsFromPOM(_:)))
      NSMenu.Item("i18n:Menu.ClearMemorizedPhrases")?
        .act(#selector(clearPOM(_:)))
        .alternated()

      NSMenu.Item.separator() // ---------------------
      NSMenu.Item("i18n:Menu.CheckForUpdates")?
        .act(#selector(checkForUpdate(_:)))
        .nulled(silentMode)
      NSMenu.Item("i18n:Menu.RebootVChewing")?
        .act(#selector(selfTerminate(_:)))
      NSMenu.Item("i18n:Menu.CheatSheet")?
        .act(#selector(showCheatSheet(_:)))
        .nulled(silentMode)
      NSMenu.Item("i18n:Menu.UninstallVChewing")?
        .act(#selector(selfUninstall(_:)))
        .nulled(silentMode || !optionKeyPressed)
    }
  }

  @objc
  public func switchInputMode(_: Any? = nil) {
    core?.toggleInputMode()
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
  public func toggleCassetteMode(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    // Use cassettePath() which includes internal cache fallback.
    if !PrefMgr.shared.cassetteEnabled,
       LMMgr.cassettePath().isEmpty {
      asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
        IMEApp.buzz()
        let alert = NSAlert(error: "i18n:LMMgr.accessFailure.cassette.title".i18n)
        alert.informativeText = LMMgr.cassetteAccessFailureDescription(path: PrefMgr.shared.cassettePath)
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
      message: "i18n:UserDef.kUsingHotKeyRevLookup.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.cassetteEnabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
    let cassetteDataLoaded = core?.inputMode.langModel.isCassetteDataLoaded
    if let cassetteDataLoaded, !cassetteDataLoaded {
      LMMgr.loadCassetteData()
    }
  }

  @objc
  public func toggleSCPCTypingMode(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:UserDef.kUsingHotKeySCPC.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.useSCPCTypingMode.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
  }

  @objc
  public func toggleChineseConverter(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:UserDef.kUsingHotKeyKangXi.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.chineseConversionEnabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
  }

  @objc
  public func toggleShiftJISShinjitaiOutput(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:UserDef.kUsingHotKeyHalfWidthASCII.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
  }

  @objc
  public func toggleCurrencyNumerals(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:UserDef.kUsingHotKeyCassette.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.currencyNumeralsEnabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
  }

  @objc
  public func toggleHalfWidthPunctuation(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:UserDef.kUsingHotKeyCurrencyNumerals.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.halfWidthPunctuationEnabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
  }

  @objc
  public func toggleCNS11643Enabled(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:UserDef.kUsingHotKeyCNS.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.cns11643Enabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
  }

  @objc
  public func toggleSymbolEnabled(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:Menu.SymbolEmojiInput".i18n + "\n"
        + (
          PrefMgr.shared.symbolInputEnabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
  }

  @objc
  public func toggleAssociatedPhrasesEnabled(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:UserDef.kUsingHotKeyAssociates.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.associatedPhrasesEnabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
        )
    )
  }

  @objc
  public func togglePhraseReplacement(_: Any? = nil) {
    core?.resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "i18n:UserDef.kPhraseReplacementEnabled.shortTitle".i18n + "\n"
        + (
          PrefMgr.shared.phraseReplacementEnabled.toggled()
            ? "i18n:NotificationSwitch.On".i18n
            : "i18n:NotificationSwitch.Off".i18n
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
    let bundleID = core?.clientBundleIdentifier
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
  public func sponsorTheDevelopment(_: Any? = nil) {
    guard let url = URL(string: "https://vchewing.github.io/SPONSOR_ME.html") else { return }
    NSWorkspace.shared.open(url)
  }

  // MARK: Internal

  var optionKeyPressed: Bool { NSEvent.keyModifierFlags.contains(.option) }
  var silentMode: Bool { core?.clientBundleIdentifier == "com.apple.SecurityAgent" }

  var currentRAMUsageDescription: String? {
    // 關閉 malloc zone 的空閒頁面，讓選單顯示的數值儘可能真實
    // 而不是因為 allocator cache 還沒退回導致的人為偏高。
    // 使用匿名私有記憶體（`task_vm_info.internal`）而非
    // `phys_footprint`，避免被 Liquid Glass / GPU / neural
    // engine 的共享記憶體帳目欺騙。
    NSApplication.purgeMallocZones()
    guard let currentMemorySizeInBytes = NSApplication.memoryFootprintAnonymous else { return nil }
    let currentMemorySize: Double = (Double(currentMemorySizeInBytes) / 1_024 / 1_024)
      .rounded(toPlaces: 1)
    return "i18n:IME.RAMUsedLabelHeader".i18n + " \(currentMemorySize)MB"
  }
}
