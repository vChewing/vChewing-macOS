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

// MARK: - LMAssembly.LMCassette

extension LMAssembly {
  /// 磁帶模組，用來方便使用者自行擴充字根輸入法。
  struct LMCassette {
    // MARK: Internal

    private(set) var filePath: String?
    private(set) var nameShort: String = ""
    private(set) var nameENG: String = ""
    private(set) var nameCJK: String = ""
    private(set) var nameIntl: String = ""
    private(set) var nullCandidate: String = ""
    /// 一個漢字可能最多要用到多少碼。
    private(set) var maxKeyLength: Int = 1
    private(set) var selectionKeys: String = ""
    private(set) var endKeys: [String] = []
    private(set) var wildcardKey: String = ""
    private(set) var keysToDirectlyCommit: String = ""
    private(set) var keyNameMap: [String: String] = [:]
    private(set) var quickDefMap: [String: String] = [:]
    private(set) var quickPhraseMap: [String: [String]] = [:]
    private(set) var quickPhraseCommissionKey: String = ""
    private(set) var charDefMap: [String: [String]] = [:]
    private(set) var charDefWildcardMap: [String: [String]] = [:]
    private(set) var symbolDefMap: [String: [String]] = [:]
    private(set) var reverseLookupMap: [String: [String]] = [:]
    /// 字根輸入法專用八股文：[字詞:頻次]。
    private(set) var octagramMap: [String: Int] = [:]
    /// 音韻輸入法專用八股文：[字詞:(頻次, 讀音)]。
    private(set) var octagramDividedMap: [String: (Int, String)] = [:]
    private(set) var areCandidateKeysShiftHeld: Bool = false
    private(set) var supplyQuickResults: Bool = false
    private(set) var supplyPartiallyMatchedResults: Bool = false
    var candidateKeysValidator: (String) -> Bool = { _ in false }

    // MARK: Private

    /// 計算頻率時要用到的東西 - NORM
    private var norm = 0.0
  }
}

extension LMAssembly.LMCassette {
  /// 計算頻率時要用到的東西 - fscale
  private static let fscale = 2.7
  /// 萬用花牌字符，哪怕花牌鍵仍不可用。
  var wildcard: String { wildcardKey.isEmpty ? "†" : wildcardKey }
  /// 資料陣列內承載的核心 charDef 資料筆數。
  var count: Int { charDefMap.count }
  /// 是否已有資料載入。
  var isLoaded: Bool { !charDefMap.isEmpty }
  /// 返回「允許使用的敲字鍵」的陣列。
  var allowedKeys: [String] { Array(keyNameMap.keys + [" "]).deduplicated }
  /// 將給定的按鍵字母轉換成要顯示的形態。
  func convertKeyToDisplay(char: String) -> String {
    keyNameMap[char] ?? char
  }

  /// 載入給定的 CIN 檔案內容。
  /// - Note:
  /// - 檢查是否以 `%gen_inp` 或者 `%ename` 開頭、以確認其是否為 cin 檔案。在讀到這些資訊之前的行都會被忽略。
  /// - `%ename` 決定磁帶的英文名、`%cname` 決定磁帶的 CJK 名稱、
  /// `%sname` 決定磁帶的最短英文縮寫名稱、`%intlname` 決定磁帶的本地化名稱綜合字串。
  /// - `%encoding` 不處理，因為 Swift 只認 UTF-8。
  /// - `%selkey`  不處理，因為唯音輸入法有自己的選字鍵體系。
  /// - `%endkey` 是會觸發組字事件的按鍵。
  /// - `%wildcardkey` 決定磁帶的萬能鍵名稱，只有第一個字元會生效。
  /// - `%nullcandidate` 用來指明 `%quick` 字段給出的候選字當中有哪一種是無效的。
  /// - `%keyname begin` 至 `%keyname end` 之間是字根翻譯表，先讀取為 Swift 辭典以備用。
  /// - `%quick begin` 至 `%quick end` 之間則是簡碼資料，對應的 value 得拆成單個漢字。
  /// - `%chardef begin` 至 `%chardef end` 之間則是詞庫資料。
  /// - `%symboldef begin` 至 `%symboldef end` 之間則是符號選單的專用資料。
  /// - `%octagram begin` 至 `%octagram end` 之間則是詞語頻次資料。
  /// 第三欄資料為對應字根、可有可無。第一欄與第二欄分別為「字詞」與「統計頻次」。
  /// - Parameter path: 檔案路徑。
  /// - Returns: 是否載入成功。
  @discardableResult
  mutating func open(_ path: String) -> Bool {
    if isLoaded { return false }
    let oldPath = filePath
    filePath = nil
    if FileManager.default.fileExists(atPath: path) {
      do {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
          throw LMAssembly.FileErrors.fileHandleError("")
        }
        let lineReader = try LineReader(file: fileHandle)
        var theMaxKeyLength = 1
        var loadingKeys = false
        var loadingQuickSets = false {
          willSet {
            supplyQuickResults = true
            if !newValue, quickDefMap.keys.contains(wildcardKey) { wildcardKey = "" }
          }
        }
        var loadingCharDefinitions = false {
          willSet {
            if !newValue, charDefMap.keys.contains(wildcardKey) { wildcardKey = "" }
          }
        }
        var loadingSymbolDefinitions = false {
          willSet {
            if !newValue, symbolDefMap.keys.contains(wildcardKey) { wildcardKey = "" }
          }
        }
        var loadingOctagramData = false
        var loadingQuickPhrases = false
        var keysUsedInCharDef: Set<String> = .init()

        for strLine in lineReader {
          let isTabDelimiting = strLine.contains("\t")
          let cells = isTabDelimiting ? strLine.split(separator: "\t") : strLine
            .split(separator: " ")
          guard cells.count >= 1 else { continue }
          let strFirstCell = cells[0].trimmingCharacters(in: .newlines)
          let strSecondCell = cells.count >= 2 ? cells[1].trimmingCharacters(in: .newlines) : nil
          // 處理雜項資訊
          if strLine.first == "%", strFirstCell != "%" {
            // %flag_disp_partial_match
            if strLine == "%flag_disp_partial_match" {
              supplyPartiallyMatchedResults = true
              supplyQuickResults = true
            }
            guard let strSecondCell = strSecondCell else { continue }
            processTags: switch strFirstCell {
            case "%keyname" where strSecondCell == "begin": loadingKeys = true
            case "%keyname" where strSecondCell == "end": loadingKeys = false
            case "%quick" where strSecondCell == "begin": loadingQuickSets = true
            case "%quick" where strSecondCell == "end": loadingQuickSets = false
            case "%chardef" where strSecondCell == "begin": loadingCharDefinitions = true
            case "%chardef" where strSecondCell == "end": loadingCharDefinitions = false
            case "%symboldef" where strSecondCell == "begin": loadingSymbolDefinitions = true
            case "%symboldef" where strSecondCell == "end": loadingSymbolDefinitions = false
            case "%octagram" where strSecondCell == "begin": loadingOctagramData = true
            case "%octagram" where strSecondCell == "end": loadingOctagramData = false
            case "%quickphrases" where strSecondCell == "begin": loadingQuickPhrases = true
            case "%quickphrases" where strSecondCell == "end": loadingQuickPhrases = false
            case "%ename" where nameENG.isEmpty:
              parseSubCells: for neta in strSecondCell.components(separatedBy: ";") {
                let subNetaGroup = neta.components(separatedBy: ":")
                guard subNetaGroup.count == 2, subNetaGroup[1].contains("en") else { continue }
                nameENG = String(subNetaGroup[0])
                break parseSubCells
              }
              guard nameENG.isEmpty else { break processTags }
              nameENG = strSecondCell
            case "%intlname"
              where nameIntl.isEmpty: nameIntl = strSecondCell
              .replacingOccurrences(of: "_", with: " ")
            case "%cname" where nameCJK.isEmpty: nameCJK = strSecondCell
            case "%sname" where nameShort.isEmpty: nameShort = strSecondCell
            case "%nullcandidate" where nullCandidate.isEmpty: nullCandidate = strSecondCell
            case "%selkey"
              where selectionKeys.isEmpty: selectionKeys = strSecondCell.map(\.description)
              .deduplicated.joined()
            case "%endkey"
              where endKeys.isEmpty: endKeys = strSecondCell.map(\.description).deduplicated
            case "%wildcardkey"
              where wildcardKey.isEmpty: wildcardKey = strSecondCell.first?.description ?? ""
            case "%keys_to_directly_commit"
              where keysToDirectlyCommit.isEmpty: keysToDirectlyCommit = strSecondCell
            case "%quickphrases_commission_key"
              where quickPhraseCommissionKey.isEmpty:
              quickPhraseCommissionKey = strSecondCell.first?.description ?? ""
            default: break processTags
            }
            continue
          }

          // 處理普通資料
          guard let strSecondCell = strSecondCell else { continue }
          if loadingKeys {
            keyNameMap[strFirstCell] = strSecondCell.trimmingCharacters(in: .newlines)
          } else if loadingQuickSets {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            quickDefMap[strFirstCell, default: .init()].append(strSecondCell)
          } else if loadingQuickPhrases {
            theMaxKeyLength = max(theMaxKeyLength, strFirstCell.count)
            var remainderLine = strLine.trimmingCharacters(in: .newlines)
            if remainderLine.hasPrefix(strFirstCell) {
              remainderLine.removeFirst(strFirstCell.count)
            }
            let trimmedRemainder = remainderLine.drop(while: { $0 == "\t" || $0 == " " })
            let remainderString = String(trimmedRemainder)
            var phraseCandidates: [String] = []
            if isTabDelimiting {
              phraseCandidates = remainderString.split(separator: "\t").map {
                $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
              }
            } else {
              let trimmed = remainderString
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
              if !trimmed.isEmpty { phraseCandidates = [trimmed] }
            }
            let sanitized = phraseCandidates
              .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
              .filter { !$0.isEmpty && $0 != nullCandidate }
            guard !sanitized.isEmpty else { continue }
            var phrases = quickPhraseMap[strFirstCell, default: []]
            phrases.append(contentsOf: sanitized)
            phrases = phrases
              .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
              .filter { !$0.isEmpty && $0 != nullCandidate }
              .deduplicated
            quickPhraseMap[strFirstCell] = phrases
          } else if loadingCharDefinitions, !loadingSymbolDefinitions {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            charDefMap[strFirstCell, default: []].append(strSecondCell)
            if strFirstCell.count > 1 {
              strFirstCell.map(\.description).forEach { keyChar in
                keysUsedInCharDef.insert(keyChar.description)
              }
            }
            reverseLookupMap[strSecondCell, default: []].append(strFirstCell)
            var keyComps = strFirstCell.map(\.description)
            while !keyComps.isEmpty {
              keyComps.removeLast()
              charDefWildcardMap[keyComps.joined() + wildcard, default: []].append(strSecondCell)
            }
          } else if loadingSymbolDefinitions {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            symbolDefMap[strFirstCell, default: []].append(strSecondCell)
            reverseLookupMap[strSecondCell, default: []].append(strFirstCell)
          } else if loadingOctagramData {
            guard let countValue = Int(strSecondCell) else { continue }
            switch cells.count {
            case 2: octagramMap[strFirstCell] = countValue
            case 3: octagramDividedMap[strFirstCell] = (
                countValue,
                cells[2].trimmingCharacters(in: .newlines)
              )
            default: break
            }
            norm += Self.fscale ** (Double(cells[0].count) / 3.0 - 1.0) * Double(countValue)
          }
        }
        // Post process.
        // 備註：因為 Package 層級嵌套的現狀，此處不太方便檢查是否需要篩掉 J / K 鍵。
        // 因此只能在其他地方做篩檢。
        if !candidateKeysValidator(selectionKeys) { selectionKeys = "1234567890" }
        if !keysUsedInCharDef.intersection(selectionKeys.map(\.description)).isEmpty {
          areCandidateKeysShiftHeld = true
        }
        maxKeyLength = theMaxKeyLength
        keyNameMap[wildcardKey] = keyNameMap[wildcardKey] ?? "？"
        filePath = path
        return true
      } catch {
        vCLMLog("CIN Loading Failed: File Access Error.")
      }
    } else {
      vCLMLog("CIN Loading Failed: File Missing.")
    }
    filePath = oldPath
    return false
  }

  mutating func clear() {
    // 明確清理所有字典以釋放記憶體
    keyNameMap.removeAll(keepingCapacity: false)
    quickDefMap.removeAll(keepingCapacity: false)
    quickPhraseMap.removeAll(keepingCapacity: false)
    charDefMap.removeAll(keepingCapacity: false)
    charDefWildcardMap.removeAll(keepingCapacity: false)
    symbolDefMap.removeAll(keepingCapacity: false)
    reverseLookupMap.removeAll(keepingCapacity: false)
    octagramMap.removeAll(keepingCapacity: false)
    octagramDividedMap.removeAll(keepingCapacity: false)
    endKeys.removeAll(keepingCapacity: false)

    // 重置為初始狀態
    self = .init()
  }

  func quickSetsFor(key: String) -> String? {
    guard !key.isEmpty else { return nil }
    var result = [String]()
    if let specifiedResult = quickDefMap[key], !specifiedResult.isEmpty {
      result.append(contentsOf: specifiedResult.map(\.description))
    }
    if supplyQuickResults, result.isEmpty {
      if supplyPartiallyMatchedResults {
        let fetched = charDefMap.compactMap {
          $0.key.starts(with: key) ? $0 : nil
        }.stableSort {
          $0.key.count < $1.key.count
        }.flatMap(\.value).filter {
          $0.count == 1
        }
        result.append(contentsOf: fetched.deduplicated.prefix(selectionKeys.count * 6))
      } else {
        let fetched = (charDefMap[key] ?? [String]()).filter { $0.count == 1 }
        result.append(contentsOf: fetched.deduplicated.prefix(selectionKeys.count * 6))
      }
    }
    return result.isEmpty ? nil : result.joined(separator: "\t")
  }

  func quickPhrasesFor(key: String) -> [String]? {
    guard !key.isEmpty else { return nil }
    guard let phrases = quickPhraseMap[key]?
      .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
      .filter({ !$0.isEmpty }) else { return nil }
    let sanitized = phrases.filter { $0 != nullCandidate }.deduplicated
    return sanitized.isEmpty ? nil : sanitized
  }

  /// 根據給定的字根索引鍵，來獲取資料庫辭典內的對應結果。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  func unigramsFor(key: String, keyArray: [String]? = nil) -> [Megrez.Unigram] {
    let keyArray = keyArray ?? key.split(separator: "-").map(\.description)
    let arrRaw = charDefMap[key]?.deduplicated ?? []
    var arrRawWildcard: [String] = []
    if let arrRawWildcardValues = charDefWildcardMap[key]?.deduplicated,
       key.contains(wildcard), key.first?.description != wildcard {
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
      arrResults.append(.init(keyArray: keyArray, value: neta, score: theScore))
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
        arrResults.append(.init(keyArray: keyArray, value: neta, score: theScore))
      }
    }
    return arrResults
  }

  /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  func hasUnigramsFor(key: String) -> Bool {
    charDefMap[key] != nil
      ||
      (
        charDefWildcardMap[key] != nil && key.contains(wildcard) && key.first?
          .description != wildcard
      )
  }

  // MARK: - Private Functions.

  private func calculateWeight(count theCount: Int, phraseLength: Int) -> Double {
    var weight: Double = 0
    switch theCount {
    case -2: // 拗音假名
      weight = -13
    case -1: // 單個假名
      weight = -13
    case 0: // 墊底低頻漢字與詞語
      weight = log10(
        Self.fscale ** (Double(phraseLength) / 3.0 - 1.0) * 0.25 / norm
      )
    default:
      weight = log10(
        Self.fscale ** (Double(phraseLength) / 3.0 - 1.0)
          * Double(theCount) / norm
      )
    }
    return weight
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
