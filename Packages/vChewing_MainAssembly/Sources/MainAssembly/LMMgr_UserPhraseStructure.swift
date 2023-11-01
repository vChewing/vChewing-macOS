// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LangModelAssembly
import Shared

// MARK: - 使用者語彙類型定義

public extension LMMgr {
  struct UserPhrase: Hashable {
    public private(set) var keyArray: [String]
    public private(set) var value: String
    public private(set) var inputMode: Shared.InputMode
    public private(set) var isConverted: Bool = false
    public var weight: Double?

    public var isDuplicated: Bool {
      LMMgr.checkIfPhrasePairExists(userPhrase: value, mode: inputMode, keyArray: keyArray)
    }

    public var joinedKey: String {
      keyArray.joined(separator: "-")
    }

    public var isValid: Bool {
      !keyArray.isEmpty && keyArray.filter(\.isEmpty).isEmpty && !value.isEmpty
    }

    public var description: String {
      descriptionCells.joined(separator: " ")
    }

    public var descriptionCells: [String] {
      var result = [String]()
      result.append(value)
      result.append(joinedKey)
      if let weight = weight {
        result.append(weight.description)
      }
      if isDuplicated {
        result.append("#𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎")
      }
      if isConverted {
        result.append("#𝙃𝙪𝙢𝙖𝙣𝘾𝙝𝙚𝙘𝙠𝙍𝙚𝙦𝙪𝙞𝙧𝙚𝙙")
      }
      return result
    }

    public var crossConverted: UserPhrase {
      if isConverted { return self }
      var result = self
      result.value = ChineseConverter.crossConvert(value)
      result.inputMode = inputMode.reversed
      result.isConverted = true
      return result
    }

    public var isAlreadyFiltered: Bool {
      LMMgr.getLM(mode: inputMode).isPairFiltered(pair: .init(keyArray: keyArray, value: value))
    }

    public func write(toFilter: Bool) -> Bool {
      guard isValid else {
        vCLog("UserPhrase.write(toFilter: \(toFilter.description)) Error: UserPhrase invalid.")
        return false
      }
      guard LMMgr.chkUserLMFilesExist(inputMode) else {
        vCLog("UserPhrase.write(toFilter: \(toFilter.description)) Error: UserLMFiles not exist.")
        return false
      }
      if !toFilter, isAlreadyFiltered {
        vCLog("START REMOVING THIS PHRASE FROM FILTER.")
        removeFromFilter()
        // 在整理過一遍之後，如果還是被排除的狀態的話，則證明語彙濾除清單檔案有格式問題、需要整理。
        // 這種情況下，先強制整理，再排除。
        if isAlreadyFiltered {
          removeFromFilter(forceConsolidate: true)
        }
        return !isAlreadyFiltered
      }
      /// 施工筆記：
      /// 有些使用者的語彙檔案已經過於龐大了（超過一千行），
      /// 每次寫入時都全文整理格式的話，會引發嚴重的效能問題。
      /// 所以這裡不再強制要求整理格式。
      let theType: vChewingLM.ReplacableUserDataType = toFilter ? .theFilter : .thePhrases
      let theURL = LMMgr.userDictDataURL(mode: inputMode, type: theType)
      var fileSize: UInt64?
      do {
        let dict = try FileManager.default.attributesOfItem(atPath: theURL.path)
        if let value = dict[FileAttributeKey.size] as? UInt64 { fileSize = value }
      } catch {
        vCLog("UserPhrase.write(toFilter: \(toFilter.description)) Error: Target file size is null.")
        return false
      }
      guard let fileSize = fileSize else {
        vCLog("UserPhrase.write(toFilter: \(toFilter.description)) Error: Target file size is null.")
        return false
      }
      guard var dataToInsert = "\(description)\n".data(using: .utf8) else {
        vCLog("UserPhrase.write(toFilter: \(toFilter.description)) Error: Failed from preparing insertion data.")
        return false
      }
      guard let writeFile = FileHandle(forUpdatingAtPath: theURL.path) else {
        vCLog("UserPhrase.write(toFilter: \(toFilter.description)) Error: Failed from initiating file handle.")
        return false
      }
      defer { writeFile.closeFile() }
      if fileSize > 0 {
        writeFile.seek(toFileOffset: fileSize - 1)
        if writeFile.readDataToEndOfFile().first != 0x0A {
          dataToInsert.insert(0x0A, at: 0)
        }
      }
      writeFile.seekToEndOfFile()
      writeFile.write(dataToInsert)
      return true
    }

    /// 嘗試將該筆記錄從語彙濾除清單檔案內移除，但可能會因為語彙濾除清單檔案尚未整理的格式而失敗。
    ///
    /// 原理：發現該當條目時，直接全部置換為 NULL（0x0）。這樣可以最小化磁碟寫入次數。
    /// （不然還得將當前位置後面的內容整個重新寫入。）
    /// - Parameter confirm: 再檢查一遍是否符合執行條件。不符合的話，就啥也不做。
    @discardableResult public func removeFromFilter(confirm: Bool = false, forceConsolidate: Bool = false) -> Bool {
      let debugOutput = NSMutableString()
      defer {
        if debugOutput.length > 0 { vCLog(debugOutput.description) }
      }
      if confirm {
        guard isValid else {
          debugOutput.append("removeFromFilter(): This user phrase pair is invalid. \(descriptionCells.prefix(2).joined(separator: " "))")
          return false
        }
        guard isAlreadyFiltered else {
          debugOutput.append("removeFromFilter(): This user phrase pair is not in the filtered list.")
          return false
        }
      }
      let theURL = LMMgr.userDictDataURL(mode: inputMode, type: .theFilter)
      if forceConsolidate, !vChewingLM.LMConsolidator.consolidate(path: theURL.path, pragma: false) { return false }
      // Get FileSize.
      var fileSize: UInt64?
      do {
        let dict = try FileManager.default.attributesOfItem(atPath: theURL.path)
        if let value = dict[FileAttributeKey.size] as? UInt64 { fileSize = value }
      } catch {
        debugOutput.append("removeFromFilter(): Failed from getting the file size of the filter list file.")
        return false
      }
      guard let fileSize = fileSize else { return false }
      // Prepare FileHandle.
      guard let fileHandle = FileHandle(forUpdatingAtPath: theURL.path) else {
        debugOutput.append("removeFromFilter(): Failed from handling the filter list file.")
        return false
      }
      defer { fileHandle.closeFile() }
      // Get bytes for matching.
      let usefulCells = descriptionCells.prefix(2)
      guard usefulCells.count == 2 else { return false }
      guard let data1 = usefulCells.joined(separator: " ").data(using: .utf8) else { return false }
      guard let data2 = usefulCells.joined(separator: "\t").data(using: .utf8) else { return false }
      let bufferLength = data1.count // data1 與 data2 長度相等
      guard fileSize >= bufferLength else { return true }
      let blankData = Data([UInt8](repeating: 0x0, count: bufferLength)) // 用來搞填充的垃圾資料
      let sharpData = Data([0x23]) // Sharp Sign (#)
      fileHandle.seek(toFileOffset: 0) // 從頭開始讀取處理。
      for currentOffset in -1 ..< (Int(fileSize) - bufferLength - 1) {
        /// !! 注意：FileHandle 的 seek 位置會在每次 readData() / write() 之後都有變動。
        // 確定手術位置
        let currentWorkingOffset = UInt64(currentOffset + 1)
        // 讀取且檢查當前位元組
        fileHandle.seek(toFileOffset: UInt64(max(0, currentOffset)))
        let currentByte = fileHandle.readData(ofLength: 1)
        guard currentByte != sharpData else { continue }
        // 開始手術
        fileHandle.seek(toFileOffset: currentWorkingOffset)
        let dataScoped = fileHandle.readData(ofLength: bufferLength)
        guard [data1, data2].contains(dataScoped) else { continue }
        fileHandle.seek(toFileOffset: currentWorkingOffset)
        fileHandle.write(blankData)
      }
      LMMgr.reloadUserFilterDirectly(mode: inputMode)
      return true
    }
  }
}
