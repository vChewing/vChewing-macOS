// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import SwiftUI

// MARK: - VwrSettingsPaneOutput

@available(macOS 14, *)
public struct VwrSettingsPaneOutput: View {
  // MARK: - Main View

  public var body: some View {
    Form {
      Section {
        UserDef.kKanjiConversionPreferences.renderUI()
        UserDef.kInlineDumpPinyinInLieuOfZhuyin.renderUI()
        UserDef.kTrimUnfinishedReadingsOnCommit.renderUI()
        UserDef.kRomanNumeralOutputFormat.renderUI()
      }
      Section(header: Text("i18n:Settings.SectionExperimental")) {
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
