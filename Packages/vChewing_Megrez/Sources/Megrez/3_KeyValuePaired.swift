// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Megrez.KeyValuePaired

extension Megrez {
  /// 鍵值配對，乃索引鍵陣列與讀音的配對單元。
  public struct KeyValuePaired: Equatable, CustomStringConvertible, Hashable, Comparable, Codable {
    // MARK: Lifecycle

    /// 初期化一組鍵值配對。
    /// - Parameters:
    ///   - keyArray: 索引鍵陣列。一般情況下用來放置讀音等可以用來作為索引的內容。
    ///   - value: 資料值。
    ///   - score: 權重（雙精度小數）。
    public init(keyArray: [String] = [], value: String = "N/A", score: Double = 0) {
      self.keyArray = keyArray.isEmpty ? ["N/A"] : keyArray
      self.value = value.isEmpty ? "N/A" : value
      self.score = score
    }

    /// 初期化一組鍵值配對。
    /// - Parameter tripletExpression: 傳入的通用陣列表達形式。
    public init(_ tripletExpression: (keyArray: [String], value: String, score: Double)) {
      self.keyArray = tripletExpression.keyArray.isEmpty ? ["N/A"] : tripletExpression.keyArray
      let theValue = tripletExpression.value.isEmpty ? "N/A" : tripletExpression.value
      self.value = theValue
      self.score = tripletExpression.score
    }

    /// 初期化一組鍵值配對。
    /// - Parameter tuplet: 傳入的通用陣列表達形式。
    public init(_ tupletExpression: (keyArray: [String], value: String)) {
      self.keyArray = tupletExpression.keyArray.isEmpty ? ["N/A"] : tupletExpression.keyArray
      let theValue = tupletExpression.value.isEmpty ? "N/A" : tupletExpression.value
      self.value = theValue
      self.score = 0
    }

    /// 初期化一組鍵值配對。
    /// - Parameters:
    ///   - key: 索引鍵。一般情況下用來放置讀音等可以用來作為索引的內容。
    ///   - value: 資料值。
    ///   - score: 權重（雙精度小數）。
    public init(key: String = "N/A", value: String = "N/A", score: Double = 0) {
      self.keyArray = key.isEmpty ? ["N/A"] : key.sliced(by: Megrez.Compositor.theSeparator)
      self.value = value.isEmpty ? "N/A" : value
      self.score = score
    }

    // MARK: Public

    /// 索引鍵陣列。一般情況下用來放置讀音等可以用來作為索引的內容。
    public let keyArray: [String]
    /// 資料值，通常是詞語或單個字。
    public let value: String
    /// 權重。
    public let score: Double

    /// 通用陣列表達形式。
    public var keyValueTuplet: (keyArray: [String], value: String) { (keyArray, value) }
    /// 通用陣列表達形式。
    public var triplet: (keyArray: [String], value: String, score: Double) {
      (keyArray, value, score)
    }

    /// 將當前鍵值列印成一個字串。
    public var description: String { "(\(keyArray.description),\(value),\(score))" }
    /// 判斷當前鍵值配對是否合規。如果鍵與值有任一為空，則結果為 false。
    public var isValid: Bool { !keyArray.joined().isEmpty && !value.isEmpty }
    /// 將當前鍵值列印成一個字串，但如果該鍵值配對為空的話則僅列印「()」。
    public var toNGramKey: String { !isValid ? "()" : "(\(joinedKey()),\(value))" }
    public var hardCopy: Self {
      .init(keyArray: keyArray, value: value, score: score)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.hashValue == rhs.hashValue
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      (lhs.keyArray.count < rhs.keyArray.count)
        || (lhs.keyArray.count == rhs.keyArray.count && lhs.value < rhs.value)
    }

    public static func > (lhs: Self, rhs: Self) -> Bool {
      (lhs.keyArray.count > rhs.keyArray.count)
        || (lhs.keyArray.count == rhs.keyArray.count && lhs.value > rhs.value)
    }

    public static func <= (lhs: Self, rhs: Self) -> Bool {
      (lhs.keyArray.count <= rhs.keyArray.count)
        || (lhs.keyArray.count == rhs.keyArray.count && lhs.value <= rhs.value)
    }

    public static func >= (lhs: Self, rhs: Self) -> Bool {
      (lhs.keyArray.count >= rhs.keyArray.count)
        || (lhs.keyArray.count == rhs.keyArray.count && lhs.value >= rhs.value)
    }

    /// 做為預設雜湊函式。
    /// - Parameter hasher: 目前物件的雜湊碼。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(keyArray)
      hasher.combine(value)
      hasher.combine(score)
    }

    public func joinedKey(by separator: String = Megrez.Compositor.theSeparator) -> String {
      keyArray.joined(separator: separator)
    }
  }
}

extension Megrez.Compositor {
  /// 規定候選字陣列內容的獲取範圍類型：
  /// - all: 不只包含其它兩類結果，還允許游標穿插候選字。
  /// - beginAt: 僅獲取從當前游標位置開始的節點內的候選字。
  /// - endAt 僅獲取在當前游標位置結束的節點內的候選字。
  public enum CandidateFetchFilter { case all, beginAt, endAt }

  /// 返回在當前位置的所有候選字詞（以詞音配對的形式）。如果組字器內有幅節、且游標
  /// 位於組字器的（文字輸入順序的）最前方（也就是游標位置的數值是最大合規數值）的
  /// 話，那麼這裡會對 location 的位置自動減去 1、以免去在呼叫該函式後再處理的麻煩。
  /// - Parameter location: 游標位置，必須是顯示的游標位置、不得做任何事先糾偏處理。
  /// - Returns: 候選字音配對陣列。
  public func fetchCandidates(
    at givenLocation: Int? = nil, filter givenFilter: CandidateFetchFilter = .all
  )
    -> [Megrez.KeyValuePaired] {
    var result = [Megrez.KeyValuePaired]()
    guard !keys.isEmpty else { return result }
    var location = max(min(givenLocation ?? cursor, keys.count), 0)
    var filter = givenFilter
    if filter == .endAt {
      if location == keys.count { filter = .all }
      location -= 1
    }
    location = max(min(location, keys.count - 1), 0)
    let anchors: [(location: Int, node: Megrez.Node)] = fetchOverlappingNodes(at: location)
    let keyAtCursor = keys[location]
    anchors.forEach { theAnchor in
      let theNode = theAnchor.node
      theNode.unigrams.forEach { gram in
        switch filter {
        case .all:
          // 得加上這道篩選，不然會出現很多無效結果。
          if !theNode.keyArray.contains(keyAtCursor) { return }
        case .beginAt:
          guard theAnchor.location == location else { return }
        case .endAt:
          guard theNode.keyArray.last == keyAtCursor else { return }
          switch theNode.segLength {
          case 2... where theAnchor.location + theAnchor.node.segLength - 1 != location: return
          default: break
          }
        }
        result.append(.init(keyArray: theNode.keyArray, value: gram.value, score: gram.score))
      }
    }
    return result
  }

  /// 使用給定的候選字（詞音配對），將給定位置的節點的候選字詞改為與之一致的候選字詞。
  ///
  /// 該函式僅用作過程函式。
  /// - Parameters:
  ///   - candidate: 指定用來覆寫為的候選字（詞音鍵值配對）。
  ///   - location: 游標位置。
  ///   - overrideType: 指定覆寫行為。
  ///   - enforceRetokenization: 是否強制重新分詞，對所有重疊節點施作重置與降權，以避免殘留舊節點狀態。
  ///   - perceptionHandler: 覆寫成功後用於回傳觀測智慧的回呼。
  /// - Returns: 該操作是否成功執行。
  @discardableResult
  public func overrideCandidate(
    _ candidate: Megrez.KeyValuePaired, at location: Int,
    overrideType: Megrez.Node.OverrideType = .withSpecified,
    isExplicitlyOverridden: Bool = false,
    enforceRetokenization: Bool = false,
    perceptionHandler: ((Megrez.PerceptionIntel) -> ())? = nil
  )
    -> Bool {
    overrideCandidateAgainst(
      keyArray: candidate.keyArray,
      at: location,
      value: candidate.value,
      score: candidate.score < 0 ? candidate.score : nil,
      type: overrideType,
      isExplicitlyOverridden: isExplicitlyOverridden,
      enforceRetokenization: enforceRetokenization,
      perceptionHandler: perceptionHandler
    )
  }

  /// 使用給定的候選字詞字串，將給定位置的節點的候選字詞改為與之一致的候選字詞。
  ///
  /// 注意：如果有多個「單元圖資料值雷同、卻讀音不同」的節點的話，該函式的行為結果不可控。
  /// - Parameters:
  ///   - candidate: 指定用來覆寫為的候選字（字串）。
  ///   - location: 游標位置。
  ///   - overrideType: 指定覆寫行為。
  ///   - enforceRetokenization: 是否強制重新分詞，對所有重疊節點施作重置與降權，以避免殘留舊節點狀態。
  ///   - perceptionHandler: 覆寫成功後用於回傳觀測智慧的回呼。
  /// - Returns: 該操作是否成功執行。
  @discardableResult
  public func overrideCandidateLiteral(
    _ candidate: String,
    at location: Int, overrideType: Megrez.Node.OverrideType = .withSpecified,
    isExplicitlyOverridden: Bool = false,
    enforceRetokenization: Bool = false,
    perceptionHandler: ((Megrez.PerceptionIntel) -> ())? = nil
  )
    -> Bool {
    overrideCandidateAgainst(
      keyArray: nil,
      at: location,
      value: candidate,
      score: nil,
      type: overrideType,
      isExplicitlyOverridden: isExplicitlyOverridden,
      enforceRetokenization: enforceRetokenization,
      perceptionHandler: perceptionHandler
    )
  }

  // MARK: Internal implementations.

  /// 使用給定的候選字（詞音配對）、或給定的候選字詞字串，將給定位置的節點的候選字詞改為與之一致的候選字詞。
  /// - Parameters:
  ///   - keyArray: 索引鍵陣列，也就是詞音配對當中的讀音。
  ///   - location: 游標位置。
  ///   - value: 資料值。
  ///   - score: 指定分數。
  ///   - type: 指定覆寫行為。
  ///   - enforceRetokenization: 是否強制重新分詞，對所有重疊節點施作重置與降權，以避免殘留舊節點狀態。
  ///   - perceptionHandler: 覆寫成功後用於回傳觀測智慧的回呼。
  /// - Returns: 該操作是否成功執行。
  internal func overrideCandidateAgainst(
    keyArray: [String]?,
    at location: Int,
    value: String,
    score specifiedScore: Double? = nil,
    type: Megrez.Node.OverrideType,
    isExplicitlyOverridden: Bool,
    enforceRetokenization: Bool,
    perceptionHandler: ((Megrez.PerceptionIntel) -> ())? = nil
  )
    -> Bool {
    let location = max(min(location, keys.count), 0) // 防呆
    let effectiveLocation = min(keys.count - 1, location)

    // 獲取重疊節點
    let arrOverlappedNodes = fetchOverlappingNodes(at: effectiveLocation)

    guard !arrOverlappedNodes.isEmpty else { return false }

    // 用於觀測：覆寫生效前的 walk 與游標
    let hasPerceptor = perceptionHandler != nil
    let previouslyAssembled: [Megrez.GramInPath] = hasPerceptor ? assemble() : []
    let beforeCursor = min(keys.count, location)

    // 尋找相符的節點
    var overridden: (location: Int, node: Megrez.Node)?
    var overriddenGram: Megrez.Unigram?
    var errorHappened = false

    for anchor in arrOverlappedNodes {
      // 如果提供了keyArray，確認該節點包含這個keyArray
      if let keyArray, anchor.node.keyArray != keyArray {
        continue
      }

      overrideTask: do {
        let selectionSucceeded = anchor.node.selectOverrideUnigram(
          value: value,
          type: type
        )
        overriddenGram = anchor.node.currentUnigram
        guard selectionSucceeded else {
          errorHappened = true
          break overrideTask
        }
        if type == .withSpecified {
          let baselineOverrideScore = 114_514.0
          let desiredScore = specifiedScore ?? Swift.max(
            anchor.node.overridingScore,
            baselineOverrideScore
          )
          anchor.node.overrideStatus = .init(
            overridingScore: desiredScore,
            currentOverrideType: .withSpecified,
            isExplicitlyOverridden: isExplicitlyOverridden,
            currentUnigramIndex: anchor.node.currentUnigramIndex
          )
        }
        overridden = anchor
        break
      }
    }

    // 如果沒有找到相符的節點，拋出錯誤
    guard !errorHappened, let overridden, overriddenGram != nil else {
      return false
    }

    defer {
      // 覆寫後組句與觀測：
      let currentAssembled = assemble()
      if let perceptionHandler, !previouslyAssembled.isEmpty {
        // 供新版觀測 API（前/後路徑比較 + 三情境分類）
        let perceptedIntel = Megrez.makePerceptionIntel(
          previouslyAssembled: previouslyAssembled,
          currentAssembled: currentAssembled,
          cursor: beforeCursor
        )
        if let perceptedIntel {
          perceptionHandler(perceptedIntel)
        }
      }
    }

    // 更新重疊節點的覆寫權重
    let overriddenRange = overridden.location ..< min(
      segments.count,
      overridden.location + overridden.node.segLength
    )

    if enforceRetokenization {
      let overriddenNodeRef = overridden.node
      let demotionScore = -Swift.max(1.0, Swift.abs(overriddenNodeRef.overridingScore))
      for i in overriddenRange {
        let overlappingNodes = fetchOverlappingNodes(at: i)
        for anchor in overlappingNodes where anchor.node !== overriddenNodeRef
          && anchor.location <= overridden.location {
          if shouldResetNode(anchor: anchor.node, overriddenNode: overriddenNodeRef) {
            anchor.node.reset()
          }
          anchor.node.overrideStatus = .init(
            overridingScore: demotionScore,
            currentOverrideType: .withSpecified,
            isExplicitlyOverridden: anchor.node.isExplicitlyOverridden,
            currentUnigramIndex: anchor.node.currentUnigramIndex
          )
        }
      }
    } else {
      for i in overriddenRange {
        let overlappingNodes = fetchOverlappingNodes(at: i)

        for anchor in overlappingNodes where anchor.node != overridden.node {
          // 檢查是否需要重設節點
          let shouldReset = shouldResetNode(
            anchor: anchor.node,
            overriddenNode: overridden.node
          )

          if shouldReset {
            anchor.node.reset()
          } else {
            anchor.node.overridingScore /= 4
          }
        }
      }
    }
    return true
  }

  /// 判斷一個節點是否需要被重設
  /// - Parameters:
  ///   - anchor: 待檢查的節點
  ///   - overriddenNode: 已覆寫的節點
  /// - Returns: 是否需要重設
  private func shouldResetNode(anchor: Megrez.Node, overriddenNode: Megrez.Node) -> Bool {
    guard overriddenNode.segLength <= anchor.segLength else {
      return true
    }
    let anchorValue = anchor.value
    let overriddenValue = overriddenNode.value

    let anchorNodeKeyJoined = anchor.keyArray.joined(separator: "\t")
    let overriddenNodeKeyJoined = overriddenNode.keyArray.joined(separator: "\t")

    var shouldReset = !overriddenNodeKeyJoined.has(string: anchorNodeKeyJoined)
    shouldReset = shouldReset || !overriddenValue.has(string: anchorValue)

    return shouldReset
  }
}

// MARK: - Perception observation with pre/post walks

extension Megrez {
  /// 觀測上下文類型。
  public enum POMObservationScenario: String, Codable {
    /// 同長度更換。
    case sameLenSwap
    /// 短詞變長詞。
    case shortToLong
    /// 長詞變短詞。
    case longToShort
  }

  /// 觀測上下文情形。
  public struct PerceptionIntel: Codable, Hashable {
    /// 將游標附近的上下文序列化成三段式的 gram 簽名，用於記憶回放比對。
    /// 最後一段永遠紀錄覆寫後的候選字詞，其前兩段保留覆寫前的語境快照。
    public let contextualizedGramKey: String
    /// 候選字。
    public let candidate: String
    /// 頭部讀音。
    public let headReading: String
    /// 觀測場景。
    public let scenario: POMObservationScenario
    /// 強制高分覆寫。
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
    previouslyAssembled: [Megrez.GramInPath],
    currentAssembled: [Megrez.GramInPath],
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
    let forceHSO = isShortToLong // 只有短→長時需要強推長詞
    let keyCursorRaw = Swift.max(
      afterHit.range.lowerBound,
      Swift.min(cursor, afterHit.range.upperBound - 1)
    )

    func clampedCursor(for source: [Megrez.GramInPath]) -> Int {
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

    switch scenario {
    case .shortToLong:
      let cursorPrev = clampedCursor(for: previouslyAssembled)
      let cursorCurr = clampedCursor(for: currentAssembled)
      let keyGenPrev = previouslyAssembled.generateKeyForPerception(cursor: cursorPrev)
      let keyGenCurr = currentAssembled.generateKeyForPerception(cursor: cursorCurr)

      if let keyGenPrev, let keyGenCurr {
        var mergedParts = splitKeyParts(keyGenPrev.ngramKey)
        let currentParts = splitKeyParts(keyGenCurr.ngramKey)
        if let newHead = currentParts.last {
          mergedParts[mergedParts.count - 1] = newHead
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
      let separator = Megrez.Compositor.theSeparator
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
      scoreFromLM: afterHit.gram.score
    )
  }
}
