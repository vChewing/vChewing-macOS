// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared
import SwiftExtension

// MARK: - TDK4AppKit.CandidatePool4AppKit

extension TDK4AppKit {
  // MARK: - CandidatePool

  /// 候選字窗會用到的資料池單位，即用即拋。
  final class CandidatePool4AppKit: Sendable {
    // MARK: Lifecycle

    // MARK: - Constructors

    /// 初期化一個候選字窗專用資料池。
    /// - Parameters:
    ///   - candidates: 要塞入的候選字詞陣列。
    ///   - selectionKeys: 選字鍵。
    ///   - direction: 橫向排列還是縱向排列（預設情況下是縱向）。
    ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
    init(
      candidates: [CandidateInState], lines: Int = 3,
      isExpanded expanded: Bool = true, selectionKeys: String = "123456789",
      layout: UILayoutOrientation = .vertical, locale: String = ""
    ) {
      self._maxLinesPerPage = max(1, lines)
      self.isExpanded = expanded
      self.layout = .horizontal
      self.selectionKeys = "123456789"
      self.candidateDataAll = []
      // 以上只是為了糊弄 compiler。接下來才是正式的初期化。
      construct(candidates: candidates, selectionKeys: selectionKeys, layout: layout, locale: locale)
    }

    // MARK: Internal

    typealias CandidateCellData4AppKit = TDK4AppKit.CandidateCellData4AppKit

    struct UIMetrics {
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
    static let shitCell = CandidateCellData4AppKit(key: " ", displayedText: "💩", isSelected: false)
    static let blankCell = CandidateCellData4AppKit(key: " ", displayedText: "　", isSelected: false)

    private(set) var _maxLinesPerPage: Int
    private(set) var layout: UILayoutOrientation
    private(set) var selectionKeys: String
    private(set) var candidateDataAll: [CandidateCellData4AppKit]
    private(set) var candidateLines: [[CandidateCellData4AppKit]] = []
    private(set) var highlightedIndex: Int = 0
    private(set) var currentLineNumber = 0
    private(set) var isExpanded: Bool = false
    var metrics: UIMetrics = .allZeroed
    var tooltip: String = ""
    var reverseLookupResult: [String] = []

    // MARK: - 動態變數

    let padding: CGFloat = 2
    let originDelta: CGFloat = 5
    let cellTextHeight = CandidatePool4AppKit.shitCell.textDimension.height

    var cellRadius: CGFloat {
      if #unavailable(macOS 11.0) { return 4 }
      if #unavailable(macOS 26.0) { return 6 }
      return floor(metrics.highlightedCandidate.height / 2)
    }

    var windowRadius: CGFloat { originDelta + cellRadius }

    /// 當前資料池每頁顯示的最大行/列數。
    var maxLinesPerPage: Int { isExpanded ? _maxLinesPerPage : 1 }

    /// 當前資料池是否正在以多列/多行的形式呈現候選字詞。
    var isMatrix: Bool { maxLinesPerPage > 1 }

    /// 當前資料池是否能夠以多列/多行的形式呈現候選字詞。
    var isExpandable: Bool { _maxLinesPerPage > 1 }

    /// 用來在初期化一個候選字詞資料池的時候研判「橫版多行選字窗每行最大應該塞多少個候選字詞」。
    /// 注意：該參數不用來計算視窗寬度，所以無須算上候選字詞間距。
    var maxRowWidth: Double { ceil(Double(maxLineCapacity) * Self.blankCell.cellLength()) }

    /// 當前高亮的候選字詞的順序標籤（同時顯示資料池內已有的全部的候選字詞的數量）
    var currentPositionLabelText: String {
      (highlightedIndex + 1).description + "/" + candidateDataAll.count.description
    }

    /// 當前高亮的候選字詞。
    var currentCandidate: CandidateCellData4AppKit? {
      (0 ..< candidateDataAll.count)
        .contains(highlightedIndex) ? candidateDataAll[highlightedIndex] : nil
    }

    /// 當前高亮的候選字詞的文本。如果相關資料不存在或者不合規的話，則返回空字串。
    var currentSelectedCandidateText: String? { currentCandidate?.displayedText ?? nil }

    /// 每行/每列理論上應該最多塞多少個候選字詞。這其實就是當前啟用的選字鍵的數量。
    var maxLineCapacity: Int { selectionKeys.count }

    /// 當選字窗處於單行模式時，如果一行內的內容過少的話，該變數會指出需要再插入多少個空白候選字詞單位。
    var dummyCellsRequiredForCurrentLine: Int {
      maxLineCapacity - candidateLines[currentLineNumber].count
    }

    /// 如果當前的行數小於最大行數的話，該變數會指出還需要多少空白行。
    var lineRangeForFinalPageBlanked: Range<Int> {
      0 ..< (maxLinesPerPage - lineRangeForCurrentPage.count)
    }

    /// 當前頁所在的行範圍。
    var lineRangeForCurrentPage: Range<Int> {
      recordedLineRangeForCurrentPage ?? fallbackedLineRangeForCurrentPage
    }

    /// 當前高亮候選字所在的某個相容頁的行範圍。該參數僅用作墊底回退之用途、或者其它極端用途。
    var fallbackedLineRangeForCurrentPage: Range<Int> {
      currentLineNumber ..< min(candidateLines.count, currentLineNumber + maxLinesPerPage)
    }

    /// 初期化一個候選字窗專用資料池。
    /// - Parameters:
    ///   - candidates: 要塞入的候選字詞陣列。
    ///   - selectionKeys: 選字鍵。
    ///   - direction: 橫向排列還是縱向排列（預設情況下是縱向）。
    ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
    func reinit(
      candidates: [CandidateInState], lines: Int = 3,
      isExpanded expanded: Bool = true, selectionKeys: String = "123456789",
      layout: UILayoutOrientation = .vertical, locale: String = ""
    ) {
      _maxLinesPerPage = max(1, lines)
      isExpanded = expanded
      self.layout = .horizontal
      self.selectionKeys = "123456789"
      candidateDataAll = []
      // 以上只是為了糊弄 compiler。接下來才是正式的初期化。
      construct(candidates: candidates, selectionKeys: selectionKeys, layout: layout, locale: locale)
    }

    nonisolated func cleanData() {
      mainSync {
        self.cleanDataOnMain()
      }
    }

    func cleanDataOnMain() {
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
      layout: UILayoutOrientation = .vertical, locale: String = ""
    ) {
      self.layout = layout
      Self.blankCell.locale = locale
      self.selectionKeys = selectionKeys.isEmpty ? "123456789" : selectionKeys
      cleanDataOnMain()
      var allCandidates = candidates.map {
        CandidateCellData4AppKit(key: " ", displayedText: $0.value, segLength: $0.keyArray.count)
      }
      if allCandidates.isEmpty { allCandidates.append(Self.blankCell) }
      candidateDataAll = allCandidates
      candidateLines.removeAll()
      var currentColumn: [CandidateCellData4AppKit] = []
      let minCellWidth = Self.blankCell.cellLength()
      // 注意：此處使用 _maxLinesPerPage 而非 isMatrix，因為 cleanData() 會重設 isExpanded。
      let shouldCalculateRowWidth = (layout == .horizontal) && (_maxLinesPerPage > 1)
      for (i, candidate) in candidateDataAll.enumerated() {
        candidate.index = i
        candidate.whichLine = candidateLines.count
        var isOverflown: Bool = (currentColumn.count == maxLineCapacity) && !currentColumn.isEmpty
        if shouldCalculateRowWidth {
          // 使用倍數化寬度來計算行容量。
          let accumulatedWidth: Double = currentColumn.map {
            $0.cellWidthMultiplied(minCellWidth: minCellWidth)
          }.reduce(0, +)
          let candidateWidth = candidate.cellWidthMultiplied(minCellWidth: minCellWidth)
          let remainingSpaceWidth: Double = maxRowWidth - candidateWidth
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
} // extension TDK4AppKit

extension TDK4AppKit.CandidatePool4AppKit {
  func expandIfNeeded(isBackward: Bool) {
    guard !candidateLines.isEmpty, !isExpanded, isExpandable else { return }
    let candidatesShown: [CandidateCellData4AppKit] = candidateLines[lineRangeForCurrentPage]
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
  func flipPage(isBackward: Bool) -> Bool {
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
  func calculateCandidateIndex(subIndex: Int) -> Int? {
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
  func consecutivelyFlipLines(isBackward: Bool, count givenCount: Int) -> Bool {
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
  func highlightNeighborCandidate(isBackward: Bool) -> Bool {
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
  func highlight(at indexSpecified: Int) {
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

  func cellWidth(_ cell: CandidateCellData4AppKit) -> (min: CGFloat?, max: CGFloat?) {
    let minAccepted = ceil(Self.shitCell.cellLength(isMatrix: false))
    let defaultMin: CGFloat = cell.cellLength(isMatrix: maxLinesPerPage != 1)
    var min: CGFloat = defaultMin
    if layout != .vertical, maxLinesPerPage == 1 {
      min = max(minAccepted, cell.cellLength(isMatrix: false))
    } else if layout == .vertical, maxLinesPerPage == 1 {
      min = max(Double(CandidateCellData4AppKit.unifiedSize * 6), ceil(cell.size * 5.6))
    }
    return (min, nil)
  }

  func isFilterable(target index: Int) -> Bool {
    let segLength = candidateDataAll[index].segLength
    guard segLength == 1 else { return true }
    return cellsOf(segLength: segLength).count > 1
  }

  func cellsOf(segLength: Int) -> [CandidateCellData4AppKit] {
    candidateDataAll.filter { $0.segLength == segLength }
  }
}

// MARK: - Privates.

extension TDK4AppKit.CandidatePool4AppKit {
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
    let minCellWidth = Self.blankCell.cellLength()
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
      let targetRow = candidateLines[currentLineNumber - 1]
      // Horizontal matrix 模式：基於 X 軸位置找最接近的 cell。
      if _maxLinesPerPage > 1 {
        let currentRow = candidateLines[currentLineNumber]
        result = Self.findClosestSubIndex(
          from: (currentRow, currentSubIndex),
          to: targetRow, minCellWidth: minCellWidth
        )
      }
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
      let targetRow = candidateLines[currentLineNumber + 1]
      // Horizontal matrix 模式：基於 X 軸位置找最接近的 cell。
      if _maxLinesPerPage > 1 {
        let currentRow = candidateLines[currentLineNumber]
        result = Self.findClosestSubIndex(
          from: (currentRow, currentSubIndex),
          to: targetRow, minCellWidth: minCellWidth
        )
      }
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

extension TDK4AppKit.CandidatePool4AppKit {
  /// 計算從一行移動到另一行時，基於 X 軸位置找到最接近的 cell 的 subIndex。
  fileprivate static func findClosestSubIndex(
    from sourceIntel: (row: [CandidateCellData4AppKit], subIndex: Int),
    to targetRow: [CandidateCellData4AppKit], minCellWidth: Double
  )
    -> Int {
    let (sourceRow, sourceSubIndex) = sourceIntel
    guard !targetRow.isEmpty else { return 0 }
    // 計算當前 cell 的 X 軸中心位置。
    var currentCellCenterX: Double = 0
    for (i, cell) in sourceRow.enumerated() {
      let cellWidth = cell.cellWidthMultiplied(minCellWidth: minCellWidth)
      if i < sourceSubIndex {
        currentCellCenterX += cellWidth
      } else if i == sourceSubIndex {
        currentCellCenterX += cellWidth / 2
        break
      }
    }
    // 在目標行中找到 X 位置最接近的 cell。
    var bestIndex = 0
    var bestDistance = Double.greatestFiniteMagnitude
    var accumulatedX: Double = 0
    for (i, cell) in targetRow.enumerated() {
      let cellWidth = cell.cellWidthMultiplied(minCellWidth: minCellWidth)
      let cellCenterX = accumulatedX + cellWidth / 2
      let distance = abs(cellCenterX - currentCellCenterX)
      if distance < bestDistance {
        bestDistance = distance
        bestIndex = i
      }
      accumulatedX += cellWidth
    }
    return bestIndex
  }
}

extension NSColor {
  fileprivate static var dark: NSColor { NSColor(calibratedWhite: 0.12, alpha: 1) }
}

// MARK: - RoundedBadgeTextAttachmentCell

private final class RoundedBadgeTextAttachmentCell: NSTextAttachmentCell {
  // MARK: Lifecycle

  init(
    label: String,
    attributes: [NSAttributedString.Key: Any],
    backgroundColor: NSColor,
    padding: NSEdgeInsets
  ) {
    self.text = NSAttributedString(string: label, attributes: attributes)
    self.backgroundColor = backgroundColor
    self.padding = padding

    let constraint = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    let textBounds = text.boundingRect(
      with: constraint,
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    var size = CGSize(
      width: ceil(textBounds.width) + padding.left + padding.right,
      height: ceil(textBounds.height) + padding.top + padding.bottom
    )
    if let font = attributes[.font] as? NSFont {
      let ascent = font.ascender
      let descent = -font.descender
      let lineHeight = ceil(ascent + descent)
      size.height = max(size.height, lineHeight + padding.top + padding.bottom)
    }
    self.cachedSize = size
    self.cornerRadius = size.height / 2
    super.init()
  }

  @available(*, unavailable)
  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  // MARK: NSTextAttachmentCell

  nonisolated override func cellSize() -> CGSize { cachedSize }

  override func draw(withFrame cellFrame: CGRect, in controlView: NSView?, characterIndex: Int) {
    backgroundColor.setFill()
    NSBezierPath(roundedRect: cellFrame, xRadius: cornerRadius, yRadius: cornerRadius).fill()

    let textRect = CGRect(
      x: cellFrame.origin.x + padding.left,
      y: cellFrame.origin.y + padding.bottom,
      width: cellFrame.width - padding.left - padding.right,
      height: cellFrame.height - padding.top - padding.bottom
    )
    text.draw(in: textRect)
  }

  // MARK: Private

  private let text: NSAttributedString
  private let backgroundColor: NSColor
  private let cornerRadius: CGFloat
  private let padding: NSEdgeInsets
  private let cachedSize: CGSize
}

// MARK: - UI Metrics.

extension TDK4AppKit.CandidatePool4AppKit {
  func updateMetrics() {
    // 開工
    let initialOrigin: CGPoint = .init(x: originDelta, y: originDelta)
    var totalAccuSize: CGSize = .zero
    // Origin is at the top-left corner.
    var currentOrigin: CGPoint = initialOrigin
    var highlightedCellRect: CGRect = .zero
    var highlightedLineRect: CGRect = .zero
    var currentPageLines = candidateLines[lineRangeForCurrentPage]
    var blankLines = maxLinesPerPage - currentPageLines.count
    var fillBlankCells = true
    switch (layout, isMatrix) {
    case (.horizontal, false):
      blankLines = 0
      fillBlankCells = false
    case (.vertical, false): blankLines = 0
    case (_, true): break
    }
    while blankLines > 0 {
      currentPageLines.append(.init(repeating: Self.shitCell, count: maxLineCapacity))
      blankLines -= 1
    }
    Self.shitCell.updateMetrics(pool: self, origin: currentOrigin)
    Self.shitCell.isHighlighted = false
    let minimumCellDimension = Self.shitCell.visualDimension
    let minCellWidth = Self.blankCell.cellLength()
    currentPageLines.forEach { currentLine in
      let currentLineOrigin = currentOrigin
      var accumulatedLineSize: CGSize = .zero
      var currentLineRect: CGRect { .init(origin: currentLineOrigin, size: accumulatedLineSize) }
      let lineHasHighlightedCell = currentLine.hasHighlightedCell

      currentLine.forEach { currentCell in
        currentCell.updateMetrics(pool: self, origin: currentOrigin)
        var cellDimension = currentCell.visualDimension
        // Horizontal matrix 模式：使用倍數化寬度。
        if layout == .horizontal, isMatrix {
          cellDimension.width = currentCell.cellWidthMultiplied(minCellWidth: minCellWidth)
        } else if layout == .vertical || currentCell.displayedText.count <= 2 {
          cellDimension.width = max(minimumCellDimension.width, cellDimension.width)
        }
        cellDimension.height = max(minimumCellDimension.height, cellDimension.height)
        // 更新 visualDimension 供後續使用。
        currentCell.visualDimension.width = cellDimension.width

        switch self.layout {
        case .horizontal:
          accumulatedLineSize.width += cellDimension.width
          accumulatedLineSize.height = max(accumulatedLineSize.height, cellDimension.height)
        case .vertical:
          accumulatedLineSize.height += cellDimension.height
          accumulatedLineSize.width = max(accumulatedLineSize.width, cellDimension.width)
        }

        if lineHasHighlightedCell {
          switch self.layout {
          case .horizontal where currentCell.isHighlighted:
            highlightedCellRect.size.width = cellDimension.width
          case .vertical:
            highlightedCellRect.size.width = max(
              highlightedCellRect.size.width,
              cellDimension.width
            )
          default: break
          }
          if currentCell.isHighlighted {
            highlightedCellRect.origin = currentOrigin
            highlightedCellRect.size.height = cellDimension.height
          }
        }

        switch self.layout {
        case .horizontal: currentOrigin.x += cellDimension.width
        case .vertical: currentOrigin.y += cellDimension.height
        }
      }

      if lineHasHighlightedCell {
        highlightedLineRect.origin = currentLineRect.origin
        switch self.layout {
        case .horizontal:
          highlightedLineRect.size.height = currentLineRect.size.height
        case .vertical:
          highlightedLineRect.size.width = currentLineRect.size.width
        }
      }

      switch self.layout {
      case .horizontal:
        highlightedLineRect.size.width = max(currentLineRect.size.width, highlightedLineRect.width)
      case .vertical:
        highlightedLineRect.size.height = max(
          currentLineRect.size.height,
          highlightedLineRect.height
        )
        currentLine.forEach { theCell in
          theCell.visualDimension.width = accumulatedLineSize.width
        }
      }

      switch self.layout {
      case .horizontal:
        currentOrigin.x = originDelta
        currentOrigin.y += accumulatedLineSize.height
        totalAccuSize.width = max(totalAccuSize.width, accumulatedLineSize.width)
        totalAccuSize.height += accumulatedLineSize.height
      case .vertical:
        currentOrigin.y = originDelta
        currentOrigin.x += accumulatedLineSize.width
        totalAccuSize.height = max(totalAccuSize.height, accumulatedLineSize.height)
        totalAccuSize.width += accumulatedLineSize.width
      }
    }
    if fillBlankCells {
      switch layout {
      case .horizontal:
        totalAccuSize.width = max(
          totalAccuSize.width,
          CGFloat(maxLineCapacity) * minimumCellDimension.width
        )
        highlightedLineRect.size.width = totalAccuSize.width
      case .vertical:
        totalAccuSize.height = CGFloat(maxLineCapacity) * minimumCellDimension.height
      }
    }
    // 繪製附加內容
    let strPeripherals = attributedDescriptionBottomPanes
    var dimensionPeripherals = strPeripherals.getBoundingDimension(forceFallback: true)
    dimensionPeripherals.width = ceil(dimensionPeripherals.width)
    dimensionPeripherals.height = ceil(dimensionPeripherals.height)
    if finalContainerOrientation == .horizontal {
      totalAccuSize.width += 5
      dimensionPeripherals.width += 5
      let delta = max(
        CandidateCellData4AppKit.unifiedTextHeight + padding * 2 - dimensionPeripherals.height,
        0
      )
      currentOrigin = .init(x: totalAccuSize.width + originDelta, y: ceil(delta / 2) + originDelta)
      totalAccuSize.width += dimensionPeripherals.width
    } else {
      totalAccuSize.height += 2
      currentOrigin = .init(x: padding + originDelta, y: totalAccuSize.height + originDelta)
      totalAccuSize.height += dimensionPeripherals.height
      totalAccuSize.width = max(totalAccuSize.width, dimensionPeripherals.width)
    }
    let rectPeripherals = CGRect(origin: currentOrigin, size: dimensionPeripherals)
    totalAccuSize.width += originDelta * 2
    totalAccuSize.height += originDelta * 2
    metrics = .init(
      fittingSize: totalAccuSize,
      highlightedLine: highlightedLineRect,
      highlightedCandidate: highlightedCellRect,
      peripherals: rectPeripherals
    )
  }

  private var finalContainerOrientation: NSUserInterfaceLayoutOrientation {
    if maxLinesPerPage == 1, layout == .horizontal { return .horizontal }
    return .vertical
  }
}

// MARK: - Using One Single NSAttributedString. (Some of them are for debug purposes.)

extension TDK4AppKit.CandidatePool4AppKit {
  // MARK: Candidate List with Peripherals.

  var attributedDescription: NSAttributedString {
    switch layout {
    case .horizontal: return attributedDescriptionHorizontal
    case .vertical: return attributedDescriptionVertical
    }
  }

  private var sharedParagraphStyle: NSParagraphStyle { CandidateCellData4AppKit.sharedParagraphStyle }

  private var attributedDescriptionHorizontal: NSAttributedString {
    let paragraphStyle = sharedParagraphStyle
    let attrCandidate: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: Self.blankCell.phraseFont(size: Self.blankCell.size),
      .paragraphStyle: paragraphStyle,
    ]
    let result = NSMutableAttributedString(string: "", attributes: attrCandidate)
    let spacer = NSAttributedString(string: " ", attributes: attrCandidate)
    let lineFeed = NSAttributedString(string: "\n", attributes: attrCandidate)
    for lineID in lineRangeForCurrentPage {
      let arrLine = candidateLines[lineID]
      arrLine.enumerated().forEach { cellID, currentCell in
        let cellString = NSMutableAttributedString(
          attributedString: currentCell.attributedString(
            noSpacePadding: false,
            withHighlight: true,
            isMatrix: isMatrix
          )
        )
        if lineID != currentLineNumber {
          cellString.addAttribute(
            .foregroundColor,
            value: NSColor.gray,
            range: .init(location: 0, length: cellString.string.utf16.count)
          )
        }
        result.append(cellString)
        if cellID < arrLine.count - 1 {
          result.append(spacer)
        }
      }
      if lineID < lineRangeForCurrentPage.upperBound - 1 || isMatrix {
        result.append(lineFeed)
      } else {
        result.append(spacer)
      }
    }
    // 這裡已經換行過了。
    result.append(attributedDescriptionBottomPanes)
    return result
  }

  private var attributedDescriptionVertical: NSAttributedString {
    let paragraphStyle = sharedParagraphStyle
    let attrCandidate: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: Self.blankCell.phraseFont(size: Self.blankCell.size),
      .paragraphStyle: paragraphStyle,
    ]
    let result = NSMutableAttributedString(string: "", attributes: attrCandidate)
    let spacer = NSMutableAttributedString(string: "　", attributes: attrCandidate)
    let lineFeed = NSAttributedString(string: "\n", attributes: attrCandidate)
    for (inlineIndex, _) in selectionKeys.enumerated() {
      for (lineID, lineData) in candidateLines.enumerated() {
        if !fallbackedLineRangeForCurrentPage.contains(lineID) { continue }
        if !(0 ..< lineData.count).contains(inlineIndex) { continue }
        let currentCell = lineData[inlineIndex]
        let cellString = NSMutableAttributedString(
          attributedString: currentCell.attributedString(
            noSpacePadding: false,
            withHighlight: true,
            isMatrix: isMatrix
          )
        )
        if lineID != currentLineNumber {
          cellString.addAttribute(
            .foregroundColor,
            value: NSColor.gray,
            range: .init(location: 0, length: cellString.string.utf16.count)
          )
        }
        result.append(cellString)
        if isMatrix, currentCell.displayedText.count > 1 {
          if currentCell.isHighlighted {
            spacer.addAttribute(
              .backgroundColor,
              value: currentCell.themeColorCocoa,
              range: .init(location: 0, length: spacer.string.utf16.count)
            )
          } else {
            spacer.removeAttribute(
              .backgroundColor,
              range: .init(location: 0, length: spacer.string.utf16.count)
            )
          }
          result.append(spacer)
        }
      }
      result.append(lineFeed)
    }
    // 這裡已經換行過了。
    result.append(attributedDescriptionBottomPanes)
    return result
  }

  // MARK: Peripherals

  var attributedDescriptionBottomPanes: NSAttributedString {
    let paragraphStyle = sharedParagraphStyle
    let result = NSMutableAttributedString(string: "")
    result.append(attributedDescriptionPositionCounter)
    if !tooltip.isEmpty { result.append(attributedDescriptionTooltip) }
    if !reverseLookupResult.isEmpty { result.append(attributedDescriptionReverseLookup) }
    result.addAttribute(
      .paragraphStyle,
      value: paragraphStyle,
      range: .init(location: 0, length: result.string.utf16.count)
    )
    return result
  }

  private var attributedDescriptionPositionCounter: NSAttributedString {
    let attachment = NSTextAttachment()
    let badgeCell = makePositionCounterBadgeCell()
    attachment.attachmentCell = badgeCell
    return .init(attachment: attachment)
  }

  private var attributedDescriptionTooltip: NSAttributedString {
    let positionCounterTextSize = max(ceil(CandidateCellData4AppKit.unifiedSize * 0.7), 11)
    let tooltipColorBG = Self.shitCell.clientThemeColor ?? Self.shitCell.themeColorCocoa
    let tooltipColorText = NSColor.white
    let attrTooltip: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: Self.blankCell.phraseFontEmphasized(size: positionCounterTextSize),
      .foregroundColor: tooltipColorText,
    ]
    let fontSize = CGFloat(positionCounterTextSize)
    let verticalInset = max((fontSize * 0.12).rounded(.up), 1)
    let horizontalInset = max((fontSize * 0.12).rounded(.up), 1)
    let attachment = NSTextAttachment()
    let badgeCell = RoundedBadgeTextAttachmentCell(
      label: " \(tooltip) ",
      attributes: attrTooltip,
      backgroundColor: tooltipColorBG,
      padding: .init(
        top: verticalInset,
        left: horizontalInset,
        bottom: verticalInset,
        right: horizontalInset
      )
    )
    attachment.attachmentCell = badgeCell
    return .init(attachment: attachment)
  }

  private var attributedDescriptionReverseLookup: NSAttributedString {
    let reverseLookupTextSize = max(ceil(CandidateCellData4AppKit.unifiedSize * 0.6), 9)
    let badgeFont = Self.blankCell.phraseFont(size: reverseLookupTextSize)
    let attrReverseLookup: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: badgeFont,
      .foregroundColor: CandidateCellData4AppKit.absoluteTextColor,
    ]
    var segments: [String] = []
    var addedCounter = 0
    for neta in reverseLookupResult {
      segments.append(" \(neta) ")
      addedCounter += 1
      if maxLinesPerPage == 1, addedCounter == 2 { break }
    }
    guard !segments.isEmpty else { return NSAttributedString(string: "") }
    let label = segments.joined()
    let fontSize = CGFloat(reverseLookupTextSize)
    let referenceHeight = positionCounterBadgeHeight()
    let contentHeight = badgeContentHeight(label: label, attributes: attrReverseLookup)
    let verticalInset = max((referenceHeight - contentHeight) / 2, 1)
    let horizontalInset = max((fontSize * 0.45).rounded(.up), 4)
    let attachment = NSTextAttachment()
    let badgeCell = RoundedBadgeTextAttachmentCell(
      label: label,
      attributes: attrReverseLookup,
      backgroundColor: .clear,
      padding: .init(
        top: verticalInset,
        left: horizontalInset,
        bottom: verticalInset,
        right: horizontalInset
      )
    )
    attachment.attachmentCell = badgeCell
    return .init(attachment: attachment)
  }
}

// MARK: - Badge Helpers

extension TDK4AppKit.CandidatePool4AppKit {
  fileprivate func makePositionCounterBadgeCell() -> RoundedBadgeTextAttachmentCell {
    let positionCounterColorBG =
      NSApplication.isDarkMode
        ? NSColor(white: 0.215, alpha: 0.7)
        : NSColor(white: 0.9, alpha: 0.7)
    let positionCounterColorText = CandidateCellData4AppKit.plainTextColor
    let positionCounterTextSize = max(ceil(CandidateCellData4AppKit.unifiedSize * 0.7), 11)
    let badgeFont = Self.blankCell.phraseFontEmphasized(size: positionCounterTextSize)
    let attrPositionCounter: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: badgeFont,
      .foregroundColor: positionCounterColorText,
    ]
    let fontSize = CGFloat(positionCounterTextSize)
    let verticalInset = max((fontSize * 0.12).rounded(.up), 1)
    let horizontalInset = max((fontSize * 0.45).rounded(.up), 4)
    return RoundedBadgeTextAttachmentCell(
      label: "\(currentPositionLabelText)",
      attributes: attrPositionCounter,
      backgroundColor: positionCounterColorBG,
      padding: .init(
        top: verticalInset,
        left: horizontalInset,
        bottom: verticalInset,
        right: horizontalInset
      )
    )
  }

  fileprivate func positionCounterBadgeHeight() -> CGFloat {
    makePositionCounterBadgeCell()
      .cellSize().height
  }

  fileprivate func badgeContentHeight(
    label: String,
    attributes: [NSAttributedString.Key: Any]
  )
    -> CGFloat {
    let constraint = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    let textBounds = NSAttributedString(string: label, attributes: attributes).boundingRect(
      with: constraint,
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    var contentHeight = ceil(textBounds.height)
    if let font = attributes[.font] as? NSFont {
      let ascent = font.ascender
      let descent = -font.descender
      let lineHeight = ceil(ascent + descent)
      contentHeight = max(contentHeight, lineHeight)
    }
    return contentHeight
  }
}
