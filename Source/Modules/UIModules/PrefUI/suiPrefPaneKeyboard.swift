// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

@available(macOS 10.15, *)
struct suiPrefPaneKeyboard: View {
  @State private var selSelectionKeysList = mgrPrefs.suggestedCandidateKeys
  @State private var selSelectionKeys =
    UserDefaults.standard.string(forKey: UserDef.kCandidateKeys.rawValue) ?? mgrPrefs.defaultCandidateKeys
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

  private let contentMaxHeight: Double = 432
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
    ScrollView {
      Preferences.Container(contentWidth: contentWidth) {
        Preferences.Section(label: { Text(LocalizedStringKey("Selection Keys:")) }) {
          ComboBox(
            items: mgrPrefs.suggestedCandidateKeys,
            text: $selSelectionKeys.onChange {
              let value = selSelectionKeys
              let keys: String = value.trimmingCharacters(in: .whitespacesAndNewlines).deduplicate
              do {
                try mgrPrefs.validate(candidateKeys: keys)
                mgrPrefs.candidateKeys = keys
                selSelectionKeys = mgrPrefs.candidateKeys
              } catch mgrPrefs.CandidateKeyError.empty {
                selSelectionKeys = mgrPrefs.candidateKeys
              } catch {
                if let window = ctlPrefUI.shared.controller.window {
                  let alert = NSAlert(error: error)
                  alert.beginSheetModal(for: window) { _ in
                    selSelectionKeys = mgrPrefs.candidateKeys
                  }
                  clsSFX.beep()
                }
              }
            }
          ).frame(width: 180).disabled(mgrPrefs.useIMKCandidateWindow)
          if mgrPrefs.useIMKCandidateWindow {
            Text(
              LocalizedStringKey(
                "⚠︎ This feature in IMK Candidate Window defects. Please consult Apple Developer Relations\nand tell them the related Radar ID: #FB11300759."
              )
            )
            .preferenceDescription()
          } else {
            Text(
              LocalizedStringKey(
                "Choose or hit Enter to confim your prefered keys for selecting candidates."
              )
            )
            .preferenceDescription()
          }
        }
        Preferences.Section(label: { Text(LocalizedStringKey("Phonetic Parser:")) }) {
          HStack {
            Picker(
              "",
              selection: $selMandarinParser.onChange {
                let value = selMandarinParser
                mgrPrefs.mandarinParser = value
                switch value {
                  case 0:
                    if !IMKHelper.arrDynamicBasicKeyLayouts.contains(mgrPrefs.basicKeyboardLayout) {
                      mgrPrefs.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
                      selBasicKeyboardLayout = mgrPrefs.basicKeyboardLayout
                    }
                  default:
                    if IMKHelper.arrDynamicBasicKeyLayouts.contains(mgrPrefs.basicKeyboardLayout) {
                      mgrPrefs.basicKeyboardLayout = "com.apple.keylayout.ABC"
                      selBasicKeyboardLayout = mgrPrefs.basicKeyboardLayout
                    }
                }
              }
            ) {
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
          HStack {
            Text(
              NSLocalizedString(
                "Choose the phonetic layout for Mandarin parser.",
                comment: ""
              ) + (mgrPrefs.appleLanguages[0].contains("en") ? " " : "")
                + NSLocalizedString(
                  "Apple Dynamic Bopomofo Basic Keyboard Layouts (Dachen & Eten Traditional) must match the Dachen parser in order to be functional.",
                  comment: ""
                )
            )
            .preferenceDescription().fixedSize(horizontal: false, vertical: true)
            Spacer().frame(width: 30)
          }
        }
        Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Basic Keyboard Layout:")) }) {
          HStack {
            Picker(
              "",
              selection: $selBasicKeyboardLayout.onChange {
                let value = selBasicKeyboardLayout
                mgrPrefs.basicKeyboardLayout = value
                if IMKHelper.arrDynamicBasicKeyLayouts.contains(value) {
                  mgrPrefs.mandarinParser = 0
                  selMandarinParser = mgrPrefs.mandarinParser
                }
              }
            ) {
              ForEach(0...(IMKHelper.allowedBasicLayoutsAsTISInputSources.count - 1), id: \.self) { id in
                let theEntry = IMKHelper.allowedBasicLayoutsAsTISInputSources[id]
                if let theEntry = theEntry {
                  Text(theEntry.vChewingLocalizedName).tag(theEntry.identifier)
                } else {
                  Divider()
                }
              }.id(UUID())
            }
            .labelsHidden()
            .frame(width: 240.0)
          }
          HStack {
            Text(
              NSLocalizedString(
                "Choose the macOS-level basic keyboard layout.",
                comment: ""
              ) + (mgrPrefs.appleLanguages[0].contains("en") ? " " : "")
                + NSLocalizedString(
                  "Non-QWERTY alphanumerical keyboard layouts are for Pinyin parser only.",
                  comment: ""
                )
            )
            .preferenceDescription().fixedSize(horizontal: false, vertical: true)
            Spacer().frame(width: 30)
          }
        }
        Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Keyboard Shortcuts:")) }) {
          Toggle(
            LocalizedStringKey("Per-Char Select Mode"),
            isOn: $selUsingHotKeySCPC.onChange {
              mgrPrefs.usingHotKeySCPC = selUsingHotKeySCPC
            }
          )
          Toggle(
            LocalizedStringKey("Per-Char Associated Phrases"),
            isOn: $selUsingHotKeyAssociates.onChange {
              mgrPrefs.usingHotKeyAssociates = selUsingHotKeyAssociates
            }
          )
          Toggle(
            LocalizedStringKey("CNS11643 Mode"),
            isOn: $selUsingHotKeyCNS.onChange {
              mgrPrefs.usingHotKeyCNS = selUsingHotKeyCNS
            }
          )
          Toggle(
            LocalizedStringKey("Force KangXi Writing"),
            isOn: $selUsingHotKeyKangXi.onChange {
              mgrPrefs.usingHotKeyKangXi = selUsingHotKeyKangXi
            }
          )
          Toggle(
            LocalizedStringKey("JIS Shinjitai Output"),
            isOn: $selUsingHotKeyJIS.onChange {
              mgrPrefs.usingHotKeyJIS = selUsingHotKeyJIS
            }
          )
          Toggle(
            LocalizedStringKey("Half-Width Punctuation Mode"),
            isOn: $selUsingHotKeyHalfWidthASCII.onChange {
              mgrPrefs.usingHotKeyHalfWidthASCII = selUsingHotKeyHalfWidthASCII
            }
          )
          Toggle(
            LocalizedStringKey("Currency Numeral Output"),
            isOn: $selUsingHotKeyCurrencyNumerals.onChange {
              mgrPrefs.usingHotKeyCurrencyNumerals = selUsingHotKeyCurrencyNumerals
            }
          )
        }
      }
    }
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
  }
}

@available(macOS 11.0, *)
struct suiPrefPaneKeyboard_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneKeyboard()
  }
}
