// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

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
