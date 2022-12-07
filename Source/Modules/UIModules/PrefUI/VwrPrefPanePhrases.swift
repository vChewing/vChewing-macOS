// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import PhraseEditorUI
import SSPreferences
import Shared
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPanePhrases: View {
  private let contentMaxHeight: Double = 440
  private let contentWidth: Double = {
    switch PrefMgr.shared.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 580
        }
    }
  }()

  var isMontereyOrAbove: Bool = {
    if #available(macOS 12.0, *) {
      return true
    }
    return false
  }()

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: contentWidth) {
        SSPreferences.Section(title: "", bottomDivider: true) {
          VwrPhraseEditorUI(delegate: LMMgr.shared).frame(height: 395)
        }
      }
    }
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPanePhrases_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPanePhrases()
  }
}
