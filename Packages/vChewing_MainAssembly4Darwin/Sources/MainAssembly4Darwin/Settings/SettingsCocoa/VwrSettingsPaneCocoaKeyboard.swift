// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

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
          UserDef.kKeyboardParser.renderCocoa(
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
            UserDef.kUsingHotKeyKangXi.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyRevLookup.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
          }
          NSStackView.build(.vertical) {
            UserDef.kUsingHotKeyJIS.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyHalfWidthASCII.renderCocoa(
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

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Keyboard()
}
