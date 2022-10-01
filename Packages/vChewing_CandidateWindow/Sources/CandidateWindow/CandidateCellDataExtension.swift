// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import SwiftUI

@available(macOS 12, *)
extension CandidateCellData {
  public var attributedStringForSwiftUI: some View {
    var result: some View {
      ZStack(alignment: .leading) {
        if isSelected {
          Color(nsColor: CandidateCellData.highlightBackground).ignoresSafeArea().cornerRadius(6)
        }
        VStack(spacing: 0) {
          HStack(spacing: 4) {
            if UserDefaults.standard.bool(forKey: UserDef.kHandleDefaultCandidateFontsByLangIdentifier.rawValue) {
              Text(AttributedString(attributedStringHeader)).frame(width: CandidateCellData.unifiedSize * 2 / 3)
              Text(AttributedString(attributedString))
            } else {
              Text(key).font(.system(size: fontSizeKey).monospaced())
                .foregroundColor(.init(nsColor: fontColorKey)).lineLimit(1)
              Text(displayedText).font(.system(size: fontSizeCandidate))
                .foregroundColor(.init(nsColor: fontColorCandidate)).lineLimit(1)
            }
          }.padding(4)
        }
      }.fixedSize(horizontal: false, vertical: true)
    }
    return result
  }
}
