// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import SwiftExtension

// MARK: - CandidatePool

/// 候選字窗會用到的資料池單位，即用即拋。
public final class CandidatePool {
  // MARK: Lifecycle

  // MARK: - Constructors

  /// 初期化一個候選字窗專用資料池。
  /// - Parameters:
  ///   - candidates: 要塞入的候選字詞陣列。
  ///   - selectionKeys: 選字鍵。
  ///   - direction: 橫向排列還是縱向排列（預設情況下是縱向）。
  ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
  public init(
    candidates: [CandidateInState], lines: Int = 3,
    isExpanded expanded: Bool = true, selectionKeys: String = "123456789",
    layout: LayoutOrientation = .vertical, locale: String = ""
  ) {
    self._maxLinesPerPage = max(1, lines)
    self.isExpanded = expanded
    self.layout = .horizontal
    self.selectionKeys = "123456789"
    self.candidateDataAll = []
    // 以上只是為了糊弄 compiler。接下來才是正式的初期化。
    construct(candidates: candidates, selectionKeys: selectionKeys, layout: layout, locale: locale)
  }

  // MARK: Public

  public struct UIMetrics {
    static var allZeroed: Self {
      .init(
        fittingSize: .zero,
        highlightedLine: .zero,
        highlightedCandidate: .zero,
        peripherals: .zero
      )
    }

    let fittingSize: CGSize
    let highlightedLine: CGRect
    let highlightedCandidate: CGRect
    let peripherals: CGRect
  }

  // 只用來測量單漢字候選字 cell 的最大可能寬度。
  public static let shitCell = CandidateCellData(key: " ", displayedText: "💩", isSelected: false)
  public static let blankCell = CandidateCellData(key: " ", displayedText: "　", isSelected: false)

  public private(set) var _maxLinesPerPage: Int
  public private(set) var layout: LayoutOrientation
  public private(set) var selectionKeys: String
  public private(set) var candidateDataAll: [CandidateCellData]
  public private(set) var candidateLines: [[CandidateCellData]] = []
  public private(set) var highlightedIndex: Int = 0
  public private(set) var currentLineNumber = 0
  public private(set) var isExpanded: Bool = false
  public var metrics: UIMetrics = .allZeroed
  public var tooltip: String = ""
  public var reverseLookupResult: [String] = []

  // MARK: - 動態變數

  public let padding: CGFloat = 2
  public let originDelta: CGFloat = 5
  public let cellTextHeight = CandidatePool.shitCell.textDimension.height

  public var cellRadius: CGFloat {
    if #unavailable(macOS 11.0) { return 4 }
    if #unavailable(macOS 26.0) { return 6 }
    return floor(metrics.highlightedCandidate.height / 2)
  }

  public var windowRadius: CGFloat { originDelta + cellRadius }

  /// 當前資料池每頁顯示的最大行/列數。
  public var maxLinesPerPage: Int { isExpanded ? _maxLinesPerPage : 1 }

  /// 當前資料池是否正在以多列/多行的形式呈現候選字詞。
  public var isMatrix: Bool { maxLinesPerPage > 1 }

  /// 當前資料池是否能夠以多列/多行的形式呈現候選字詞。
  public var isExpandable: Bool { _maxLinesPerPage > 1 }

  /// 用來在初期化一個候選字詞資料池的時候研判「橫版多行選字窗每行最大應該塞多少個候選字詞」。
  /// 注意：該參數不用來計算視窗寬度，所以無須算上候選字詞間距。
  public var maxRowWidth: Double { ceil(Double(maxLineCapacity) * Self.blankCell.cellLength()) }

  /// 當前高亮的候選字詞的順序標籤（同時顯示資料池內已有的全部的候選字詞的數量）
  public var currentPositionLabelText: String {
    (highlightedIndex + 1).description + "/" + candidateDataAll.count.description
  }

  /// 當前高亮的候選字詞。
  public var currentCandidate: CandidateCellData? {
    (0 ..< candidateDataAll.count)
      .contains(highlightedIndex) ? candidateDataAll[highlightedIndex] : nil
  }

  /// 當前高亮的候選字詞的文本。如果相關資料不存在或者不合規的話，則返回空字串。
  public var currentSelectedCandidateText: String? { currentCandidate?.displayedText ?? nil }

  /// 每行/每列理論上應該最多塞多少個候選字詞。這其實就是當前啟用的選字鍵的數量。
  public var maxLineCapacity: Int { selectionKeys.count }

  /// 當選字窗處於單行模式時，如果一行內的內容過少的話，該變數會指出需要再插入多少個空白候選字詞單位。
  public var dummyCellsRequiredForCurrentLine: Int {
    maxLineCapacity - candidateLines[currentLineNumber].count
  }

  /// 如果當前的行數小於最大行數的話，該變數會指出還需要多少空白行。
  public var lineRangeForFinalPageBlanked: Range<Int> {
    0 ..< (maxLinesPerPage - lineRangeForCurrentPage.count)
  }

  /// 當前頁所在的行範圍。
  public var lineRangeForCurrentPage: Range<Int> {
    recordedLineRangeForCurrentPage ?? fallbackedLineRangeForCurrentPage
  }

  /// 當前高亮候選字所在的某個相容頁的行範圍。該參數僅用作墊底回退之用途、或者其它極端用途。
  public var fallbackedLineRangeForCurrentPage: Range<Int> {
    currentLineNumber ..< min(candidateLines.count, currentLineNumber + maxLinesPerPage)
  }

  /// 初期化一個候選字窗專用資料池。
  /// - Parameters:
  ///   - candidates: 要塞入的候選字詞陣列。
  ///   - selectionKeys: 選字鍵。
  ///   - direction: 橫向排列還是縱向排列（預設情況下是縱向）。
  ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
  public func reinit(
    candidates: [CandidateInState], lines: Int = 3,
    isExpanded expanded: Bool = true, selectionKeys: String = "123456789",
    layout: LayoutOrientation = .vertical, locale: String = ""
  ) {
    _maxLinesPerPage = max(1, lines)
    isExpanded = expanded
    self.layout = .horizontal
    self.selectionKeys = "123456789"
    candidateDataAll = []
    // 以上只是為了糊弄 compiler。接下來才是正式的初期化。
    construct(candidates: candidates, selectionKeys: selectionKeys, layout: layout, locale: locale)
  }

  public func cleanData() {
    recordedLineRangeForCurrentPage = nil
    previouslyRecordedLineRangeForPreviousPage = nil
    currentLineNumber = 0
    metrics = .allZeroed
    isExpanded = false
    tooltip = ""
    reverseLookupResult = []
  }

  // MARK: Private

  private var recordedLineRangeForCurrentPage: Range<Int>?
  private var previouslyRecordedLineRangeForPreviousPage: Range<Int>?

  /// 初期化（或者自我重新初期化）一個候選字窗專用資料池。
  /// - Parameters:
  ///   - candidates: 要塞入的候選字詞陣列。
  ///   - selectionKeys: 選字鍵。
  ///   - direction: 橫向排列還是縱向排列（預設情況下是縱向）。
  ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
  private func construct(
    candidates: [CandidateInState], selectionKeys: String = "123456789",
    layout: LayoutOrientation = .vertical, locale: String = ""
  ) {
    self.layout = layout
    Self.blankCell.locale = locale
    self.selectionKeys = selectionKeys.isEmpty ? "123456789" : selectionKeys
    cleanData()
    var allCandidates = candidates.map {
      CandidateCellData(key: " ", displayedText: $0.value, segLength: $0.keyArray.count)
    }
    if allCandidates.isEmpty { allCandidates.append(Self.blankCell) }
    candidateDataAll = allCandidates
    candidateLines.removeAll()
    var currentColumn: [CandidateCellData] = []
    for (i, candidate) in candidateDataAll.enumerated() {
      candidate.index = i
      candidate.whichLine = candidateLines.count
      var isOverflown: Bool = (currentColumn.count == maxLineCapacity) && !currentColumn.isEmpty
      if layout == .horizontal {
        let accumulatedWidth: Double = currentColumn.map { $0.cellLength() }.reduce(0, +)
        let remainingSpaceWidth: Double = maxRowWidth - candidate.cellLength()
        isOverflown = isOverflown || accumulatedWidth > remainingSpaceWidth
      }
      if isOverflown {
        candidateLines.append(currentColumn)
        currentColumn.removeAll()
        candidate.whichLine += 1
      }
      candidate.subIndex = currentColumn.count
      candidate.locale = locale
      currentColumn.append(candidate)
    }
    candidateLines.append(currentColumn)
    recordedLineRangeForCurrentPage = fallbackedLineRangeForCurrentPage
    highlight(at: 0)
    updateMetrics()
  }
}

// MARK: - Public Functions (for all OS)

extension CandidatePool {
  /// 選字窗的候選字詞陳列方向。
  public enum LayoutOrientation {
    case horizontal
    case vertical
  }

  public func update() {
    if #available(macOS 10.15, *) {
      asyncOnMain { [weak self] in
        guard let self = self else { return }
        self.objectWillChange.send()
      }
    }
  }

  public func expandIfNeeded(isBackward: Bool) {
    guard !candidateLines.isEmpty, !isExpanded, isExpandable else { return }
    let candidatesShown: [CandidateCellData] = candidateLines[lineRangeForCurrentPage]
      .flatMap { $0 }
    guard !candidatesShown.filter(\.isHighlighted).isEmpty else { return }
    isExpanded = true
    if candidateLines.count <= _maxLinesPerPage {
      recordedLineRangeForCurrentPage = lineRangeForFirstPage
    } else {
      switch isBackward {
      case true:
        if lineRangeForFirstPage.contains(currentLineNumber) {
          recordedLineRangeForCurrentPage = lineRangeForFirstPage
        } else {
          recordedLineRangeForCurrentPage = max(0, currentLineNumber - _maxLinesPerPage + 1) ..<
            currentLineNumber + 1
        }
      case false:
        if lineRangeForFinalPage.contains(currentLineNumber) {
          recordedLineRangeForCurrentPage = lineRangeForFinalPage
        } else {
          recordedLineRangeForCurrentPage = currentLineNumber ..< min(
            candidateLines.count,
            currentLineNumber + _maxLinesPerPage
          )
        }
      }
    }
    updateMetrics()
  }

  /// 往指定的方向翻頁。
  /// - Parameter isBackward: 是否逆向翻頁。
  /// - Returns: 操作是否順利。
  @discardableResult
  public func flipPage(isBackward: Bool) -> Bool {
    if !isExpanded, isExpandable {
      expandIfNeeded(isBackward: isBackward)
      return true
    }
    backupLineRangeForCurrentPage()
    defer { flipLineRangeToNeighborPage(isBackward: isBackward) }
    var theCount = maxLinesPerPage
    let rareConditionA: Bool = isBackward && currentLineNumber == 0
    let rareConditionB: Bool = !isBackward && currentLineNumber == candidateLines.count - 1
    if rareConditionA || rareConditionB { theCount = 1 }
    return consecutivelyFlipLines(isBackward: isBackward, count: theCount)
  }

  /// 嘗試用給定的行內編號推算該候選字在資料池內的總編號。
  /// - Parameter subIndex: 給定的行內編號。
  /// - Returns: 推算結果（可能會是 nil）。
  public func calculateCandidateIndex(subIndex: Int) -> Int? {
    let arrCurrentLine = candidateLines[currentLineNumber]
    if !(0 ..< arrCurrentLine.count).contains(subIndex) { return nil }
    return arrCurrentLine[subIndex].index
  }

  /// 往指定的方向連續翻行。
  /// - Parameters:
  ///   - isBackward: 是否逆向翻行。
  ///   - count: 翻幾行。
  /// - Returns: 操作是否順利。
  @discardableResult
  public func consecutivelyFlipLines(isBackward: Bool, count givenCount: Int) -> Bool {
    expandIfNeeded(isBackward: isBackward)
    switch isBackward {
    case false where currentLineNumber == candidateLines.count - 1:
      return highlightNeighborCandidate(isBackward: false)
    case true where currentLineNumber == 0:
      return highlightNeighborCandidate(isBackward: true)
    default:
      if givenCount <= 0 { return false }
      for _ in 0 ..< min(maxLinesPerPage, givenCount) {
        selectNewNeighborLine(isBackward: isBackward)
      }
      return true
    }
  }

  /// 嘗試高亮前方或者後方的鄰近候選字詞。
  /// - Parameter isBackward: 是否是後方的鄰近候選字詞。
  /// - Returns: 是否成功。
  @discardableResult
  public func highlightNeighborCandidate(isBackward: Bool) -> Bool {
    switch isBackward {
    case false where highlightedIndex >= candidateDataAll.count - 1:
      highlight(at: 0)
      return false
    case true where highlightedIndex <= 0:
      highlight(at: candidateDataAll.count - 1)
      return false
    default:
      highlight(at: highlightedIndex + (isBackward ? -1 : 1))
      return true
    }
  }

  /// 高亮指定的候選字。
  /// - Parameter indexSpecified: 給定的候選字詞索引編號，得是資料池內的總索引編號。
  public func highlight(at indexSpecified: Int) {
    var indexSpecified = indexSpecified
    let isBackward: Bool = indexSpecified > highlightedIndex
    highlightedIndex = indexSpecified
    if !(0 ..< candidateDataAll.count).contains(highlightedIndex) {
      switch highlightedIndex {
      case candidateDataAll.count...:
        currentLineNumber = candidateLines.count - 1
        highlightedIndex = max(0, candidateDataAll.count - 1)
        indexSpecified = highlightedIndex
      case ..<0:
        highlightedIndex = 0
        currentLineNumber = 0
        indexSpecified = highlightedIndex
      default: break
      }
    }
    for (i, candidate) in candidateDataAll.enumerated() {
      candidate.isHighlighted = (indexSpecified == i)
      if candidate.isHighlighted { currentLineNumber = candidate.whichLine }
    }
    for (i, candidateColumn) in candidateLines.enumerated() {
      if i != currentLineNumber {
        candidateColumn.forEach {
          $0.selectionKey = " "
        }
      } else {
        for (i, neta) in candidateColumn.enumerated() {
          if neta.selectionKey.isEmpty { continue }
          neta.selectionKey = selectionKeys.map(\.description)[i]
        }
      }
    }
    if highlightedIndex != 0, indexSpecified == 0 {
      recordedLineRangeForCurrentPage = fallbackedLineRangeForCurrentPage
    } else {
      fixLineRange(isBackward: isBackward)
    }
  }

  public func cellWidth(_ cell: CandidateCellData) -> (min: CGFloat?, max: CGFloat?) {
    let minAccepted = ceil(Self.shitCell.cellLength(isMatrix: false))
    let defaultMin: CGFloat = cell.cellLength(isMatrix: maxLinesPerPage != 1)
    var min: CGFloat = defaultMin
    if layout != .vertical, maxLinesPerPage == 1 {
      min = max(minAccepted, cell.cellLength(isMatrix: false))
    } else if layout == .vertical, maxLinesPerPage == 1 {
      min = max(Double(CandidateCellData.unifiedSize * 6), ceil(cell.size * 5.6))
    }
    return (min, nil)
  }

  public func isFilterable(target index: Int) -> Bool {
    let segLength = candidateDataAll[index].segLength
    guard segLength == 1 else { return true }
    return cellsOf(segLength: segLength).count > 1
  }

  public func cellsOf(segLength: Int) -> [CandidateCellData] {
    candidateDataAll.filter { $0.segLength == segLength }
  }
}

// MARK: - Privates.

extension CandidatePool {
  fileprivate enum VerticalDirection {
    case up
    case down
  }

  fileprivate enum HorizontalDirection {
    case left
    case right
  }

  /// 第一頁所在的行範圍。
  fileprivate var lineRangeForFirstPage: Range<Int> {
    0 ..< min(maxLinesPerPage, candidateLines.count)
  }

  /// 最後一頁所在的行範圍。
  fileprivate var lineRangeForFinalPage: Range<Int> {
    max(0, candidateLines.count - maxLinesPerPage) ..< candidateLines.count
  }

  fileprivate func selectNewNeighborLine(isBackward: Bool) {
    switch layout {
    case .horizontal: selectNewNeighborRow(direction: isBackward ? .up : .down)
    case .vertical: selectNewNeighborColumn(direction: isBackward ? .left : .right)
    }
  }

  fileprivate func fixLineRange(isBackward: Bool = false) {
    if !lineRangeForCurrentPage.contains(currentLineNumber) {
      switch isBackward {
      case false:
        let theMin = currentLineNumber
        let theMax = min(theMin + maxLinesPerPage, candidateLines.count)
        recordedLineRangeForCurrentPage = theMin ..< theMax
      case true:
        let theMax = currentLineNumber + 1
        let theMin = max(0, theMax - maxLinesPerPage)
        recordedLineRangeForCurrentPage = theMin ..< theMax
      }
    }
  }

  fileprivate func backupLineRangeForCurrentPage() {
    previouslyRecordedLineRangeForPreviousPage = lineRangeForCurrentPage
  }

  fileprivate func flipLineRangeToNeighborPage(isBackward: Bool = false) {
    guard let prevRange = previouslyRecordedLineRangeForPreviousPage else { return }
    var lowerBound = prevRange.lowerBound
    var upperBound = prevRange.upperBound
    // 先對上下邊界資料值做模進處理。
    lowerBound += maxLinesPerPage * (isBackward ? -1 : 1)
    upperBound += maxLinesPerPage * (isBackward ? -1 : 1)
    // 然後糾正可能出錯的資料值。
    branch1: switch isBackward {
    case false:
      if upperBound < candidateLines.count { break branch1 }
      if lowerBound < lineRangeForFinalPage.lowerBound { break branch1 }
      let isOverFlipped = !lineRangeForFinalPage.contains(currentLineNumber)
      recordedLineRangeForCurrentPage = isOverFlipped ? lineRangeForFirstPage :
        lineRangeForFinalPage
      return
    case true:
      if lowerBound > 0 { break branch1 }
      if upperBound > lineRangeForFirstPage.upperBound { break branch1 }
      let isOverFlipped = !lineRangeForFirstPage.contains(currentLineNumber)
      recordedLineRangeForCurrentPage = isOverFlipped ? lineRangeForFinalPage :
        lineRangeForFirstPage
      return
    }
    let result = lowerBound ..< upperBound
    if result.contains(currentLineNumber) {
      recordedLineRangeForCurrentPage = result
      return
    }
    // 應該不會有漏檢的情形了。
  }

  fileprivate func selectNewNeighborRow(direction: VerticalDirection) {
    let currentSubIndex = candidateDataAll[highlightedIndex].subIndex
    var result = currentSubIndex
    branch: switch direction {
    case .up:
      if currentLineNumber <= 0 {
        if candidateLines.isEmpty { break }
        let firstRow = candidateLines[0]
        let newSubIndex = min(currentSubIndex, firstRow.count - 1)
        highlight(at: firstRow[newSubIndex].index)
        fixLineRange(isBackward: false)
        break branch
      }
      if currentLineNumber >= candidateLines
        .count - 1 { currentLineNumber = candidateLines.count - 1 }
      result = currentSubIndex
      // 考慮到選字窗末行往往都是將選字窗貼左排列的（而非左右平鋪排列），所以這裡對「↑」鍵不採用這段特殊處理。
      // if candidateLines[currentLineNumber].count != candidateLines[currentLineNumber - 1].count {
      //   let ratio: Double = min(1, Double(currentSubIndex) / Double(candidateLines[currentLineNumber].count))
      //   result = max(Int(floor(Double(candidateLines[currentLineNumber - 1].count) * ratio)), result)
      // }
      let targetRow = candidateLines[currentLineNumber - 1]
      let newSubIndex = min(result, targetRow.count - 1)
      highlight(at: targetRow[newSubIndex].index)
      fixLineRange(isBackward: true)
    case .down:
      if currentLineNumber >= candidateLines.count - 1 {
        if candidateLines.isEmpty { break }
        let finalRow = candidateLines[candidateLines.count - 1]
        let newSubIndex = min(currentSubIndex, finalRow.count - 1)
        highlight(at: finalRow[newSubIndex].index)
        fixLineRange(isBackward: true)
        break branch
      }
      result = currentSubIndex
      // 特殊處理。
      if candidateLines[currentLineNumber].count != candidateLines[currentLineNumber + 1].count {
        let ratio: Double = min(
          1,
          Double(currentSubIndex) / Double(candidateLines[currentLineNumber].count)
        )
        result = max(
          Int(floor(Double(candidateLines[currentLineNumber + 1].count) * ratio)),
          result
        )
      }
      let targetRow = candidateLines[currentLineNumber + 1]
      let newSubIndex = min(result, targetRow.count - 1)
      highlight(at: targetRow[newSubIndex].index)
      fixLineRange(isBackward: false)
    }
  }

  fileprivate func selectNewNeighborColumn(direction: HorizontalDirection) {
    let currentSubIndex = candidateDataAll[highlightedIndex].subIndex
    switch direction {
    case .left:
      if currentLineNumber <= 0 {
        if candidateLines.isEmpty { break }
        let firstColumn = candidateLines[0]
        let newSubIndex = min(currentSubIndex, firstColumn.count - 1)
        highlight(at: firstColumn[newSubIndex].index)
        break
      }
      if currentLineNumber >= candidateLines
        .count - 1 { currentLineNumber = candidateLines.count - 1 }
      let targetColumn = candidateLines[currentLineNumber - 1]
      let newSubIndex = min(currentSubIndex, targetColumn.count - 1)
      highlight(at: targetColumn[newSubIndex].index)
      fixLineRange(isBackward: true)
    case .right:
      if currentLineNumber >= candidateLines.count - 1 {
        if candidateLines.isEmpty { break }
        let finalColumn = candidateLines[candidateLines.count - 1]
        let newSubIndex = min(currentSubIndex, finalColumn.count - 1)
        highlight(at: finalColumn[newSubIndex].index)
        break
      }
      let targetColumn = candidateLines[currentLineNumber + 1]
      let newSubIndex = min(currentSubIndex, targetColumn.count - 1)
      highlight(at: targetColumn[newSubIndex].index)
      fixLineRange(isBackward: false)
    }
  }
}

// MARK: ObservableObject

@available(macOS 10.15, *)
extension CandidatePool: ObservableObject {}
