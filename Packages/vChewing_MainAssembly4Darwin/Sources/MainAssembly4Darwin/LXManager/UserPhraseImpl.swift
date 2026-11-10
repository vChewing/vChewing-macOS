// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// Apple artificially gated the modern FileHandle API names behind macOS 10.15 / 10.15.4,
// even though these APIs have no version restriction on Linux/Windows.
// Use @backDeployed to provide fallbacks on older Darwin via the legacy names.
#if canImport(Darwin)
  extension FileHandle {
    // 每個成員各標 `nonisolated`（§5.1(b)：標頭修飾詞下放至成員）。
    // 標頭層級的 `nonisolated extension` 會令 5.10 拒收
    // （`'nonisolated' modifier cannot be applied to this declaration`）；
    // 而 `defaultIsolation(MainActor.self)` 之下，成員不標即落回 MainActor、脫離不了非隔離呼叫端。
    @backDeployed(before: macOS 10.15)
    nonisolated public final func close() throws {
      closeFile()
    }

    @backDeployed(before: macOS 10.15)
    nonisolated public final func seek(toOffset offset: UInt64) throws {
      seek(toFileOffset: offset)
    }

    @backDeployed(before: macOS 10.15)
    @discardableResult
    nonisolated public final func seekToEnd() throws -> UInt64 {
      seekToEndOfFile()
    }

    @backDeployed(before: macOS 10.15)
    nonisolated public final func readToEnd() throws -> Data? {
      let data = readDataToEndOfFile()
      return data.isEmpty ? nil : data
    }

    @backDeployed(before: macOS 10.15)
    nonisolated public final func read(upToCount count: Int) throws -> Data? {
      let data = readData(ofLength: count)
      return data.isEmpty ? nil : data
    }

    @backDeployed(before: macOS 10.15)
    nonisolated public final func write(contentsOf data: Data) throws {
      write(data)
    }
  }
#endif

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
    LXMgr.checkIfPhrasePairExists(userPhrase: value, mode: inputMode, keyArray: keyArray)
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
    inputMode.lexicon.lxQuerier.isPairFiltered(pair: .init(keyArray: keyArray, value: value))
  }

  /// 於主執行緒備妥一份落盤計畫。
  ///
  /// 所有語言模組之查詢（該配對是否已在濾除清單內、該列是否與既存條目重複、權重幾何）皆在此
  /// 完成——那些狀態由主執行緒單獨持有。耗時的檔案 I/O 則交給
  /// ``LXAssembly/UserPhraseFileWriter`` 於使用者資料寫入巷上執行（P345）。
  ///
  /// - Parameter toFilter: 是否要加入濾除清單。
  /// - Returns: 落盤計畫；輸入資料不合規時為 `nil`。
  public func makeWritePlan(toFilter: Bool) -> LXAssembly.UserPhraseFileWriter.WritePlan? {
    guard isValid else {
      vCLog("UserPhrase.makeWritePlan(toFilter: \(toFilter.description)) Error: UserPhrase invalid.")
      return nil
    }
    let cells = descriptionCells
    // 已在濾除清單內者，本次「不加濾除」實為「自濾除清單移出」。
    if !toFilter, isAlreadyFiltered {
      let type: LXAssembly.ReplaceableUserDataType = .theFilter
      return .init(
        kind: .unfilter,
        targetURL: LXMgr.userDictDataURL(mode: inputMode, type: type),
        cells: cells,
        templateURL: LXMgr.templateURL(for: type, mode: inputMode)
      )
    }
    let type: LXAssembly.ReplaceableUserDataType = toFilter ? .theFilter : .thePhrases
    return .init(
      kind: .append,
      targetURL: LXMgr.userDictDataURL(mode: inputMode, type: type),
      cells: cells,
      templateURL: LXMgr.templateURL(for: type, mode: inputMode)
    )
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
    let fetchedUnigrams = inputMode.lexicon.lxQuerier.grams(for: keyArray)
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
