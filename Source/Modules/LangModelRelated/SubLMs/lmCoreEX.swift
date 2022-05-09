// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/// 與之前的 LMCore 不同，LMCoreEX 不在辭典內記錄實體，而是記錄 range 範圍。
/// 需要資料的時候，直接拿 range 去 strData 取資料。
/// 資料記錄原理與上游 C++ 的 ParselessLM 差不多，但用的是 Swift 原生手段。
/// 主要時間消耗仍在 For 迴圈，但這個算法可以顯著減少記憶體佔用。

import Foundation

extension vChewing {
  @frozen public struct LMCoreEX {
    var rangeMap: [String: [Range<String.Index>]] = [:]
    var strData: String = ""
    var shouldReverse: Bool = false
    var allowConsolidation: Bool = false
    var defaultScore: Double = 0
    var shouldForceDefaultScore: Bool = false

    public var count: Int {
      rangeMap.count
    }

    public init(
      reverse: Bool = false, consolidate: Bool = false, defaultScore scoreDefault: Double = 0,
      forceDefaultScore: Bool = false
    ) {
      rangeMap = [:]
      allowConsolidation = consolidate
      shouldReverse = reverse
      defaultScore = scoreDefault
      shouldForceDefaultScore = forceDefaultScore
    }

    public func isLoaded() -> Bool {
      !rangeMap.isEmpty
    }

    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded() {
        return false
      }

      if allowConsolidation {
        LMConsolidator.fixEOF(path: path)
        LMConsolidator.consolidate(path: path, pragma: true)
      }

      do {
        strData = try String(contentsOfFile: path, encoding: .utf8).replacingOccurrences(of: "\t", with: " ")
        strData.ranges(splitBy: "\n").forEach {
          let neta = strData[$0].components(separatedBy: " ")
          if neta.count >= 2 {
            let theKey = shouldReverse ? neta[1] : neta[0]
            if !neta[0].isEmpty, !neta[1].isEmpty, theKey.first != "#" {
              let theValue = $0
              rangeMap[theKey, default: []].append(theValue)
            }
          }
        }
      } catch {
        IME.prtDebugIntel("\(error)")
        IME.prtDebugIntel("↑ Exception happened when reading data at: \(path).")
        return false
      }

      return true
    }

    public mutating func close() {
      if isLoaded() {
        rangeMap.removeAll()
      }
    }

    // MARK: - Advanced features

    public func dump() {
      var strDump = ""
      for entry in rangeMap {
        let netaRanges: [Range<String.Index>] = entry.value
        for netaRange in netaRanges {
          let neta = strData[netaRange]
          let addline = neta + "\n"
          strDump += addline
        }
      }
      IME.prtDebugIntel(strDump)
    }

    public func bigramsForKeys(precedingKey: String, key: String) -> [Megrez.Bigram] {
      // 這裡用了點廢話處理，不然函數構建體會被 Swift 格式整理工具給毀掉。
      // 其實只要一句「[Megrez.Bigram]()」就夠了。
      precedingKey == key ? [Megrez.Bigram]() : [Megrez.Bigram]()
    }

    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      var grams: [Megrez.Unigram] = []
      if let arrRangeRecords: [Range<String.Index>] = rangeMap[key] {
        for netaRange in arrRangeRecords {
          let neta = strData[netaRange].components(separatedBy: " ")
          let theValue: String = shouldReverse ? neta[0] : neta[1]
          let kvPair = Megrez.KeyValuePair(key: key, value: theValue)
          var theScore = defaultScore
          if neta.count >= 3, !shouldForceDefaultScore {
            theScore = .init(neta[2]) ?? defaultScore
          }
          if theScore > 0 {
            theScore *= -1  // 應對可能忘記寫負號的情形
          }
          grams.append(Megrez.Unigram(keyValue: kvPair, score: theScore))
        }
      }
      return grams
    }

    public func hasUnigramsFor(key: String) -> Bool {
      rangeMap[key] != nil
    }
  }
}

// MARK: - StringView Ranges Extension (by Isaac Xen)

extension String {
  fileprivate func ranges(splitBy separator: Element) -> [Range<String.Index>] {
    var startIndex = startIndex
    return split(separator: separator).reduce(into: []) { ranges, substring in
      _ = range(of: substring, range: startIndex..<endIndex).map { range in
        ranges.append(range)
        startIndex = range.upperBound
      }
    }
  }
}
