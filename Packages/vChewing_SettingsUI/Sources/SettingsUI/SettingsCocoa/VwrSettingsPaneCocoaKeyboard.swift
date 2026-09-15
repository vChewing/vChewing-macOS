// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

// MARK: - SettingsPanesCocoa.Keyboard

extension SettingsPanesCocoa {
  public final class Keyboard: NSViewController {
    // MARK: Public

    override public func loadView() {
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    }

    // MARK: Internal

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }

    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth) {
          NSStackView.build(.horizontal) {
            "i18n:Settings.SectionQuickSetup".i18n.makeNSLabel(fixWidth: contentWidth)
            NSView()
            NSButton(
              verbatim: "↻ㄅ" + " " + "i18n:KeyboardLayout.DachenTraditional".i18n,
              target: self,
              action: #selector(quickSetupButtonDachen(_:))
            )
            NSButton(
              verbatim: "↻ㄅ" + " " + "i18n:KeyboardLayout.EtenTraditionalShort".i18n,
              target: self,
              action: #selector(quickSetupButtonEtenTraditional(_:))
            )
            NSButton(
              verbatim: "↻Ａ", target: self,
              action: #selector(quickSetupButtonHanyuPinyin(_:))
            )
          }
          UserDef.kKeyboardParser4Zhuyin.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
          UserDef.kKeyboardParser4Pinyin.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
          UserDef.kBasicKeyboardLayout.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
          UserDef.kAlphanumericalKeyboardLayout.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
        }?.boxed()
        NSStackView.build(.horizontal, insets: .new(all: 4, left: 16, right: 16)) {
          "i18n:Settings.SectionKeyboardShortcuts".i18n.makeNSLabel(fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(.horizontal, width: contentWidth) {
          NSStackView.build(.vertical) {
            UserDef.kUsingHotKeySCPC.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyAssociates.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyCNS.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyKanjiConversionMode.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyRevLookup.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
          }
          NSStackView.build(.vertical) {
            UserDef.kUsingHotKeyPinyinZhuyinTypingSwitch.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyHalfWidthPunctuation.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyCurrencyNumerals.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyCassette.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyInputMode.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
          }
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction
    func quickSetupButtonDachen(_: NSControl) {
      PrefMgr.shared.keyboardParser = 0
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
    }

    @IBAction
    func quickSetupButtonEtenTraditional(_: NSControl) {
      PrefMgr.shared.keyboardParser = 1
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
    }

    @IBAction
    func quickSetupButtonHanyuPinyin(_: NSControl) {
      PrefMgr.shared.keyboardParser = 100
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ABC"
    }
  }
}

// `#Preview` 是 SwiftUI 的巨集，展開需要 6.2 以上的巨集外掛（`@available` 擋不住展開）；
// 5.10 側編不到它，故整段圈進 compiler condition。
#if compiler(>=6.2)
  @available(macOS 14.0, *)
  #Preview(traits: .fixedLayout(width: 600, height: 768)) {
    SettingsPanesCocoa.Keyboard()
  }
#endif
