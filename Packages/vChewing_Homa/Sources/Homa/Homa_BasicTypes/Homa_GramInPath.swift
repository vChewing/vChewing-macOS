// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Homa.GramInPath

extension Homa {
  /// 輕量化節點封裝，便於將節點內的有效資訊以 Sendable 形式獨立傳遞。
  ///
  /// 該結構體的所有成員均為不可變狀態。
  @frozen
  public struct GramInPath: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(gram: Gram, isExplicit: Bool) {
      self.gram = gram
      self.isExplicit = isExplicit
    }

    // MARK: Public

    public let gram: Gram
    public let isExplicit: Bool

    public var value: String { gram.current }
    public var score: Double { gram.probability }
    public var segLength: Int { gram.segLength }
    public var keyArray: [String] { gram.keyArray }
    public var isReadingMismatched: Bool { gram.isReadingMismatched }

    /// 該節點當前狀態所展示的鍵值配對。
    public var asCandidatePair: Homa.CandidatePair {
      .init(keyArray: keyArray, value: value)
    }

    /// 將當前單元圖的讀音陣列按照給定的分隔符銜接成一個字串。
    /// - Parameter separator: 給定的分隔符，預設值為 Assembler.theSeparator。
    /// - Returns: 已經銜接完畢的字串。
    public func joinedCurrentKey(by separator: String) -> String {
      keyArray.joined(separator: separator)
    }
  }
}

// MARK: - Perception Observation

extension Homa {
  /// 觀測上下文類型。
  public enum POMObservationScenario: String, Codable, Sendable {
    /// 同長度更換。
    case sameLenSwap
    /// 短詞變長詞。
    case shortToLong
    /// 長詞變短詞。
    case longToShort
  }

  /// 觀測上下文情形。
  public struct PerceptionIntel: Codable, Hashable, Sendable {
    /// 觀測情境被序列化後的複元圖簽名。
    public let contextualizedGramKey: String
    /// 候選字。
    public let candidate: String
    /// 頭部讀音。
    public let headReading: String
    /// 觀測場景。
    public let scenario: POMObservationScenario
    /// 是否需強制高分覆寫。
    public let forceHighScoreOverride: Bool
    /// 語言模型分數。
    public let scoreFromLM: Double
  }

  /// 根據候選字覆寫行為前後的組句結果，在指定游標位置得出觀測上下文之情形。
  /// - Parameters:
  ///   - previouslyAssembled: 候選字覆寫行為前的組句結果。
  ///   - currentAssembled: 候選字覆寫行為後的組句結果。
  ///   - cursor: 游標。
  /// - Returns: 觀測上下文結果。
  public static func makePerceptionIntel(
    previouslyAssembled: [Homa.GramInPath],
    currentAssembled: [Homa.GramInPath],
    cursor: Int
  )
    -> PerceptionIntel? {
    guard !previouslyAssembled.isEmpty, !currentAssembled.isEmpty else { return nil }

    // 確認游標落在 currentAssembled 的有效節點
    guard let afterHit = currentAssembled.findGram(at: cursor) else { return nil }
    let current = afterHit.gram
    let currentLen = current.segLength
    if currentLen > 3 { return nil }

    // 在 previouslyAssembled 中找到對應 head 的節點（使用 after 的節點區間上界 -1 作為內點）
    let border1 = afterHit.range.upperBound - 1
    let border2 = previouslyAssembled.totalKeyCount - 1
    let innerIndex = Swift.max(0, Swift.min(border1, border2))
    guard let beforeHit = previouslyAssembled.findGram(at: innerIndex) else { return nil }
    let prevHead = beforeHit.gram
    let prevLen = prevHead.segLength

    let isBreakingUp = (currentLen == 1 && prevLen > 1)
    let isShortToLong = (currentLen > prevLen)
    let scenario: POMObservationScenario = switch (isBreakingUp, isShortToLong) {
    case (true, _): .longToShort
    case (false, true): .shortToLong
    case (false, false): .sameLenSwap
    }
    let forceHSO = isShortToLong
    let keyCursorRaw = Swift.max(
      afterHit.range.lowerBound,
      Swift.min(cursor, afterHit.range.upperBound - 1)
    )

    func clampedCursor(for source: [Homa.GramInPath]) -> Int {
      Swift.max(0, Swift.min(keyCursorRaw, max(source.totalKeyCount - 1, 0)))
    }

    func splitKeyParts(_ key: String) -> [String] {
      let parts = key.split(separator: "&").map(String.init)
      if parts.isEmpty { return ["()", "()", "()"] }
      if parts.count >= 3 { return parts }
      var padded = parts
      while padded.count < 3 { padded.insert("()", at: 0) }
      return padded
    }

    var keyGen: (ngramKey: String, candidate: String, headReading: String)?
    let headKeyOffset = keyCursorRaw - afterHit.range.lowerBound

    switch scenario {
    case .shortToLong:
      let cursorPrev = clampedCursor(for: previouslyAssembled)
      let cursorCurr = clampedCursor(for: currentAssembled)
      let keyGenPrev = previouslyAssembled.generateKeyForPerception(cursor: cursorPrev)
      let keyGenCurr = currentAssembled.generateKeyForPerception(cursor: cursorCurr)

      if let keyGenPrev, let keyGenCurr {
        let mergedPreview = splitKeyParts(keyGenPrev.ngramKey)
        let currentParts = splitKeyParts(keyGenCurr.ngramKey)
        var mergedParts = mergedPreview
        if let newHead = currentParts.last {
          let hasPlaceholderContext = currentParts.dropLast().contains("()")
          if hasPlaceholderContext {
            mergedParts[mergedParts.count - 1] = newHead
          } else {
            let valueSegments = Array(afterHit.gram.value).map(String.init)
            let headValueSegment = valueSegments.indices.contains(headKeyOffset)
              ? valueSegments[headKeyOffset] : afterHit.gram.value
            let refinedHead = "(\(keyGenCurr.headReading),\(headValueSegment))"
            mergedParts[mergedParts.count - 1] = refinedHead
          }
        }
        keyGen = (
          ngramKey: mergedParts.joined(separator: "&"),
          candidate: keyGenCurr.candidate,
          headReading: keyGenCurr.headReading
        )
      } else {
        keyGen = keyGenCurr ?? keyGenPrev
      }

    case .longToShort, .sameLenSwap:
      let primarySource = currentAssembled
      let fallbackSource = previouslyAssembled

      if primarySource.totalKeyCount > 0 {
        let cursorPrimary = clampedCursor(for: primarySource)
        keyGen = primarySource.generateKeyForPerception(cursor: cursorPrimary)
      }

      if keyGen == nil, fallbackSource.totalKeyCount > 0 {
        let cursorFallback = clampedCursor(for: fallbackSource)
        keyGen = fallbackSource.generateKeyForPerception(cursor: cursorFallback)
      }
    }

    guard let keyGen else { return nil }

    let normalizedHeadReading: String = {
      let separator = "-"
      if scenario == .shortToLong || afterHit.gram.segLength > 1 {
        let joined = afterHit.gram.joinedCurrentKey(by: separator)
        return joined.isEmpty ? keyGen.headReading : joined
      }
      return keyGen.headReading
    }()

    return .init(
      contextualizedGramKey: keyGen.ngramKey,
      candidate: current.value,
      headReading: normalizedHeadReading,
      scenario: scenario,
      forceHighScoreOverride: forceHSO,
      scoreFromLM: current.score
    )
  }
}

extension Array where Element == Homa.GramInPath {
  /// 從一個節點陣列當中取出目前的選字字串陣列。
  public var values: [String] { map(\.value) }

  /// 從一個節點陣列當中取出目前的索引鍵陣列。
  public func joinedKeys(by separator: String) -> [String] {
    map { $0.keyArray.joined(separator: separator) }
  }

  /// 從一個節點陣列當中取出目前的索引鍵陣列。
  public var keyArrays: [[String]] { map(\.keyArray) }

  /// 返回一連串的節點起點。結果為 (Result A, Result B) 字典陣列。
  /// Result A 以索引查座標，Result B 以座標查索引。
  private var gramBorderPointDictPair: (regionCursorMap: [Int: Int], cursorRegionMap: [Int: Int]) {
    // Result A 以索引查座標，Result B 以座標查索引。
    var resultA = [Int: Int]()
    var resultB: [Int: Int] = [-1: 0] // 防呆
    var cursorCounter = 0
    enumerated().forEach { gramCounter, neta in
      resultA[gramCounter] = cursorCounter
      neta.keyArray.forEach { _ in
        resultB[cursorCounter] = gramCounter
        cursorCounter += 1
      }
    }
    resultA[count] = cursorCounter
    resultB[cursorCounter] = count
    return (resultA, resultB)
  }

  /// 返回一個字典，以座標查索引。允許以游標位置查詢其屬於第幾個幅節座標（從 0 開始算）。
  public var cursorRegionMap: [Int: Int] { gramBorderPointDictPair.cursorRegionMap }

  /// 總讀音單元數量。在絕大多數情況下，可視為總幅節長度。
  public var totalKeyCount: Int { map(\.keyArray.count).reduce(0, +) }

  /// 根據給定的游標，返回其前後最近的節點邊界。
  /// - Parameter cursor: 給定的游標。
  public func contextRange(ofGivenCursor cursor: Int) -> Range<Int> {
    guard !isEmpty else { return 0 ..< 0 }
    let frontestSegLength = reversed()[0].keyArray.count
    var nilReturn = (totalKeyCount - frontestSegLength) ..< totalKeyCount
    if cursor >= totalKeyCount { return nilReturn } // 防呆
    let cursor = Swift.max(0, cursor) // 防呆
    nilReturn = cursor ..< cursor
    // 下文按道理來講不應該會出現 nilReturn。
    let mapPair = gramBorderPointDictPair
    guard let rearNodeID = mapPair.cursorRegionMap[cursor] else { return nilReturn }
    guard let rearIndex = mapPair.regionCursorMap[rearNodeID]
    else { return nilReturn }
    guard let frontIndex = mapPair.regionCursorMap[rearNodeID + 1]
    else { return nilReturn }
    return rearIndex ..< frontIndex
  }

  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameters:
  ///   - cursor: 給定游標位置。
  /// - Returns: 查找結果。
  public func findGram(at cursor: Int) -> (gram: Homa.GramInPath, range: Range<Int>)? {
    guard !isEmpty else { return nil }
    let cursor = Swift.max(0, Swift.min(cursor, totalKeyCount - 1)) // 防呆
    let range = contextRange(ofGivenCursor: cursor)
    guard let rearNodeID = cursorRegionMap[cursor] else { return nil }
    guard count - 1 >= rearNodeID else { return nil }
    return (self[rearNodeID], range)
  }

  /// 偵測是否出現游標切斷組字區內字元的情況。
  ///
  /// 此處不需要針對 cursor 做邊界檢查。
  public func isCursorCuttingChar(cursor: Int) -> Bool {
    let index = cursor
    var isBound = (index == contextRange(ofGivenCursor: index).lowerBound)
    if index == totalKeyCount { isBound = true }
    let rawResult = findGram(at: index)?.gram.isReadingMismatched ?? false
    return !isBound && rawResult
  }

  /// 偵測游標是否切斷區域。
  ///
  /// 此處不需要針對 cursor 做邊界檢查。
  public func isCursorCuttingRegion(cursor: Int) -> Bool {
    let index = cursor
    var isBound = (index == contextRange(ofGivenCursor: index).lowerBound)
    if index == totalKeyCount { isBound = true }
    return !isBound
  }

  /// 提供一組逐字的字音配對陣列（不使用 Homa 的 KeyValuePaired 類型），但字音不相符的節點除外。
  public var smashedPairs: [(key: String, value: String)] {
    var arrData = [(key: String, value: String)]()
    forEach { gram in
      if gram.isReadingMismatched, !gram.keyArray.joined().isEmpty {
        arrData.append(
          (key: gram.keyArray.joined(separator: "\t"), value: gram.value)
        )
        return
      }
      let arrValueChars = gram.value.map(\.description)
      gram.keyArray.enumerated().forEach { i, key in
        arrData.append((key: key, value: arrValueChars[i]))
      }
    }
    return arrData
  }

  /// 生成用以洞察使用者覆寫行為的複元圖索引鍵，最多支援指定長度的 n-gram（預設 3-gram）。
  ///
  /// - Remark: 除非有專門指定游標，否則身為 `[GramInPath]` 自身的
  /// 「陣列最尾端」（也就是打字方向上最前方）的那個 Gram 會被當成 Head。
  /// 若游標落在多字詞節點內，Head 會選擇游標右方（文字輸入方向上的下一個）讀音。
  /// - Parameters:
  ///   - cursor: 指定用於當作 head 的游標位置；若為 nil 則取陣列尾端。
  ///   - maxContext: 最多向前取用的上下文節點數（含 head），預設 3。
  public func generateKeyForPerception(
    cursor: Int? = nil,
    maxContext: Int = 3
  )
    -> (ngramKey: String, candidate: String, headReading: String)? {
    guard maxContext > 0 else { return nil }

    let headInfo: (pair: Homa.GramInPath, range: Range<Int>)?
    let resolvedCursor: Int
    if let cursor,
       (0 ..< totalKeyCount).contains(cursor),
       let hit = findGram(at: cursor) {
      headInfo = (pair: hit.gram, range: hit.range)
      resolvedCursor = Swift.max(
        hit.range.lowerBound,
        Swift.min(cursor, hit.range.upperBound - 1)
      )
    } else if let tail = last {
      let lowerBound = totalKeyCount - tail.keyArray.count
      headInfo = (pair: tail, range: lowerBound ..< totalKeyCount)
      resolvedCursor = Swift.max(lowerBound, totalKeyCount - 1)
    } else {
      headInfo = nil
      resolvedCursor = 0
    }

    guard let headInfo else { return nil }
    let headPair = headInfo.pair
    let headRange = headInfo.range
    let headKeyOffset = Swift.max(0, resolvedCursor - headRange.lowerBound)
    guard headPair.keyArray.indices.contains(headKeyOffset) else { return nil }

    let placeholder = "()"
    let readingSeparator = "-"

    func isPunctuation(_ pair: Homa.GramInPath) -> Bool {
      guard let firstReading = pair.keyArray.first else { return false }
      return firstReading.first == "_"
    }

    func combinedString(for pair: Homa.GramInPath) -> String? {
      guard !pair.value.isEmpty else { return nil }
      guard !pair.keyArray.isEmpty else { return nil }
      let reading = pair.joinedCurrentKey(by: readingSeparator)
      guard !reading.isEmpty else { return nil }
      return "(\(reading),\(pair.value))"
    }

    let headIndex = lastIndex(where: { $0.gram.id == headPair.gram.id })
      ?? lastIndex(where: { $0 == headPair })
    guard let headIndex else { return nil }

    var resultCells = [String](repeating: placeholder, count: maxContext)
    resultCells[maxContext - 1] = combinedString(for: headPair) ?? placeholder

    var contextSlot = maxContext - 2
    var currentIndex = headIndex - 1
    var encounteredPunctuation = false

    while contextSlot >= 0 {
      guard currentIndex >= 0 else {
        resultCells[contextSlot] = placeholder
        contextSlot -= 1
        continue
      }

      let currentPair = self[currentIndex]
      currentIndex -= 1

      if encounteredPunctuation || isPunctuation(currentPair) {
        encounteredPunctuation = true
        resultCells[contextSlot] = placeholder
        contextSlot -= 1
        continue
      }

      resultCells[contextSlot] = combinedString(for: currentPair) ?? placeholder
      contextSlot -= 1
    }

    let headReading = headPair.keyArray[headKeyOffset]
    return (
      resultCells.joined(separator: "&"),
      headPair.value,
      headReading
    )
  }
}
