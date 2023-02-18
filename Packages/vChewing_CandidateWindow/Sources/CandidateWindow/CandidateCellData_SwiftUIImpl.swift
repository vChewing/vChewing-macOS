// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import SwiftUI

// MARK: - Contents specifically made for SwiftUI.

@available(macOS 10.15, *)
public extension CandidateCellData {
  var themeColor: Color {
    // 設定當前高亮候選字的背景顏色。
    let result: Color = {
      switch locale {
      case "zh-Hans": return Color.red
      case "zh-Hant": return Color.blue
      case "ja": return Color(red: 0.64, green: 0.52, blue: 0.37)
      default: return Color.accentColor
      }
    }()
    return result.opacity(0.85)
  }

  var attributedStringForSwiftUIBackports: some View {
    var result: some View {
      ZStack(alignment: .leading) {
        if isHighlighted {
          themeColor.cornerRadius(6)
          VStack(spacing: 0) {
            HStack(spacing: 4) {
              Text(verbatim: key).font(.custom("Menlo", size: fontSizeKey))
                .foregroundColor(Color.white.opacity(0.8)).lineLimit(1)
              Text(verbatim: displayedText)
                .font(.init(CTFontCreateUIFontForLanguage(.system, fontSizeCandidate, locale as CFString)!))
                .foregroundColor(Color(white: 1)).lineLimit(1)
            }.padding(3).foregroundColor(Color(white: 0.9))
          }.frame(alignment: .leading)
        } else {
          VStack(spacing: 0) {
            HStack(spacing: 4) {
              Text(verbatim: key).font(.custom("Menlo", size: fontSizeKey))
                .foregroundColor(Color.secondary).lineLimit(1)
              Text(verbatim: displayedText)
                .font(.init(CTFontCreateUIFontForLanguage(.system, fontSizeCandidate, locale as CFString)!))
                .foregroundColor(Color.primary).lineLimit(1)
            }.padding(3).foregroundColor(Color(white: 0.9))
          }.frame(alignment: .leading)
        }
      }.fixedSize(horizontal: false, vertical: true)
    }
    return result
  }

  @available(macOS 12, *)
  var attributedStringForSwiftUI: some View {
    var result: some View {
      ZStack(alignment: .leading) {
        if isHighlighted {
          themeColor.ignoresSafeArea().cornerRadius(6)
        }
        VStack(spacing: 0) {
          HStack(spacing: 4) {
            if UserDefaults.standard.bool(forKey: UserDef.kLegacyCandidateViewTypesettingMethodEnabled.rawValue) {
              Text(AttributedString(attributedStringHeader))
              Text(AttributedString(attributedStringPhrase()))
            } else {
              Text(verbatim: key).font(.system(size: fontSizeKey).monospaced())
                .foregroundColor(.init(nsColor: fontColorKey)).lineLimit(1)
              Text(verbatim: displayedText)
                .font(.init(CTFontCreateUIFontForLanguage(.system, fontSizeCandidate, locale as CFString)!))
                .foregroundColor(.init(nsColor: fontColorCandidate)).lineLimit(1)
            }
          }.padding(3)
        }.frame(alignment: .leading)
      }.fixedSize(horizontal: false, vertical: true)
    }
    return result
  }
}
