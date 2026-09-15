// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬，legacy 倉庫（＝本倉的「子集 ＋ Swift 5.10 Dialect」，砍掉了 SwiftUI）無對位模組可繼承；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

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

#endif
