// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Preferences
import Shared
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPaneGeneral: View {
  @State private var selCandidateUIFontSize = UserDefaults.standard.integer(
    forKey: UserDef.kCandidateListTextSize.rawValue)
  @State private var selUILanguage: [String] =
    Shared.arrSupportedLocales.contains(
      ((UserDefaults.standard.object(forKey: UserDef.kAppleLanguages.rawValue) == nil)
        ? ["auto"] : UserDefaults.standard.array(forKey: UserDef.kAppleLanguages.rawValue) as? [String] ?? ["auto"])[0])
    ? ((UserDefaults.standard.object(forKey: UserDef.kAppleLanguages.rawValue) == nil)
      ? ["auto"] : UserDefaults.standard.array(forKey: UserDef.kAppleLanguages.rawValue) as? [String] ?? ["auto"])
    : ["auto"]
  @State private var selEnableHorizontalCandidateLayout = UserDefaults.standard.bool(
    forKey: UserDef.kUseHorizontalCandidateList.rawValue)
  @State private var selEnableKanjiConvToKangXi = UserDefaults.standard.bool(
    forKey: UserDef.kChineseConversionEnabled.rawValue)
  @State private var selEnableKanjiConvToJIS = UserDefaults.standard.bool(
    forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue)
  @State private var selShowHanyuPinyinInCompositionBuffer = UserDefaults.standard.bool(
    forKey: UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue)
  @State private var selInlineDumpPinyinInLieuOfZhuyin = UserDefaults.standard.bool(
    forKey: UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue)
  @State private var selEnableFartSuppressor = UserDefaults.standard.bool(
    forKey: UserDef.kShouldNotFartInLieuOfBeep.rawValue)
  @State private var selEnableAutoUpdateCheck = UserDefaults.standard.bool(
    forKey: UserDef.kCheckUpdateAutomatically.rawValue)
  @State private var selEnableDebugMode = UserDefaults.standard.bool(forKey: UserDef.kIsDebugModeEnabled.rawValue)

  private let contentMaxHeight: Double = 440
  private let contentWidth: Double = {
    switch PrefMgr.shared.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 580
        }
    }
  }()

  var body: some View {
    ScrollView {
      Preferences.Container(contentWidth: contentWidth) {
        Preferences.Section(label: { Text(LocalizedStringKey("Candidate Size:")) }) {
          Picker(
            "",
            selection: $selCandidateUIFontSize.onChange {
              PrefMgr.shared.candidateListTextSize = Double(selCandidateUIFontSize)
            }
          ) {
            Group {
              Text("12").tag(12)
              Text("14").tag(14)
              Text("16").tag(16)
              Text("17").tag(17)
              Text("18").tag(18)
              Text("20").tag(20)
              Text("22").tag(22)
              Text("24").tag(24)
            }
            Group {
              Text("32").tag(32)
              Text("64").tag(64)
              Text("96").tag(96)
            }
          }
          .labelsHidden()
          .frame(width: 120.0)
          Text(LocalizedStringKey("Choose candidate font size for better visual clarity."))
            .preferenceDescription()
        }
        Preferences.Section(label: { Text(LocalizedStringKey("UI Language:")) }) {
          Picker(
            LocalizedStringKey("Follow OS settings"),
            selection: $selUILanguage.onChange {
              vCLog(selUILanguage[0])
              if selUILanguage == PrefMgr.shared.appleLanguages
                || (selUILanguage[0] == "auto"
                  && UserDefaults.standard.object(forKey: UserDef.kAppleLanguages.rawValue) == nil)
              {
                return
              }
              if selUILanguage[0] != "auto" {
                PrefMgr.shared.appleLanguages = selUILanguage
              } else {
                UserDefaults.standard.removeObject(forKey: UserDef.kAppleLanguages.rawValue)
              }
              NSLog("vChewing App self-terminated due to UI language change.")
              NSApp.terminate(nil)
            }
          ) {
            Text(LocalizedStringKey("Follow OS settings")).tag(["auto"])
            Text(LocalizedStringKey("Simplified Chinese")).tag(["zh-Hans"])
            Text(LocalizedStringKey("Traditional Chinese")).tag(["zh-Hant"])
            Text(LocalizedStringKey("Japanese")).tag(["ja"])
            Text(LocalizedStringKey("English")).tag(["en"])
          }
          .labelsHidden()
          .frame(width: 180.0)

          Text(LocalizedStringKey("Change user interface language (will reboot the IME)."))
            .preferenceDescription()
        }
        Preferences.Section(label: { Text(LocalizedStringKey("Candidate Layout:")) }) {
          Picker(
            "",
            selection: $selEnableHorizontalCandidateLayout.onChange {
              PrefMgr.shared.useHorizontalCandidateList = selEnableHorizontalCandidateLayout
            }
          ) {
            Text(LocalizedStringKey("Vertical")).tag(false)
            Text(LocalizedStringKey("Horizontal")).tag(true)
          }
          .labelsHidden()
          .horizontalRadioGroupLayout()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose your preferred layout of the candidate window."))
            .preferenceDescription()
        }
        Preferences.Section(label: { Text(LocalizedStringKey("Output Settings:")) }) {
          Toggle(
            LocalizedStringKey("Auto-convert traditional Chinese glyphs to KangXi characters"),
            isOn: $selEnableKanjiConvToKangXi.onChange {
              PrefMgr.shared.chineseConversionEnabled = selEnableKanjiConvToKangXi
              selEnableKanjiConvToJIS = PrefMgr.shared.shiftJISShinjitaiOutputEnabled
            }
          )
          Toggle(
            LocalizedStringKey("Auto-convert traditional Chinese glyphs to JIS Shinjitai characters"),
            isOn: $selEnableKanjiConvToJIS.onChange {
              PrefMgr.shared.shiftJISShinjitaiOutputEnabled = selEnableKanjiConvToJIS
              selEnableKanjiConvToKangXi = PrefMgr.shared.chineseConversionEnabled
            }
          )
          Toggle(
            LocalizedStringKey("Show Hanyu-Pinyin in the inline composition buffer"),
            isOn: $selShowHanyuPinyinInCompositionBuffer.onChange {
              PrefMgr.shared.showHanyuPinyinInCompositionBuffer = selShowHanyuPinyinInCompositionBuffer
            }
          )
          Toggle(
            LocalizedStringKey("Commit Hanyu-Pinyin instead on Ctrl(+Option)+Command+Enter"),
            isOn: $selInlineDumpPinyinInLieuOfZhuyin.onChange {
              PrefMgr.shared.inlineDumpPinyinInLieuOfZhuyin = selInlineDumpPinyinInLieuOfZhuyin
            }
          )
          Toggle(
            LocalizedStringKey("Stop farting (when typed phonetic combination is invalid, etc.)"),
            isOn: $selEnableFartSuppressor.onChange {
              PrefMgr.shared.shouldNotFartInLieuOfBeep = selEnableFartSuppressor
              IMEApp.buzz()
            }
          )
        }
        Preferences.Section(label: { Text(LocalizedStringKey("Misc Settings:")).controlSize(.small) }) {
          Toggle(
            LocalizedStringKey("Check for updates automatically"),
            isOn: $selEnableAutoUpdateCheck.onChange {
              PrefMgr.shared.checkUpdateAutomatically = selEnableAutoUpdateCheck
            }
          )
          .controlSize(.small)
          Toggle(
            LocalizedStringKey("Debug Mode"),
            isOn: $selEnableDebugMode.onChange {
              PrefMgr.shared.isDebugModeEnabled = selEnableDebugMode
            }
          )
          .controlSize(.small)
        }
      }
    }
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneGeneral_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneGeneral()
  }
}
