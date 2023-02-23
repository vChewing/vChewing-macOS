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

// MARK: - Main View

@available(macOS 10.15, *)
public struct VwrCandidateTDK: View {
  public weak var controller: CtlCandidateTDK?
  @Environment(\.colorScheme) var colorScheme
  @State public var thePool: CandidatePool
  @State public var forceCatalinaCompatibility: Bool = false
  var tooltip: String { thePool.tooltip }
  var reverseLookupResult: [String] { thePool.reverseLookupResult }

  let horizontalCellSpacing: CGFloat = 0

  public var body: some View {
    Group {
      VStack(alignment: .leading, spacing: 0) {
        switch thePool.layout {
        case .horizontal:
          ZStack {
            candidateListBackground
            HStack {
              mainViewHorizontal
              if thePool.maxLinesPerPage == 1 {
                rightPanes
              }
            }
          }
        default:
          mainViewVertical.background(candidateListBackground)
        }
        if thePool.maxLinesPerPage > 1 || thePool.layout == .vertical {
          if controller?.delegate?.showReverseLookupResult ?? true, !tooltip.isEmpty {
            ZStack(alignment: .leading) {
              bottomPanelBackgroundTDK
                .opacity(colorScheme == .dark ? 0 : 0.35)
              reverseLookupPane.padding([.top, .horizontal], 4).padding([.bottom], 2)
            }
          }
          statusBar.background(
            bottomPanelBackgroundTDK
              .opacity(colorScheme == .dark ? 0.35 : 0.5)
          )
        }
      }
      .frame(minWidth: windowWidth, maxWidth: windowWidth)
      .background(candidateListBackground)
      .overlay(
        RoundedRectangle(cornerRadius: 10).stroke(
          absoluteBackgroundColor.opacity(colorScheme == .dark ? 1 : 0.1), lineWidth: 0.5
        )
      )
      .cornerRadius(10)
    }
  }
}

// MARK: - Main Views.

@available(macOS 10.15, *)
extension VwrCandidateTDK {
  var mainViewHorizontal: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 1.6) {
        ForEach(thePool.lineRangeForCurrentPage, id: \.self) { rowIndex in
          ZStack(alignment: .leading) {
            lineBackground(lineID: rowIndex).cornerRadius(6)
            HStack(spacing: horizontalCellSpacing) {
              ForEach(Array(thePool.candidateLines[rowIndex]), id: \.self) { currentCandidate in
                drawCandidate(currentCandidate).fixedSize()
              }
            }
          }
          .opacity(rowIndex == thePool.currentLineNumber ? 1 : 0.95)
          .id(rowIndex)
        }
        if thePool.maxLinesPerPage - thePool.lineRangeForCurrentPage.count > 0 {
          ForEach(thePool.lineRangeForFinalPageBlanked, id: \.self) { _ in
            HStack(spacing: 0) {
              attributedStringFor(cell: thePool.blankCell)
                .frame(alignment: .topLeading)
                .contentShape(Rectangle())
              Spacer()
            }.frame(
              minWidth: 0,
              maxWidth: thePool.maxLinesPerPage != 1 ? .infinity : nil,
              alignment: .topLeading
            )
          }
        }
      }
    }
    .fixedSize(horizontal: thePool.maxLinesPerPage == 1, vertical: true)
    .padding([.horizontal, .top], 5)
    .padding([.bottom], thePool.maxLinesPerPage == 1 ? 5 : 2)
  }

  var mainViewVertical: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: 4) {
        ForEach(Array(thePool.lineRangeForCurrentPage.enumerated()), id: \.offset) { loopIndex, columnIndex in
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(thePool.candidateLines[columnIndex]), id: \.self) { currentCandidate in
              drawCandidate(currentCandidate)
            }
            if thePool.candidateLines[columnIndex].count < thePool.maxLineCapacity {
              ForEach(0 ..< thePool.dummyCellsRequiredForCurrentLine, id: \.self) { _ in
                drawCandidate(thePool.blankCell)
              }
            }
          }
          .background(lineBackground(lineID: columnIndex)).cornerRadius(6)
          .opacity(columnIndex == thePool.currentLineNumber ? 1 : 0.95)
          .frame(
            minWidth: thePool.maxLinesPerPage == 1
              ? max(Double(CandidateCellData.unifiedSize * 6), 90)
              : nil,
            alignment: .topLeading
          )
          .id(columnIndex)
          if thePool.maxLinesPerPage > 1, thePool.maxLinesPerPage <= loopIndex + 1 {
            Spacer(minLength: 0)
          }
        }
        if thePool.maxLinesPerPage - thePool.lineRangeForCurrentPage.count > 0 {
          ForEach(Array(thePool.lineRangeForFinalPageBlanked.enumerated()), id: \.offset) { loopIndex, _ in
            VStack(alignment: .leading, spacing: 0) {
              ForEach(0 ..< thePool.maxLineCapacity, id: \.self) { _ in
                attributedStringFor(cell: thePool.blankCell).fixedSize()
                  .frame(
                    width: ceil(thePool.blankCell.minWidthToDraw(isMatrix: true)),
                    alignment: .topLeading
                  )
                  .contentShape(Rectangle())
              }
            }.frame(
              minWidth: 0,
              maxWidth: .infinity,
              alignment: .topLeading
            )
            if thePool.maxLinesPerPage > 1,
               loopIndex >= thePool.maxLinesPerPage - thePool.lineRangeForCurrentPage.count - 1
            {
              Spacer(minLength: 0)
            }
          }
        }
      }
    }
    .fixedSize(horizontal: true, vertical: false)
    .padding([.horizontal, .top], 5)
    .padding([.bottom], thePool.maxLinesPerPage == 1 ? 5 : 2)
  }
}

// MARK: - Common Components.

@available(macOS 10.15, *)
extension VwrCandidateTDK {
  func drawCandidate(_ cell: CandidateCellData) -> some View {
    attributedStringFor(cell: cell)
      .frame(minWidth: cellWidth(cell).min, maxWidth: cellWidth(cell).max, alignment: .topLeading)
      .contentShape(Rectangle())
      .onTapGesture { didSelectCandidateAt(cell.index) }
      .contextMenu {
        if controller?.delegate?.isCandidateContextMenuEnabled ?? false {
          Button {
            didRightClickCandidateAt(cell.index, action: .toBoost)
          } label: {
            Text("↑ " + cell.displayedText)
          }
          Button {
            didRightClickCandidateAt(cell.index, action: .toNerf)
          } label: {
            Text("↓ " + cell.displayedText)
          }
          Button {
            didRightClickCandidateAt(cell.index, action: .toFilter)
          } label: {
            Text("✖︎ " + cell.displayedText)
          }
        }
      }
  }

  func lineBackground(lineID: Int) -> Color {
    let isCurrentLineInMatrix = lineID == thePool.currentLineNumber && thePool.maxLinesPerPage != 1
    switch thePool.layout {
    case .horizontal where isCurrentLineInMatrix:
      return Color.primary.opacity(0.05)
    case .vertical where isCurrentLineInMatrix:
      return absoluteBackgroundColor.opacity(0.15)
    default:
      return Color.clear
    }
  }

  func cellWidth(_ cell: CandidateCellData) -> (min: CGFloat?, max: CGFloat?) {
    let minAccepted = ceil(thePool.blankCell.minWidthToDraw(isMatrix: false) * 1.1)
    let defaultMin: CGFloat = cell.minWidthToDraw(isMatrix: thePool.maxLinesPerPage != 1)
    var min: CGFloat = defaultMin
    if thePool.layout != .vertical, thePool.maxLinesPerPage == 1 {
      min = max(minAccepted, cell.minWidthToDraw(isMatrix: false))
    }
    return (min, nil)
  }

  var windowWidth: CGFloat? {
    let paddings: CGFloat = 10.0
    let spacings: CGFloat = horizontalCellSpacing * Double(thePool.maxLineCapacity - 1)
    let maxWindowWith: CGFloat
      = ceil(
        Double(thePool.maxLineCapacity) * (thePool.blankCell.minWidthToDraw())
          + paddings + spacings
      )
    return thePool.layout == .horizontal && thePool.maxLinesPerPage > 1 ? maxWindowWith : nil
  }

  var firstReverseLookupResult: String {
    reverseLookupResult.first?.trimmingCharacters(in: .newlines) ?? ""
  }

  /// 以系統字型就給定的粗細狀態與字號來測量給定的字串的渲染寬度，且給出其「向上取整值」。
  /// - Remark: 所有 SwiftUI Text 元件必須手動在介面元素尺寸處理這方面加上向上取整的步驟，
  /// 否則的話：當元素尺寸不是整數、且整個視窗內部的 View 都在 .fixedSize() 的時候，
  /// 視窗內整個 View 的橫向或縱向起始座標可能就不是 0 而是 -0.5。
  /// - Parameters:
  ///   - text: 給定的字串。
  ///   - fontSize: 給定的字號。
  ///   - isBold: 給定的粗細狀態。
  /// - Returns: 測量出來的字串渲染寬度，經過向上取整之處理。
  func getTextWidth(text: String, fontSize: CGFloat, isBold: Bool) -> CGFloat? {
    guard !text.isEmpty else { return nil }
    let attributes: [NSAttributedString.Key: AnyObject] = [
      .font: NSFont.systemFont(ofSize: fontSize, weight: isBold ? .bold : .regular),
      .paragraphStyle: CandidateCellData.sharedParagraphStyle,
    ]
    let attrString = NSAttributedString(string: text, attributes: attributes)
    return ceil(attrString.boundingDimension.width)
  }

  var positionLabelView: some View {
    ZStack {
      Color(white: colorScheme == .dark ? 0.215 : 0.9).cornerRadius(4)
      Text(thePool.currentPositionLabelText).lineLimit(1)
        .font(.system(size: max(ceil(CandidateCellData.unifiedSize * 0.7), 11), weight: .bold))
        .frame(
          width: getTextWidth(
            text: thePool.currentPositionLabelText,
            fontSize: max(ceil(CandidateCellData.unifiedSize * 0.7), 11),
            isBold: true
          )
        )
        .padding([.horizontal], 2)
        .foregroundColor(.primary.opacity(0.8))
    }.fixedSize()
  }

  var rightPanes: some View {
    HStack {
      if !tooltip.isEmpty {
        ZStack(alignment: .center) {
          Circle().fill(highlightBackgroundTDK.opacity(0.8))
          Text(tooltip.first?.description ?? "").padding(2).font(.system(size: CandidateCellData.unifiedSize))
        }.frame(width: ceil(CandidateCellData.unifiedSize * 1.7), height: ceil(CandidateCellData.unifiedSize * 1.7))
      }
      VStack(alignment: .center, spacing: 1) {
        positionLabelView
        if controller?.delegate?.showReverseLookupResult ?? true {
          if !firstReverseLookupResult.isEmpty {
            ZStack(alignment: .center) {
              Color(white: colorScheme == .dark ? 0.2 : 0.9).cornerRadius(4)
              Text(firstReverseLookupResult)
                .font(.system(size: max(ceil(CandidateCellData.unifiedSize * 0.6), 9)))
                .frame(
                  width: getTextWidth(
                    text: firstReverseLookupResult,
                    fontSize: max(ceil(CandidateCellData.unifiedSize * 0.6), 9),
                    isBold: false
                  )
                )
                .opacity(0.8).padding([.horizontal], 4)
            }.fixedSize()
          }
        }
      }
      .opacity(0.9)
      .fixedSize()
      .padding([.trailing], 12)
    }
  }

  var reverseLookupPane: some View {
    HStack(alignment: .center, spacing: 2) {
      if thePool.maxLinesPerPage == 1 {
        if !firstReverseLookupResult.isEmpty {
          ZStack(alignment: .center) {
            Color(white: colorScheme == .dark ? 0.3 : 0.9).cornerRadius(3)
            Text("\(firstReverseLookupResult.trimmingCharacters(in: .newlines))")
              .lineLimit(1).padding([.horizontal], 2)
          }.fixedSize()
        }
      } else {
        Text("→").opacity(0.8)
        ForEach(reverseLookupResult, id: \.self) { currentResult in
          ZStack(alignment: .center) {
            Color(white: colorScheme == .dark ? 0.3 : 0.9).cornerRadius(3)
            Text("\(currentResult.trimmingCharacters(in: .newlines))")
              .lineLimit(1).padding([.horizontal], 2)
          }.fixedSize()
        }
      }
    }
    .font(.system(size: max(ceil(CandidateCellData.unifiedSize * 0.6), 9)))
    .foregroundColor(colorScheme == .light ? Color(white: 0.1) : Color(white: 0.9))
  }

  var statusBar: some View {
    HStack(alignment: .center) {
      if !tooltip.isEmpty {
        Text(tooltip).lineLimit(1)
      } else {
        if controller?.delegate?.showReverseLookupResult ?? true, tooltip.isEmpty {
          reverseLookupPane.padding(0)
        }
      }
      Spacer()
      positionLabelView
    }
    .font(.system(size: max(ceil(CandidateCellData.unifiedSize * 0.7), 11), weight: .bold))
    .padding([.bottom, .horizontal], 7).padding([.top], 2)
    .fixedSize(horizontal: false, vertical: true)
  }

  var highlightBackgroundTDK: Color {
    tooltip.isEmpty ? Color(white: colorScheme == .dark ? 0.2 : 0.9) : thePool.blankCell.themeColor
  }

  var candidateListBackground: some View {
    Group {
      absoluteBackgroundColor
      if colorScheme == .dark {
        Color.primary.opacity(0.05)
      } else {
        Color.primary.opacity(0.01)
      }
    }
  }

  var absoluteBackgroundColor: Color {
    if colorScheme == .dark {
      return Color(white: 0)
    } else {
      return Color(white: 1)
    }
  }

  var bottomPanelBackgroundTDK: Color {
    Color(white: colorScheme == .dark ? 0.145 : 0.95)
  }

  func attributedStringFor(cell theCell: CandidateCellData) -> some View {
    let defaultResult = theCell.attributedStringForSwiftUIBackports
    if forceCatalinaCompatibility {
      return defaultResult
    }
    if #available(macOS 12, *) {
      return theCell.attributedStringForSwiftUI
    }
    return defaultResult
  }
}

// MARK: - Delegate Methods

@available(macOS 10.15, *)
extension VwrCandidateTDK {
  func didSelectCandidateAt(_ pos: Int) {
    controller?.delegate?.candidatePairSelected(at: pos)
  }

  func didRightClickCandidateAt(_ pos: Int, action: CandidateContextMenuAction) {
    controller?.delegate?.candidatePairRightClicked(at: pos, action: action)
  }
}

// MARK: - Preview

import SwiftExtension

@available(macOS 10.15, *)
struct AttributedLabel_Previews: PreviewProvider {
  @State static var testCandidates: [String] = [
    "二十四歲是學生", "二十四歲", "昏睡紅茶", "食雪漢", "意味深", "學生", "便乗",
    "🐂🍺🐂🍺", "🐃🍺", "🐂🍺", "🐃🐂🍺🍺", "🐂🍺", "🐃🍺", "🐂🍺", "🐃🍺", "🐂🍺", "🐃🍺",
    "迫真", "驚愕", "論證", "正論", "惱", "悲", "屑", "食", "雪", "漢", "意", "味",
    "深", "二", "十", "四", "歲", "是", "學", "生", "昏", "睡", "紅", "茶", "便", "乗",
    "嗯", "哼", "啊",
  ]
  @State static var reverseLookupResult = ["mmmmm", "dddd"]
  @State static var tooltip = "📼"
  @State static var oldOS: Bool = true

  static var thePoolX: CandidatePool {
    var result = CandidatePool(
      candidates: testCandidates, lines: 4,
      selectionKeys: "123456", layout: .horizontal
    )
    result.reverseLookupResult = Self.reverseLookupResult
    result.tooltip = Self.tooltip
    result.highlight(at: 0)
    return result
  }

  static var thePoolXS: CandidatePool {
    var result = CandidatePool(
      candidates: testCandidates, lines: 1,
      selectionKeys: "123456", layout: .horizontal
    )
    result.reverseLookupResult = Self.reverseLookupResult
    result.tooltip = Self.tooltip
    result.highlight(at: 1)
    return result
  }

  static var thePoolY: CandidatePool {
    var result = CandidatePool(
      candidates: testCandidates, lines: 4,
      selectionKeys: "123456", layout: .vertical
    )
    result.reverseLookupResult = Self.reverseLookupResult
    result.tooltip = Self.tooltip
    result.flipPage(isBackward: false)
    result.highlight(at: 2)
    return result
  }

  static var thePoolYS: CandidatePool {
    var result = CandidatePool(
      candidates: testCandidates, lines: 1,
      selectionKeys: "123456", layout: .vertical
    )
    result.reverseLookupResult = Self.reverseLookupResult
    result.tooltip = Self.tooltip
    result.highlight(at: 1)
    return result
  }

  static var candidateListBackground: Color {
    if NSApplication.isDarkMode {
      return Color(white: 0.05)
    } else {
      return Color(white: 0.99)
    }
  }

  static var previews: some View {
    VStack {
      HStack(alignment: .top) {
        Text("田所選字窗 效能模式").bold().font(Font.system(.title))
        VStack {
          AttributedLabel(attributedString: Self.thePoolX.attributedDescription)
            .padding(5)
            .background(candidateListBackground)
            .cornerRadius(10).fixedSize()
          AttributedLabel(attributedString: Self.thePoolXS.attributedDescription)
            .padding(5)
            .background(candidateListBackground)
            .cornerRadius(10).fixedSize()
          HStack {
            AttributedLabel(attributedString: Self.thePoolY.attributedDescription)
              .padding(5)
              .background(candidateListBackground)
              .cornerRadius(10).fixedSize()
            AttributedLabel(attributedString: Self.thePoolYS.attributedDescription)
              .padding(5)
              .background(candidateListBackground)
              .cornerRadius(10).fixedSize()
          }
        }
      }
      Divider()
      HStack(alignment: .top) {
        Text("田所選字窗 SwiftUI 模式").bold().font(Font.system(.title))
        VStack {
          VwrCandidateTDK(controller: nil, thePool: thePoolX, forceCatalinaCompatibility: oldOS).fixedSize()
          VwrCandidateTDK(controller: nil, thePool: thePoolXS, forceCatalinaCompatibility: oldOS).fixedSize()
          HStack {
            VwrCandidateTDK(controller: nil, thePool: thePoolY, forceCatalinaCompatibility: oldOS).fixedSize()
            VwrCandidateTDK(controller: nil, thePool: thePoolYS, forceCatalinaCompatibility: oldOS).fixedSize()
          }
        }
      }
    }
  }
}