// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import MainAssembly
import PhraseEditorUI
import Shared
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPanePhrases: View {
  var body: some View {
    ScrollView {
      VStack {
        GroupBox {
          VwrPhraseEditorUI(delegate: LMMgr.shared, window: CtlPrefUI.shared?.window)
            .padding(4)
            .frame(maxWidth: .infinity)
            .frame(height: 440)
        }
      }
      .padding(4)
      .padding()
      .frame(minWidth: CtlPrefUIShared.formWidth, maxWidth: ceil(CtlPrefUIShared.formWidth * 1.2))
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPanePhrases_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPanePhrases()
  }
}
