// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

// MARK: - SettingsPanesCocoa.General

extension SettingsPanesCocoa {
  public final class General: NSViewController {
    // MARK: Public

    override public func loadView() {
      prepareLangSelectorButton()
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    }

    // MARK: Internal

    var currentLanguageSelectItem: NSMenuItem?
    let btnLangSelector = NSPopUpButton()
    let languages = ["auto", "en", "zh-Hans", "zh-Hant", "ja"]
    let languageDisplayMap: [String: String] = [
      "auto": "i18n:Settings.OptionAuto",
      "en": "i18n:LanguageName.LocaleCodeEN",
      "zh-Hans": "i18n:LanguageName.LocaleCodeZHHans",
      "zh-Hant": "i18n:LanguageName.LocaleCodeZHHant",
      "ja": "i18n:LanguageName.LocaleCodeJA",
    ]

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }
    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth, withDividers: false) {
          var strNotice = "\u{2022} "
          strNotice += "i18n:InfoMessage.MouseWheelScrollWithCheatSheet".i18n
          strNotice += "\n\u{2022} "
          strNotice += "i18n:InfoMessage.DeleteKeyNote".i18n
          strNotice.makeNSLabel(descriptive: true, fixWidth: contentWidth)
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kAppleLanguages.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabGeneral
          ) { renderable in
            renderable.currentControl = self.btnLangSelector
          }
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kReadingNarrationCoverage.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabGeneral
          ) { renderable in
            renderable.currentControl?.target = self
            renderable.currentControl?.action = #selector(self.updateNarratorSettingsAction(_:))
          }
          // 「敲字時自動糾正讀音組合」「允許對無效的讀音使用 BackSpace 編輯」「拼音並擊」
          // 「模擬 90 年代前期注音逐字選字輸入風格」「亦使用「\」或「¥」鍵啟用漢音鍵盤符號模式」
          // 此五項已遷往「行為設定」（Phase 248）。
          if Date.isTodayTheDate(from: 0_401) {
            UserDef.kShouldNotFartInLieuOfBeep
              .renderCocoa(
                fixWidth: contentWidth,
                prefUITab: .tabGeneral
              ) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.onFartControlChange(_:))
              }
          }
        }?.boxed()
        NSStackView.buildSection(.horizontal, width: contentWidth) {
          UserDef.kCheckUpdateAutomatically.renderCocoa(
            fixWidth: contentHalfWidth,
            prefUITab: .tabGeneral
          )
          UserDef.kIsDebugModeEnabled.renderCocoa(
            fixWidth: contentHalfWidth,
            prefUITab: .tabGeneral
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          NSStackView.build(.horizontal) {
            NSButton(
              "i18n:Settings.ApplySCPCPreset.ButtonTitle".i18n,
              target: self,
              action: #selector(applySCPCPreset(_:))
            )
            NSView()
          }
          NSStackView.build(.horizontal) {
            NSButton(
              "i18n:Settings.OpenConfigAssistant.ButtonTitle".i18n,
              target: self,
              action: #selector(beginOpenConfigAssistant(_:))
            )
            NSView()
          }
          NSStackView.build(.horizontal) {
            NSButton(
              "i18n:Settings.ImportConfigFromClipboard.ButtonTitle".i18n,
              target: self,
              action: #selector(beginClipboardImport(_:))
            )
            NSView()
          }
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    // Credit: Hiraku (in ObjC; 2022); Refactored by Shiki (2024).
    func prepareLangSelectorButton() {
      let chosenLangObj = PrefMgr.shared.appleLanguages.first ?? "auto"
      btnLangSelector.menu?.removeAllItems()
      // 嚴重警告：NSMenu.items 在 macOS 10.13 為止的系統下是唯讀的！！
      // 往這個 property 裡面直接寫東西會導致整個視窗叫不出來！！！
      btnLangSelector.menu?.appendItems {
        for language in languages {
          NSMenuItem(languageDisplayMap[language, default: language].i18n)?.represent(language)
        }
      }
      currentLanguageSelectItem = btnLangSelector.menu?.items.first {
        $0.representedObject as? String == chosenLangObj
      } ?? btnLangSelector.menu?.items.first
      btnLangSelector.select(currentLanguageSelectItem)
      btnLangSelector.action = #selector(updateUiLanguageAction(_:))
      btnLangSelector.target = self
      btnLangSelector.font = NSFont.systemFont(ofSize: 12)
    }

    @IBAction
    func applySCPCPreset(_ sender: NSButton) {
      asyncOnMain {
        let window = CtlSettingsCocoa.shared?.window
        let alert = NSAlert()
        alert.messageText = "i18n:Settings.ApplySCPCPreset.Confirm.AlertTitle".i18n
        alert.informativeText = "i18n:Settings.ApplySCPCPreset.Confirm.AlertMessage".i18n
        alert.addButton(withTitle: "i18n:Common.Yes".i18n)
        alert.addButton(withTitle: "i18n:Common.No".i18n)
        alert.beginSheetModal(at: window) { response in
          if response == .alertFirstButtonReturn {
            PrefMgr.shared.useSpaceToCommitHighlightedCandidate4SCPC = false
            PrefMgr.shared.candidateKeys = "123456789"
            PrefMgr.shared.useHorizontalCandidateList = false
            PrefMgr.shared.enforceSingleLineCandidateWindowLayout4SCPC = true
            if PrefMgr.shared.pinyinTypingEnabled {
              PrefMgr.shared.pinyinTypingEnabled = false
            }
            if !PrefMgr.shared.useSCPCTypingMode {
              SettingsUIHost.shared.notify(
                "i18n:UserDef.kUsingHotKeySCPC.shortTitle".i18n + "\n"
                  + (
                    PrefMgr.shared.useSCPCTypingMode.toggled()
                      ? "i18n:NotificationSwitch.On".i18n
                      : "i18n:NotificationSwitch.Off".i18n
                  )
              )
            }
            // 錯開兩條通知，防止兩條通知重疊到一起。
            asyncOnMain {
              if !PrefMgr.shared.associatedPhrasesEnabled {
                SettingsUIHost.shared.notify(
                  "i18n:UserDef.kUsingHotKeyAssociates.shortTitle".i18n + "\n"
                    + (
                      PrefMgr.shared.associatedPhrasesEnabled.toggled()
                        ? "i18n:NotificationSwitch.On".i18n
                        : "i18n:NotificationSwitch.Off".i18n
                    )
                )
              }
            }
            window.callAlert(
              title: "i18n:Settings.ApplySCPCPreset.Succeeded.AlertTitle".i18n,
              text: "i18n:Settings.ApplySCPCPreset.Succeeded.AlertMessage".i18n
            )
          }
        }
      }
    }

    /// 兩態分派：當前輸入法之 main bundle 內是否同捆 `assistant.html`（見 `AssistantLauncher`）。
    /// 判準於按下之當下求值，不得於面板載入時快取。
    @IBAction
    func beginOpenConfigAssistant(_ sender: NSButton) {
      asyncOnMain {
        let window = CtlSettingsCocoa.shared?.window
        let alert = NSAlert()
        if AssistantLauncher.hasBundledAssistant {
          alert.messageText = "i18n:Settings.OpenConfigAssistant.Choose.AlertTitle".i18n
          alert.informativeText = "i18n:Settings.OpenConfigAssistant.Choose.AlertMessage".i18n
          alert.addButton(withTitle: "i18n:Settings.OpenConfigAssistant.Choose.ButtonBundled".i18n)
          alert.addButton(withTitle: "i18n:Settings.OpenConfigAssistant.Choose.ButtonOnline".i18n)
          alert.beginSheetModal(at: window) { response in
            switch response {
            case .alertFirstButtonReturn: AssistantLauncher.openBundled()
            case .alertSecondButtonReturn: AssistantLauncher.openOnline()
            default: break
            }
          }
        } else {
          alert.messageText = "i18n:Settings.OpenConfigAssistant.Unbundled.AlertTitle".i18n
          alert.informativeText = "i18n:Settings.OpenConfigAssistant.Unbundled.AlertMessage".i18n
          alert.addButton(withTitle: "i18n:Settings.OpenConfigAssistant.Unbundled.ButtonOnline".i18n)
          alert.beginSheetModal(at: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            AssistantLauncher.openOnline()
          }
        }
      }
    }

    @IBAction
    func beginClipboardImport(_ sender: NSButton) {
      asyncOnMain {
        let window = CtlSettingsCocoa.shared?.window
        let preparation = PrefsExchange.prepare(
          fromClipboardString: NSPasteboard.general.string(forType: .string)
        )
        let alert = NSAlert()
        alert.messageText = preparation.alertTitle
        alert.informativeText = preparation.alertMessage
        switch preparation {
        case let .confirmApplying(_, payload, _, _):
          alert.addButton(withTitle: "i18n:Settings.ImportConfigFromClipboard.Confirm.ButtonApply".i18n)
          alert.addButton(withTitle: "i18n:Common.Cancel".i18n)
          alert.beginSheetModal(at: window) { response in
            // 取消即完全不寫入：載荷之套用一概留待「套用」鈕。
            guard response == .alertFirstButtonReturn else { return }
            PrefsExchange.applyPayload(payload)
            window.callAlert(
              title: "i18n:Settings.ImportConfigFromClipboard.Succeeded.AlertTitle".i18n,
              text: "i18n:Settings.ImportConfigFromClipboard.Succeeded.AlertMessage".i18n
            )
          }
        default:
          alert.addButton(withTitle: "i18n:Common.OK".i18n)
          alert.beginSheetModal(at: window)
        }
      }
    }

    @IBAction
    func updateNarratorSettingsAction(_: NSControl) {
      SpeechSputnik.shared.refreshStatus()
    }

    @IBAction
    func updateUiLanguageAction(_ sender: NSPopUpButton) {
      let language = languages[sender.indexOfSelectedItem]
      guard let bundleID = Bundle.main.bundleIdentifier, bundleID.contains("vChewing") else {
        print("App Language Changed to \(language).")
        return
      }
      if let selectItem = btnLangSelector.selectedItem, currentLanguageSelectItem == selectItem {
        return
      }
      if language != "auto" {
        PrefMgr.shared.appleLanguages = [language]
      } else {
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
      }
      vCLog(forced: true, "vChewing App self-terminated due to UI language change.")
      NSApp.terminate(nil)
    }

    @IBAction
    func onFartControlChange(_: NSControl) {
      let content = "i18n:UserDef.kShouldNotFartInLieuOfBeep.description".i18n
      let alert = NSAlert(error: "i18n:Common.Warning".i18n)
      alert.informativeText = content
      alert.addButton(withTitle: "i18n:Common.Uncheck".i18n)
      if #available(macOS 11, *) {
        alert.buttons.forEach { button in
          button.hasDestructiveAction = true
        }
      }
      alert.addButton(withTitle: "i18n:Common.LeaveItChecked".i18n)
      let window = CtlSettingsCocoa.shared?.window
      if !PrefMgr.shared.shouldNotFartInLieuOfBeep {
        PrefMgr.shared.shouldNotFartInLieuOfBeep = true
        alert.beginSheetModal(at: window) { result in
          switch result {
          case .alertFirstButtonReturn:
            PrefMgr.shared.shouldNotFartInLieuOfBeep = false
          case .alertSecondButtonReturn:
            PrefMgr.shared.shouldNotFartInLieuOfBeep = true
          default: break
          }
          IMEApp.buzz()
        }
        return
      }
      IMEApp.buzz()
    }
  }
}

// `#Preview` 是 SwiftUI 的巨集，展開需要 6.2 以上的巨集外掛（`@available` 擋不住展開）；
// 5.10 側編不到它，故整段圈進 compiler condition。
#if compiler(>=6.2)
  @available(macOS 14.0, *)
  #Preview(traits: .fixedLayout(width: 600, height: 768)) {
    SettingsPanesCocoa.General()
  }
#endif
