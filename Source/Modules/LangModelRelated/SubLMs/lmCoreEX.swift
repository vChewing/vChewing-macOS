// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension vChewing {
  /// 與之前的 LMCore 不同，LMCoreEX 不在辭典內記錄實體，而是記錄 range 範圍。
  /// 需要資料的時候，直接拿 range 去 strData 取資料。
  /// 資料記錄原理與上游 C++ 的 ParselessLM 差不多，但用的是 Swift 原生手段。
  /// 主要時間消耗仍在 For 迴圈，但這個算法可以顯著減少記憶體佔用。
  @frozen public struct LMCoreEX {
    /// 資料庫辭典。索引內容為注音字串，資料內容則為字串首尾範圍、方便自 strData 取資料。
    var rangeMap: [String: [Range<String.Index>]] = [:]
    /// 資料庫字串陣列。
    var strData: String = ""
    /// 聲明原始檔案內第一、二縱列的內容是否彼此顛倒。
    var shouldReverse: Bool = false
    var allowConsolidation: Bool = false
    /// 當某一筆資料內的權重資料毀損時，要施加的預設權重。
    var defaultScore: Double = 0
    /// 啟用該選項的話，會強制施加預設權重、而無視原始權重資料。
    var shouldForceDefaultScore: Bool = false

    /// 資料陣列內承載的資料筆數。
    public var count: Int {
      rangeMap.count
    }

    /// 初期化該語言模型。
    ///
    /// - parameters:
    ///   - reverse: 聲明原始檔案內第一、二縱列的內容是否彼此顛倒。
    ///   - consolidate: 請且僅請對使用者語言模組啟用該參數：是否自動整理格式。
    ///   - defaultScore: 當某一筆資料內的權重資料毀損時，要施加的預設權重。
    ///   - forceDefaultScore: 啟用該選項的話，會強制施加預設權重、而無視原始權重資料。
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

    /// 檢測資料庫辭典內是否已經有載入的資料。
    public func isLoaded() -> Bool {
      !rangeMap.isEmpty
    }

    /// 將資料從檔案讀入至資料庫辭典內。
    /// - parameters:
    ///   - path: 給定路徑。
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
        strData = strData.replacingOccurrences(of: "\r", with: "\n")
        strData.ranges(splitBy: "\n").filter { !$0.isEmpty }.forEach {
          let neta = strData[$0].split(separator: " ")
          if neta.count >= 2, String(neta[0]).first != "#" {
            if !neta[0].isEmpty, !neta[1].isEmpty {
              let theKey = shouldReverse ? String(neta[1]) : String(neta[0])
              let theValue = $0
              rangeMap[Tekkon.cnvHanyuPinyinToPhona(target: theKey.lowercased()), default: []].append(theValue)
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

    /// 將當前語言模組的資料庫辭典自記憶體內卸除。
    public mutating func close() {
      if isLoaded() {
        rangeMap.removeAll()
      }
    }

    // MARK: - Advanced features

    /// 將當前資料庫辭典的內容以文本的形式輸出至 macOS 內建的 Console.app。
    ///
    /// 該功能僅作偵錯之用途。
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

    /// 根據給定的讀音索引鍵，來獲取資料庫辭典內的對應資料陣列的字串首尾範圍資料、據此自 strData 取得字串形式的資料、生成單元圖陣列。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      var grams: [Megrez.Unigram] = []
      if let arrRangeRecords: [Range<String.Index>] = rangeMap[key] {
        for netaRange in arrRangeRecords {
          let neta = strData[netaRange].split(separator: " ")
          let theValue: String = shouldReverse ? String(neta[0]) : String(neta[1])
          var theScore = defaultScore
          if neta.count >= 3, !shouldForceDefaultScore, !neta[2].contains("#") {
            theScore = .init(String(neta[2])) ?? defaultScore
          }
          if theScore > 0 {
            theScore *= -1  // 應對可能忘記寫負號的情形
          }
          grams.append(Megrez.Unigram(value: theValue, score: theScore))
        }
      }
      return grams
    }

    /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func hasUnigramsFor(key: String) -> Bool {
      rangeMap[key] != nil
    }
  }
}

// MARK: - StringView Ranges Extension (by Isaac Xen)

extension String {
  /// 就該字串與給定分隔符、返回每一元素的首尾索引值。
  /// - parameters:
  ///   - splitBy: 給定分隔符
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
