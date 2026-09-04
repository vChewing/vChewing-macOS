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
  /// reloadData 去重用的顯示組態快照：任一項變動都必須重建資料池，
  /// 否則會沿用前次建池時的版面、選字鍵、展頁狀態或字型區域設定。
  struct CandidateDisplayConfig: Equatable {
    var maxLinesPerPage: Int
    var isExpanded: Bool
    var selectionKeys: String
    var layout: UILayoutOrientation
    var locale: String
  }

  // MARK: - CandidatePool

  /// 選字窗會用到的資料池單位，即用即拋。
  final class CandidatePool4AppKit: Sendable {
    // MARK: Lifecycle

    // MARK: - Constructors

    /// 初期化一個選字窗專用資料池。
    /// - Parameters:
    ///   - candidates: 要塞入的候選字詞陣列。
    ///   - selectionKeys: 選字鍵。
    ///   - direction: 橫向排列還是縱向排列（預設情況下是縱向）。
    ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
    init(
      candidates: [CandidateInState], lines: Int = 4,
      isExpanded expanded: Bool = true, selectionKeys: String = "123456789",
      layout: UILayoutOrientation = .vertical, locale: String = ""
    ) {
      self._maxLinesPerPage = max(1, lines)
      self.isExpanded = expanded
      self.layout = .horizontal
      self.selectionKeys = "123456789"
      self.candidateDataAll = []
      // 以上只是為了糊弄 compiler。接下來才是正式的初期化。
      construct(
        candidates: candidates,
        isExpanded: expanded,
        selectionKeys: selectionKeys,
        layout: layout,
        locale: locale
      )
    }

    // MARK: Internal

    typealias CandidateCellData4AppKit = TDK4AppKit.CandidateCellData4AppKit

    struct UIMetrics {
      static var allZeroed: Self {
        .init(
          fittingSize: .zero,
          highlightedLine: .zero,
          highlightedCandidate: .zero,
          peripherals: .zero,
          readingDisambiguation: .zero,
          unfinishedReading: .zero
        )
      }

      let fittingSize: CGSize
      let highlightedLine: CGRect
      let highlightedCandidate: CGRect
      let peripherals: CGRect
      let readingDisambiguation: CGRect
      /// 頂部 pane（未完成讀音）的排版矩形。zero 表示該 pane 隱藏。
      let unfinishedReading: CGRect
    }

    // 只用來測量單漢字候選字 cell 的最大可能寬度。
    // 注意：範本 cell 的 index 恆為 0，絕不得流入池級屬性字串快取
    // （headerCache / phraseCache 以 cell.index 為鍵），否則會與真實 cell 0 碰撞。
    static var shitCell = CandidateCellData4AppKit(key: " ", displayedText: "💩", isSelected: false)
    static var blankCell = CandidateCellData4AppKit(key: " ", displayedText: "　", isSelected: false)

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
    /// 當前高亮候選字詞的讀音 disambiguation 顯示內容。nil 表示無需顯示。
    var readingDisambiguationResult: String?

    /// 頂部 pane 的未完成讀音顯示內容。nullable：nil／空字串時整個 pane 隱藏。
    /// 何時提供由 data provider（Session／InputHandler 側）決定。
    var unfinishedReadingResult: String?

    /// 注音讀音轉換為拼音顯示用的 nullable converter。
    /// 由組字引擎層（具備 Tekkon 能力的一側）指派；nil 時維持注音讀音原樣。
    var phonabetPinyinConverter: ((String) -> String)?

    // MARK: - GSI Scroll Model

    /// 捲動偏移量（pixel）。0 = 第一行對齊 viewport 頂端。
    var scrollOffset: CGFloat = 0

    /// 全部候選行（不含底部欄位）的完整尺寸。
    var candidateOnlySize: CGSize = .zero

    // MARK: - 動態變數

    let padding: CGFloat = 2
    let cellTextHeight = CandidatePool4AppKit.shitCell.textDimension.height

    let originDelta: CGFloat = {
      if #unavailable(macOS 26.0) { return 5 }
      return 2
    }()

    /// 橫向還是縱向排列。
    var isHorizontal: Bool { layout == .horizontal }

    /// 單行高度（horizontal matrix）或單列寬度（vertical matrix）。
    var lineStep: CGFloat { cellTextHeight + 2 * padding }

    /// 頁面候選區尺寸（= pure cell area，不含 padding，column matrix 依 scrollOffset 動態調整）。
    var pageCandidateSize: CGSize {
      guard isMatrix else { return candidateOnlySize }
      if isHorizontal {
        let range = lineRangeForCurrentPage
        let clamped = max(range.lowerBound, 0) ..< min(range.upperBound, candidateLines.count)
        let width: CGFloat = {
          let pageLines = candidateLines[clamped]
          let maxW = pageLines.map { line in
            line.reduce(0) { $0 + $1.visualDimension.width }
          }.max() ?? candidateOnlySize.width
          return max(candidateOnlySize.width, maxW)
        }()
        return CGSize(width: width, height: lineStep * CGFloat(maxLinesPerPage))
      } else {
        let range = lineRangeForCurrentPage
        let clamped = max(range.lowerBound, 0) ..< min(range.upperBound, candidateLines.count)
        let pageWidth = candidateLines[clamped].reduce(0) { $0 + ($1.first?.visualDimension.width ?? 0) }
        let height: CGFloat = {
          let maxH = candidateLines[clamped].map { col in
            col.reduce(0) { $0 + $1.visualDimension.height }
          }.max() ?? candidateOnlySize.height
          return max(candidateOnlySize.height, maxH)
        }()
        return CGSize(width: pageWidth, height: height)
      }
    }

    /// 最大捲動偏移量。0 表示內容未超出 viewport，無需捲動。
    var maxScrollOffset: CGFloat {
      guard isMatrix else { return 0 }
      if isHorizontal {
        return max(0, candidateOnlySize.height - lineStep * CGFloat(maxLinesPerPage))
      } else {
        return max(0, candidateOnlySize.width - pageCandidateSize.width)
      }
    }

    /// Thumb 長度佔軌道的比例 (0…1)。
    var scrollerThumbRatio: CGFloat {
      guard maxScrollOffset > 0 else { return 1 }
      if isHorizontal {
        return (lineStep * CGFloat(maxLinesPerPage)) / candidateOnlySize.height
      } else {
        return pageCandidateSize.width / candidateOnlySize.width
      }
    }

    /// Thumb 在軌道中的位置比例 (0…1)。
    var scrollerThumbPosition: CGFloat {
      guard maxScrollOffset > 0 else { return 0 }
      return scrollOffset / maxScrollOffset
    }

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

    // MARK: - GSI Scroll Operations

    /// 以 pixel 為單位捲動（touchpad 慣性）。
    func scrollByPixels(_ delta: CGFloat) {
      scrollOffset += delta
      clampScrollOffset()
    }

    /// 以行數為單位捲動（滾輪 / 鍵盤翻頁）。
    func scrollByLines(_ delta: Int) {
      if isHorizontal {
        scrollOffset += CGFloat(delta) * lineStep
      } else {
        guard !candidateLines.isEmpty else { return }
        var cur = 0, bestDist = CGFloat.greatestFiniteMagnitude
        for (i, col) in candidateLines.enumerated() {
          let d = abs(scrollOffset - (col.first?.visualOrigin.x ?? 0))
          if d < bestDist { bestDist = d; cur = i }
        }
        let target = max(0, min(candidateLines.count - 1, cur + delta))
        scrollOffset = candidateLines[target].first?.visualOrigin.x ?? 0
      }
      clampScrollOffset()
    }

    /// 吸附到最近行/列邊界（touchpad release）。
    func snapScrollOffset() {
      if isHorizontal {
        scrollOffset = round(scrollOffset / lineStep) * lineStep
      } else {
        guard !candidateLines.isEmpty else { return }
        var bestX: CGFloat = 0, bestDist = CGFloat.greatestFiniteMagnitude
        for col in candidateLines {
          let d = abs(scrollOffset - (col.first?.visualOrigin.x ?? 0))
          if d < bestDist { bestDist = d; bestX = col.first?.visualOrigin.x ?? 0 }
        }
        scrollOffset = bestX
      }
      clampScrollOffset()
    }

    /// 讓指定行/列進入可見範圍。
    func scrollToMakeLineVisible(_ lineIndex: Int) {
      guard isMatrix else { return }
      if isHorizontal {
        let lineTop = CGFloat(lineIndex) * lineStep
        let lineBottom = lineTop + lineStep
        let viewportSize = pageCandidateSize.height
        if lineTop < scrollOffset {
          scrollOffset = lineTop
        } else if lineBottom > scrollOffset + viewportSize {
          scrollOffset = lineBottom - viewportSize
        }
      } else {
        let firstCol = lineRangeForCurrentPage.lowerBound
        guard firstCol < candidateLines.count else { return }
        scrollOffset = candidateLines[firstCol].first?.visualOrigin.x ?? 0
      }
      clampScrollOffset()
    }

    /// 重置捲動偏移量到頂端。
    func resetScrollOffset() {
      scrollOffset = 0
    }

    /// 初期化一個選字窗專用資料池。
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
      construct(
        candidates: candidates,
        isExpanded: expanded,
        selectionKeys: selectionKeys,
        layout: layout,
        locale: locale
      )
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
      readingDisambiguationResult = nil
      unfinishedReadingResult = nil
      headerCache.removeAll()
      phraseCache.removeAll()
    }

    // MARK: Private

    /// 選字鍵屬性字串快取（keyed by cell.index），僅存活於一次排版→繪製循環內。
    private var headerCache: [Int: NSAttributedString] = [:]
    /// 候選字詞屬性字串快取（keyed by cell.index，再依 isMatrix 分層）。
    private var phraseCache: [Int: [Bool: NSAttributedString]] = [:]

    private var recordedLineRangeForCurrentPage: Range<Int>?
    private var previouslyRecordedLineRangeForPreviousPage: Range<Int>?

    private func clampScrollOffset() {
      scrollOffset = max(0, min(scrollOffset, maxScrollOffset))
    }

    /// 初期化（或者自我重新初期化）一個選字窗專用資料池。
    /// - Parameters:
    ///   - candidates: 要塞入的候選字詞陣列。
    ///   - selectionKeys: 選字鍵。
    ///   - direction: 橫向排列還是縱向排列（預設情況下是縱向）。
    ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
    private func construct(
      candidates: [CandidateInState], isExpanded expanded: Bool = true,
      selectionKeys: String = "123456789",
      layout: UILayoutOrientation = .vertical, locale: String = ""
    ) {
      self.layout = layout
      Self.blankCell.locale = locale
      self.selectionKeys = selectionKeys.isEmpty ? "123456789" : selectionKeys
      cleanDataOnMain()
      isExpanded = expanded
      var allCandidates = candidates.map {
        CandidateCellData4AppKit(key: " ", displayedText: $0.value, keyArray: $0.keyArray, segLength: $0.keyArray.count)
      }
      if allCandidates.isEmpty { allCandidates.append(Self.blankCell) }
      candidateDataAll = allCandidates
      candidateLines.removeAll()
      var currentColumn: [CandidateCellData4AppKit] = []
      let minCellWidth = Self.blankCell.cellLength()
      let shouldCalculateRowWidth = (layout == .horizontal)
      for i in candidateDataAll.indices {
        var candidate = candidateDataAll[i]
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
        // 寫回資料池（struct 值語義：candidateDataAll 與 candidateLines 各自持有副本）。
        candidateDataAll[i] = candidate
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
    // 高亮狀態需同步寫入 candidateDataAll 與 candidateLines 兩份陣列（struct 值語義下
    // 兩者各持獨立副本）：candidateDataAll 是索引查詢的真源，candidateLines 是視圖繪製、
    // 展頁判定與高亮排版矩形的讀取源。以 cell.index 對映兩陣列的同一邏輯 cell。
    for i in candidateDataAll.indices {
      let isHighlighted = (indexSpecified == i)
      candidateDataAll[i].isHighlighted = isHighlighted
      if isHighlighted { currentLineNumber = candidateDataAll[i].whichLine }
      let lineIndex = candidateDataAll[i].whichLine
      let subIndex = candidateDataAll[i].subIndex
      if candidateLines.indices.contains(lineIndex),
         candidateLines[lineIndex].indices.contains(subIndex) {
        candidateLines[lineIndex][subIndex].isHighlighted = isHighlighted
      }
    }
    for (i, candidateColumn) in candidateLines.enumerated() {
      if i != currentLineNumber {
        for j in candidateLines[i].indices {
          candidateLines[i][j].selectionKey = " "
          let flatIndex = candidateLines[i][j].index
          if candidateDataAll.indices.contains(flatIndex) {
            candidateDataAll[flatIndex].selectionKey = " "
          }
        }
      } else {
        for (j, neta) in candidateColumn.enumerated() {
          if neta.selectionKey.isEmpty { continue }
          let key = selectionKeys.map(\.description)[j]
          candidateLines[i][j].selectionKey = key
          let flatIndex = candidateLines[i][j].index
          if candidateDataAll.indices.contains(flatIndex) {
            candidateDataAll[flatIndex].selectionKey = key
          }
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
  /// 排版給定的行陣列：計算每顆 cell 的 visualOrigin / visualDimension 並返回總累積尺寸。
  /// 幾何資料會按 startingLineIndex 對應的行序寫回資料池的 candidateLines（struct 值語義）。
  /// 傳入的 throwaway 行（如 updateMetrics 內的空白填充行）若超出資料池行數範圍，則不會被寫回。
  /// - Parameters:
  ///   - lines: 要排版的行陣列。
  ///   - initialOrigin: 排版起點。
  ///   - startingLineIndex: 第一行對應的 candidateLines 行序；nil 表示不寫回。
  ///   - realLineCount: 傳入行陣列中真實行的數量；僅前 realLineCount 行會被寫回。
  ///     nil 表示全部視為真實行。末頁不足 maxLinesPerPage 時，翻頁可能讓行範圍落在
  ///     資料池中段，此時填充行的寫回目標仍在 candidateLines 範圍內，必須靠此參數攔截。
  /// - Returns: 排版後的總累積尺寸（不含 originDelta 外圍 padding）與排版後的行陣列。
  @discardableResult
  private func layoutCells(
    in lines: [[CandidateCellData4AppKit]],
    initialOrigin: CGPoint,
    startingLineIndex: Int? = nil,
    realLineCount: Int? = nil
  )
    -> (size: CGSize, lines: [[CandidateCellData4AppKit]]) {
    // 屬性字串快取僅存活於一次排版→繪製循環內，排版前一律清空。
    headerCache.removeAll()
    phraseCache.removeAll()
    var totalAccuSize = CGSize.zero
    var currentOrigin = initialOrigin
    var resultLines = lines

    // 先拷貝出模板 cell 再就地變更，避免對 static var 的 mutating 存取與
    // 內部 cellWidth(_:) 對同一 static var 的重疊讀取造成 exclusivity 衝突。
    var templateCell = Self.shitCell
    templateCell.isHighlighted = false
    templateCell.updateMetrics(pool: self, origin: currentOrigin)
    Self.shitCell = templateCell
    let minimumCellDimension = Self.shitCell.visualDimension
    let minCellWidth = Self.blankCell.cellLength()

    for (lineOffset, currentLine) in resultLines.enumerated() {
      var accumulatedLineSize = CGSize.zero

      for (cellID, currentCell) in currentLine.enumerated() {
        var updatedCell = currentCell
        updatedCell.updateMetrics(pool: self, origin: currentOrigin)
        var cellDimension = updatedCell.visualDimension

        if layout == .horizontal, isMatrix {
          cellDimension.width = updatedCell.cellWidthMultiplied(minCellWidth: minCellWidth)
        } else if layout == .vertical || updatedCell.displayedText.count <= 2 {
          cellDimension.width = max(minimumCellDimension.width, cellDimension.width)
        }
        cellDimension.height = max(minimumCellDimension.height, cellDimension.height)
        updatedCell.visualDimension.width = cellDimension.width
        resultLines[lineOffset][cellID] = updatedCell

        switch layout {
        case .horizontal:
          accumulatedLineSize.width += cellDimension.width
          accumulatedLineSize.height = max(accumulatedLineSize.height, cellDimension.height)
        case .vertical:
          accumulatedLineSize.height += cellDimension.height
          accumulatedLineSize.width = max(accumulatedLineSize.width, cellDimension.width)
        }

        switch layout {
        case .horizontal: currentOrigin.x += cellDimension.width
        case .vertical: currentOrigin.y += cellDimension.height
        }
      }

      if layout == .vertical {
        for cellID in resultLines[lineOffset].indices {
          resultLines[lineOffset][cellID].visualDimension.width = accumulatedLineSize.width
        }
      }

      // 寫回資料池（僅限真實行；填充行藉 realLineCount 攔截，避免覆寫資料池中段的真實行）。
      if let startingLineIndex, lineOffset < (realLineCount ?? candidateLines.count) {
        let targetLineIndex = startingLineIndex + lineOffset
        if (0 ..< candidateLines.count).contains(targetLineIndex) {
          candidateLines[targetLineIndex] = resultLines[lineOffset]
        }
      }

      switch layout {
      case .horizontal:
        currentOrigin.x = initialOrigin.x
        currentOrigin.y += accumulatedLineSize.height
        totalAccuSize.width = max(totalAccuSize.width, accumulatedLineSize.width)
        totalAccuSize.height += accumulatedLineSize.height
      case .vertical:
        currentOrigin.y = initialOrigin.y
        currentOrigin.x += accumulatedLineSize.width
        totalAccuSize.height = max(totalAccuSize.height, accumulatedLineSize.height)
        totalAccuSize.width += accumulatedLineSize.width
      }
    }

    return (totalAccuSize, resultLines)
  }

  func updateMetrics() {
    // 先測量頂部 pane（unfinished reading）的尺寸；nil／空字串時整段為零、pane 隱藏。
    let strUnfinishedReading = attributedDescriptionUnfinishedReading
    var dimensionUnfinishedReading = CGSize.zero
    if !strUnfinishedReading.string.isEmpty {
      let rawDim = strUnfinishedReading.getBoundingDimension(forceFallback: true)
      dimensionUnfinishedReading = CGSize(width: ceil(rawDim.width), height: ceil(rawDim.height))
    }

    let initialOrigin = CGPoint(x: originDelta, y: originDelta)

    // 準備當前頁的行陣列（含空白行填充）。
    var currentPageLines = Array(candidateLines[lineRangeForCurrentPage])
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

    // 第一趟：排版 cell，取得總尺寸與排版後的行陣列。
    let layoutResult = layoutCells(
      in: currentPageLines, initialOrigin: initialOrigin,
      startingLineIndex: lineRangeForCurrentPage.lowerBound,
      realLineCount: lineRangeForCurrentPage.count
    )
    var totalAccuSize = layoutResult.size
    currentPageLines = layoutResult.lines

    // 第二趟：從已排好的 cell 中反推 highlighted rects。
    var highlightedCellRect: CGRect = .zero
    var highlightedLineRect: CGRect = .zero
    let allCells = currentPageLines.flatMap { $0 }
    if let hCell = allCells.first(where: { $0.isHighlighted }),
       let hLine = currentPageLines.first(where: { $0.contains(where: { $0.isHighlighted }) }),
       let first = hLine.first, let last = hLine.last {
      highlightedCellRect = CGRect(origin: hCell.visualOrigin, size: hCell.visualDimension)
      let minX = first.visualOrigin.x
      let minY = first.visualOrigin.y
      switch layout {
      case .horizontal:
        let width = (last.visualOrigin.x + last.visualDimension.width) - minX
        let height = hLine.map(\.visualDimension.height).max() ?? highlightedCellRect.height
        highlightedLineRect = CGRect(x: minX, y: minY, width: width, height: height)
      case .vertical:
        let height = (last.visualOrigin.y + last.visualDimension.height) - minY
        let width = hLine.map(\.visualDimension.width).max() ?? highlightedCellRect.width
        highlightedLineRect = CGRect(x: minX, y: minY, width: width, height: height)
      }
    }

    // 空白 cell 尺寸補償。
    if fillBlankCells {
      let minDim = Self.shitCell.visualDimension
      switch layout {
      case .horizontal:
        totalAccuSize.width = max(totalAccuSize.width, CGFloat(maxLineCapacity) * minDim.width)
        highlightedLineRect.size.width = totalAccuSize.width
      case .vertical:
        totalAccuSize.height = CGFloat(maxLineCapacity) * minDim.height
      }
    }

    // 繪製附加內容（peripherals + reading disambiguation）。
    let strPeripherals = attributedDescriptionBottomPanes
    var dimensionPeripherals = strPeripherals.getBoundingDimension(forceFallback: true)
    dimensionPeripherals.width = ceil(dimensionPeripherals.width)
    dimensionPeripherals.height = ceil(dimensionPeripherals.height)
    var currentOrigin: CGPoint
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
    var rectPeripherals = CGRect(origin: currentOrigin, size: dimensionPeripherals)

    let strReadingDisambiguation = attributedDescriptionReadingDisambiguation
    var rectReadingDisambiguation: CGRect = .zero
    if !strReadingDisambiguation.string.isEmpty {
      var dimReading = strReadingDisambiguation.getBoundingDimension(forceFallback: true)
      dimReading.width = ceil(dimReading.width)
      dimReading.height = ceil(dimReading.height)
      let readingOrigin: CGPoint
      if finalContainerOrientation == .horizontal {
        let bottomOfCandidates = originDelta + totalAccuSize.height
        let bottomOfPeripherals = rectPeripherals.maxY
        let contentBottom = max(bottomOfCandidates, bottomOfPeripherals)
        readingOrigin = .init(x: originDelta, y: contentBottom + padding)
      } else {
        readingOrigin = .init(x: originDelta, y: rectPeripherals.maxY + padding)
      }
      rectReadingDisambiguation = .init(origin: readingOrigin, size: dimReading)
      totalAccuSize.width = max(totalAccuSize.width, dimReading.width + originDelta)
      totalAccuSize.height = readingOrigin.y + dimReading.height - originDelta
    }
    totalAccuSize.width += originDelta * 2
    totalAccuSize.height += originDelta * 2

    // 頂部 pane：若存在，則將既有幾何資料整體下移（topPaneShift）騰出 pane 空間。
    // 這樣一來無論橫向／縱向、單行／多行模式，候選區與底部欄位的相對位置皆不受影響。
    let topPaneShift = dimensionUnfinishedReading.height > 0
      ? dimensionUnfinishedReading.height + padding : 0
    let rectUnfinishedReading: CGRect
    if topPaneShift > 0 {
      rectUnfinishedReading = .init(
        origin: .init(x: originDelta, y: originDelta), size: dimensionUnfinishedReading
      )
      for lineIndex in candidateLines.indices {
        for cellIndex in candidateLines[lineIndex].indices {
          candidateLines[lineIndex][cellIndex].visualOrigin.y += topPaneShift
        }
      }
      highlightedCellRect.origin.y += topPaneShift
      highlightedLineRect.origin.y += topPaneShift
      rectPeripherals.origin.y += topPaneShift
      rectReadingDisambiguation.origin.y += topPaneShift
      totalAccuSize.height += topPaneShift
      // 頂部 pane 可能比候選區更寬，視窗寬度需一併放寬（左右各留 originDelta 邊距）。
      totalAccuSize.width = max(totalAccuSize.width, dimensionUnfinishedReading.width + originDelta * 2)
    } else {
      rectUnfinishedReading = .zero
    }

    metrics = .init(
      fittingSize: totalAccuSize,
      highlightedLine: highlightedLineRect,
      highlightedCandidate: highlightedCellRect,
      peripherals: rectPeripherals,
      readingDisambiguation: rectReadingDisambiguation,
      unfinishedReading: rectUnfinishedReading
    )
  }

  private var finalContainerOrientation: NSUserInterfaceLayoutOrientation {
    if maxLinesPerPage == 1, layout == .horizontal { return .horizontal }
    return .vertical
  }

  /// 計算全部候選行（不含底部欄位）的完整尺寸，並一併更新所有 cell 的 visualOrigin。
  /// 供 GSI scroll mode 使用，以便 draw(_:) 可以繪製全部候選行。
  func computeCandidateOnlySize() {
    candidateOnlySize = layoutCells(
      in: candidateLines, initialOrigin: .zero, startingLineIndex: 0
    ).size
  }
}

// MARK: - Attributed String Accessors (with pool-level caching).

extension TDK4AppKit.CandidatePool4AppKit {
  /// 取得指定 cell 的「選字鍵」屬性字串（以 cell.index 為鍵的池級快取）。
  func attributedStringHeader(for cell: CandidateCellData4AppKit) -> NSAttributedString {
    if let cached = headerCache[cell.index] { return cached }
    let result = cell.makeAttributedStringHeader()
    headerCache[cell.index] = result
    return result
  }

  /// 取得指定 cell 的「候選字詞」屬性字串（以 cell.index 為鍵的池級快取）。
  func attributedStringPhrase(
    for cell: CandidateCellData4AppKit, isMatrix: Bool
  )
    -> NSAttributedString {
    if let cached = phraseCache[cell.index]?[isMatrix] { return cached }
    let result = cell.makeAttributedStringPhrase(isMatrix: isMatrix)
    if phraseCache[cell.index] == nil { phraseCache[cell.index] = [:] }
    phraseCache[cell.index]?[isMatrix] = result
    return result
  }

  /// 取得指定 cell 的組合屬性字串（選字鍵 + 候選字詞），組件走池級快取。
  func attributedString(
    for cell: CandidateCellData4AppKit,
    noSpacePadding: Bool = true, withHighlight: Bool = false, isMatrix: Bool = false
  )
    -> NSAttributedString {
    CandidateCellData4AppKit.assembleAttributedString(
      for: cell,
      header: attributedStringHeader(for: cell),
      phrase: attributedStringPhrase(for: cell, isMatrix: isMatrix),
      noSpacePadding: noSpacePadding,
      withHighlight: withHighlight
    )
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
          attributedString: attributedString(
            for: currentCell,
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
          attributedString: attributedString(
            for: currentCell,
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

  // MARK: Reading Disambiguation

  /// 讀音 disambiguation 顯示用的 NSAttributedString。
  /// 樣式繼承 reverse lookup 區域，但文字透明度降為 80%。
  /// 當 readingDisambiguationResult 為 nil 時返回空字串。
  var attributedDescriptionReadingDisambiguation: NSAttributedString {
    guard let readingText = readingDisambiguationResult, !readingText.isEmpty else {
      return NSAttributedString(string: "")
    }
    let readingTextSize = max(ceil(CandidateCellData4AppKit.unifiedSize * 0.6), 9)
    let badgeFont = Self.blankCell.phraseFont(size: readingTextSize)
    let attrReading: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: badgeFont,
      // 繼承 reverse lookup 區域的文字顏色，但透明度降為 80%
      .foregroundColor: CandidateCellData4AppKit.absoluteTextColor.withAlphaComponent(0.8),
    ]
    let label = " \(readingText) "
    let fontSize = CGFloat(readingTextSize)
    let referenceHeight = positionCounterBadgeHeight()
    let contentHeight = badgeContentHeight(label: label, attributes: attrReading)
    let verticalInset = max((referenceHeight - contentHeight) / 2, 1)
    let horizontalInset = max((fontSize * 0.45).rounded(.up), 4)
    let attachment = NSTextAttachment()
    let badgeCell = RoundedBadgeTextAttachmentCell(
      label: label,
      attributes: attrReading,
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

  // MARK: Unfinished Reading Pane (頂部)

  /// 選字窗頂部 pane（unfinished reading）用的 NSAttributedString。
  /// 文字樣式與 page indicator（位置計數器）一致，但無底色。
  /// 文字前綴為「✍️ 」（一個 emoji + 一個 ASCII SPACE）。
  /// unfinishedReadingResult 為 nil／空字串時返回空字串（pane 隱藏）。
  var attributedDescriptionUnfinishedReading: NSAttributedString {
    guard let readingText = unfinishedReadingResult, !readingText.isEmpty else {
      return NSAttributedString(string: "")
    }
    let paneTextSize = max(ceil(CandidateCellData4AppKit.unifiedSize * 0.7), 11)
    let attrPane: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: Self.blankCell.phraseFontEmphasized(size: paneTextSize),
      .foregroundColor: CandidateCellData4AppKit.plainTextColor,
    ]
    let label = "✍️ \(readingText)"
    let fontSize = CGFloat(paneTextSize)
    let referenceHeight = positionCounterBadgeHeight()
    let contentHeight = badgeContentHeight(label: label, attributes: attrPane)
    let verticalInset = max((referenceHeight - contentHeight) / 2, 1)
    let horizontalInset = max((fontSize * 0.45).rounded(.up), 4)
    let attachment = NSTextAttachment()
    let badgeCell = RoundedBadgeTextAttachmentCell(
      label: label,
      attributes: attrPane,
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

  // MARK: Reading Disambiguation Logic

  /// 計算當前高亮候選字詞的讀音 disambiguation 顯示。
  /// 規則：
  /// - 若任一讀音 cell 以 `_` 開頭：不顯示（標點／特殊鍵）。
  /// - 若 segLength == 1：始終顯示（拼音免聲調模式下單字皆有潛在歧義）。
  /// - 若 segLength > 1：僅在候選池內存在同字不同音／不同幅節長度的其他 cell 時顯示。
  func updateReadingDisambiguation() {
    readingDisambiguationResult = nil
    guard let currentCandidate = currentCandidate else { return }
    let currentKeyArray = currentCandidate.keyArray
    // 讀音 cell 以 "_" 開頭者不處理（標點、特殊鍵等）
    guard !currentKeyArray.contains(where: { $0.hasPrefix("_") }) else { return }
    let displayedText = currentCandidate.displayedText
    let currentSegLength = currentCandidate.segLength

    // Rule 1: 同字但 readingArray 不全等 → 顯示
    let sameTextCells = candidateDataAll.filter { $0.displayedText == displayedText }
    let rule1 = !sameTextCells.allSatisfy { $0.keyArray == currentKeyArray }

    // Rule 2: segLength == 1 且池內單字 reading 種類 > 1 → 全部單字顯示
    var rule2 = false
    if currentSegLength == 1 {
      let singleSegCells = candidateDataAll.filter { $0.segLength == 1 }
      let distinctReadings = Set(singleSegCells.map { $0.keyArray })
      rule2 = distinctReadings.count > 1
    }

    if rule1 || rule2 {
      let readingString = currentKeyArray.map { key in
        key.hasPrefix("_") ? "??" : (phonabetPinyinConverter?(key) ?? key)
      }.joined(separator: "-")
      readingDisambiguationResult = readingString
    }
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

extension TDK4AppKit.CandidatePool4AppKit {
  enum ScrollLineDirection {
    case next
    case previous
  }

  /// Returns the dominant scroll-axis direction for flip-line operations.
  /// Uses the axis with larger absolute delta; threshold is ±1.
  static func dominantScrollLineDirection(_ event: NSEvent) -> ScrollLineDirection? {
    let deltaX = event.deltaX
    let deltaY = event.deltaY
    if abs(deltaY) >= abs(deltaX) {
      if deltaY > 1 { return .next }
      if deltaY < -1 { return .previous }
    } else {
      if deltaX > 1 { return .next }
      if deltaX < -1 { return .previous }
    }
    return nil
  }
}
