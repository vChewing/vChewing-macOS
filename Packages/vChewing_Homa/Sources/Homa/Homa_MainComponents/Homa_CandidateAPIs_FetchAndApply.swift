// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Extending Assembler for Candidates (Fetch).

extension Homa.Assembler {
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
    at givenLocation: Int? = nil,
    filter givenFilter: CandidateFetchFilter = .all
  )
    -> [Homa.CandidatePairWeighted] {
    var result = [Homa.CandidatePairWeighted]()
    guard !keys.isEmpty else { return result }
    var location = max(min(givenLocation ?? cursor, keys.count), 0)
    var filter = givenFilter
    if filter == .endAt {
      if location == keys.count { filter = .all }
      location -= 1
    }
    location = max(min(location, keys.count - 1), 0)
    let anchors: [(location: Int, node: Homa.Node)] = fetchOverlappingNodes(at: location)
    let keyAtCursor = keys[location]
    let cursorAlternatives = keyAtCursor.allValues
    var seen = Set<Homa.CandidatePair>()
    anchors.forEach { theAnchor in
      let theNode = theAnchor.node
      theNode.grams.forEach { gram in
        guard gram.previous == nil else { return } // 不要讓雙元圖的結果出現在選字窗內。
        switch filter {
        case .all:
          // 得加上這道篩選，不然會出現很多無效結果。
          // keyArray4Query 為該節點的第一組替代讀音組合，用於快速篩選。
          if !theNode.keyArray4Query.contains(where: { cursorAlternatives.contains($0) }) { return }
        case .beginAt:
          guard theAnchor.location == location else { return }
        case .endAt:
          guard theAnchor.location + theNode.segLength - 1 == location else { return }
          guard let lastKey = theNode.keyArray4Query.last, cursorAlternatives.contains(lastKey) else { return }
        }
        let newCandidate = Homa.CandidatePair(
          keyArray: gram.keyArray,
          value: gram.current
        ).weighted(gram.probability)
        guard !seen.contains(newCandidate.pair) else { return }
        result.append(newCandidate)
        seen.insert(newCandidate.pair)
      }
    }
    return result.sorted {
      (
        $0.pair.segLength,
        $0.pair.keyArray.joined(separator: "-")
      ) > (
        $1.pair.segLength,
        $1.pair.keyArray.joined(separator: "-")
      )
    }
  }

  /// 使用給定的候選字（詞音配對），將給定位置的節點的候選字詞改為與之一致的候選字詞。
  ///
  /// 該函式僅用作過程函式。
  /// - Parameters:
  ///   - candidate: 指定用來覆寫為的候選字（詞音鍵值配對）。
  ///   - location: 游標位置。
  ///   - overrideType: 指定覆寫行為。
  ///   - isExplicitlyOverridden: 是否視為使用者明確覆寫，而非自動機制。
  /// - Throws: 如果沒有找到相符的節點或無法覆寫，拋出適當的異常。
  public func overrideCandidate(
    _ candidate: Homa.CandidatePair,
    at location: Int,
    type overrideType: Homa.Node.OverrideType = .withSpecified,
    isExplicitlyOverridden: Bool = false,
    enforceRetokenization: Bool = false,
    perceptionHandler: ((Homa.PerceptionIntel) -> ())? = nil
  ) throws {
    try overrideCandidateAgainst(
      keyArray: candidate.keyArray,
      at: location,
      value: candidate.value,
      score: nil,
      type: overrideType,
      isExplicitlyOverridden: isExplicitlyOverridden,
      enforceRetokenization: enforceRetokenization,
      perceptionHandler: perceptionHandler
    )
  }

  public func overrideCandidate(
    _ candidate: Homa.CandidatePairWeighted,
    at location: Int,
    type overrideType: Homa.Node.OverrideType = .withSpecified,
    isExplicitlyOverridden: Bool = false,
    enforceRetokenization: Bool = false,
    perceptionHandler: ((Homa.PerceptionIntel) -> ())? = nil
  ) throws {
    try overrideCandidateAgainst(
      keyArray: candidate.pair.keyArray,
      at: location,
      value: candidate.pair.value,
      score: nil,
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
  ///   - isExplicitlyOverridden: 是否視為使用者明確覆寫，而非自動機制。
  /// - Returns: 該操作是否成功執行。
  public func overrideCandidateLiteral(
    _ candidate: String,
    at location: Int,
    overrideType type: Homa.Node.OverrideType = .withSpecified,
    isExplicitlyOverridden: Bool = false,
    enforceRetokenization: Bool = false,
    perceptionHandler: ((Homa.PerceptionIntel) -> ())? = nil
  ) throws {
    try overrideCandidateAgainst(
      keyArray: nil,
      at: location,
      value: candidate,
      score: nil,
      type: type,
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
  /// - Throws: 如果節點不存在或覆寫失敗，拋出適當的異常。
  internal func overrideCandidateAgainst(
    keyArray: [String]?,
    at location: Int,
    value: String,
    score specifiedScore: Double? = nil,
    type: Homa.Node.OverrideType,
    isExplicitlyOverridden: Bool,
    enforceRetokenization: Bool,
    perceptionHandler: ((Homa.PerceptionIntel) -> ())? = nil
  ) throws {
    let location = max(min(location, keys.count), 0) // 防呆
    let effectiveLocation = min(keys.count - 1, location)

    // 獲取重疊節點
    let arrOverlappedNodes = fetchOverlappingNodes(at: effectiveLocation)

    if arrOverlappedNodes.isEmpty {
      throw Homa.Exception.nothingOverriddenAtNode
    }

    let shouldObserve = perceptionHandler != nil || perceptor != nil
    let previouslyAssembled: [Homa.GramInPath] = shouldObserve ? assemble() : []
    let cursorBeforeOverride = min(keys.count, location)

    // 尋找相符的節點
    var overridden: (location: Int, node: Homa.Node)?
    var lastError: Homa.Exception?

    for anchor in arrOverlappedNodes {
      // 如果提供了keyArray，確認該節點包含這個keyArray
      if let keyArray, !anchor.node.allActualKeyArraysCached.contains(keyArray) {
        continue
      }

      do {
        _ = try anchor.node.selectOverrideGram(
          keyArray: keyArray,
          value: value,
          type: type
        )
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
            currentUnigramIndex: anchor.node.currentGramIndex
          )
        }
        overridden = anchor
        break
      } catch let error as Homa.Exception {
        lastError = error
      } catch {
        // 此部分（在理論上來講）永遠都無法被運行。
        print(error)
      }
    }

    // 如果沒有找到相符的節點，拋出錯誤
    guard let overridden else {
      throw lastError ?? .nothingOverriddenAtNode
    }

    defer {
      let currentAssembled = assemble()
      if shouldObserve {
        let intel = Homa.makePerceptionIntel(
          previouslyAssembled: previouslyAssembled,
          currentAssembled: currentAssembled,
          cursor: cursorBeforeOverride
        )
        if let intel {
          (perceptionHandler ?? perceptor)?(intel)
        }
      }
    }

    // 更新重疊節點的覆寫權重
    let overriddenRange =
      overridden
        .location ..< min(
          segments.count,
          overridden.location + overridden.node.segLength
        )

    for i in overriddenRange {
      let overlappingNodes = fetchOverlappingNodes(at: i)

      if enforceRetokenization {
        let overriddenNodeRef = overridden.node
        let demotionScore = -Swift.max(1.0, Swift.abs(overriddenNodeRef.overridingScore))
        for anchor in overlappingNodes
          where anchor.node !== overriddenNodeRef
          && anchor.location <= overridden.location {
          if shouldResetNode(anchor: anchor.node, overriddenNode: overriddenNodeRef) {
            anchor.node.reset()
          }
          anchor.node.overrideStatus = .init(
            overridingScore: demotionScore,
            currentOverrideType: .withSpecified,
            isExplicitlyOverridden: anchor.node.isExplicitlyOverridden,
            currentUnigramIndex: anchor.node.currentGramIndex
          )
        }
        continue
      }

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

  /// 判斷一個節點是否需要被重設
  /// - Parameters:
  ///   - anchor: 待檢查的節點
  ///   - overriddenNode: 已覆寫的節點
  /// - Returns: 是否需要重設
  private func shouldResetNode(anchor: Homa.Node, overriddenNode: Homa.Node) -> Bool {
    guard overriddenNode.segLength <= anchor.segLength else {
      return true
    }
    guard let anchorValue = anchor.value,
          let overriddenValue = overriddenNode.value
    else {
      return false
    }

    let anchorNodeKeyJoined = anchor.keyArray4Query.joined(separator: "\t")
    let overriddenNodeKeyJoined = overriddenNode.keyArray4Query.joined(separator: "\t")

    var shouldReset = !overriddenNodeKeyJoined.has(string: anchorNodeKeyJoined)
    shouldReset = shouldReset || !overriddenValue.has(string: anchorValue)

    return shouldReset
  }
}

// MARK: - Extending Assembler for Segment.

extension Homa.Assembler {
  /// 找出所有與該位置重疊的節點。其返回值為一個節錨陣列（包含節點、以及其起始位置）。
  /// - Parameter location: 游標位置。
  /// - Returns: 一個包含所有與該位置重疊的節點的陣列。
  internal func fetchOverlappingNodes(at givenLocation: Int) -> [(location: Int, node: Homa.Node)] {
    var results = [(location: Int, node: Homa.Node)]()
    let givenLocation = max(0, min(givenLocation, keys.count - 1))
    guard segments.indices.contains(givenLocation) else { return results }

    // 先獲取詀位置的所有單字節點
    segments[givenLocation].keys.sorted().forEach { theSegLength in
      guard let node = segments[givenLocation][theSegLength] else { return }
      Self.insertAnchor(segmentIndex: givenLocation, node: node, to: &results)
    }

    // 再獲取以當前位置結尾的節點
    let begin = givenLocation - min(givenLocation, maxSegLength - 1)
    (begin ..< givenLocation).forEach { theLocation in
      let neededLength = givenLocation - theLocation + 1
      let maxAvailableLength = segments[theLocation].maxLength

      guard neededLength <= maxAvailableLength else { return }
      (neededLength ... maxAvailableLength).forEach { theLength in
        guard let node = segments[theLocation][theLength] else { return }
        Self.insertAnchor(segmentIndex: theLocation, node: node, to: &results)
      }
    }

    return results
  }

  /// 要在 fetchOverlappingNodes() 內使用的一個工具函式。
  /// 按照節點幅節長度排序插入節點錨點。
  /// - Parameters:
  ///   - location: 節點起始位置。
  ///   - node: 要插入的節點。
  ///   - targetContainer: 目標容器。
  private static func insertAnchor(
    segmentIndex location: Int,
    node: Homa.Node,
    to targetContainer: inout [(location: Int, node: Homa.Node)]
  ) {
    guard !node.keyArray.joined().isEmpty else { return }
    let anchor = (location: location, node: node)

    // 若容器為空，直接添加
    if targetContainer.isEmpty {
      targetContainer.append(anchor)
      return
    }

    // 按節點幅節長度排序插入
    var inserted = false
    targetContainer.indices.forEach { i in
      guard !inserted else { return }
      if targetContainer[i].node.segLength <= anchor.node.segLength {
        targetContainer.insert(anchor, at: i)
        inserted = true
      }
    }

    // 若未插入，添加到末尾
    if !inserted {
      targetContainer.append(anchor)
    }
  }
}
