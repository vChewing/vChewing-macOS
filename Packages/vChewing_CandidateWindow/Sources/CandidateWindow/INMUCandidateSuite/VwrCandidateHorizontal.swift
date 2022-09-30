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
struct CandidatePoolViewUIHorizontal_Previews: PreviewProvider {
  @State static var testCandidates: [String] = [
    "八月中秋山林涼", "八月中秋", "風吹大地", "山林涼", "草枝擺", "八月", "中秋",
    "🐂🍺🐂🍺", "🐃🍺", "🐂🍺", "🐃🐂🍺🍺", "🐂🍺", "🐃🍺", "🐂🍺", "🐃🍺", "🐂🍺", "🐃🍺",
    "山林", "風吹", "大地", "草枝", "八", "月", "中", "秋", "山", "林", "涼", "風",
    "吹", "大", "地", "草", "枝", "擺", "八", "月", "中", "秋", "山", "林", "涼", "風",
    "吹", "大", "地", "草", "枝", "擺",
  ]
  static var thePool: CandidatePool {
    let result = CandidatePool(candidates: testCandidates, rowCapacity: 6)
    // 下一行待解決：無論這裡怎麼指定高亮選中項是哪一筆，其所在行都得被卷動到使用者眼前。
    result.highlightHorizontal(at: 5)
    return result
  }

  static var previews: some View {
    VwrCandidateHorizontal(controller: .init(.horizontal), thePool: thePool).fixedSize()
  }
}

@available(macOS 12, *)
public struct VwrCandidateHorizontal: View {
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
          ForEach(thePool.rangeForCurrentHorizontalPage, id: \.self) { rowIndex in
            HStack(spacing: 10) {
              ForEach(Array(thePool.candidateRows[rowIndex]), id: \.self) { currentCandidate in
                currentCandidate.attributedStringForSwiftUI.fixedSize()
                  .frame(
                    maxWidth: .infinity,
                    alignment: .topLeading
                  )
                  .contentShape(Rectangle())
                  .onTapGesture { didSelectCandidateAt(currentCandidate.index) }
              }
            }.frame(
              minWidth: 0,
              maxWidth: .infinity,
              alignment: .topLeading
            ).id(rowIndex)
            Divider()
          }
          if thePool.maximumRowsPerPage - thePool.rangeForCurrentHorizontalPage.count > 0 {
            ForEach(thePool.rangeForLastHorizontalPageBlanked, id: \.self) { _ in
              HStack(spacing: 0) {
                thePool.blankCell.attributedStringForSwiftUI
                  .frame(maxWidth: .infinity, alignment: .topLeading)
                  .contentShape(Rectangle())
                Spacer()
              }.frame(
                minWidth: 0,
                maxWidth: .infinity,
                alignment: .topLeading
              )
              Divider()
            }
          }
        }
      }
      .fixedSize(horizontal: false, vertical: true).padding(5)
      .background(Color(nsColor: NSColor.controlBackgroundColor).ignoresSafeArea())
      ZStack(alignment: .leading) {
        Color(nsColor: hint.isEmpty ? .windowBackgroundColor : CandidateCellData.highlightBackground).ignoresSafeArea()
        HStack(alignment: .bottom) {
          Text(hint).font(.system(size: max(CandidateCellData.unifiedSize * 0.7, 11), weight: .bold)).lineLimit(1)
          Spacer()
          Text(positionLabel).font(.system(size: max(CandidateCellData.unifiedSize * 0.7, 11), weight: .bold))
            .lineLimit(
              1)
        }
        .padding(6).foregroundColor(
          .init(nsColor: hint.isEmpty ? .controlTextColor : .selectedMenuItemTextColor.withAlphaComponent(0.9))
        )
      }
    }
    .frame(minWidth: thePool.maxWindowWidth, maxWidth: thePool.maxWindowWidth)
  }
}
