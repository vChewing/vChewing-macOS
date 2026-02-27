// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - VwrSettingsPaneKeyboard

@available(macOS 14, *)
public struct VwrSettingsPaneKeyboard: View {
  // MARK: Public

  // MARK: - Main View

  public var body: some View {
    Form {
      Section {
        HStack(alignment: .top) {
          Text("Quick Setup:")
          Spacer()
          Button {
            keyboardParser = 0
            basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
          } label: {
            Text("↻ㄅ" + " " + "Dachen Trad.".i18n)
          }
          Button {
            keyboardParser = 1
            basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
          } label: {
            Text("↻ㄅ" + " " + "Eten Trad.".i18n)
          }
          Button {
            keyboardParser = 100
            basicKeyboardLayout = "com.apple.keylayout.ABC"
          } label: {
            Text("↻Ａ")
          }
        }
        UserDef.kKeyboardParser.renderUI()
        UserDef.kBasicKeyboardLayout.renderUI()
        UserDef.kAlphanumericalKeyboardLayout.renderUI()
      }
      Section(header: Text("Keyboard Shortcuts:")) {
        VwrSettingsPaneKeyboard_KeyboardShortcuts()
      }
    }.formStyled()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
  }

  // MARK: Private

  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: 0, UserDef.kKeyboardParser.rawValue)
  private var keyboardParser: Int

  @AppStorage(
    wrappedValue: UserDef.kBasicKeyboardLayout.stringDefaultValue,
    UserDef.kBasicKeyboardLayout.rawValue
  )
  private var basicKeyboardLayout: String
}

// MARK: - VwrSettingsPaneKeyboard_KeyboardShortcuts

@available(macOS 14, *)
private struct VwrSettingsPaneKeyboard_KeyboardShortcuts: View {
  // MARK: - Main View

  var body: some View {
    HStack(alignment: .top, spacing: NSFont.systemFontSize) {
      VStack(alignment: .leading) {
        UserDef.kUsingHotKeySCPC.renderUI()
        UserDef.kUsingHotKeyAssociates.renderUI()
        UserDef.kUsingHotKeyCNS.renderUI()
        UserDef.kUsingHotKeyKangXi.renderUI()
        UserDef.kUsingHotKeyRevLookup.renderUI()
      }
      Divider()
      VStack(alignment: .leading) {
        UserDef.kUsingHotKeyJIS.renderUI()
        UserDef.kUsingHotKeyHalfWidthASCII.renderUI()
        UserDef.kUsingHotKeyCurrencyNumerals.renderUI()
        UserDef.kUsingHotKeyCassette.renderUI()
        UserDef.kUsingHotKeyInputMode.renderUI()
      }
    }
  }
}

// MARK: - VwrSettingsPaneKeyboard_Previews

@available(macOS 14, *)
struct VwrSettingsPaneKeyboard_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneKeyboard()
  }
}
