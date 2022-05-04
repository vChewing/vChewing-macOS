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

import Cocoa
import SwiftUI

@available(macOS 11.0, *)
struct suiPrefPaneGeneral: View {
  @State private var selCandidateUIFontSize = UserDefaults.standard.integer(forKey: UserDef.kCandidateListTextSize)
  @State private var selUILanguage: [String] =
    IME.arrSupportedLocales.contains(
      ((UserDefaults.standard.object(forKey: UserDef.kAppleLanguages) == nil)
        ? ["auto"] : UserDefaults.standard.array(forKey: UserDef.kAppleLanguages) as? [String] ?? ["auto"])[0])
    ? ((UserDefaults.standard.object(forKey: UserDef.kAppleLanguages) == nil)
      ? ["auto"] : UserDefaults.standard.array(forKey: UserDef.kAppleLanguages) as? [String] ?? ["auto"])
    : ["auto"]
  @State private var selEnableHorizontalCandidateLayout = UserDefaults.standard.bool(
    forKey: UserDef.kUseHorizontalCandidateList)
  @State private var selShowPageButtonsInCandidateUI = UserDefaults.standard.bool(
    forKey: UserDef.kShowPageButtonsInCandidateWindow)
  @State private var selEnableKanjiConvToKangXi = UserDefaults.standard.bool(
    forKey: UserDef.kChineseConversionEnabled)
  @State private var selEnableKanjiConvToJIS = UserDefaults.standard.bool(
    forKey: UserDef.kShiftJISShinjitaiOutputEnabled)
  @State private var selEnableFartSuppressor = UserDefaults.standard.bool(forKey: UserDef.kShouldNotFartInLieuOfBeep)
  @State private var selEnableAutoUpdateCheck = UserDefaults.standard.bool(forKey: UserDef.kCheckUpdateAutomatically)
  @State private var selEnableDebugMode = UserDefaults.standard.bool(forKey: UserDef.kIsDebugModeEnabled)
  private let contentWidth: Double = {
    switch mgrPrefs.appleLanguages[0] {
      case "ja":
        return 465
      default:
        if mgrPrefs.appleLanguages[0].contains("zh-Han") {
          return 450
        } else {
          return 550
        }
    }
  }()

  var body: some View {
    Preferences.Container(contentWidth: contentWidth) {
      Preferences.Section(bottomDivider: false, label: { Text(LocalizedStringKey("Candidate Size:")) }) {
        Picker("", selection: $selCandidateUIFontSize) {
          Text("12").tag(12)
          Text("14").tag(14)
          Text("16").tag(16)
          Text("18").tag(18)
          Text("24").tag(24)
          Text("32").tag(32)
          Text("64").tag(64)
          Text("96").tag(96)
        }.onChange(of: selCandidateUIFontSize) { value in
          mgrPrefs.candidateListTextSize = CGFloat(value)
        }
        .labelsHidden()
        .frame(width: 120.0)
        Text(LocalizedStringKey("Choose candidate font size for better visual clarity."))
          .preferenceDescription()
      }
      Preferences.Section(bottomDivider: false, label: { Text(LocalizedStringKey("UI Language:")) }) {
        Picker(LocalizedStringKey("Follow OS settings"), selection: $selUILanguage) {
          Text(LocalizedStringKey("Follow OS settings")).tag(["auto"])
          Text(LocalizedStringKey("Simplified Chinese")).tag(["zh-Hans"])
          Text(LocalizedStringKey("Traditional Chinese")).tag(["zh-Hant"])
          Text(LocalizedStringKey("Japanese")).tag(["ja"])
          Text(LocalizedStringKey("English")).tag(["en"])
        }.onChange(of: selUILanguage) { value in
          IME.prtDebugIntel(value[0])
          if selUILanguage == mgrPrefs.appleLanguages
            || (selUILanguage[0] == "auto"
              && UserDefaults.standard.object(forKey: UserDef.kAppleLanguages) == nil)
          {
            return
          }
          if selUILanguage[0] != "auto" {
            mgrPrefs.appleLanguages = value
          } else {
            UserDefaults.standard.removeObject(forKey: UserDef.kAppleLanguages)
          }
          NSLog("vChewing App self-terminated due to UI language change.")
          NSApplication.shared.terminate(nil)
        }
        .labelsHidden()
        .frame(width: 180.0)

        Text(LocalizedStringKey("Change user interface language (will reboot the IME)."))
          .preferenceDescription()
      }
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Candidate Layout:")) }) {
        Picker("", selection: $selEnableHorizontalCandidateLayout) {
          Text(LocalizedStringKey("Vertical")).tag(false)
          Text(LocalizedStringKey("Horizontal")).tag(true)
        }.onChange(of: selEnableHorizontalCandidateLayout) { value in
          mgrPrefs.useHorizontalCandidateList = value
        }
        .labelsHidden()
        .horizontalRadioGroupLayout()
        .pickerStyle(RadioGroupPickerStyle())
        Text(LocalizedStringKey("Choose your preferred layout of the candidate window."))
          .preferenceDescription()
        Toggle(
          LocalizedStringKey("Show page buttons in candidate window"), isOn: $selShowPageButtonsInCandidateUI
        ).controlSize(.small)
      }
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Output Settings:")) }) {
        Toggle(
          LocalizedStringKey("Auto-convert traditional Chinese glyphs to KangXi characters"),
          isOn: $selEnableKanjiConvToKangXi
        ).onChange(of: selEnableKanjiConvToKangXi) { value in
          mgrPrefs.chineseConversionEnabled = value
          selEnableKanjiConvToKangXi = value
          if value {
            mgrPrefs.shiftJISShinjitaiOutputEnabled = !value
            selEnableKanjiConvToJIS = !value
          }
        }
        Toggle(
          LocalizedStringKey("Auto-convert traditional Chinese glyphs to JIS Shinjitai characters"),
          isOn: $selEnableKanjiConvToJIS
        ).onChange(of: selEnableKanjiConvToJIS) { value in
          mgrPrefs.shiftJISShinjitaiOutputEnabled = value
          selEnableKanjiConvToJIS = value
          if value {
            mgrPrefs.chineseConversionEnabled = !value
            selEnableKanjiConvToKangXi = !value
          }
        }
        Toggle(
          LocalizedStringKey("Stop farting (when typed phonetic combination is invalid, etc.)"),
          isOn: $selEnableFartSuppressor
        ).onChange(of: selEnableFartSuppressor) { value in
          mgrPrefs.shouldNotFartInLieuOfBeep = value
          clsSFX.beep()
        }
      }
      Preferences.Section(label: { Text(LocalizedStringKey("Misc Settings:")).controlSize(.small) }) {
        Toggle(LocalizedStringKey("Check for updates automatically"), isOn: $selEnableAutoUpdateCheck)
          .onChange(of: selEnableAutoUpdateCheck) { value in
            mgrPrefs.checkUpdateAutomatically = value
          }
          .controlSize(.small)
        Toggle(LocalizedStringKey("Debug Mode"), isOn: $selEnableDebugMode).controlSize(.small)
          .onChange(of: selEnableDebugMode) { value in
            mgrPrefs.isDebugModeEnabled = value
          }
      }
    }
  }
}

@available(macOS 11.0, *)
struct suiPrefPaneGeneral_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneGeneral()
  }
}
