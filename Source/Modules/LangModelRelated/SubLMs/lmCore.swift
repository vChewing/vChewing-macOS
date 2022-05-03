// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

// 威注音重新設計原廠詞庫語言模組。不排序，但使用 Swift 內建的 String 處理。

import Foundation

extension vChewing {
  public class LMCore {
    var keyValueScoreMap: [String: [Megrez.Unigram]] = [:]
    var theData: String = ""
    var shouldReverse: Bool = false
    var allowConsolidation: Bool = false
    var defaultScore: Double = 0
    var shouldForceDefaultScore: Bool = false

    public init(
      reverse: Bool = false, consolidate: Bool = false, defaultScore scoreDefault: Double = 0,
      forceDefaultScore: Bool = false
    ) {
      keyValueScoreMap = [:]
      theData = ""
      allowConsolidation = consolidate
      shouldReverse = reverse
      defaultScore = scoreDefault
      shouldForceDefaultScore = forceDefaultScore
    }

    deinit {
      if isLoaded() {
        close()
      }
    }

    public func isLoaded() -> Bool {
      !keyValueScoreMap.isEmpty
    }

    @discardableResult public func open(_ path: String) -> Bool {
      if isLoaded() {
        return false
      }

      if allowConsolidation {
        if !LMConsolidator.fixEOF(path: path) {
          return false
        }
        if !LMConsolidator.consolidate(path: path, pragma: true) {
          return false
        }
      }

      do {
        theData = try String(contentsOfFile: path, encoding: .utf8)
      } catch {
        IME.prtDebugIntel("\(error)")
        IME.prtDebugIntel("↑ Exception happened when reading Associated Phrases data.")
        return false
      }

      let length = theData.count
      guard length > 0 else {
        return false
      }

      let arrData = theData.components(separatedBy: "\n")
      for (lineID, lineContent) in arrData.enumerated() {
        if !lineContent.hasPrefix("#") {
          let lineContent = lineContent.replacingOccurrences(of: "\t", with: " ")
          if lineContent.components(separatedBy: " ").count < 2 {
            if arrData.last != "" {
              IME.prtDebugIntel("Line #\(lineID + 1) Wrecked: \(lineContent)")
            }
            continue
          }
          var currentUnigram = Megrez.Unigram(keyValue: Megrez.KeyValuePair(), score: self.defaultScore)
          var columnOne = ""
          var columnTwo = ""
          for (unitID, unitContent) in lineContent.components(separatedBy: " ").enumerated() {
            switch unitID {
              case 0:
                columnOne = unitContent
              case 1:
                columnTwo = unitContent
              case 2:
                if !self.shouldForceDefaultScore {
                  if let unitContentConverted = Double(unitContent) {
                    currentUnigram.score = unitContentConverted
                  } else {
                    IME.prtDebugIntel("Line #\(lineID) Score Data Wrecked: \(lineContent)")
                  }
                }
              default: break
            }
          }
          // 標點符號的頻率最好鎖定一下。
          if columnOne.contains("_punctuation_") {
            currentUnigram.score -= (Double(lineID) * 0.000001)
          }
          let kvPair =
            self.shouldReverse
            ? Megrez.KeyValuePair(key: columnTwo, value: columnOne)
            : Megrez.KeyValuePair(key: columnOne, value: columnTwo)
          currentUnigram.keyValue = kvPair
          let key = self.shouldReverse ? columnTwo : columnOne
          self.keyValueScoreMap[key, default: []].append(currentUnigram)
        }
      }
      IME.prtDebugIntel("\(self.keyValueScoreMap.count) entries of data loaded from: \(path)")
      theData = ""
      return true
    }

    public func close() {
      if isLoaded() {
        keyValueScoreMap.removeAll()
      }
    }

    // MARK: - Advanced features

    public func dump() {
      var strDump = ""
      for entry in keyValueScoreMap {
        let rows: [Megrez.Unigram] = entry.1
        for row in rows {
          let addline = row.keyValue.key + " " + row.keyValue.value + " " + String(row.score) + "\n"
          strDump += addline
        }
      }
      IME.prtDebugIntel(strDump)
    }

    open func bigramsForKeys(precedingKey: String, key: String) -> [Megrez.Bigram] {
      // 這裡用了點廢話處理，不然函數構建體會被 Swift 格式整理工具給毀掉。
      // 其實只要一句「[Megrez.Bigram]()」就夠了。
      precedingKey == key ? [Megrez.Bigram]() : [Megrez.Bigram]()
    }

    open func unigramsFor(key: String) -> [Megrez.Unigram] {
      keyValueScoreMap[key] ?? [Megrez.Unigram]()
    }

    open func hasUnigramsFor(key: String) -> Bool {
      keyValueScoreMap[key] != nil
    }
  }
}
