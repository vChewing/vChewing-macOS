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
    NavigationStack {
      Form {
        Section {
          HStack(alignment: .top) {
            Text("Quick Setup:")
            Spacer()
            Button {
              keyboardParser = 0
              basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
            } label: {
              Text("↻ㄅ" + " " + "i18n:KeyboardLayout.dachenTrad".localized)
            }
            Button {
              keyboardParser = 1
              basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
            } label: {
              Text("↻ㄅ" + " " + "i18n:KeyboardLayout.etenTrad".localized)
            }
            Button {
              keyboardParser = 100
              basicKeyboardLayout = "com.apple.keylayout.ABC"
            } label: {
              Text("↻Ａ")
            }
          }
          UserDef.kKeyboardParser.bind($keyboardParser).render()
          UserDef.kBasicKeyboardLayout.bind($basicKeyboardLayout).render()
          UserDef.kAlphanumericalKeyboardLayout.bind($alphanumericalKeyboardLayout).render()
        }
        Section(header: Text("Keyboard Shortcuts:")) {
          VwrSettingsPaneKeyboard_KeyboardShortcuts()
        }
      }.formStyled()
    }
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
    wrappedValue: PrefMgr.kDefaultBasicKeyboardLayout,
    UserDef.kBasicKeyboardLayout.rawValue
  )
  private var basicKeyboardLayout: String

  @AppStorage(
    wrappedValue: PrefMgr.kDefaultAlphanumericalKeyboardLayout,
    UserDef.kAlphanumericalKeyboardLayout.rawValue
  )
  private var alphanumericalKeyboardLayout: String
}

// MARK: - VwrSettingsPaneKeyboard_KeyboardShortcuts

@available(macOS 14, *)
private struct VwrSettingsPaneKeyboard_KeyboardShortcuts: View {
  // MARK: Internal

  // MARK: - Main View

  var body: some View {
    HStack(alignment: .top, spacing: NSFont.systemFontSize) {
      VStack(alignment: .leading) {
        UserDef.kUsingHotKeySCPC.bind($usingHotKeySCPC).render()
        UserDef.kUsingHotKeyAssociates.bind($usingHotKeyAssociates).render()
        UserDef.kUsingHotKeyCNS.bind($usingHotKeyCNS).render()
        UserDef.kUsingHotKeyKangXi.bind($usingHotKeyKangXi).render()
        UserDef.kUsingHotKeyRevLookup.bind($usingHotKeyRevLookup).render()
      }
      Divider()
      VStack(alignment: .leading) {
        UserDef.kUsingHotKeyJIS.bind($usingHotKeyJIS).render()
        UserDef.kUsingHotKeyHalfWidthASCII.bind($usingHotKeyHalfWidthASCII).render()
        UserDef.kUsingHotKeyCurrencyNumerals.bind($usingHotKeyCurrencyNumerals).render()
        UserDef.kUsingHotKeyCassette.bind($usingHotKeyCassette).render()
        UserDef.kUsingHotKeyInputMode.bind($usingHotKeyInputMode).render()
      }
    }
  }

  // MARK: Private

  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeySCPC.rawValue)
  private var usingHotKeySCPC: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyAssociates.rawValue)
  private var usingHotKeyAssociates: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCNS.rawValue)
  private var usingHotKeyCNS: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyKangXi.rawValue)
  private var usingHotKeyKangXi: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyJIS.rawValue)
  private var usingHotKeyJIS: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyHalfWidthASCII.rawValue)
  private var usingHotKeyHalfWidthASCII: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCurrencyNumerals.rawValue)
  private var usingHotKeyCurrencyNumerals: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCassette.rawValue)
  private var usingHotKeyCassette: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyRevLookup.rawValue)
  private var usingHotKeyRevLookup: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyInputMode.rawValue)
  private var usingHotKeyInputMode: Bool
}

// MARK: - VwrSettingsPaneKeyboard_Previews

@available(macOS 14, *)
struct VwrSettingsPaneKeyboard_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneKeyboard()
  }
}
