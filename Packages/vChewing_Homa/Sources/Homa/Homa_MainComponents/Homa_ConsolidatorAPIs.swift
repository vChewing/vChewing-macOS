// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Extending Assembler for Node Consolidation.

extension Homa.Assembler {
  /// 鞏固當前組字器游標上下文，防止在當前游標位置固化節點時給作業範圍以外的內容帶來不想要的變化。
  ///
  /// 打比方說輸入法原廠詞庫內有「章太炎」一詞，你敲「章太炎」，然後想把「太」改成「泰」以使其變成「章泰炎」。
  /// **macOS 內建的注音輸入法不會在這個過程對這個詞除了「太」以外的部分有任何變動**，
  /// 但石磬軟體的所有輸入法產品都對此有 Bug：會將這些部分全部重設為各自的讀音下的最高原始權重的漢字。
  /// 也就是說，選字之後的結果可能會變成「張泰言」。
  ///
  /// - Remark: 類似的可以拿來測試的詞有「蔡依林」「周杰倫」。
  ///
  /// 測試時請務必也測試「敲長句子、且這種詞在句子中間出現時」的情況。
  /// - Parameters:
  ///   - theCandidate: 要拿來覆寫的詞音配對。
  ///   - cursorType: 選字時是前置游標還是後置游標。
  /// - Throws: 任何可能的覆寫失敗。（一般情況下不用處理這個，除非需要診斷故障。）
  public func consolidateCandidateCursorContext(
    for theCandidate: Homa.CandidatePair,
    cursorType: CandidateCursor,
    debugIntelHandler: ((String) -> ())? = nil
  ) throws {
    // 針對給定的候選字推算實際游標位置並拿到鞏固邊界範圍與偵錯資訊。
    let targetCursor = getLogicalCandidateCursorPosition(forCursor: cursorType)
    let candidateRange = candidateRange(
      for: theCandidate,
      cursorType: cursorType,
      cursorPosition: targetCursor
    )
    let (consolidationRange, debugIntel) = calculateConsolidationBoundaries(
      for: theCandidate,
      candidateRange: candidateRange,
      cursorPosition: targetCursor
    )
    if let debugIntelHandler {
      debugIntelHandler("[HOMA_DEBUG] \(debugIntel)")
    }

    // 沒有任何可鞏固區間的話，提前結束。
    guard !consolidationRange.isEmpty else { return }

    // 用於避免重複處理同一節點。
    var nodeIndices = [Int]()

    // 自鞏固下界開始掃描，逐節點鎖定並處理內容。
    var position = consolidationRange.lowerBound
    while position < consolidationRange.upperBound {
      guard let regionIndex = assembledSentence.cursorRegionMap[position] else {
        // 該位置沒有對應節點，往後尋找。
        position += 1
        continue
      }
      if nodeIndices.contains(regionIndex) {
        // 同一節點已處理，跳過重複索引。
        position += 1
        continue
      }
      nodeIndices.append(regionIndex)

      guard assembledSentence.indices.contains(regionIndex) else { break }
      guard let currentHit = assembledSentence.findGram(at: position) else {
        position += 1
        continue
      }
      let currentNode = currentHit.gram
      let nodeLength = currentNode.keyArray.count
      guard nodeLength > 0 else {
        position += 1
        continue
      }

      let nodeStart = currentHit.range.lowerBound
      let nodeRange = currentHit.range
      let overlapsTarget = nodeRange.overlaps(candidateRange)
      var nextPosition = nodeStart

      let values = currentNode.value.map(\.description)

      if !overlapsTarget {
        // 節點不與覆寫範圍接觸時，先嘗試整段覆寫，失敗再退回逐鍵覆寫流程。
        attempt: do {
          try overrideNodeAsWhole(currentNode, at: nodeStart)
          position = nodeStart + nodeLength
          continue
        } catch {
          break attempt
        }
        guard values.count == currentNode.keyArray.count else {
          position = nodeStart + nodeLength
          continue
        }
        for (subPosition, key) in currentNode.keyArray.enumerated() {
          guard values.count > subPosition else { break }
          let pair = Homa.CandidatePair(keyArray: [key], value: values[subPosition])
          try? overrideCandidate(pair, at: nextPosition)
          nextPosition += 1
        }
        position = nextPosition
        continue
      }

      guard values.count == currentNode.keyArray.count else {
        // 與覆寫範圍相交但缺少完整值時，改用強制整段覆寫。
        attempt: do {
          try overrideNodeAsWhole(currentNode, at: nodeStart)
          position = nodeStart + nodeLength
          continue
        } catch {
          break attempt
        }
        position = nodeStart + nodeLength
        continue
      }

      // 節點與覆寫範圍相交且值完整，改以逐鍵覆寫確保最終內容與原值一致。
      for (subPosition, key) in currentNode.keyArray.enumerated() {
        guard values.count > subPosition else { break }
        let pair = Homa.CandidatePair(keyArray: [key], value: values[subPosition])
        try overrideCandidate(pair, at: nextPosition)
        nextPosition += 1
      }
      position = nextPosition
    }
  }

  /// 計算在執行候選字鞏固（consolidate）時需要鎖定的上下文邊界範圍。
  ///
  /// 此函式會模擬一次候選字覆寫（在暫存鏡像上執行，不會變更真實狀態），
  /// 並根據覆寫前後的差異來決定一個安全的鞏固範圍，確保只會影響必要的相關節點，
  /// 避免在鞏固候選時對其他無關位置產生不必要的改變（例如導致某些詞被錯誤 re-tokenize）。
  ///
  /// - Parameters:
  ///   - candidate: 被覆寫的候選配對（keyArray + value）。
  ///   - cursorPosition: 實際用於覆寫的游標位置（邏輯位置）。
  /// - Returns: 回傳一個 Range<Int> 表示要被鞏固的字元索引範圍，以及 debug 相關字串資訊。
  private func calculateConsolidationBoundaries(
    for candidate: Homa.CandidatePair,
    candidateRange: Range<Int>,
    cursorPosition: Int
  )
    -> (range: Range<Int>, debugInfo: String) {
    // 暫存既有句子內容，以便乾操控後恢復。
    let currentAssembledSentence = assembledSentence
    var frontBoundaryEX = candidateRange.upperBound
    var rearBoundaryEX = candidateRange.lowerBound
    var debugIntelToPrint = ""

    // 建立節點覆寫狀態鏡像並暫停感知器，避免試算影響真實狀態。
    let gridOverrideStatusMirror = createNodeOverrideStatusMirror()
    let cursorBackup = cursor
    let markerBackup = marker
    let perceptorBackup = perceptor
    perceptor = nil

    defer {
      // 恢復所有乾操控前的狀態。
      restoreFromNodeOverrideStatusMirror(gridOverrideStatusMirror)
      assembledSentence = currentAssembledSentence
      cursor = cursorBackup
      marker = markerBackup
      perceptor = perceptorBackup
    }

    // 嘗試在原位置覆寫候選字，若成功則評估回寫後的上下文邊界。
    if (try? overrideCandidate(
      candidate,
      at: cursorPosition,
      type: .withSpecified,
      isExplicitlyOverridden: true,
      enforceRetokenization: true
    )) != nil {
      assemble()
      let probeCursor = Swift.min(
        Swift.max(candidateRange.lowerBound, cursorPosition),
        Swift.max(candidateRange.upperBound - 1, candidateRange.lowerBound)
      )
      let range = assembledSentence.contextRange(ofGivenCursor: probeCursor)
      rearBoundaryEX = Swift.min(rearBoundaryEX, range.lowerBound)
      frontBoundaryEX = Swift.max(frontBoundaryEX, range.upperBound)
      debugIntelToPrint.append("EX: \(rearBoundaryEX)..<\(frontBoundaryEX), ")
    }

    // 與當前上下文邊界做比較，計算初步的鞏固範圍。
    let initialRange = currentAssembledSentence.contextRange(ofGivenCursor: cursorPosition)
    var rearBoundary = Swift.min(initialRange.lowerBound, rearBoundaryEX)
    var frontBoundary = Swift.max(initialRange.upperBound, frontBoundaryEX)
    debugIntelToPrint.append("INI: \(rearBoundary)..<\(frontBoundary), ")

    // 向後計算
    // 先往游標後方跳 Segment 以取得最靠後的安全邊界。
    let cursorTempBackup = cursor
    while cursor > rearBoundary {
      try? jumpCursorBySegment(to: .rear)
    }
    rearBoundary = Swift.min(cursor, rearBoundary)

    // 再往前跳 Segment，避免超出句子長度與範圍。
    cursor = cursorTempBackup
    while cursor < frontBoundary {
      try? jumpCursorBySegment(to: .front)
    }
    frontBoundary = Swift.min(Swift.max(cursor, frontBoundary), length)
    cursor = cursorTempBackup

    debugIntelToPrint.append("FIN: \(rearBoundary)..<\(frontBoundary)")

    return (rearBoundary ..< frontBoundary, debugIntelToPrint)
  }

  private func candidateRange(
    for candidate: Homa.CandidatePair,
    cursorType: CandidateCursor,
    cursorPosition: Int
  )
    -> Range<Int> {
    let candidateLength = Swift.max(candidate.keyArray.count, 1)
    let rangeStart: Int = switch cursorType {
    case .placedFront: Swift.max(0, cursorPosition - candidateLength + 1)
    case .placedRear: cursorPosition
    }
    let rangeEnd = Swift.min(length, rangeStart + candidateLength)
    return rangeStart ..< Swift.max(rangeEnd, rangeStart)
  }

  /// 嘗試將完整節點內容一次性覆寫（整段覆寫法）。
  ///
  /// 函式會先嘗試一次性覆寫；若失敗，會嘗試使用指定覆寫類型並強制 retokenize，
  /// 以提高覆寫成功率。若仍失敗，會將錯誤拋回給呼叫端處理。
  ///
  /// - Parameters:
  ///   - node: 要覆寫的 GramInPath 節點。
  ///   - startPosition: 該節點在鍵軸中的起始位置（游標位置）。
  /// - Throws: 覆寫失敗時會拋出 Homa.Exception。
  private func overrideNodeAsWhole(
    _ node: Homa.GramInPath,
    at startPosition: Int
  ) throws {
    // 試圖以整個節點的候選配對一次覆寫到位。
    let candidate = Homa.CandidatePair(
      keyArray: node.keyArray,
      value: node.value
    )
    firstAttempt: do {
      try overrideCandidate(candidate, at: startPosition)
      return
    } catch {
      break firstAttempt
    }
    // 若第一次覆寫失敗，改用強制重斷詞方式再嘗試一次。
    try overrideCandidate(
      candidate,
      at: startPosition,
      type: .withSpecified,
      enforceRetokenization: true
    )
  }
}
