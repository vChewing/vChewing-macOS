// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension SettingsPanesCocoa {
  public class General: NSViewController {
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

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }
    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth, withDividers: false) {
          var strNotice = "\u{2022} "
          strNotice +=
            "Please use mouse wheel to scroll each page if needed. The CheatSheet is available in the IME menu."
            .localized
          strNotice += "\n\u{2022} "
          strNotice +=
            "Note: The “Delete ⌫” key on Mac keyboard is named as “BackSpace ⌫” here in order to distinguish the real “Delete ⌦” key from full-sized desktop keyboards. If you want to use the real “Delete ⌦” key on a Mac keyboard with no numpad equipped, you have to press “Fn+⌫” instead."
            .localized
          strNotice.makeNSLabel(descriptive: true, fixWidth: contentWidth)
          UserDef.kAppleLanguages.render(fixWidth: contentWidth) { renderable in
            renderable.currentControl = self.btnLangSelector
          }
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kReadingNarrationCoverage.render(fixWidth: contentWidth) { renderable in
            renderable.currentControl?.target = self
            renderable.currentControl?.action = #selector(self.updateNarratorSettingsAction(_:))
          }
          UserDef.kAutoCorrectReadingCombination.render(fixWidth: contentWidth)
          UserDef.kShowHanyuPinyinInCompositionBuffer.render(fixWidth: contentWidth)
          UserDef.kKeepReadingUponCompositionError.render(fixWidth: contentWidth)
          UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.render(fixWidth: contentWidth)
          UserDef.kUseSCPCTypingMode.render(fixWidth: contentWidth)
        }?.boxed()
        NSStackView.buildSection(.horizontal, width: contentWidth) {
          UserDef.kCheckUpdateAutomatically.render(fixWidth: contentHalfWidth)
          UserDef.kIsDebugModeEnabled.render(fixWidth: contentHalfWidth)
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
          NSMenuItem(language.localized)?.represent(language)
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
