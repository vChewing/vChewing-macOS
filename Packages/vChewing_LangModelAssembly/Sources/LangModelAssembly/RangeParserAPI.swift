// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - StringView Ranges Extension MK3

// Credit: Shiki Suen (MK3)

extension String {
  // Reuse the UTF-8 fast path for both line parsing and per-line cell scanning.
  private func parseRanges(
    in sourceRange: Range<String.Index>,
    splitee separator: Character,
    task: (_ theRange: Range<String.Index>, _ itemIndex: Int) -> Bool
  ) {
    guard !sourceRange.isEmpty else { return }

    if separator.unicodeScalars.count == 1,
       let separatorScalar = separator.unicodeScalars.first,
       separatorScalar.value < 0x80,
       let separatorByte = UInt8(exactly: separatorScalar.value) {
      let utf8View = utf8
      var itemStart = sourceRange.lowerBound
      var i = sourceRange.lowerBound
      var itemIndex = 0
      while i < sourceRange.upperBound {
        if utf8View[i] == separatorByte {
          if itemStart < i {
            guard task(itemStart ..< i, itemIndex) else { return }
            itemIndex += 1
          }
          utf8View.formIndex(after: &i)
          itemStart = i
          continue
        }
        utf8View.formIndex(after: &i)
      }
      if itemStart < sourceRange.upperBound {
        _ = task(itemStart ..< sourceRange.upperBound, itemIndex)
      }
      return
    }

    var itemStart = sourceRange.lowerBound
    var i = sourceRange.lowerBound
    var itemIndex = 0
    while i < sourceRange.upperBound {
      if self[i] == separator {
        if itemStart < i {
          guard task(itemStart ..< i, itemIndex) else { return }
          itemIndex += 1
        }
        i = index(after: i)
        itemStart = i
        continue
      }
      i = index(after: i)
    }
    if itemStart < sourceRange.upperBound {
      _ = task(itemStart ..< sourceRange.upperBound, itemIndex)
    }
  }

  /// 分析傳入的原始辭典檔案（UTF-8 TXT）的資料。
  /// 以直接掃描分隔符位置的方式取得每一行的 Range，無需建構 Substring 陣列。
  /// - Parameters:
  ///   - separator: 行內單元分隔符。
  ///   - task: 要執行的外包任務。
  func parse(
    splitee separator: Character,
    task: (_ theRange: Range<String.Index>) -> ()
  ) {
    parseRanges(in: startIndex ..< endIndex, splitee: separator) { theRange, _ in
      task(theRange)
      return true
    }
  }

  /// 在既有字串範圍內依照分隔符逐格掃描，忽略空片段且允許提早停止。
  /// - Parameters:
  ///   - sourceRange: 要處理的字串範圍。
  ///   - separator: 格內單元分隔符。
  ///   - task: 對每個 cell range 執行的任務；回傳 false 可提早結束掃描。
  func parseCells(
    in sourceRange: Range<String.Index>,
    splitee separator: Character,
    task: (_ theRange: Range<String.Index>, _ itemIndex: Int) -> Bool
  ) {
    parseRanges(in: sourceRange, splitee: separator, task: task)
  }
}

// MARK: - StringView Ranges Extension MK1 Backup (by Isaac Xen)

// This is only for reference and is not used in this assembly.

extension String {
  fileprivate func ranges(splitBy separator: Element) -> [Range<String.Index>] {
    var startIndex = startIndex
    return split(separator: separator).reduce(into: []) { ranges, substring in
      _ = range(of: substring, range: startIndex ..< endIndex).map { range in
        ranges.append(range)
        startIndex = range.upperBound
      }
    }
  }
}
