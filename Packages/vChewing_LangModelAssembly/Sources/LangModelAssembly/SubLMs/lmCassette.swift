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
    public private(set) var nameENG: String = ""
    public private(set) var nameCJK: String = ""
    /// 一個漢字可能最多要用到多少碼。
    public private(set) var maxKeyLength: Int = 1
    public private(set) var selectionKeys: [String] = []
    public private(set) var endKeys: [String] = []
    public private(set) var keyNameMap: [String: String] = [:]
    public private(set) var charDefMap: [String: [String]] = [:]

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
    /// - `%ename` 決定磁帶的英文名、`%cname` 決定磁帶的 CJK 名稱。
    /// - `%encoding` 不處理，因為 Swift 只認 UTF-8。
    /// - `%selkey`  不處理，因為威注音輸入法有自己的選字鍵體系。
    /// - `%endkey` 是會觸發組字事件的按鍵。
    /// - `%keyname begin` 至 `%keyname end` 之間是字根翻譯表，先讀取為 Swift 辭典以備用。
    /// - `%chardef begin` 至 `%chardef end` 之間則是詞庫資料。
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
          var isOV = false
          var shouldStartReading = false
          var loadingKeys = false
          var loadingCharDefinitions = false
          for (_, strLine) in lineReader.enumerated() {
            if !shouldStartReading, strLine.contains("%gen_inp") || strLine.contains("%ename ") {
              isOV = strLine.contains("%gen_inp")
              shouldStartReading = true
            }
            guard shouldStartReading else { continue }
            if !loadingKeys, strLine.contains("%keyname begin") { loadingKeys = true }
            if loadingKeys, strLine.contains("%keyname end") { loadingKeys = false }
            if !loadingCharDefinitions, strLine.contains("%chardef begin") { loadingCharDefinitions = true }
            if loadingCharDefinitions, strLine.contains("%chardef end") { loadingCharDefinitions = false }
            let cells: [String.SubSequence] =
              strLine.contains("\t") ? strLine.split(separator: "\t") : strLine.split(separator: " ")
            guard cells.count == 2 else { continue }
            if loadingKeys, !cells[0].contains("%keyname") {
              keyNameMap[String(cells[0])] = String(cells[1])
            } else if loadingCharDefinitions, !strLine.contains("%chardef") {
              theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
              charDefMap[String(cells[0]), default: []].append(String(cells[1]))
            }
            guard !loadingKeys, !loadingCharDefinitions else { continue }
            if nameENG.isEmpty, strLine.contains("%ename ") {
              if isOV {
                nameENG = String(cells[1])
              } else {
                for neta in cells[1].components(separatedBy: ";") {
                  let subNetaGroup = neta.components(separatedBy: ":")
                  if subNetaGroup.count == 2, subNetaGroup[1].contains("en") {
                    nameENG = String(subNetaGroup[0])
                    break
                  }
                }
                if nameENG.isEmpty { nameENG = String(cells[1]) }
              }
            }
            if nameCJK.isEmpty, strLine.contains("%cname ") { nameCJK = String(cells[1]) }
            if selectionKeys.isEmpty, strLine.contains("%selkey ") {
              selectionKeys = cells[1].map { String($0) }.deduplicated
            }
            if endKeys.isEmpty, strLine.contains("%endkey ") {
              endKeys = cells[1].map { String($0) }.deduplicated
            }
          }
          maxKeyLength = theMaxKeyLength
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
      nameENG.removeAll()
      nameCJK.removeAll()
      selectionKeys.removeAll()
      endKeys.removeAll()
      maxKeyLength = 1
    }

    /// 根據給定的讀音索引鍵，來獲取資料庫辭典內的對應結果。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      guard let arrRaw = charDefMap[key]?.deduplicated, !arrRaw.isEmpty else { return [] }
      var arrResults = [Megrez.Unigram]()
      for (i, neta) in arrRaw.enumerated() {
        arrResults.append(.init(value: neta, score: Double(i) * -0.001))
      }
      return arrResults
    }

    /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func hasUnigramsFor(key: String) -> Bool {
      charDefMap[key] != nil
    }
  }
}
