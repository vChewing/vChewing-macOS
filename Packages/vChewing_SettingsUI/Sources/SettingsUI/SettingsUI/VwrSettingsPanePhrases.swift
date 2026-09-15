// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬，legacy 倉庫（＝本倉的「子集 ＋ Swift 5.10 Dialect」，砍掉了 SwiftUI）無對位模組可繼承；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

  import SwiftUI

  // MARK: - VwrSettingsPanePhrases

  @available(macOS 14, *)
  public struct VwrSettingsPanePhrases: View {
    public var body: some View {
      GroupBox {
        VwrPhraseEditorUI(delegate: SettingsUIHost.shared.phraseEditorDelegate, window: CtlSettingsUI.shared?.window)
          .padding(4)
          .frame(maxWidth: .infinity, minHeight: 440)
      }
      .padding()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
    }
  }

  // MARK: - VwrSettingsPanePhrases_Previews

  @available(macOS 14, *)
  struct VwrSettingsPanePhrases_Previews: PreviewProvider {
    static var previews: some View {
      VwrSettingsPanePhrases()
    }
  }

#endif
