// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

@available(macOS 11.0, *)
struct suiPrefPaneKeyboard: View {
  @State private var selMandarinParser = UserDefaults.standard.integer(forKey: UserDef.kMandarinParser.rawValue)
  @State private var selBasicKeyboardLayout: String =
    UserDefaults.standard.string(forKey: UserDef.kBasicKeyboardLayout.rawValue) ?? mgrPrefs.basicKeyboardLayout

  @State private var selUsingHotKeySCPC = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeySCPC.rawValue)
  @State private var selUsingHotKeyAssociates = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyAssociates.rawValue)
  @State private var selUsingHotKeyCNS = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyCNS.rawValue)
  @State private var selUsingHotKeyKangXi = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyKangXi.rawValue)
  @State private var selUsingHotKeyJIS = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyJIS.rawValue)
  @State private var selUsingHotKeyHalfWidthASCII = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyHalfWidthASCII.rawValue)
  @State private var selUsingHotKeyCurrencyNumerals = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyCurrencyNumerals.rawValue)

  private let contentWidth: Double = {
    switch mgrPrefs.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if mgrPrefs.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 550
        }
    }
  }()

  var body: some View {
    Preferences.Container(contentWidth: contentWidth) {
      Preferences.Section(label: { Text(LocalizedStringKey("Phonetic Parser:")) }) {
        HStack {
          Picker("", selection: $selMandarinParser) {
            Group {
              Text(LocalizedStringKey("Dachen (Microsoft Standard / Wang / 01, etc.)")).tag(0)
              Text(LocalizedStringKey("Eten Traditional")).tag(1)
              Text(LocalizedStringKey("IBM")).tag(4)
              Text(LocalizedStringKey("MiTAC")).tag(5)
              Text(LocalizedStringKey("Seigyou")).tag(8)
              Text(LocalizedStringKey("Fake Seigyou")).tag(6)
            }
            Divider()
            Group {
              Text(LocalizedStringKey("Dachen 26 (libChewing)")).tag(7)
              Text(LocalizedStringKey("Eten 26")).tag(3)
              Text(LocalizedStringKey("Hsu")).tag(2)
              Text(LocalizedStringKey("Starlight")).tag(9)
            }
            Divider()
            Group {
              Text(LocalizedStringKey("Hanyu Pinyin with Numeral Intonation")).tag(10)
              Text(LocalizedStringKey("Secondary Pinyin with Numeral Intonation")).tag(11)
              Text(LocalizedStringKey("Yale Pinyin with Numeral Intonation")).tag(12)
              Text(LocalizedStringKey("Hualuo Pinyin with Numeral Intonation")).tag(13)
              Text(LocalizedStringKey("Universal Pinyin with Numeral Intonation")).tag(14)
            }
          }.onChange(of: selMandarinParser) { value in
            mgrPrefs.mandarinParser = value
            switch value {
              case 0:
                if !AppleKeyboardConverter.arrDynamicBasicKeyLayout.contains(mgrPrefs.basicKeyboardLayout) {
                  mgrPrefs.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
                  selBasicKeyboardLayout = mgrPrefs.basicKeyboardLayout
                }
              default:
                if AppleKeyboardConverter.arrDynamicBasicKeyLayout.contains(mgrPrefs.basicKeyboardLayout) {
                  mgrPrefs.basicKeyboardLayout = "com.apple.keylayout.ABC"
                  selBasicKeyboardLayout = mgrPrefs.basicKeyboardLayout
                }
            }
          }
          .labelsHidden()
          Button {
            mgrPrefs.mandarinParser = 0
            selMandarinParser = mgrPrefs.mandarinParser
            mgrPrefs.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
            selBasicKeyboardLayout = mgrPrefs.basicKeyboardLayout
          } label: {
            Text("↻ㄅ")
          }
          Button {
            mgrPrefs.mandarinParser = 10
            selMandarinParser = mgrPrefs.mandarinParser
            mgrPrefs.basicKeyboardLayout = "com.apple.keylayout.ABC"
            selBasicKeyboardLayout = mgrPrefs.basicKeyboardLayout
          } label: {
            Text("↻Ａ")
          }
        }
        .frame(width: 380.0)
        Text(LocalizedStringKey("Choose the phonetic layout for Mandarin parser."))
          .preferenceDescription()
      }
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Basic Keyboard Layout:")) }) {
        HStack {
          Picker("", selection: $selBasicKeyboardLayout) {
            ForEach(0...(IME.arrEnumerateSystemKeyboardLayouts.count - 1), id: \.self) { id in
              Text(IME.arrEnumerateSystemKeyboardLayouts[id].strName).tag(
                IME.arrEnumerateSystemKeyboardLayouts[id].strValue)
            }.id(UUID())
          }.onChange(of: selBasicKeyboardLayout) { value in
            mgrPrefs.basicKeyboardLayout = value
            if AppleKeyboardConverter.arrDynamicBasicKeyLayout.contains(value) {
              mgrPrefs.mandarinParser = 0
              selMandarinParser = mgrPrefs.mandarinParser
            }
          }
          .labelsHidden()
          .frame(width: 240.0)
        }
        Text(LocalizedStringKey("Choose the macOS-level basic keyboard layout."))
          .preferenceDescription()
      }
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Keyboard Shortcuts:")) }) {
        Toggle(
          LocalizedStringKey("Per-Char Select Mode"),
          isOn: $selUsingHotKeySCPC
        ).onChange(of: selUsingHotKeySCPC) { value in
          mgrPrefs.usingHotKeySCPC = value
          selUsingHotKeySCPC = value
        }
        Toggle(
          LocalizedStringKey("Per-Char Associated Phrases"),
          isOn: $selUsingHotKeyAssociates
        ).onChange(of: selUsingHotKeyAssociates) { value in
          mgrPrefs.usingHotKeyAssociates = value
          selUsingHotKeyAssociates = value
        }
        Toggle(
          LocalizedStringKey("CNS11643 Mode"),
          isOn: $selUsingHotKeyCNS
        ).onChange(of: selUsingHotKeyCNS) { value in
          mgrPrefs.usingHotKeyCNS = value
          selUsingHotKeyCNS = value
        }
        Toggle(
          LocalizedStringKey("Force KangXi Writing"),
          isOn: $selUsingHotKeyKangXi
        ).onChange(of: selUsingHotKeyKangXi) { value in
          mgrPrefs.usingHotKeyKangXi = value
          selUsingHotKeyKangXi = value
        }
        Toggle(
          LocalizedStringKey("JIS Shinjitai Output"),
          isOn: $selUsingHotKeyJIS
        ).onChange(of: selUsingHotKeyJIS) { value in
          mgrPrefs.usingHotKeyJIS = value
          selUsingHotKeyJIS = value
        }
        Toggle(
          LocalizedStringKey("Half-Width Punctuation Mode"),
          isOn: $selUsingHotKeyHalfWidthASCII
        ).onChange(of: selUsingHotKeyHalfWidthASCII) { value in
          mgrPrefs.usingHotKeyHalfWidthASCII = value
          selUsingHotKeyHalfWidthASCII = value
        }
        Toggle(
          LocalizedStringKey("Currency Numeral Output"),
          isOn: $selUsingHotKeyCurrencyNumerals
        ).onChange(of: selUsingHotKeyCurrencyNumerals) { value in
          mgrPrefs.usingHotKeyCurrencyNumerals = value
          selUsingHotKeyCurrencyNumerals = value
        }
      }
    }
    Divider()
    Preferences.Container(contentWidth: contentWidth) {
      Preferences.Section(title: "") {
        VStack(alignment: .leading, spacing: 10) {
          Text(
            LocalizedStringKey(
              "Non-QWERTY alphanumeral keyboard layouts are for Hanyu Pinyin parser only."
            )
          )
          .preferenceDescription()
          Text(
            LocalizedStringKey(
              "Apple Dynamic Bopomofo Basic Keyboard Layouts (Dachen & Eten Traditional) must match the Dachen parser in order to be functional."
            )
          )
          .preferenceDescription()
        }
      }
    }
  }
}

@available(macOS 11.0, *)
struct suiPrefPaneKeyboard_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneKeyboard()
  }
}
