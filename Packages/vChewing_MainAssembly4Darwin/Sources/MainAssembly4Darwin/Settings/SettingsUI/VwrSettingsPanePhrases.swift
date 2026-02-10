// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - VwrSettingsPanePhrases

@available(macOS 14, *)
public struct VwrSettingsPanePhrases: View {
  public var body: some View {
    NavigationStack {
      List {
        GroupBox {
          VwrPhraseEditorUI(delegate: LMMgr.shared, window: CtlSettingsUI.shared?.window)
            .padding(4)
            .frame(maxWidth: .infinity)
            .frame(height: 440)
        }
        .padding(4)
      }
      .listStyle(.plain)
    }
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
