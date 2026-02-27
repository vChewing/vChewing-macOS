// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - VwrSettingsPaneOutput

@available(macOS 14, *)
public struct VwrSettingsPaneOutput: View {
  // MARK: - Main View

  public var body: some View {
    Form {
      Section {
        UserDef.kChineseConversionEnabled.renderUI {
          if PrefMgr.shared.chineseConversionEnabled, PrefMgr.shared.shiftJISShinjitaiOutputEnabled {
            PrefMgr.shared.shiftJISShinjitaiOutputEnabled = false
          }
        }
        UserDef.kShiftJISShinjitaiOutputEnabled.renderUI {
          if PrefMgr.shared.chineseConversionEnabled, PrefMgr.shared.shiftJISShinjitaiOutputEnabled {
            PrefMgr.shared.chineseConversionEnabled = false
          }
        }
        UserDef.kInlineDumpPinyinInLieuOfZhuyin.renderUI()
        UserDef.kTrimUnfinishedReadingsOnCommit.renderUI()
        UserDef.kRomanNumeralOutputFormat.renderUI()
      }
      Section(header: Text("Experimental:")) {
        UserDef.kHardenVerticalPunctuations.renderUI()
      }
    }.formStyled()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
  }
}

// MARK: - VwrSettingsPaneOutput_Previews

@available(macOS 14, *)
struct VwrSettingsPaneOutput_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneOutput()
  }
}
