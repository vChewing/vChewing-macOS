// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import SSPreferences
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPaneOutput: View {
  @State private var selEnableKanjiConvToKangXi = UserDefaults.standard.bool(
    forKey: UserDef.kChineseConversionEnabled.rawValue)
  @State private var selEnableKanjiConvToJIS = UserDefaults.standard.bool(
    forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue)
  @State private var selInlineDumpPinyinInLieuOfZhuyin = UserDefaults.standard.bool(
    forKey: UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue)
  @State private var selTrimUnfinishedReadingsOnCommit = UserDefaults.standard.bool(
    forKey: UserDef.kTrimUnfinishedReadingsOnCommit.rawValue)
  @State private var selHardenVerticalPunctuations: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kHardenVerticalPunctuations.rawValue)

  var macOSMontereyOrLaterDetected: Bool {
    if #available(macOS 12, *) {
      return true
    }
    return false
  }

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: CtlPrefUI.contentWidth) {
        SSPreferences.Section(title: "Output Settings:".localized) {
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
            LocalizedStringKey("Commit Hanyu-Pinyin instead on Ctrl(+Option)+Command+Enter"),
            isOn: $selInlineDumpPinyinInLieuOfZhuyin.onChange {
              PrefMgr.shared.inlineDumpPinyinInLieuOfZhuyin = selInlineDumpPinyinInLieuOfZhuyin
            }
          )
          Toggle(
            LocalizedStringKey("Trim unfinished readings / strokes on commit"),
            isOn: $selTrimUnfinishedReadingsOnCommit.onChange {
              PrefMgr.shared.trimUnfinishedReadingsOnCommit = selTrimUnfinishedReadingsOnCommit
            }
          )
          Toggle(
            LocalizedStringKey("Harden vertical punctuations during vertical typing (not recommended)"),
            isOn: $selHardenVerticalPunctuations.onChange {
              PrefMgr.shared.hardenVerticalPunctuations = selHardenVerticalPunctuations
            }
          )
          Text(
            LocalizedStringKey(
              "⚠︎ This feature is useful ONLY WHEN the font you are using doesn't support dynamic vertical punctuations. However, typed vertical punctuations will always shown as vertical punctuations EVEN IF your editor has changed the typing direction to horizontal."
            )
          )
          .preferenceDescription().prefDescriptionWidthLimited()
        }
      }
    }
    .frame(maxHeight: CtlPrefUI.contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneOutput_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneOutput()
  }
}
