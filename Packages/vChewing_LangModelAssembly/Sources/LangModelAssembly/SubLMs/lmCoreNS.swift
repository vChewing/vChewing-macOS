// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import Shared

extension vChewingLM {
  /// 與之前的 LMCore 不同，LMCoreNS 直接讀取 plist。
  /// 這樣一來可以節省在舊 mac 機種內的資料讀入速度。
  /// 目前僅針對輸入法原廠語彙資料檔案使用 plist 格式。
  @frozen public struct LMCoreNS {
    public private(set) var filePath: String?
    /// 資料庫辭典。索引內容為經過加密的注音字串，資料內容則為 UTF8 資料陣列。
    var dataMap: [String: [Data]] = [:]
    /// 【已作廢】資料庫字串陣列。在 LMCoreNS 內沒有作用。
    var strData: String = ""
    /// 【已作廢】聲明原始檔案內第一、二縱列的內容是否彼此顛倒。
    var shouldReverse = false
    /// 請且僅請對使用者語言模組啟用該參數：是否自動整理格式。
    var allowConsolidation = false
    /// 當某一筆資料內的權重資料毀損時，要施加的預設權重。
    var defaultScore: Double = 0
    /// 啟用該選項的話，會強制施加預設權重、而無視原始權重資料。
    var shouldForceDefaultScore = false

    /// 資料陣列內承載的資料筆數。
    public var count: Int { dataMap.count }

    /// 初期化該語言模型。
    ///
    /// 某些參數在 LMCoreNS 內已作廢，但仍保留、以方便那些想用該專案源碼做實驗的人群。
    ///
    /// - parameters:
    ///   - reverse: 已作廢：聲明原始檔案內第一、二縱列的內容是否彼此顛倒。
    ///   - consolidate: 請且僅請對使用者語言模組啟用該參數：是否自動整理格式。
    ///   - defaultScore: 當某一筆資料內的權重資料毀損時，要施加的預設權重。
    ///   - forceDefaultScore: 啟用該選項的話，會強制施加預設權重、而無視原始權重資料。
    public init(
      reverse: Bool = false, consolidate: Bool = false, defaultScore scoreDefault: Double = 0,
      forceDefaultScore: Bool = false
    ) {
      dataMap = [:]
      allowConsolidation = consolidate
      shouldReverse = reverse
      defaultScore = scoreDefault
      shouldForceDefaultScore = forceDefaultScore
    }

    /// 檢測資料庫辭典內是否已經有載入的資料。
    public var isLoaded: Bool { !dataMap.isEmpty }

    /// 將資料從檔案讀入至資料庫辭典內。
    /// - parameters:
    ///   - path: 給定路徑。
    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded { return false }
      let oldPath = filePath
      filePath = nil

      do {
        let rawData = try Data(contentsOf: URL(fileURLWithPath: path))
        let rawPlist: [String: [Data]] =
          try PropertyListSerialization.propertyList(from: rawData, format: nil) as? [String: [Data]] ?? .init()
        dataMap = rawPlist
      } catch {
        filePath = oldPath
        vCLog("↑ Exception happened when reading plist file at: \(path).")
        return false
      }

      filePath = path
      return true
    }

    /// 將當前語言模組的資料庫辭典自記憶體內卸除。
    public mutating func clear() {
      filePath = nil
      strData.removeAll()
      dataMap.removeAll()
    }

    // MARK: - Advanced features

    public func saveData() {
      guard let filePath = filePath, let plistURL = URL(string: filePath) else { return }
      do {
        let plistData = try PropertyListSerialization.data(fromPropertyList: dataMap, format: .binary, options: 0)
        try plistData.write(to: plistURL)
      } catch {
        vCLog("Failed to save current database to: \(filePath)")
      }
    }

    /// 將當前資料庫辭典的內容以文本的形式輸出至 macOS 內建的 Console.app。
    ///
    /// 該功能僅作偵錯之用途。
    public func dump() {
      var strDump = ""
      for entry in dataMap {
        let netaSets: [Data] = entry.value
        let theKey = entry.key
        for netaSet in netaSets {
          let strNetaSet = String(decoding: netaSet, as: UTF8.self)
          let neta = Array(strNetaSet.trimmingCharacters(in: .newlines).components(separatedBy: " ").reversed())
          let theValue = neta[0]
          var theScore = defaultScore
          if neta.count >= 2, !shouldForceDefaultScore {
            theScore = .init(String(neta[1])) ?? defaultScore
          }
          strDump += "\(cnvPhonabetToASCII(theKey)) \(theValue) \(theScore)\n"
        }
      }
      vCLog(strDump)
    }

    /// 根據給定的讀音索引鍵，來獲取資料庫辭典內的對應資料陣列的 UTF8 資料、就地分析、生成單元圖陣列。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      var grams: [Megrez.Unigram] = []
      var gramsHW: [Megrez.Unigram] = []
      guard let arrRangeRecords: [Data] = dataMap[cnvPhonabetToASCII(key)] else { return grams }
      for netaSet in arrRangeRecords {
        let strNetaSet = String(decoding: netaSet, as: UTF8.self)
        let neta = Array(strNetaSet.trimmingCharacters(in: .newlines).split(separator: " ").reversed())
        let theValue: String = .init(neta[0])
        var theScore = defaultScore
        if neta.count >= 2, !shouldForceDefaultScore {
          theScore = .init(String(neta[1])) ?? defaultScore
        }
        if theScore > 0 {
          theScore *= -1  // 應對可能忘記寫負號的情形
        }
        grams.append(Megrez.Unigram(value: theValue, score: theScore))
        if !key.contains("_punctuation") { continue }
        if let halfValue = theValue.applyingTransform(.fullwidthToHalfwidth, reverse: false) {
          if halfValue != theValue {
            gramsHW.append(Megrez.Unigram(value: halfValue, score: theScore))
          }
        }
      }
      grams.append(contentsOf: gramsHW)
      return grams
    }

    /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func hasUnigramsFor(key: String) -> Bool {
      dataMap[cnvPhonabetToASCII(key)] != nil
    }

    /// 內部函式，用以將注音讀音索引鍵進行加密。
    ///
    /// 使用這種加密字串作為索引鍵，可以增加對 plist 資料庫的存取速度。
    ///
    /// 如果傳入的字串當中包含 ASCII 下畫線符號的話，則表明該字串並非注音讀音字串，會被忽略處理。
    /// - parameters:
    ///   - incoming: 傳入的未加密注音讀音字串。
    func cnvPhonabetToASCII(_ incoming: String) -> String {
      var strOutput = incoming
      if !strOutput.contains("_") {
        for entry in Self.dicPhonabet2ASCII {
          strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
        }
      }
      return strOutput
    }

    /// 內部函式，用以將被加密的注音讀音索引鍵進行解密。
    ///
    /// 如果傳入的字串當中包含 ASCII 下畫線符號的話，則表明該字串並非注音讀音字串，會被忽略處理。
    /// - parameters:
    ///   - incoming: 傳入的已加密注音讀音字串。
    func restorePhonabetFromASCII(_ incoming: String) -> String {
      var strOutput = incoming
      if !strOutput.contains("_") {
        for entry in Self.dicPhonabet4ASCII {
          strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
        }
      }
      return strOutput
    }

    // MARK: - Constants

    static let dicPhonabet2ASCII: [String: String] = [
      "ㄅ": "b", "ㄆ": "p", "ㄇ": "m", "ㄈ": "f", "ㄉ": "d", "ㄊ": "t", "ㄋ": "n", "ㄌ": "l", "ㄍ": "g", "ㄎ": "k", "ㄏ": "h",
      "ㄐ": "j", "ㄑ": "q", "ㄒ": "x", "ㄓ": "Z", "ㄔ": "C", "ㄕ": "S", "ㄖ": "r", "ㄗ": "z", "ㄘ": "c", "ㄙ": "s", "ㄧ": "i",
      "ㄨ": "u", "ㄩ": "v", "ㄚ": "a", "ㄛ": "o", "ㄜ": "e", "ㄝ": "E", "ㄞ": "B", "ㄟ": "P", "ㄠ": "M", "ㄡ": "F", "ㄢ": "D",
      "ㄣ": "T", "ㄤ": "N", "ㄥ": "L", "ㄦ": "R", "ˊ": "2", "ˇ": "3", "ˋ": "4", "˙": "5",
    ]

    static let dicPhonabet4ASCII: [String: String] = [
      "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ", "g": "ㄍ", "k": "ㄎ", "h": "ㄏ",
      "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "Z": "ㄓ", "C": "ㄔ", "S": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ", "s": "ㄙ", "i": "ㄧ",
      "u": "ㄨ", "v": "ㄩ", "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "E": "ㄝ", "B": "ㄞ", "P": "ㄟ", "M": "ㄠ", "F": "ㄡ", "D": "ㄢ",
      "T": "ㄣ", "N": "ㄤ", "L": "ㄥ", "R": "ㄦ", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "˙",
    ]
  }
}
