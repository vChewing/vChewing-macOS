// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import SwiftExtension
import SwiftUI

@available(macOS 13, *)
public struct VwrSettingsPaneOutput: View {
  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: false, UserDef.kChineseConversionEnabled.rawValue)
  private var chineseConversionEnabled: Bool

  @AppStorage(wrappedValue: false, UserDef.kShiftJISShinjitaiOutputEnabled.rawValue)
  private var shiftJISShinjitaiOutputEnabled: Bool

  @AppStorage(wrappedValue: false, UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue)
  private var inlineDumpPinyinInLieuOfZhuyin: Bool

  @AppStorage(wrappedValue: true, UserDef.kTrimUnfinishedReadingsOnCommit.rawValue)
  private var trimUnfinishedReadingsOnCommit: Bool

  @AppStorage(wrappedValue: false, UserDef.kHardenVerticalPunctuations.rawValue)
  private var hardenVerticalPunctuations: Bool

  // MARK: - Main View

  public var body: some View {
    ScrollView {
      Form {
        Section {
          UserDef.kChineseConversionEnabled.bind(
            $chineseConversionEnabled.onChange {
              if chineseConversionEnabled, shiftJISShinjitaiOutputEnabled {
                shiftJISShinjitaiOutputEnabled = false
              }
            }
          ).render()
          UserDef.kShiftJISShinjitaiOutputEnabled.bind(
            $shiftJISShinjitaiOutputEnabled.onChange {
              if chineseConversionEnabled, shiftJISShinjitaiOutputEnabled {
                chineseConversionEnabled = false
              }
            }
          ).render()
          UserDef.kInlineDumpPinyinInLieuOfZhuyin.bind($inlineDumpPinyinInLieuOfZhuyin).render()
          UserDef.kTrimUnfinishedReadingsOnCommit.bind($trimUnfinishedReadingsOnCommit).render()
        }
        Section(header: Text("Experimental:")) {
          UserDef.kHardenVerticalPunctuations.bind($hardenVerticalPunctuations).render()
        }
      }.formStyled()
    }
    .frame(
      minWidth: CtlSettingsUI.formWidth,
      maxHeight: CtlSettingsUI.contentMaxHeight
    )
  }
}

@available(macOS 13, *)
struct VwrSettingsPaneOutput_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneOutput()
  }
}
