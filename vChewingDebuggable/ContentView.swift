// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import MainAssembly
import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack {
      Button("Call Settings // Cocoa") {
        CtlSettingsCocoa.show()
      }
      Button("Call Settings // SwiftUI") {
        CtlSettingsUI.show()
      }
    }.padding(16).frame(width: 640, height: 480)
  }
}
