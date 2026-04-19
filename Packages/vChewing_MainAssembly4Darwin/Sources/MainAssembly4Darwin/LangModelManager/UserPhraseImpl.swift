// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - UserPhraseInsertable Extensions.

extension UserPhraseInsertable {
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

  public var isDuplicated: Bool {
    LMMgr.checkIfPhrasePairExists(userPhrase: value, mode: inputMode, keyArray: keyArray)
  }

  public var crossConverted: Self {
    isConverted ? self : .init(
      keyArray: keyArray,
      value: ChineseConverter.crossConvert(value),
      inputMode: inputMode.reversed,
      isConverted: true,
      weight: weight
    )
  }

  public var isAlreadyFiltered: Bool {
    inputMode.langModel.isPairFiltered(pair: .init(keyArray: keyArray, value: value))
  }

  public func write(toFilter: Bool) -> Bool {
    LMAssembly.withFileHandleQueueSync {
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
      let theType: LMAssembly.ReplacableUserDataType = toFilter ? .theFilter : .thePhrases
      let theURL = LMMgr.userDictDataURL(mode: inputMode, type: theType)
      var fileSize: UInt64?
      do {
        let dict = try FileManager.default.attributesOfItem(atPath: theURL.path)
        if let value = dict[FileAttributeKey.size] as? UInt64 { fileSize = value }
      } catch {
        vCLog(
          "UserPhrase.write(toFilter: \(toFilter.description)) Error: Target file size is null."
        )
        return false
      }
      guard let fileSize = fileSize else {
        vCLog(
          "UserPhrase.write(toFilter: \(toFilter.description)) Error: Target file size is null."
        )
        return false
      }
      guard var dataToInsert = "\(description)\n".data(using: .utf8) else {
        vCLog(
          "UserPhrase.write(toFilter: \(toFilter.description)) Error: Failed from preparing insertion data."
        )
        return false
      }
      guard let writeFile = FileHandle(forUpdatingAtPath: theURL.path) else {
        vCLog(
          "UserPhrase.write(toFilter: \(toFilter.description)) Error: Failed from initiating file handle."
        )
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
  }

  /// 嘗試將該筆記錄從語彙濾除清單檔案內移除，但可能會因為語彙濾除清單檔案尚未整理的格式而失敗。
  ///
  /// 原理：發現該當條目時，直接全部置換為 NULL（0x0）。這樣可以最小化磁碟寫入次數。
  /// （不然還得將當前位置後面的內容整個重新寫入。）
  /// - Parameter confirm: 再檢查一遍是否符合執行條件。不符合的話，就啥也不做。
  @discardableResult
  public func removeFromFilter(
    confirm: Bool = false,
    forceConsolidate: Bool = false
  )
    -> Bool {
    LMAssembly.withFileHandleQueueSync {
      var debugOutput = ContiguousArray<String>()
      defer {
        if !debugOutput.isEmpty { vCLog(debugOutput.joined(separator: "\n")) }
      }
      if confirm {
        guard isValid else {
          debugOutput
            .append(
              "removeFromFilter(): This user phrase pair is invalid. \(descriptionCells.prefix(2).joined(separator: " "))"
            )
          return false
        }
        guard isAlreadyFiltered else {
          debugOutput
            .append("removeFromFilter(): This user phrase pair is not in the filtered list.")
          return false
        }
      }
      let theURL = LMMgr.userDictDataURL(mode: inputMode, type: .theFilter)
      if forceConsolidate,
         !LMAssembly.LMConsolidator.consolidate(path: theURL.path, pragma: false) { return false }
      // Get FileSize.
      var fileSize: UInt64?
      do {
        let dict = try FileManager.default.attributesOfItem(atPath: theURL.path)
        if let value = dict[FileAttributeKey.size] as? UInt64 { fileSize = value }
      } catch {
        debugOutput
          .append("removeFromFilter(): Failed from getting the file size of the filter list file.")
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
      let lfData = Data([0x0A]) // Line Feed '\n'
      fileHandle.seek(toFileOffset: 0) // 從頭開始讀取處理。
      for currentWorkingOffset in 0 ... (Int(fileSize) - bufferLength) {
        /// !! 注意：FileHandle 的 seek 位置會在每次 readData() / write() 之後都有變動。
        // 只在「行首或換行（LF）之後」嘗試匹配；此外，若前一位元組是 # 則略過。
        if currentWorkingOffset > 0 {
          fileHandle.seek(toFileOffset: UInt64(currentWorkingOffset - 1))
          let previousByte = fileHandle.readData(ofLength: 1)
          if previousByte == sharpData { continue }
          guard previousByte == lfData else { continue }
        }
        // 開始手術
        fileHandle.seek(toFileOffset: UInt64(currentWorkingOffset))
        let dataScoped = fileHandle.readData(ofLength: bufferLength)
        guard [data1, data2].contains(dataScoped) else { continue }
        fileHandle.seek(toFileOffset: UInt64(currentWorkingOffset))
        fileHandle.write(blankData)
      }
      LMMgr.reloadUserFilterDirectly(mode: inputMode)
      return true
    }
  }
}

// MARK: - Weight Suggestions.

extension UserPhraseInsertable {
  public mutating func updateWeight(basedOn action: CandidateContextMenuAction) {
    weight = suggestNextFreq(for: action)
  }

  public func suggestNextFreq(
    for action: CandidateContextMenuAction,
    extreme: Bool = false
  )
    -> Double? {
    var extremeFallbackResult: Double? {
      switch action {
      case .toBoost: return nil // 不填寫權重的話，預設權重是 0
      case .toNerf: return -114.514
      case .toFilter: return nil
      }
    }
    guard !extreme, isSingleCharReadingPair else { return extremeFallbackResult }
    let fetchedUnigrams = inputMode.langModel.unigramsFor(keyArray: keyArray)
    let currentWeight = weight ?? fetchedUnigrams.first { $0.current == value }?.probability
    guard let currentWeight = currentWeight else { return extremeFallbackResult }
    let fetchedScores = fetchedUnigrams.map(\.probability)
    var neighborValue: Double?
    switch action {
    case .toBoost:
      neighborValue = currentWeight.findNeighborValue(from: fetchedScores, greater: true)
      if let realNeighborValue = neighborValue {
        neighborValue = realNeighborValue + 0.000001
      } else if let fetchedMax = fetchedScores.min(), currentWeight <= fetchedMax {
        neighborValue = Swift.min(0, currentWeight + 0.000001)
      } else {
        // 理論上來講，這種情況不該出現。
        neighborValue = Swift.min(0, currentWeight + 1)
      }
    case .toNerf:
      neighborValue = currentWeight.findNeighborValue(from: fetchedScores, greater: false)
      if let realNeighborValue = neighborValue {
        neighborValue = realNeighborValue - 0.000001
      } else if let fetchedMax = fetchedScores.max(), currentWeight >= fetchedMax {
        neighborValue = Swift.max(-114.514, currentWeight - 0.000001)
      } else {
        // 理論上來講，這種情況不該出現。
        neighborValue = Swift.max(-114.514, currentWeight - 1)
      }
    case .toFilter: return nil
    }
    return neighborValue ?? extremeFallbackResult
  }
}
