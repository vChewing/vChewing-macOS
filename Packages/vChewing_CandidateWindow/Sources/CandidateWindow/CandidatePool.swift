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
public struct CandidatePool {
  public var currentRowNumber = 0
  public private(set) var selectionKeys: String
  public private(set) var highlightedIndex: Int = 0
  public private(set) var maxColumnCapacity: Int = 6
  public private(set) var candidateDataAll: [CandidateCellData] = []
  public private(set) var candidateRows: [[CandidateCellData]] = []
  public var maxWindowHeight: Double { ceil(maxWindowWidth * 0.4) }
  public var isVerticalLayout: Bool { maxColumnCapacity == 1 }
  public var maxColumnWidth: Int { Int(Double(maxColumnCapacity + 3) * 2) * Int(ceil(CandidateCellData.unifiedSize)) }
  public var maxWindowWidth: Double {
    ceil(Double(maxColumnCapacity + 3) * 2.7 * ceil(CandidateCellData.unifiedSize) * 1.2)
  }

  public var rangeForCurrentPage: Range<Int> { currentRowNumber..<min(candidateRows.count, currentRowNumber + 6) }

  public enum VerticalDirection {
    case up
    case down
  }

  /// 初期化一個候選字池。
  /// - Parameters:
  ///   - candidates: 要塞入的候選字詞陣列。
  ///   - columnCapacity: (第一行的最大候選字詞數量, 陣列畫面展開之後的每一行的最大候選字詞數量)。
  public init(candidates: [String], columnCapacity: Int = 6, selectionKeys: String = "123456789", locale: String = "") {
    maxColumnCapacity = max(1, columnCapacity)
    self.selectionKeys = selectionKeys
    candidateDataAll = candidates.map { .init(key: "0", displayedText: $0) }
    var currentColumn: [CandidateCellData] = []
    for (i, candidate) in candidateDataAll.enumerated() {
      candidate.index = i
      candidate.whichRow = candidateRows.count
      let isOverflown: Bool = currentColumn.map(\.cellLength).reduce(0, +) + candidate.cellLength > maxColumnWidth
      if isOverflown || currentColumn.count == maxColumnCapacity, !currentColumn.isEmpty {
        candidateRows.append(currentColumn)
        currentColumn.removeAll()
        candidate.whichRow += 1
      }
      candidate.subIndex = currentColumn.count
      candidate.locale = locale
      currentColumn.append(candidate)
    }
    candidateRows.append(currentColumn)
  }

  public mutating func selectNewNeighborRow(direction: VerticalDirection) {
    let currentSubIndex = candidateDataAll[highlightedIndex].subIndex
    var result = currentSubIndex
    switch direction {
      case .up:
        if currentRowNumber <= 0 {
          if candidateRows.isEmpty { break }
          let firstRow = candidateRows[0]
          let newSubIndex = min(currentSubIndex, firstRow.count - 1)
          highlight(at: firstRow[newSubIndex].index)
          break
        }
        if currentRowNumber >= candidateRows.count - 1 { currentRowNumber = candidateRows.count - 1 }
        if candidateRows[currentRowNumber].count != candidateRows[currentRowNumber - 1].count {
          let ratio: Double = min(1, Double(currentSubIndex) / Double(candidateRows[currentRowNumber].count))
          result = Int(floor(Double(candidateRows[currentRowNumber - 1].count) * ratio))
        }
        let targetRow = candidateRows[currentRowNumber - 1]
        let newSubIndex = min(result, targetRow.count - 1)
        highlight(at: targetRow[newSubIndex].index)
      case .down:
        if currentRowNumber >= candidateRows.count - 1 {
          if candidateRows.isEmpty { break }
          let finalRow = candidateRows[candidateRows.count - 1]
          let newSubIndex = min(currentSubIndex, finalRow.count - 1)
          highlight(at: finalRow[newSubIndex].index)
          break
        }
        if candidateRows[currentRowNumber].count != candidateRows[currentRowNumber + 1].count {
          let ratio: Double = min(1, Double(currentSubIndex) / Double(candidateRows[currentRowNumber].count))
          result = Int(floor(Double(candidateRows[currentRowNumber + 1].count) * ratio))
        }
        let targetRow = candidateRows[currentRowNumber + 1]
        let newSubIndex = min(result, targetRow.count - 1)
        highlight(at: targetRow[newSubIndex].index)
    }
  }

  public mutating func highlight(at indexSpecified: Int) {
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
    for (i, candidateColumn) in candidateRows.enumerated() {
      if i != currentRowNumber {
        candidateColumn.forEach {
          $0.key = " "
        }
      } else {
        for (i, neta) in candidateColumn.enumerated() {
          neta.key = selectionKeys.map { String($0) }[i]
        }
      }
    }
  }
}
