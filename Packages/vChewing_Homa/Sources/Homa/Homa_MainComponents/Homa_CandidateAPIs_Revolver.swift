// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Extending Assembler for Candidates (Revolvement).

extension Homa.Assembler {
  /// 選字游標種類：選字時是游標在（文字書寫方向上的）前方（macOS 內建注音）、還是在後方（微軟新注音）。
  public enum CandidateCursor: Int {
    /// 游標在（文字書寫方向上的）前方（macOS 內建注音）。
    case placedFront = 0
    /// 游標在（文字書寫方向上的）後方（微軟新注音）。
    case placedRear = -1
  }

  /// 根據當前組字器的狀態推算出用以獲取候選字的邏輯游標。
  ///
  /// - Parameters:
  ///   - candidateCursorType: 選字游標種類：
  ///     - 前置游標模式（placedFront）：只要不在最後端，就往後方移一位。
  ///     - 後置游標模式（placedRear）：只有在最前端時，才往後方移一位。
  ///   - isMarker: 是否以標記器為依據。停用的話則以敲字游標為依據。
  /// - Returns: 選字游標的邏輯位置。
  public func getLogicalCandidateCursorPosition(
    forCursor candidateCursorType: CandidateCursor,
    isMarker: Bool = false
  )
    -> Int {
    let currentPos = isMarker ? marker : cursor
    let isAtFrontEdge = (currentPos == length)
    let isAtRearEdge = currentPos <= 0
    guard !isAtRearEdge else { return 0 }
    return switch candidateCursorType {
    case .placedFront: currentPos - 1
    case .placedRear: currentPos - (isAtFrontEdge ? 1 : 0)
    }
  }

  /// 以給定之參數來處理上下文候選字詞之輪替。
  /// - Parameters:
  ///   - cursorType: 選字時是前置游標還是後置游標。
  ///   - counterClockwise: 輪替順序方向。
  /// - Returns: 將輪替之後的候選字詞回傳給呼叫者，以便接下來的操作（比如鞏固上下文，等）。
  @discardableResult
  public func revolveCandidate(
    cursorType: CandidateCursor,
    counterClockwise: Bool,
    debugIntelHandler: ((String) -> ())? = nil,
    candidateArrayHandler: (([Homa.CandidatePairWeighted]) -> ())? = nil
  ) throws
    -> (
      Homa.CandidatePairWeighted,
      current: Int,
      total: Int
    ) {
    guard !isEmpty else { throw Homa.Exception.assemblerIsEmpty }

    // 獲取候選字列表
    let candidates: [Homa.CandidatePairWeighted] = switch cursorType {
    case .placedFront: fetchCandidates(filter: .endAt)
    case .placedRear: fetchCandidates(filter: .beginAt)
    }

    candidateArrayHandler?(candidates)

    // 驗證候選字是否存在
    guard let firstCandidate = candidates.first else {
      throw Homa.Exception.noCandidatesAvailableToRevolve
    }
    guard candidates.count > 1 else {
      print(firstCandidate)
      throw Homa.Exception.onlyOneCandidateAvailableToRevolve
    }

    // 確保有組裝好的節點串資料
    var currentSentence: [Homa.GramInPath] = assembledSentence
    if currentSentence.isEmpty { currentSentence = assemble() }

    // 獲取當前游標位置和區域資訊
    let regionMap = currentSentence.cursorRegionMap
    let candidateCursorPos = getLogicalCandidateCursorPosition(forCursor: cursorType)
    guard let regionID = regionMap[candidateCursorPos], assembledSentence.count > regionID else {
      throw Homa.Exception.cursorOutOfReasonableNodeRegions
    }

    // 獲取當前節點和其詞組資訊
    let currentGramInPath = currentSentence[regionID]
    let currentPair = Homa.CandidatePair(
      keyArray: currentGramInPath.keyArray,
      value: currentGramInPath.value
    )

    // 計算新的候選字索引
    let newIndex = calculateNextCandidateIndex(
      candidates: candidates,
      currentPair: currentPair,
      isExplicitOverride: currentGramInPath.isExplicit,
      counterClockwise: counterClockwise
    )

    // 獲取新的候選字
    let theCandidateNow = candidates[newIndex]
    let currentRange = currentSentence.contextRange(ofGivenCursor: candidateCursorPos)
    let targetRange = calculateTargetCandidateRange(
      for: theCandidateNow.pair,
      cursorType: cursorType,
      cursorPosition: candidateCursorPos,
      totalLength: length
    )
    let needsInitialConsolidation = !currentGramInPath.isExplicit && currentRange != targetRange

    // 進行上下文鞏固和覆寫操作。
    // 只有當目標候選字真的成為邏輯游標上的 explicit node 時才算成功。
    var retryCount = 0
    let maxRetries = 20
    let previousSentence = assembledSentence
    var successfullyRevolved = false
    var debugIntel: [String] = []

    while retryCount < maxRetries {
      if retryCount > 0 || needsInitialConsolidation {
        try? consolidateCandidateCursorContext(
          for: theCandidateNow.pair,
          cursorType: cursorType
        ) { intel in
          if debugIntelHandler != nil {
            debugIntel.append(intel)
          }
        }
      }

      do {
        try overrideCandidate(
          theCandidateNow,
          at: candidateCursorPos,
          type: .withSpecified,
          isExplicitlyOverridden: true,
          enforceRetokenization: retryCount % 2 == 1
        )
      } catch {
        retryCount += 1
        if retryCount < maxRetries {
          debugIntel.append(
            "revolveCandidate: override failed, retrying (\(retryCount)/\(maxRetries))"
          )
        }
        continue
      }

      let currentSentence = assembledSentence
      let currentGramAtCursor = currentSentence.findGram(at: candidateCursorPos)?.gram
      let currentPairAtCursor = currentGramAtCursor.map {
        Homa.CandidatePair(
          keyArray: $0.keyArray,
          value: $0.value
        )
      }
      let didChangeSentence = previousSentence.map(\ .value) != currentSentence.map(\ .value)
      let didApplyTargetCandidate = currentPairAtCursor == theCandidateNow.pair
      let didLockExplicitNode = currentGramAtCursor?.isExplicit == true

      if didChangeSentence, didApplyTargetCandidate, didLockExplicitNode {
        debugIntel.append(
          "revolveCandidate: succeeded after \(retryCount + 1) attempts"
        )
        successfullyRevolved = true
        break
      }

      retryCount += 1
      if retryCount < maxRetries {
        debugIntel.append(
          "revolveCandidate: target not stabilized, retrying (\(retryCount)/\(maxRetries)) [applied=\(didApplyTargetCandidate), explicit=\(didLockExplicitNode), changed=\(didChangeSentence)]"
        )
      }
    }

    guard successfullyRevolved else {
      if let debugIntelHandler {
        debugIntel.append("IDX: \(newIndex + 1)/\(candidates.count)")
        debugIntel.append("VAL: \(theCandidateNow.pair.value)")
        debugIntel.append("\(cursorType)")
        debugIntel.append("ENC: \(cursor)")
        debugIntel.append("LCC: \(candidateCursorPos)")
        debugIntel.append(assembledSentence.compactMap(\ .value).joined())
        debugIntel.append("<- Revolve Failed")
        debugIntelHandler(debugIntel.joined(separator: " | "))
      }
      throw Homa.Exception.nothingOverriddenAtNode
    }

    // 處理偵錯資訊
    if let debugIntelHandler {
      debugIntel.append("IDX: \(newIndex + 1)/\(candidates.count)")
      debugIntel.append("VAL: \(theCandidateNow.pair.value)")
      debugIntel.append("\(cursorType)")
      debugIntel.append("ENC: \(cursor)") // Encoded Cursor
      debugIntel.append("LCC: \(candidateCursorPos)") // Logical Candidate Cursor
      debugIntel.append(assembledSentence.compactMap(\.value).joined())
      debugIntel.append(successfullyRevolved ? "<- Revolve Succeeded" : "<- Revolve Failed")
      debugIntelHandler(debugIntel.joined(separator: " | "))
    }

    return (theCandidateNow, newIndex, candidates.count)
  }

  /// 計算下一個候選字索引
  /// - Parameters:
  ///   - candidates: 候選字列表
  ///   - currentPaired: 當前配對
  ///   - isExplicitOverride: 節點是否為使用者明確覆寫
  ///   - counterClockwise: 是否逆時針旋轉
  /// - Returns: 新的候選字索引
  private func calculateNextCandidateIndex(
    candidates: [Homa.CandidatePairWeighted],
    currentPair: Homa.CandidatePair,
    isExplicitOverride: Bool,
    counterClockwise: Bool
  )
    -> Int {
    // 如果只有一個候選字，直接返回 0。
    if candidates.count == 1 { return 0 }

    let candidatePairs = candidates.map(\.pair)

    // 遇到非覆寫節點的情況，可簡便處理。
    guard isExplicitOverride else {
      // 如果當前遇到的不是第一個候選字的話，則返回 0 以重設選擇。
      guard let firstCandidate = candidatePairs.first,
            firstCandidate == currentPair else { return 0 }
      // 根據輪替方向決定返回最後一個或第二個候選字。
      return counterClockwise ? candidatePairs.count - 1 : 1
    }

    // 覆寫節點的情況：循序查找當前候選字並沿用 Typewriter 的輪替邏輯。
    var result = 0
    for candidate in candidatePairs {
      result.revolveAsIndex(
        with: candidatePairs,
        clockwise: !(candidate == currentPair && counterClockwise)
      )
      // 找到與當前節點匹配的候選字時終止輪替。
      if candidate == currentPair { break }
    }
    // 保底處理：確保索引仍在合法範圍內。
    return (0 ..< candidatePairs.count).contains(result) ? result : 0
  }

  private func calculateTargetCandidateRange(
    for candidate: Homa.CandidatePair,
    cursorType: CandidateCursor,
    cursorPosition: Int,
    totalLength: Int
  )
    -> Range<Int> {
    let candidateLength = Swift.max(candidate.keyArray.count, 1)
    let rangeStart: Int = switch cursorType {
    case .placedFront: Swift.max(0, cursorPosition - candidateLength + 1)
    case .placedRear: cursorPosition
    }
    let rangeEnd = Swift.min(totalLength, rangeStart + candidateLength)
    return rangeStart ..< Swift.max(rangeEnd, rangeStart)
  }
}
