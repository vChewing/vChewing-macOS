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
  /// - Parameters:
  ///   - separator: 行內單元分隔符。
  ///   - task: 要執行的外包任務。
  func parse(
    splitee separator: Element,
    task: @escaping (_ theRange: Range<String.Index>) -> Void
  ) {
    var startIndex = startIndex
    split(separator: separator).forEach { substring in
      let theRange = range(of: substring, range: startIndex ..< endIndex)
      guard let theRange = theRange else { return }
      task(theRange)
      startIndex = theRange.upperBound
    }
  }
}

// MARK: - StringView Ranges Extension MK1 Backup (by Isaac Xen)

// This is only for reference and is not used in this assembly.

private extension String {
  func ranges(splitBy separator: Element) -> [Range<String.Index>] {
    var startIndex = startIndex
    return split(separator: separator).reduce(into: []) { ranges, substring in
      _ = range(of: substring, range: startIndex ..< endIndex).map { range in
        ranges.append(range)
        startIndex = range.upperBound
      }
    }
  }
}
