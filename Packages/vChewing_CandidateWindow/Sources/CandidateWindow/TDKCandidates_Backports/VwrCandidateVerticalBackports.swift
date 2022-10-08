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
import SwiftUIBackports

// MARK: - Some useless tests

@available(macOS 10.15, *)
struct CandidatePoolViewUIVerticalBackports_Previews: PreviewProvider {
  @State static var testCandidates: [String] = [
    "八月中秋山林涼", "八月中秋", "風吹大地", "山林涼", "草枝擺", "🐂🍺", "🐃🍺", "八月", "中秋",
    "山林", "風吹", "大地", "草枝", "八", "月", "中", "秋", "山", "林", "涼", "風",
    "吹", "大", "地", "草", "枝", "擺", "八", "月", "中", "秋", "山", "林", "涼", "風",
    "吹", "大", "地", "草", "枝", "擺",
  ]
  static var thePool: CandidatePool {
    let result = CandidatePool(candidates: testCandidates, columnCapacity: 6, selectionKeys: "123456789")
    // 下一行待解決：無論這裡怎麼指定高亮選中項是哪一筆，其所在行都得被卷動到使用者眼前。
    result.highlight(at: 5)
    return result
  }

  static var previews: some View {
    VwrCandidateVerticalBackports(controller: .init(.horizontal), thePool: thePool).fixedSize()
  }
}

@available(macOS 10.15, *)
public struct VwrCandidateVerticalBackports: View {
  @Environment(\.colorScheme) var colorScheme
  public var controller: CtlCandidateTDK
  @State public var thePool: CandidatePool
  @State public var tooltip: String = ""

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
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 10) {
          ForEach(Array(thePool.rangeForCurrentPage.enumerated()), id: \.offset) { loopIndex, columnIndex in
            VStack(alignment: .leading, spacing: 0) {
              ForEach(Array(thePool.candidateLines[columnIndex]), id: \.self) { currentCandidate in
                HStack(spacing: 0) {
                  currentCandidate.attributedStringForSwiftUIBackports.fixedSize(horizontal: false, vertical: true)
                    .frame(
                      maxWidth: .infinity,
                      alignment: .topLeading
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { didSelectCandidateAt(currentCandidate.index) }
                }
              }
            }.frame(
              minWidth: Double(CandidateCellData.unifiedSize * 5),
              alignment: .topLeading
            ).id(columnIndex)
            if loopIndex < thePool.maxLinesPerPage - 1 {
              Divider()
            }
          }
          if thePool.maxLinesPerPage - thePool.rangeForCurrentPage.count > 0 {
            ForEach(Array(thePool.rangeForLastPageBlanked.enumerated()), id: \.offset) { loopIndex, _ in
              VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<thePool.maxLineCapacity, id: \.self) { _ in
                  thePool.blankCell.attributedStringForSwiftUIBackports.fixedSize()
                    .frame(width: Double(CandidateCellData.unifiedSize * 5), alignment: .topLeading)
                    .contentShape(Rectangle())
                }
              }.frame(
                minWidth: 0,
                maxWidth: .infinity,
                alignment: .topLeading
              )
              if loopIndex < thePool.maxLinesPerPage - thePool.rangeForCurrentPage.count - 1 {
                Divider()
              }
            }
          }
        }
      }
      .fixedSize(horizontal: true, vertical: false).padding(5)
      .background(Color(white: colorScheme == .dark ? 0.1 : 1))
      ZStack(alignment: .leading) {
        if tooltip.isEmpty {
          Color(white: colorScheme == .dark ? 0.2 : 0.9)
        } else {
          controller.highlightedColorUIBackports
        }
        HStack(alignment: .bottom) {
          Text(tooltip).font(.system(size: max(CandidateCellData.unifiedSize * 0.7, 11), weight: .bold)).lineLimit(1)
          Spacer()
          Text(positionLabel).font(.system(size: max(CandidateCellData.unifiedSize * 0.7, 11), weight: .bold))
            .lineLimit(
              1)
        }
        .padding(7).foregroundColor(
          tooltip.isEmpty && colorScheme == .light ? Color(white: 0.1) : Color(white: 0.9)
        )
      }
    }
    .cornerRadius(10)
  }
}
