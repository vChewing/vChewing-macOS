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
import SSPreferences
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPanePhrases: View {
  var body: some View {
    ScrollView {
      VStack {
        VwrPhraseEditorUI(delegate: LMMgr.shared, window: CtlPrefUIShared.sharedWindow)
          .frame(width: CtlPrefUIShared.contentWidth + 28, height: 445)
        Spacer()
      }
      .padding()
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
