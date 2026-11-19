// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - 成對標點之拆對與同步

extension InputHandlerProtocol {
  /// 若使用者選中的候選是完整的一對標點，則將其拆成左右兩個單邊元件。
  ///
  /// 拆對後兩個元件各自成為一個 gram，游標停在兩者之間。此後任一元件的輪替或重新選字
  /// 皆會觸發 `synchronizePairedPunctuationIfNeeded(at:)`。
  ///
  /// - Parameters:
  ///   - candidate: 使用者選中的候選（詞音配對）。
  ///   - location: 目標 gram 的起始索引鍵位置；`nil` 表示取 `actualNodeCursorPosition`。
  /// - Returns: 是否已處理。`false` 表示不是完整成對標點，應交回既有選字流程。
  @discardableResult
  func splitPairedPunctuationIfNeeded(
    candidate: CandidateInState,
    at location: Int? = nil
  )
    -> Bool {
    guard !prefs.useSCPCTypingMode else { return false }
    guard candidate.keyArray.count == 1,
          let pair = PairedPunctuation.decompose(fullPair: candidate.value) else { return false }

    // 先確認兩個單邊索引鍵皆在辭典內，再動組字器；否則寧可不拆，以免把原本的一對弄丟。
    guard currentLM.lxQuerier.hasUnigrams(for: [pair.leftKey]),
          currentLM.lxQuerier.hasUnigrams(for: [pair.rightKey]) else { return false }

    let targetLocation = location ?? actualNodeCursorPosition
    guard let (index, starts) = gramIndexAndStarts(for: targetLocation) else { return false }
    let sentence = assembler.assembledSentence
    guard index < sentence.count else { return false }
    let target = sentence[index]
    guard target.segLength == 1,
          target.keyArray.count == 1,
          PairedPunctuation.isPunctuationComponentKey(target.keyArray[0]),
          target.keyArray == candidate.keyArray,
          starts[index] == targetLocation else { return false }

    // 把目標 gram 換成兩個單邊索引鍵。先將游標置於目標之後，`dropKey(.rear)` 即刪目標。
    // 若插入失敗，回復到拆對前，以免原本的一對被吃掉。
    let backup = assembler.copy
    assembler.cursor = targetLocation + 1
    guard (try? assembler.dropKey(direction: .rear)) != nil else {
      assembler = backup
      return false
    }
    guard (try? assembler.insertKeys([
      .singleKey(pair.leftKey),
      .singleKey(pair.rightKey),
    ])) != nil else {
      assembler = backup
      return false
    }

    // 兩個新 gram 的預設候選未必正是使用者所選的那一對；逐個覆寫成正確的單邊。
    overridePunctuationComponent(
      key: pair.leftKey, value: pair.leftValue, at: targetLocation
    )
    overridePunctuationComponent(
      key: pair.rightKey, value: pair.rightValue, at: targetLocation + 1
    )
    // 置中：兩個 gram 之間的索引鍵位置。選字路徑若曾為邊緣游標備份，該備份會在下一次
    // `generateStateOfInputting()` 把游標還原，故此處一併清除。
    assembler.cursor = targetLocation + 1
    backupCursor = nil
    return true
  }

  /// 若打字游標試圖以單步越過一整個成對標點，則先拆對、再置中。
  ///
  /// 只處理**無修飾**的左右方向鍵；Shift（標記游標）、Option／Command（按節點跳）
  /// 一律不拆。若目標不是單一 gram 的完整成對標點，或單邊索引鍵不可得，回 `false`
  /// 交回既有游標移動。
  ///
  /// - Parameter direction: 游標移動方向。
  /// - Returns: 是否已拆對並處理掉本次移動。
  @discardableResult
  func splitPairedPunctuationIfCursorWouldCross(
    direction: Homa.Assembler.TypingDirection
  )
    -> Bool {
    guard !prefs.useSCPCTypingMode else { return false }
    let location: Int
    switch direction {
    case .front:
      guard assembler.cursor < assembler.length else { return false }
      location = assembler.cursor
    case .rear:
      guard assembler.cursor > 0 else { return false }
      location = assembler.cursor - 1
    }
    guard let (index, starts) = gramIndexAndStarts(for: location) else { return false }
    let sentence = assembler.assembledSentence
    guard index < sentence.count, starts[index] == location else { return false }
    let gram = sentence[index]
    guard gram.segLength == 1,
          gram.keyArray.count == 1,
          PairedPunctuation.isPunctuationComponentKey(gram.keyArray[0]),
          PairedPunctuation.isFullPair(gram.value) else { return false }
    return splitPairedPunctuationIfNeeded(
      candidate: (keyArray: gram.keyArray, value: gram.value),
      at: location
    )
  }

  /// 若給定位置上的標點元件與相鄰的另一半成對，則把另一半同步成對應的元件。
  ///
  /// 只處理相鄰的兩個單邊 gram；巢狀、跨內容、已遞交者一律不處理。非成對元件、
  /// 完整成對值、或相鄰者不是另一半者，一律靜默放行。
  ///
  /// - Parameter location: 被輪替或重新選字之 gram 的起始索引鍵位置。
  func synchronizePairedPunctuationIfNeeded(at location: Int) {
    guard !prefs.useSCPCTypingMode else { return }
    guard let (index, starts) = gramIndexAndStarts(for: location) else { return }
    let sentence = assembler.assembledSentence
    guard index < sentence.count else { return }
    let gram = sentence[index]
    guard gram.segLength == 1, gram.keyArray.count == 1 else { return }
    guard PairedPunctuation.isPunctuationComponentKey(gram.keyArray[0]) else { return }
    let value = gram.value
    guard let counterpart = PairedPunctuation.counterpart(of: value) else { return }

    let partnerIndex: Int
    if PairedPunctuation.isLeftComponent(value) {
      partnerIndex = index + 1
      guard partnerIndex < sentence.count else { return }
      let partner = sentence[partnerIndex]
      guard partner.segLength == 1, partner.keyArray.count == 1,
            PairedPunctuation.isPunctuationComponentKey(partner.keyArray[0]),
            PairedPunctuation.isRightComponent(partner.value),
            starts[partnerIndex] == starts[index] + 1 else { return }
    } else if PairedPunctuation.isRightComponent(value) {
      partnerIndex = index - 1
      guard partnerIndex >= 0 else { return }
      let partner = sentence[partnerIndex]
      guard partner.segLength == 1, partner.keyArray.count == 1,
            PairedPunctuation.isPunctuationComponentKey(partner.keyArray[0]),
            PairedPunctuation.isLeftComponent(partner.value),
            starts[index] == starts[partnerIndex] + 1 else { return }
    } else {
      return
    }

    let partner = sentence[partnerIndex]
    guard partner.value != counterpart else { return }
    let partnerLocation = starts[partnerIndex]
    let candidate = Homa.CandidatePair(keyArray: partner.keyArray, value: counterpart)
    let didOverride = assembler.overrideCandidate(
      candidate,
      at: partnerLocation,
      overrideType: .withSpecified,
      isExplicitlyOverridden: false,
      perceptionHandler: { _ in } // 同步是衍生結果，不另記 POM 記憶。
    )
    guard didOverride else {
      let didOverrideLiteral = (try? assembler.overrideCandidateLiteral(
        counterpart,
        at: partnerLocation,
        overrideType: .withSpecified,
        isExplicitlyOverridden: false,
        perceptionHandler: { _ in }
      )) != nil
      guard didOverrideLiteral else {
        // 使用者可能以不同索引鍵輸入了另一半（例如少按 Shift）；此時同步失敗
        // 屬預期內的使用者輸入落差，只記錄、不蜂鳴。
        vCLog("PAIRSYNC: failed to synchronize \(value) → \(counterpart)")
        return
      }
      return
    }
  }

  /// 半形模式下，若當前節點是 `\`／`|` 的單一標點，回傳可注入之完整成對候選。
  ///
  /// 半形辭典（`_half_punctuation_\`／`_half_punctuation_|`）只收單邊字元；成對候選
  /// 由本表注入，故不必為此另發一版辭典。注入僅發生在候選窗，不改變節點本身。
  func halfWidthPairedPunctuationCandidatesForCurrentNode() -> [Homa.CandidatePair] {
    guard prefs.halfWidthPunctuationEnabled,
          !prefs.useSCPCTypingMode,
          currentTypingMethod == .vChewingFactory else { return [] }
    let location = actualNodeCursorPosition
    guard let (index, starts) = gramIndexAndStarts(for: location) else { return [] }
    let sentence = assembler.assembledSentence
    guard index < sentence.count, starts[index] == location else { return [] }
    let gram = sentence[index]
    guard gram.segLength == 1, gram.keyArray.count == 1,
          ["_half_punctuation_\\", "_half_punctuation_|"].contains(gram.keyArray[0]) else { return [] }
    return PairedPunctuation.halfWidthPairValues.map {
      Homa.CandidatePair(keyArray: gram.keyArray, value: $0)
    }
  }

  // MARK: Private

  /// 以候選覆寫指定位置之標點元件；失敗時退回字面覆寫。
  private func overridePunctuationComponent(key: String, value: String, at location: Int) {
    let candidate = Homa.CandidatePair(keyArray: [key], value: value)
    let didOverride = assembler.overrideCandidate(
      candidate,
      at: location,
      overrideType: .withSpecified,
      isExplicitlyOverridden: false,
      perceptionHandler: { _ in }
    )
    guard !didOverride else { return }
    let didOverrideLiteral = (try? assembler.overrideCandidateLiteral(
      value,
      at: location,
      overrideType: .withSpecified,
      isExplicitlyOverridden: false,
      perceptionHandler: { _ in }
    )) != nil
    guard !didOverrideLiteral else { return }
    vCLog("PAIRSPLIT: failed to override \(key) → \(value)")
    errorCallback?("PAIRSPLIT")
  }

  /// 回傳包含給定索引鍵位置之 gram 的索引，以及每個 gram 的起始索引鍵位置。
  private func gramIndexAndStarts(for location: Int) -> (index: Int, starts: [Int])? {
    let sentence = assembler.assembledSentence
    guard !sentence.isEmpty else { return nil }
    var starts = [Int]()
    var cursor = 0
    sentence.forEach { gram in
      starts.append(cursor)
      cursor += gram.segLength
    }
    guard let index = starts.lastIndex(where: { $0 <= location }) else { return nil }
    guard index < sentence.count,
          location < starts[index] + sentence[index].segLength else { return nil }
    return (index, starts)
  }
}
