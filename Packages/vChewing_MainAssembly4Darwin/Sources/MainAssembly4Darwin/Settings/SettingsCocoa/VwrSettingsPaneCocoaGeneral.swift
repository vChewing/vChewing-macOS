// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

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
          UserDef.kAppleLanguages.renderCocoa(fixWidth: contentWidth) { renderable in
            renderable.currentControl = self.btnLangSelector
          }
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kReadingNarrationCoverage.renderCocoa(fixWidth: contentWidth) { renderable in
            renderable.currentControl?.target = self
            renderable.currentControl?.action = #selector(self.updateNarratorSettingsAction(_:))
          }
          UserDef.kAutoCorrectReadingCombination.renderCocoa(fixWidth: contentWidth)
          UserDef.kShowHanyuPinyinInCompositionBuffer.renderCocoa(fixWidth: contentWidth)
          UserDef.kKeepReadingUponCompositionError.renderCocoa(fixWidth: contentWidth)
          UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.renderCocoa(fixWidth: contentWidth)
          UserDef.kUseSCPCTypingMode.renderCocoa(fixWidth: contentWidth)
        }?.boxed()
        NSStackView.buildSection(.horizontal, width: contentWidth) {
          UserDef.kCheckUpdateAutomatically.renderCocoa(fixWidth: contentHalfWidth)
          UserDef.kIsDebugModeEnabled.renderCocoa(fixWidth: contentHalfWidth)
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
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.General()
}
