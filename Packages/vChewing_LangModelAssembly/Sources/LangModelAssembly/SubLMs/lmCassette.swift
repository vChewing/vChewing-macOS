// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LineReader
import Megrez
import Shared

extension vChewingLM {
  /// 磁帶模組，用來方便使用者自行擴充字根輸入法。
  public class LMCassette {
    public private(set) var nameShort: String = ""
    public private(set) var nameENG: String = ""
    public private(set) var nameCJK: String = ""
    public private(set) var nameIntl: String = ""
    /// 一個漢字可能最多要用到多少碼。
    public private(set) var maxKeyLength: Int = 1
    public private(set) var selectionKeys: [String] = []
    public private(set) var endKeys: [String] = []
    public private(set) var wildcardKey: String = ""
    public private(set) var keyNameMap: [String: String] = [:]
    public private(set) var charDefMap: [String: [String]] = [:]
    public private(set) var charDefWildcardMap: [String: [String]] = [:]
    public private(set) var reverseLookupMap: [String: [String]] = [:]
    /// 字根輸入法專用八股文：[字詞:頻次]。
    public private(set) var octagramMap: [String: Int] = [:]
    /// 音韻輸入法專用八股文：[字詞:(頻次, 讀音)]。
    public private(set) var octagramDividedMap: [String: (Int, String)] = [:]

    /// 計算頻率時要用到的東西
    private static let fscale = 2.7
    private var norm = 0.0

    /// 資料陣列內承載的資料筆數。
    public var count: Int { charDefMap.count }
    /// 是否已有資料載入。
    public var isLoaded: Bool { !charDefMap.isEmpty }
    /// 返回「允許使用的敲字鍵」的陣列。
    public var allowedKeys: [String] { Array(keyNameMap.keys + [" "]).deduplicated }
    /// 將給定的按鍵字母轉換成要顯示的形態。
    public func convertKeyToDisplay(char: String) -> String {
      keyNameMap[char] ?? char
    }

    /// 載入給定的 CIN 檔案內容。
    /// - Note:
    /// - 檢查是否以 `%gen_inp` 或者 `%ename` 開頭、以確認其是否為 cin 檔案。在讀到這些資訊之前的行都會被忽略。
    /// - `%ename` 決定磁帶的英文名、`%cname` 決定磁帶的 CJK 名稱、
    /// `%sname` 決定磁帶的最短英文縮寫名稱、`%intlname` 決定磁帶的本地化名稱綜合字串。
    /// - `%encoding` 不處理，因為 Swift 只認 UTF-8。
    /// - `%selkey`  不處理，因為威注音輸入法有自己的選字鍵體系。
    /// - `%endkey` 是會觸發組字事件的按鍵。
    /// - `%wildcardkey` 決定磁帶的萬能鍵名稱，只有第一個字元會生效。
    /// - `%keyname begin` 至 `%keyname end` 之間是字根翻譯表，先讀取為 Swift 辭典以備用。
    /// - `%chardef begin` 至 `%chardef end` 之間則是詞庫資料。
    /// - `%octagram begin` 至 `%octagram end` 之間則是詞語頻次資料。
    /// 第三欄資料為對應字根、可有可無。第一欄與第二欄分別為「字詞」與「統計頻次」。
    /// - Parameter path: 檔案路徑。
    /// - Returns: 是否載入成功。
    @discardableResult public func open(_ path: String) -> Bool {
      if isLoaded { return false }
      if FileManager.default.fileExists(atPath: path) {
        do {
          guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw FileErrors.fileHandleError("")
          }
          let lineReader = try LineReader(file: fileHandle)
          var theMaxKeyLength = 1
          var loadingKeys = false
          var loadingCharDefinitions = false
          var loadingOctagramData = false
          for strLine in lineReader {
            if !loadingKeys, strLine.contains("%keyname"), strLine.contains("begin") { loadingKeys = true }
            if loadingKeys, strLine.contains("%keyname"), strLine.contains("end") { loadingKeys = false }
            if !loadingCharDefinitions, strLine.contains("%chardef"), strLine.contains("begin") {
              loadingCharDefinitions = true
            }
            if loadingCharDefinitions, strLine.contains("%chardef"), strLine.contains("end") {
              loadingCharDefinitions = false
              if charDefMap.keys.contains(wildcardKey) { wildcardKey = "" }
            }
            if !loadingOctagramData, strLine.contains("%octagram"), strLine.contains("begin") {
              loadingOctagramData = true
            }
            if loadingOctagramData, strLine.contains("%octagram"), strLine.contains("end") {
              loadingOctagramData = false
            }
            let cells: [String.SubSequence] =
              strLine.contains("\t") ? strLine.split(separator: "\t") : strLine.split(separator: " ")
            guard cells.count >= 2 else { continue }
            let strFirstCell = String(cells[0])
            if loadingKeys, !cells[0].contains("%keyname") {
              keyNameMap[strFirstCell] = String(cells[1])
            } else if loadingCharDefinitions, !strLine.contains("%chardef") {
              let strSecondCell = String(cells[1])
              theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
              charDefMap[strFirstCell, default: []].append(strSecondCell)
              reverseLookupMap[strSecondCell, default: []].append(strFirstCell)
              var keyComps = strFirstCell.charComponents
              while !keyComps.isEmpty, !wildcardKey.isEmpty {
                keyComps.removeLast()
                if !wildcardKey.isEmpty {
                  charDefWildcardMap[keyComps.joined() + wildcardKey, default: []].append(strSecondCell)
                }
              }
            } else if loadingOctagramData, !strLine.contains("%octagram") {
              guard let countValue = Int(cells[1]) else { continue }
              switch cells.count {
                case 2: octagramMap[strFirstCell] = countValue
                case 3: octagramDividedMap[strFirstCell] = (countValue, String(cells[2]))
                default: break
              }
              norm += Self.fscale ** (Double(cells[0].count) / 3.0 - 1.0) * Double(countValue)
            }
            guard !loadingKeys, !loadingCharDefinitions, !loadingOctagramData else { continue }
            if nameENG.isEmpty, strLine.contains("%ename ") {
              for neta in cells[1].components(separatedBy: ";") {
                let subNetaGroup = neta.components(separatedBy: ":")
                if subNetaGroup.count == 2, subNetaGroup[1].contains("en") {
                  nameENG = String(subNetaGroup[0])
                  break
                }
              }
              if nameENG.isEmpty { nameENG = String(cells[1]) }
            }
            if nameIntl.isEmpty, strLine.contains("%intlname ") {
              nameIntl = String(cells[1]).replacingOccurrences(of: "_", with: " ")
            }
            if nameCJK.isEmpty, strLine.contains("%cname ") { nameCJK = String(cells[1]) }
            if nameShort.isEmpty, strLine.contains("%sname ") { nameShort = String(cells[1]) }
            if selectionKeys.isEmpty, strLine.contains("%selkey ") {
              selectionKeys = cells[1].map { String($0) }.deduplicated
            }
            if endKeys.isEmpty, strLine.contains("%endkey ") {
              endKeys = cells[1].map { String($0) }.deduplicated
            }
            if wildcardKey.isEmpty, strLine.contains("%wildcardkey ") {
              wildcardKey = cells[1].first?.description ?? ""
            }
          }
          maxKeyLength = theMaxKeyLength
          keyNameMap[wildcardKey] = keyNameMap[wildcardKey] ?? "？"
          return true
        } catch {
          vCLog("CIN Loading Failed: File Access Error.")
          return false
        }
      }
      vCLog("CIN Loading Failed: File Missing.")
      return false
    }

    public func clear() {
      keyNameMap.removeAll()
      charDefMap.removeAll()
      charDefWildcardMap.removeAll()
      nameShort.removeAll()
      nameENG.removeAll()
      nameCJK.removeAll()
      selectionKeys.removeAll()
      endKeys.removeAll()
      octagramMap.removeAll()
      octagramDividedMap.removeAll()
      wildcardKey.removeAll()
      nameIntl.removeAll()
      maxKeyLength = 1
      norm = 0
    }

    /// 根據給定的字根索引鍵，來獲取資料庫辭典內的對應結果。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      let arrRaw = charDefMap[key]?.deduplicated ?? []
      var arrRawWildcard: [String] = []
      if let arrRawWildcardValues = charDefWildcardMap[key]?.deduplicated,
        key.contains(wildcardKey), key.first?.description != wildcardKey
      {
        arrRawWildcard.append(contentsOf: arrRawWildcardValues)
      }
      var arrResults = [Megrez.Unigram]()
      var lowestScore: Double = 0
      for neta in arrRaw {
        let theScore: Double = {
          if let freqDataPair = octagramDividedMap[neta], key == freqDataPair.1 {
            return calculateWeight(count: freqDataPair.0, phraseLength: neta.count)
          } else if let freqData = octagramMap[neta] {
            return calculateWeight(count: freqData, phraseLength: neta.count)
          }
          return Double(arrResults.count) * -0.001 - 9.5
        }()
        lowestScore = min(theScore, lowestScore)
        arrResults.append(.init(value: neta, score: theScore))
      }
      lowestScore = min(-9.5, lowestScore)
      if !arrRawWildcard.isEmpty {
        for neta in arrRawWildcard {
          var theScore: Double = {
            if let freqDataPair = octagramDividedMap[neta], key == freqDataPair.1 {
              return calculateWeight(count: freqDataPair.0, phraseLength: neta.count)
            } else if let freqData = octagramMap[neta] {
              return calculateWeight(count: freqData, phraseLength: neta.count)
            }
            return Double(arrResults.count) * -0.001 - 9.7
          }()
          theScore += lowestScore
          arrResults.append(.init(value: neta, score: theScore))
        }
      }
      return arrResults
    }

    /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func hasUnigramsFor(key: String) -> Bool {
      charDefMap[key] != nil
        || (charDefWildcardMap[key] != nil && key.contains(wildcardKey) && key.first?.description != wildcardKey)
    }

    // MARK: - Private Functions.

    private func calculateWeight(count theCount: Int, phraseLength: Int) -> Double {
      var weight: Double = 0
      switch theCount {
        case -2:  // 拗音假名
          weight = -13
        case -1:  // 單個假名
          weight = -13
        case 0:  // 墊底低頻漢字與詞語
          weight = log10(
            Self.fscale ** (Double(phraseLength) / 3.0 - 1.0) * 0.25 / norm)
        default:
          weight = log10(
            Self.fscale ** (Double(phraseLength) / 3.0 - 1.0)
              * Double(theCount) / norm
          )
      }
      return weight
    }
  }
}

// MARK: - 引入冪乘函式

// Ref: https://stackoverflow.com/a/41581695/4162914
precedencegroup ExponentiationPrecedence {
  associativity: right
  higherThan: MultiplicationPrecedence
}

infix operator **: ExponentiationPrecedence

private func ** (_ base: Double, _ exp: Double) -> Double {
  pow(base, exp)
}
