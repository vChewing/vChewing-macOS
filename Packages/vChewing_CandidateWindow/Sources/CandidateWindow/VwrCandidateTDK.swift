// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import Shared
import SwiftUI

// MARK: - Some useless tests

@available(macOS 12, *)
struct CandidatePoolViewUI_Previews: PreviewProvider {
  @State static var testCandidates: [String] = [
    "八月中秋山林涼", "八月中秋", "風吹大地", "山林涼", "草枝擺", "八月", "中秋",
    "山林", "風吹", "大地", "草枝", "八", "月", "中", "秋", "山", "林", "涼", "風",
    "吹", "大", "地", "草", "枝", "擺", "八", "月", "中", "秋", "山", "林", "涼", "風",
    "吹", "大", "地", "草", "枝", "擺",
  ]
  static var thePool: CandidatePool {
    let result = CandidatePool(candidates: testCandidates, columnCapacity: 6)
    // 下一行待解決：無論這裡怎麼指定高亮選中項是哪一筆，其所在行都得被卷動到使用者眼前。
    result.highlight(at: 14)
    return result
  }

  static var previews: some View {
    VwrCandidateTDK(controller: .init(.horizontal), thePool: thePool).fixedSize()
  }
}

@available(macOS 12, *)
public struct VwrCandidateTDK: View {
  public var controller: CtlCandidateTDK
  @State public var thePool: CandidatePool
  @State public var hint: String = ""

  private var positionLabel: String {
    (thePool.highlightedIndex + 1).description + "/" + thePool.candidateDataAll.count.description
  }

  private func didSelectCandidateAt(_ pos: Int) {
    if let delegate = controller.delegate {
      delegate.candidatePairSelected(at: pos)
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading, spacing: 1.6) {
          ForEach(thePool.rangeForCurrentPage, id: \.self) { columnIndex in
            HStack(spacing: 10) {
              ForEach(Array(thePool.candidateRows[columnIndex]), id: \.self) { currentCandidate in
                currentCandidate.attributedStringForSwiftUI.fixedSize()
                  .frame(maxWidth: .infinity, alignment: .topLeading)
                  .contentShape(Rectangle())
                  .onTapGesture { didSelectCandidateAt(currentCandidate.index) }
              }
              Spacer()
            }.frame(
              minWidth: 0,
              maxWidth: .infinity,
              alignment: .topLeading
            ).id(columnIndex)
            Divider()
          }
        }
      }
      .frame(minHeight: thePool.maxWindowHeight, maxHeight: thePool.maxWindowHeight).padding(5)
      .background(Color(nsColor: NSColor.controlBackgroundColor).ignoresSafeArea())
      HStack(alignment: .bottom) {
        Text(hint).font(.system(size: max(CandidateCellData.unifiedSize * 0.7, 11), weight: .bold)).lineLimit(1)
        Spacer()
        Text(positionLabel).font(.system(size: max(CandidateCellData.unifiedSize * 0.7, 11), weight: .bold)).lineLimit(
          1)
      }.padding(6).foregroundColor(.init(nsColor: .controlTextColor))
        .shadow(color: .init(nsColor: .textBackgroundColor), radius: 1)
    }
    .frame(minWidth: thePool.maxWindowWidth, maxWidth: thePool.maxWindowWidth)
  }
}

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
              Text(AttributedString(attributedStringHeader)).frame(width: CandidateCellData.unifiedSize / 2)
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
