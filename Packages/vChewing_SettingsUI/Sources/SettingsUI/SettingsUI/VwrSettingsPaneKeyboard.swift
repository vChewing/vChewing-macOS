// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬，legacy 倉庫（＝本倉的「子集 ＋ Swift 5.10 Dialect」，砍掉了 SwiftUI）無對位模組可繼承；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

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
            Text("i18n:Settings.SectionQuickSetup".i18n)
            Spacer()
            Button {
              PrefMgr.shared.keyboardParser = 0
              basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
            } label: {
              Text("↻ㄅ" + " " + "i18n:KeyboardLayout.DachenTraditional".i18n)
            }
            Button {
              PrefMgr.shared.keyboardParser = 1
              basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
            } label: {
              Text("↻ㄅ" + " " + "i18n:KeyboardLayout.EtenTraditionalShort".i18n)
            }
            Button {
              PrefMgr.shared.keyboardParser = 100
              basicKeyboardLayout = "com.apple.keylayout.ABC"
            } label: {
              Text("↻Ａ")
            }
          }
          UserDef.kKeyboardParser4Zhuyin.renderUI()
          UserDef.kKeyboardParser4Pinyin.renderUI()
          UserDef.kBasicKeyboardLayout.renderUI()
          UserDef.kAlphanumericalKeyboardLayout.renderUI()
        }
        Section(header: Text("i18n:Settings.SectionKeyboardShortcuts".i18n)) {
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
          UserDef.kUsingHotKeyKanjiConversionMode.renderUI()
          UserDef.kUsingHotKeyRevLookup.renderUI()
        }
        Divider()
        VStack(alignment: .leading) {
          UserDef.kUsingHotKeyPinyinZhuyinTypingSwitch.renderUI()
          UserDef.kUsingHotKeyHalfWidthPunctuation.renderUI()
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

#endif
