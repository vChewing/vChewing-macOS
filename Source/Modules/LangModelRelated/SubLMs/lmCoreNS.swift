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

/// 與之前的 LMCore 不同，LMCoreNS 直接讀取 plist。
/// 這樣一來可以節省在舊 mac 機種內的資料讀入速度。

import Foundation

extension vChewing {
  @frozen public struct LMCoreNS {
    var rangeMap: [String: [Data]] = [:]
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
        let rawData = try Data(contentsOf: URL(fileURLWithPath: path))
        let rawPlist = try PropertyListSerialization.propertyList(from: rawData, format: nil) as! [String: [Data]]
        rangeMap = rawPlist
      } catch {
        IME.prtDebugIntel("↑ Exception happened when reading plist file at: \(path).")
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
        let netaSets: [Data] = entry.value
        let theKey = entry.key
        for netaSet in netaSets {
          let strNetaSet = String(decoding: netaSet, as: UTF8.self)
          let neta = Array(strNetaSet.components(separatedBy: " ").reversed())
          let theValue = neta[0]
          var theScore = defaultScore
          if neta.count >= 2, !shouldForceDefaultScore {
            theScore = .init(String(neta[1])) ?? defaultScore
          }
          strDump += "\(cnvPhonabetToASCII(theKey)) \(theValue) \(theScore)\n"
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
      if let arrRangeRecords: [Data] = rangeMap[cnvPhonabetToASCII(key)] {
        for netaSet in arrRangeRecords {
          let strNetaSet = String(decoding: netaSet, as: UTF8.self)
          let neta = Array(strNetaSet.split(separator: " ").reversed())
          let theValue: String = String(neta[0])
          let kvPair = Megrez.KeyValuePair(key: key, value: theValue)
          var theScore = defaultScore
          if neta.count >= 2, !shouldForceDefaultScore {
            theScore = .init(String(neta[1])) ?? defaultScore
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
      rangeMap[cnvPhonabetToASCII(key)] != nil
    }

    func cnvPhonabetToASCII(_ incoming: String) -> String {
      let dicPhonabet2ASCII = [
        "ㄅ": "b", "ㄆ": "p", "ㄇ": "m", "ㄈ": "f", "ㄉ": "d", "ㄊ": "t", "ㄋ": "n", "ㄌ": "l", "ㄍ": "g", "ㄎ": "k", "ㄏ": "h",
        "ㄐ": "j", "ㄑ": "q", "ㄒ": "x", "ㄓ": "Z", "ㄔ": "C", "ㄕ": "S", "ㄖ": "r", "ㄗ": "z", "ㄘ": "c", "ㄙ": "s", "ㄧ": "i",
        "ㄨ": "u", "ㄩ": "v", "ㄚ": "a", "ㄛ": "o", "ㄜ": "e", "ㄝ": "E", "ㄞ": "B", "ㄟ": "P", "ㄠ": "M", "ㄡ": "F", "ㄢ": "D",
        "ㄣ": "T", "ㄤ": "N", "ㄥ": "L", "ㄦ": "R", "ˊ": "2", "ˇ": "3", "ˋ": "4", "˙": "5",
      ]
      var strOutput = incoming
      if !strOutput.contains("_") {
        for entry in dicPhonabet2ASCII {
          strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
        }
      }
      return strOutput
    }

    func restorePhonabetFromASCII(_ incoming: String) -> String {
      let dicPhonabet4ASCII = [
        "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ", "g": "ㄍ", "k": "ㄎ", "h": "ㄏ",
        "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "Z": "ㄓ", "C": "ㄔ", "S": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ", "s": "ㄙ", "i": "ㄧ",
        "u": "ㄨ", "v": "ㄩ", "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "E": "ㄝ", "B": "ㄞ", "P": "ㄟ", "M": "ㄠ", "F": "ㄡ", "D": "ㄢ",
        "T": "ㄣ", "N": "ㄤ", "L": "ㄥ", "R": "ㄦ", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "˙",
      ]

      var strOutput = incoming
      if !strOutput.contains("_") {
        for entry in dicPhonabet4ASCII {
          strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
        }
      }
      return strOutput
    }
  }
}
