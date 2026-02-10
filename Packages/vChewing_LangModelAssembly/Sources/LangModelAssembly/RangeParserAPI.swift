// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - StringView Ranges Extension MK2

// Credit: Isaac Xen (MK1) & Shiki Suen (MK2)

extension String {
  /// 分析傳入的原始辭典檔案（UTF-8 TXT）的資料。
  /// 以直接掃描分隔符位置的方式取得每一行的 Range，無需建構 Substring 陣列。
  /// - Parameters:
  ///   - separator: 行內單元分隔符。
  ///   - task: 要執行的外包任務。
  func parse(
    splitee separator: Character,
    task: @escaping (_ theRange: Range<String.Index>) -> ()
  ) {
    guard !isEmpty else { return }
    var lineStart = startIndex
    var i = startIndex
    while i < endIndex {
      if self[i] == separator {
        if lineStart < i {
          task(lineStart ..< i)
        }
        lineStart = index(after: i)
      }
      i = index(after: i)
    }
    // 處理最後一行（若不以分隔符結尾）。
    if lineStart < endIndex {
      task(lineStart ..< endIndex)
    }
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
