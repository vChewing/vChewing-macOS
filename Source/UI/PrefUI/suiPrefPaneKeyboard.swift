// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI

@available(macOS 11.0, *)
struct suiPrefPaneKeyboard: View {
  @State private var selMandarinParser = UserDefaults.standard.integer(forKey: UserDef.kMandarinParser)
  @State private var selBasicKeyboardLayout: String =
    UserDefaults.standard.string(forKey: UserDef.kBasicKeyboardLayout) ?? mgrPrefs.basicKeyboardLayout

  @State private var selUsingHotKeySCPC = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeySCPC)
  @State private var selUsingHotKeyAssociates = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyAssociates)
  @State private var selUsingHotKeyCNS = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyCNS)
  @State private var selUsingHotKeyKangXi = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyKangXi)
  @State private var selUsingHotKeyJIS = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyJIS)
  @State private var selUsingHotKeyHalfWidthASCII = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyHalfWidthASCII)
  @State private var selUsingHotKeyCurrencyNumerals = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyCurrencyNumerals)

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
              Text(LocalizedStringKey("Dachen 26 (libChewing)")).tag(7)
              Text(LocalizedStringKey("Eten Traditional")).tag(1)
              Text(LocalizedStringKey("Eten 26")).tag(3)
              Text(LocalizedStringKey("IBM")).tag(4)
              Text(LocalizedStringKey("Hsu")).tag(2)
              Text(LocalizedStringKey("MiTAC")).tag(5)
              Text(LocalizedStringKey("Fake Seigyou")).tag(6)
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
