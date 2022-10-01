// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CandidateWindow
import Shared
import SwiftUI
import SwiftUIBackports

@available(macOS 10.15, *)
extension CandidateCellData {
  public var themeColor: some View {
    // 設定當前高亮候選字的背景顏色。
    let result: Color = {
      switch locale {
        case "zh-Hans": return Color.red
        case "zh-Hant": return Color.blue
        case "ja": return Color.pink
        default: return Color.accentColor
      }
    }()
    return result.opacity(0.85)
  }

  public var attributedStringForSwiftUIBackports: some View {
    var result: some View {
      ZStack(alignment: .leading) {
        if isSelected {
          themeColor.cornerRadius(6)
          VStack(spacing: 0) {
            HStack(spacing: 4) {
              Text(key).font(.custom("Menlo", size: fontSizeKey))
                .foregroundColor(Color.white.opacity(0.8)).lineLimit(1)
              Text(displayedText).font(.system(size: fontSizeCandidate))
                .foregroundColor(Color(white: 1)).lineLimit(1)
            }.padding(4).foregroundColor(Color(white: 0.9))
          }
        } else {
          VStack(spacing: 0) {
            HStack(spacing: 4) {
              Text(key).font(.custom("Menlo", size: fontSizeKey))
                .foregroundColor(Color.secondary).lineLimit(1)
              Text(displayedText).font(.system(size: fontSizeCandidate))
                .foregroundColor(Color.primary).lineLimit(1)
            }.padding(4).foregroundColor(Color(white: 0.9))
          }
        }
      }.fixedSize(horizontal: false, vertical: true)
    }
    return result
  }
}
