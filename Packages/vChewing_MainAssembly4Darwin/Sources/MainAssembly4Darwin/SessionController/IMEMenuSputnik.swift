// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - IMEMenuSputnik

// IMK 的 menu dispatch 走 `didCommandBySelector:client:`。此處以
// `class_addMethod` + `imp_implementationWithBlock` 直接將 closure 註冊為
// method IMP，無需任何 `@objc` Selector 暴露。

struct IMEMenuSputnik {
  // MARK: Lifecycle

  init?(controllerAddr: UInt?) {
    guard let controllerAddr else { return nil }
    // ClientAddr 在此處無意義，因為無須使用。
    self.addrPair = ClientControllerAddrPair(clientAddr: 0, controllerAddr: controllerAddr)
  }

  // MARK: Private

  private let addrPair: ClientControllerAddrPair

  private var controller: SessionCtl? {
    guard let controllerAddr = addrPair.unwrapped?.controllerAddr else { return nil }
    guard let controllerOpaque = UnsafeRawPointer(bitPattern: controllerAddr) else { return nil }
    return Unmanaged<SessionCtl>.fromOpaque(controllerOpaque).takeUnretainedValue()
  }

  private var core: InputSession? {
    controller?.core
  }
}

extension IMEMenuSputnik {
  public func build() -> NSMenu {
    // -------------
    var counter = 0
    func register(_ block: @escaping () -> ()) -> Selector {
      let name = "IMEMenuAction_\(counter):"
      counter += 1
      let sel = NSSelectorFromString(name)
      let impBlock: @convention(block) (AnyObject, Selector, Any?) -> () = { _, _, _ in block() }
      let imp = imp_implementationWithBlock(impBlock)
      if class_addMethod(SessionCtl.self, sel, imp, "v@:@") {
        return sel
      }
      method_setImplementation(class_getInstanceMethod(SessionCtl.self, sel)!, imp)
      return sel
    }
    // -------------
    let currentInputMode = IMEApp.currentInputMode
    return NSMenu().appendItems {
      if #unavailable(macOS 14) {
        NSMenu.Item("i18n:Menu.vChewingSettings")?
          .act(
            register {
              CtlSettingsCocoa.show()
              NSApp.popup()
            }
          )
          .nulled(silentMode)
      } else {
        NSMenu.Item(verbatim: "i18n:Menu.vChewingSettings".i18n + " (SwiftUI)")?
          .act(
            register {
              CtlSettingsUI.show()
              NSApp.popup()
            }
          )
          .nulled(silentMode)
        NSMenu.Item(verbatim: "i18n:Menu.vChewingSettings".i18n + " (AppKit)")?
          .act(
            register {
              CtlSettingsCocoa.show()
              NSApp.popup()
            }
          )
          .alternated().nulled(silentMode)
      }
      NSMenu.Item(verbatim: currentRAMUsageDescription)
      NSMenu.Item("i18n:Menu.SponsorTheDevelopment")?
        .act(
          register {
            guard let url = URL(string: "https://vchewing.github.io/SPONSOR_ME.html") else {
              return
            }
            NSWorkspace.shared.open(url)
          }
        )
      NSMenu.Item.separator() // ---------------------
      NSMenu.Item(
        verbatim: String(
          format: "i18n:InputMode.SwitchToInputMode:%@".i18n,
          currentInputMode.reversed.localizedDescription
        )
      )?.act(
        register {
          self.core?.toggleInputMode()
        }
      )
      .hotkey(PrefMgr.shared.usingHotKeyInputMode ? "D" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeySCPC.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:UserDef.kUsingHotKeySCPC.shortTitle".i18n
                  + "\n"
                  + (
                    PrefMgr.shared.useSCPCTypingMode.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.useSCPCTypingMode)
        .hotkey(PrefMgr.shared.usingHotKeySCPC ? "P" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeyAssociates.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:UserDef.kUsingHotKeyAssociates.shortTitle".i18n
                  + "\n"
                  + (
                    PrefMgr.shared.associatedPhrasesEnabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.associatedPhrasesEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyAssociates ? "O" : "", mask: [.command, .control])
      NSMenu.Item("i18n:Menu.EditAssociatedPhrases")?
        .act(
          register {
            LMMgr.openUserDictFile(
              type: .theAssociates,
              dual: self.optionKeyPressed,
              alt: self.optionKeyPressed
            )
          }
        )
        .alternated()
        .hotkey(
          PrefMgr.shared.usingHotKeyAssociates ? "O" : "",
          mask: [.command, .option, .control]
        )
        .nulled(silentMode)
      NSMenu.Item("i18n:UserDef.kUsingHotKeyRevLookup.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            if !PrefMgr.shared.cassetteEnabled, LMMgr.cassettePath().isEmpty {
              let strErrorTitle = "i18n:LMMgr.accessFailure.cassette.title".i18n
              let strErrorMsg = LMMgr.cassetteAccessFailureDescription(
                path: PrefMgr.shared.cassettePath
              )
              if UserDefaults.pendingUnitTests {
                vCLog("\(strErrorTitle) || \(strErrorMsg)")
              } else {
                asyncOnMain {
                  IMEApp.buzz()
                  let alert = NSAlert(error: strErrorTitle)
                  alert.informativeText = strErrorMsg
                  let result = alert.runModal()
                  NSApp.popup()
                  if result == .alertFirstButtonReturn {
                    LMMgr.resetCassettePath()
                    PrefMgr.shared.cassetteEnabled = false
                  }
                }
              }
              return
            }
            Notifier
              .notify(
                message: "i18n:UserDef.kUsingHotKeyRevLookup.shortTitle".i18n
                  + "\n"
                  + (
                    PrefMgr.shared.cassetteEnabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
            if let loaded = self.core?.inputMode.langModel.isCassetteDataLoaded, !loaded {
              LMMgr.loadCassetteData()
            }
          }
        )
        .state(PrefMgr.shared.cassetteEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyCassette ? "I" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeyCNS.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:UserDef.kUsingHotKeyCNS.shortTitle".i18n + "\n"
                  + (
                    PrefMgr.shared.cns11643Enabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.cns11643Enabled)
        .hotkey(PrefMgr.shared.usingHotKeyCNS ? "L" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeyKangXi.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:UserDef.kUsingHotKeyKangXi.shortTitle".i18n
                  + "\n"
                  + (
                    PrefMgr.shared.chineseConversionEnabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.chineseConversionEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyKangXi ? "K" : "", mask: [.command, .control])
        .nulled(currentInputMode != .imeModeCHT)
      NSMenu.Item("i18n:UserDef.kUsingHotKeyHalfWidthASCII.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:UserDef.kUsingHotKeyHalfWidthASCII.shortTitle".i18n
                  + "\n"
                  + (
                    PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.shiftJISShinjitaiOutputEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyJIS ? "J" : "", mask: [.command, .control])
        .nulled(currentInputMode != .imeModeCHT)
      NSMenu.Item("i18n:UserDef.kUsingHotKeyCassette.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:UserDef.kUsingHotKeyCassette.shortTitle".i18n
                  + "\n"
                  + (
                    PrefMgr.shared.currencyNumeralsEnabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.currencyNumeralsEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyCurrencyNumerals ? "M" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kUsingHotKeyCurrencyNumerals.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:UserDef.kUsingHotKeyCurrencyNumerals.shortTitle".i18n + "\n"
                  + (
                    PrefMgr.shared.halfWidthPunctuationEnabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.halfWidthPunctuationEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyHalfWidthASCII ? "H" : "", mask: [.command, .control])
      NSMenu.Item("i18n:UserDef.kPhraseReplacementEnabled.shortTitle")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:UserDef.kPhraseReplacementEnabled.shortTitle".i18n
                  + "\n"
                  + (
                    PrefMgr.shared.phraseReplacementEnabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.phraseReplacementEnabled)
      NSMenu.Item("i18n:Menu.EditPhraseReplacementTable")?
        .act(
          register {
            LMMgr.openUserDictFile(
              type: .theReplacements,
              dual: self.optionKeyPressed,
              alt: self.optionKeyPressed
            )
          }
        )
        .alternated().nulled(silentMode)
      NSMenu.Item("i18n:Menu.SymbolEmojiInput")?
        .act(
          register {
            self.core?.resetInputHandler(forceComposerCleanup: true)
            Notifier
              .notify(
                message: "i18n:Menu.SymbolEmojiInput".i18n
                  + "\n"
                  + (
                    PrefMgr.shared.symbolInputEnabled.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
          }
        )
        .state(PrefMgr.shared.symbolInputEnabled)
      NSMenu.Item("i18n:Menu.EditUserSymbolEmojiData")?
        .act(
          register {
            LMMgr.openUserDictFile(
              type: .theSymbols,
              dual: self.optionKeyPressed,
              alt: self.optionKeyPressed
            )
          }
        )
        .alternated().nulled(silentMode)

      NSMenu.Item.separator() // ---------------------
      NSMenu.Item("i18n:Menu.OpenUserDictionaryFolder")?
        .act(
          register {
            guard LMMgr.userDataFolderExists else { return }
            FileOpenMethod.finder.open(
              url: URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
            )
          }
        )
        .nulled(silentMode)
      NSMenu.Item("i18n:Menu.OpenAppSupportFolder")?
        .act(register { FileOpenMethod.finder.open(url: LMMgr.appSupportURL) })
        .alternated().nulled(silentMode)
      NSMenu.Item("i18n:Menu.EditVChewingUserPhrases")?
        .act(
          register {
            LMMgr.openUserDictFile(
              type: .thePhrases,
              dual: self.optionKeyPressed,
              alt: self.optionKeyPressed
            )
          }
        )
        .nulled(silentMode)
      NSMenu.Item("i18n:Menu.ReloadUserPhrases")?
        .act(register { LMMgr.initUserLangModels() })
      NSMenu.Item("i18n:Menu.EditExcludedPhrases")?
        .act(
          register {
            LMMgr.openUserDictFile(
              type: .theFilter,
              dual: self.optionKeyPressed,
              alt: self.optionKeyPressed
            )
          }
        )
        .alternated().nulled(silentMode)
      NSMenu.Item(verbatim: "i18n:UserDef.kUsingHotKeyJIS.shortTitle".i18n.withEllipsis)?
        .act(register { CtlRevLookupWindow.show() })
        .hotkey(PrefMgr.shared.usingHotKeyRevLookup ? "/" : "", mask: [.command, .control])
      NSMenu.Item("i18n:Menu.OptimizeMemorizedPhrases")?
        .act(
          register {
            LMMgr.removeUnigramsFromPerceptionOverrideModel(IMEApp.currentInputMode)
            LMMgr.removeUnigramsFromPerceptionOverrideModel(IMEApp.currentInputMode.reversed)
          }
        )
      NSMenu.Item("i18n:Menu.ClearMemorizedPhrases")?
        .act(
          register {
            LMMgr.clearPerceptionOverrideModelData(IMEApp.currentInputMode)
            LMMgr.clearPerceptionOverrideModelData(IMEApp.currentInputMode.reversed)
          }
        )
        .alternated()

      NSMenu.Item.separator() // ---------------------
      NSMenu.Item("i18n:Menu.CheckForUpdates")?
        .act(
          register {
            let bundleID = self.core?.clientBundleIdentifier
            AppDelegate.shared.checkUpdate(forced: true) { bundleID == "com.apple.SecurityAgent" }
          }
        )
        .nulled(silentMode)
      NSMenu.Item("i18n:Menu.RebootVChewing")?
        .act(
          register {
            NSApp.popup()
            NSApp.terminate(nil)
          }
        )
      NSMenu.Item("i18n:Menu.CheatSheet")?
        .act(
          register {
            guard let url = Bundle.main.url(forResource: "shortcuts", withExtension: "html") else {
              return
            }
            FileOpenMethod.safari.open(url: url)
          }
        )
        .nulled(silentMode)
      NSMenu.Item("i18n:Menu.UninstallVChewing")?
        .act(register { AppDelegate.shared.selfUninstall() })
        .nulled(silentMode || !optionKeyPressed)
    }
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
    let ramMsg = "i18n:IME.RAMUsedLabelHeader".i18n + " \(currentMemorySize)MB"
    let count4Controllers =
      "i18n:IME.RAMControllerCountLabel".i18n
        + " \(ObjCMemoryLeakTracker.shared.trackedCountByType["SessionCtl"] ?? 0)"
    return [ramMsg, count4Controllers].joined(separator: "; ")
  }
}
