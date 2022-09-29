// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import Shared

/// 候選字窗會用到的資料池單位。
public class CandidatePool {
  public let blankCell = CandidateCellData(key: " ", displayedText: "　", isSelected: false)
  public private(set) var candidateDataAll: [CandidateCellData] = []
  public private(set) var selectionKeys: String
  public private(set) var highlightedIndex: Int = 0

  // 下述變數只有橫排選字窗才會用到
  public var currentRowNumber = 0
  public var maximumRowsPerPage = 3
  public private(set) var maxRowCapacity: Int = 6
  public private(set) var candidateRows: [[CandidateCellData]] = []

  // 下述變數只有縱排選字窗才會用到
  public var currentColumnNumber = 0
  public var maximumColumnsPerPage = 3
  public private(set) var maxColumnCapacity: Int = 6
  public private(set) var candidateColumns: [[CandidateCellData]] = []

  // 動態變數
  public var maxRowWidth: Int { Int(Double(maxRowCapacity + 3) * 2) * Int(ceil(CandidateCellData.unifiedSize)) }
  public var maxWindowWidth: Double {
    ceil(Double(maxRowCapacity + 3) * 2.7 * ceil(CandidateCellData.unifiedSize) * 1.2)
  }

  public var rangeForCurrentHorizontalPage: Range<Int> {
    currentRowNumber..<min(candidateRows.count, currentRowNumber + maximumRowsPerPage)
  }

  public var rangeForCurrentVerticalPage: Range<Int> {
    currentColumnNumber..<min(candidateColumns.count, currentColumnNumber + maximumColumnsPerPage)
  }

  public var rangeForLastHorizontalPageBlanked: Range<Int> {
    0..<(maximumRowsPerPage - rangeForCurrentHorizontalPage.count)
  }

  public var rangeForLastVerticalPageBlanked: Range<Int> {
    0..<(maximumColumnsPerPage - rangeForCurrentVerticalPage.count)
  }

  public enum VerticalDirection {
    case up
    case down
  }

  public enum HorizontalDirection {
    case left
    case right
  }

  /// 初期化一個縱排候選字窗專用資料池。
  /// - Parameters:
  ///   - candidates: 要塞入的候選字詞陣列。
  ///   - columnCapacity: (第一縱列的最大候選字詞數量, 陣列畫面展開之後的每一縱列的最大候選字詞數量)。
  ///   - selectionKeys: 選字鍵。
  ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
  public init(candidates: [String], columnCapacity: Int, selectionKeys: String = "123456789", locale: String = "") {
    maxColumnCapacity = max(1, columnCapacity)
    self.selectionKeys = selectionKeys
    candidateDataAll = candidates.map { .init(key: "0", displayedText: $0) }
    var currentColumn: [CandidateCellData] = []
    for (i, candidate) in candidateDataAll.enumerated() {
      candidate.index = i
      candidate.whichColumn = candidateColumns.count
      if currentColumn.count == maxColumnCapacity, !currentColumn.isEmpty {
        candidateColumns.append(currentColumn)
        currentColumn.removeAll()
        candidate.whichColumn += 1
      }
      candidate.subIndex = currentColumn.count
      candidate.locale = locale
      currentColumn.append(candidate)
    }
    candidateColumns.append(currentColumn)
  }

  /// 初期化一個橫排候選字窗專用資料池。
  /// - Parameters:
  ///   - candidates: 要塞入的候選字詞陣列。
  ///   - rowCapacity: (第一橫行的最大候選字詞數量, 陣列畫面展開之後的每一橫行的最大候選字詞數量)。
  ///   - selectionKeys: 選字鍵。
  ///   - locale: 區域編碼。例：「zh-Hans」或「zh-Hant」。
  public init(candidates: [String], rowCapacity: Int, selectionKeys: String = "123456789", locale: String = "") {
    maxRowCapacity = max(1, rowCapacity)
    self.selectionKeys = selectionKeys
    candidateDataAll = candidates.map { .init(key: "0", displayedText: $0) }
    var currentRow: [CandidateCellData] = []
    for (i, candidate) in candidateDataAll.enumerated() {
      candidate.index = i
      candidate.whichRow = candidateRows.count
      let isOverflown: Bool = currentRow.map(\.cellLength).reduce(0, +) + candidate.cellLength > maxRowWidth
      if isOverflown || currentRow.count == maxRowCapacity, !currentRow.isEmpty {
        candidateRows.append(currentRow)
        currentRow.removeAll()
        candidate.whichRow += 1
      }
      candidate.subIndex = currentRow.count
      candidate.locale = locale
      currentRow.append(candidate)
    }
    candidateRows.append(currentRow)
  }

  public func selectNewNeighborRow(direction: VerticalDirection) {
    let currentSubIndex = candidateDataAll[highlightedIndex].subIndex
    var result = currentSubIndex
    switch direction {
      case .up:
        if currentRowNumber <= 0 {
          if candidateRows.isEmpty { break }
          let firstRow = candidateRows[0]
          let newSubIndex = min(currentSubIndex, firstRow.count - 1)
          highlightHorizontal(at: firstRow[newSubIndex].index)
          break
        }
        if currentRowNumber >= candidateRows.count - 1 { currentRowNumber = candidateRows.count - 1 }
        if candidateRows[currentRowNumber].count != candidateRows[currentRowNumber - 1].count {
          let ratio: Double = min(1, Double(currentSubIndex) / Double(candidateRows[currentRowNumber].count))
          result = Int(floor(Double(candidateRows[currentRowNumber - 1].count) * ratio))
        }
        let targetRow = candidateRows[currentRowNumber - 1]
        let newSubIndex = min(result, targetRow.count - 1)
        highlightHorizontal(at: targetRow[newSubIndex].index)
      case .down:
        if currentRowNumber >= candidateRows.count - 1 {
          if candidateRows.isEmpty { break }
          let finalRow = candidateRows[candidateRows.count - 1]
          let newSubIndex = min(currentSubIndex, finalRow.count - 1)
          highlightHorizontal(at: finalRow[newSubIndex].index)
          break
        }
        if candidateRows[currentRowNumber].count != candidateRows[currentRowNumber + 1].count {
          let ratio: Double = min(1, Double(currentSubIndex) / Double(candidateRows[currentRowNumber].count))
          result = Int(floor(Double(candidateRows[currentRowNumber + 1].count) * ratio))
        }
        let targetRow = candidateRows[currentRowNumber + 1]
        let newSubIndex = min(result, targetRow.count - 1)
        highlightHorizontal(at: targetRow[newSubIndex].index)
    }
  }

  public func selectNewNeighborColumn(direction: HorizontalDirection) {
    let currentSubIndex = candidateDataAll[highlightedIndex].subIndex
    switch direction {
      case .left:
        if currentColumnNumber <= 0 {
          if candidateColumns.isEmpty { break }
          let firstColumn = candidateColumns[0]
          let newSubIndex = min(currentSubIndex, firstColumn.count - 1)
          highlightVertical(at: firstColumn[newSubIndex].index)
          break
        }
        if currentColumnNumber >= candidateColumns.count - 1 { currentColumnNumber = candidateColumns.count - 1 }
        let targetColumn = candidateColumns[currentColumnNumber - 1]
        let newSubIndex = min(currentSubIndex, targetColumn.count - 1)
        highlightVertical(at: targetColumn[newSubIndex].index)
      case .right:
        if currentColumnNumber >= candidateColumns.count - 1 {
          if candidateColumns.isEmpty { break }
          let finalColumn = candidateColumns[candidateColumns.count - 1]
          let newSubIndex = min(currentSubIndex, finalColumn.count - 1)
          highlightVertical(at: finalColumn[newSubIndex].index)
          break
        }
        let targetColumn = candidateColumns[currentColumnNumber + 1]
        let newSubIndex = min(currentSubIndex, targetColumn.count - 1)
        highlightVertical(at: targetColumn[newSubIndex].index)
    }
  }

  public func highlightHorizontal(at indexSpecified: Int) {
    var indexSpecified = indexSpecified
    highlightedIndex = indexSpecified
    if !(0..<candidateDataAll.count).contains(highlightedIndex) {
      NSSound.beep()
      switch highlightedIndex {
        case candidateDataAll.count...:
          currentRowNumber = candidateRows.count - 1
          highlightedIndex = max(0, candidateDataAll.count - 1)
          indexSpecified = highlightedIndex
        case ..<0:
          highlightedIndex = 0
          currentRowNumber = 0
          indexSpecified = highlightedIndex
        default: break
      }
    }
    for (i, candidate) in candidateDataAll.enumerated() {
      candidate.isSelected = (indexSpecified == i)
      if candidate.isSelected { currentRowNumber = candidate.whichRow }
    }
    for (i, candidateRow) in candidateRows.enumerated() {
      if i != currentRowNumber {
        candidateRow.forEach {
          $0.key = " "
        }
      } else {
        for (i, neta) in candidateRow.enumerated() {
          neta.key = selectionKeys.map { String($0) }[i]
        }
      }
    }
  }

  public func highlightVertical(at indexSpecified: Int) {
    var indexSpecified = indexSpecified
    highlightedIndex = indexSpecified
    if !(0..<candidateDataAll.count).contains(highlightedIndex) {
      NSSound.beep()
      switch highlightedIndex {
        case candidateDataAll.count...:
          currentColumnNumber = candidateColumns.count - 1
          highlightedIndex = max(0, candidateDataAll.count - 1)
          indexSpecified = highlightedIndex
        case ..<0:
          highlightedIndex = 0
          currentColumnNumber = 0
          indexSpecified = highlightedIndex
        default: break
      }
    }
    for (i, candidate) in candidateDataAll.enumerated() {
      candidate.isSelected = (indexSpecified == i)
      if candidate.isSelected { currentColumnNumber = candidate.whichColumn }
    }
    for (i, candidateColumn) in candidateColumns.enumerated() {
      if i != currentColumnNumber {
        candidateColumn.forEach {
          $0.key = " "
        }
      } else {
        for (i, neta) in candidateColumn.enumerated() {
          if neta.key.isEmpty { continue }
          neta.key = selectionKeys.map { String($0) }[i]
        }
      }
    }
  }
}
