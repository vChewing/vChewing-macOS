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
struct CandidatePoolViewUIHorizontalBackports_Previews: PreviewProvider {
  @State static var testCandidates: [String] = [
    "二十四歲是學生", "二十四歲", "昏睡紅茶", "食雪漢", "意味深", "學生", "便乗",
    "🐂🍺🐂🍺", "🐃🍺", "🐂🍺", "🐃🐂🍺🍺", "🐂🍺", "🐃🍺", "🐂🍺", "🐃🍺", "🐂🍺", "🐃🍺",
    "迫真", "驚愕", "論證", "正論", "惱", "悲", "屑", "食", "雪", "漢", "意", "味",
    "深", "二", "十", "四", "歲", "是", "學", "生", "昏", "睡", "紅", "茶", "便", "乗",
    "嗯", "哼", "啊",
  ]
  static var thePool: CandidatePool {
    var result = CandidatePool(candidates: testCandidates, rowCapacity: 6)
    // 下一行待解決：無論這裡怎麼指定高亮選中項是哪一筆，其所在行都得被卷動到使用者眼前。
    result.highlight(at: 5)
    return result
  }

  static var previews: some View {
    VwrCandidateHorizontalBackports(controller: nil, thePool: thePool).fixedSize()
  }
}

@available(macOS 10.15, *)
public struct VwrCandidateHorizontalBackports: View {
  public weak var controller: CtlCandidateTDK?
  @Environment(\.colorScheme) var colorScheme
  @State public var thePool: CandidatePool
  @State public var tooltip: String = ""
  @State public var reverseLookupResult: [String] = []

  private var positionLabel: String {
    (thePool.highlightedIndex + 1).description + "/" + thePool.candidateDataAll.count.description
  }

  private func didSelectCandidateAt(_ pos: Int) {
    if let delegate = controller?.delegate {
      delegate.candidatePairSelected(at: pos)
    }
  }

  private func didRightClickCandidateAt(_ pos: Int, action: CandidateContextMenuAction) {
    if let delegate = controller?.delegate {
      delegate.candidatePairRightClicked(at: pos, action: action)
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 1.6) {
          ForEach(thePool.rangeForCurrentPage, id: \.self) { rowIndex in
            HStack(spacing: ceil(CandidateCellData.unifiedSize * 0.35)) {
              ForEach(Array(thePool.candidateLines[rowIndex]), id: \.self) { currentCandidate in
                currentCandidate.attributedStringForSwiftUIBackports.fixedSize()
                  .contentShape(Rectangle())
                  .frame(
                    maxWidth: .infinity,
                    alignment: .topLeading
                  )
                  .onTapGesture { didSelectCandidateAt(currentCandidate.index) }
                  .contextMenu {
                    if controller?.delegate?.isCandidateContextMenuEnabled ?? false {
                      Button {
                        didRightClickCandidateAt(currentCandidate.index, action: .toBoost)
                      } label: {
                        Text("↑ " + currentCandidate.displayedText)
                      }
                      Button {
                        didRightClickCandidateAt(currentCandidate.index, action: .toNerf)
                      } label: {
                        Text("↓ " + currentCandidate.displayedText)
                      }
                      Button {
                        didRightClickCandidateAt(currentCandidate.index, action: .toFilter)
                      } label: {
                        Text("✖︎ " + currentCandidate.displayedText)
                      }
                    }
                  }
              }
              Spacer(minLength: Double.infinity)
            }.frame(
              minWidth: 0,
              maxWidth: .infinity,
              alignment: .topLeading
            ).id(rowIndex)
            Divider()
          }
          if thePool.maxLinesPerPage - thePool.rangeForCurrentPage.count > 0 {
            ForEach(thePool.rangeForLastPageBlanked, id: \.self) { _ in
              HStack(spacing: 0) {
                thePool.blankCell.attributedStringForSwiftUIBackports
                  .contentShape(Rectangle())
                  .frame(maxWidth: .infinity, alignment: .topLeading)
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
      .fixedSize(horizontal: false, vertical: true)
      .padding([.horizontal], 5).padding([.top], 5).padding([.bottom], -1)
      if controller?.delegate?.showReverseLookupResult ?? true {
        ZStack(alignment: .leading) {
          Color(white: colorScheme == .dark ? 0.15 : 0.97)
          HStack(alignment: .center, spacing: 4) {
            Text("→")
            ForEach(reverseLookupResult, id: \.self) { currentResult in
              ZStack(alignment: .center) {
                Color(white: colorScheme == .dark ? 0.3 : 0.9).cornerRadius(3)
                Text(" \(currentResult.trimmingCharacters(in: .newlines)) ").lineLimit(1)
              }.fixedSize()
            }
          }
          .font(.system(size: max(CandidateCellData.unifiedSize * 0.6, 9)))
          .padding([.horizontal], 4).padding([.vertical], 4)
          .foregroundColor(colorScheme == .light ? Color(white: 0.1) : Color(white: 0.9))
        }
      }
      ZStack(alignment: .trailing) {
        if tooltip.isEmpty {
          Color(white: colorScheme == .dark ? 0.2 : 0.9)
        } else {
          Color(white: colorScheme == .dark ? 0.0 : 1)
          controller?.highlightedColorUIBackports
        }
        HStack(alignment: .center) {
          if !tooltip.isEmpty {
            Text(tooltip).lineLimit(1)
            Spacer()
          }
          Text(positionLabel).lineLimit(1)
        }
        .font(.system(size: max(CandidateCellData.unifiedSize * 0.7, 11), weight: .bold))
        .padding(7).foregroundColor(
          tooltip.isEmpty && colorScheme == .light ? Color(white: 0.1) : Color(white: 0.9)
        )
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(minWidth: thePool.maxWindowWidth, maxWidth: thePool.maxWindowWidth)
    .background(Color(white: colorScheme == .dark ? 0.1 : 1))
    .overlay(
      RoundedRectangle(cornerRadius: 10).stroke(
        Color(white: colorScheme == .dark ? 0 : 1).opacity(colorScheme == .dark ? 1 : 0.1), lineWidth: 0.5
      )
    )
    .cornerRadius(10)
  }
}
