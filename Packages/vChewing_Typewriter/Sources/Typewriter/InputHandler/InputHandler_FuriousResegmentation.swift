// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - 狂拼模式的 trail 管理與重切分 (Furious Typing Trail & Resegmentation)

/// 狂拼音節級分數查無命中時使用的地板值。
private let furiousSyllableScoreFloor: Double = -12

// MARK: - FuriousFrontApplyOutcome

/// 狂拼前方候選套用結果。
enum FuriousFrontApplyOutcome {
  /// 插入失敗（組字器未被變更）。
  case failed
  /// 插入成功但覆寫失敗（組句維持語言模型預設）。
  case inserted
  /// 插入＋覆寫皆成功。
  case overridden
}

extension InputHandlerProtocol {
  /// 狂拼模式是否有效：打字方法為注音組字且打字模式為狂拼。
  ///
  /// 這是狂拼各功能（前方預覽、copilot 候選窗、固化、重切分、就地選字等）的共用閘門；
  /// 前方特定的額外條件（游標在組字區最前端、無聲調暫存、注拼槽非空等）由
  /// `furiousFrontContext`／`hasFuriousFrontPending` 各自把守。
  /// `typingMode` 已把「狂拼開關＋非磁帶＋非逐字選字＋拼音注拼槽」打包為 `.pinyinFuriousTyping`。
  public var isFuriousTypingModeEffective: Bool {
    currentTypingMethod == .vChewingFactory && typingMode == .pinyinFuriousTyping
  }

  /// 狂拼模式有效且注拼槽尚有未完成拼裝的拼音字母流（前方待確認讀音）。
  public var hasFuriousFrontPending: Bool {
    isFuriousTypingModeEffective && !composer.romajiBuffer.isEmpty
  }

  /// 清空狂拼 trail。
  ///
  /// 任何使用者顯式干涉（選字、輪替、游標離開組字區最前端、手動確認讀音等）
  /// 之後都必須讓 trail 失效，否則重切分可能動到使用者確認過的內容。
  func invalidateFuriousTrail() {
    furiousTrail.removeAll()
  }

  /// 從 trail 尾端移除給定數量的拼音字母 blob。
  ///
  /// 用於「注拼槽為空時以 BackSpace 刪除組字器尾鍵」的場合：
  /// 被刪除的鍵必然是 trail 所對應的尾鍵，因此精確同步、而非全清。
  /// - Parameter count: 欲移除的筆數（預設 1）；超過 trail 長度時全部移除。
  func popFuriousTrail(_ count: Int = 1) {
    guard count > 0, !furiousTrail.isEmpty else { return }
    furiousTrail.removeLast(Swift.min(count, furiousTrail.count))
  }

  /// 狂拼模式的前方固化：把注拼槽的投機讀音固化進組字器（投機→實體）。
  ///
  /// 由「可能叫出選字窗」的觸發鍵（Space／翻頁／候選導航方向鍵）在 triage 早段觸發：
  /// 只把前方聲調桶插入組字器、**不覆寫**——保留 LM 重切分自由度，
  /// 使後續音節可自動合併成長詞（如「xi 空格 an 空格」→「西安」），
  /// 最後清空注拼槽。
  /// 聲調桶鍵保留 ⇒ 隨後開出的選字窗仍陳列其他 tone-fuzzy（全調）候選；顯示則由
  /// 真組字器組句決定（與 copilot 預覽同源：copilot 與真組字器使用同一 LM 與同一組
  /// keys，單音節顯示必然一致）。
  /// 完整音節固化後 trail 累積該拼音 blob，供語言模型引導的重切分使用；不完整前綴
  /// （如「z」）固化後 trail 失效（無法作為合法切分素材）。
  /// 失敗時靜默退回、不主動 switchState（後續正常流程會生成新狀態）。
  func solidifyFuriousFrontReading() {
    guard let furiousContext = furiousFrontContext else { return }
    let bucket = furiousContext.bucket
    let romaji = composer.romajiBuffer
    guard !romaji.isEmpty else { return }
    // 完整音節與否須在清空注拼槽之前判定（重切分 trail 不變量所需）。
    let isCompleteSyllable = composer.parser.mapZhuyinPinyin?[romaji] != nil
    guard (try? assembler.insertKeys([.multipleKeys(bucket)])) != nil else { return }
    composer.replacePinyinBuffer(with: "")
    furiousHighlightOverride = nil // 高亮覆寫僅供當拍消費。
    if isCompleteSyllable {
      furiousTrail.append(romaji)
    } else {
      invalidateFuriousTrail()
    }
    retrievePOMSuggestions(apply: true)
  }

  /// 將前方候選套用至給定的組字器實例（真實確認與高亮預覽共用）。
  ///
  /// 三路徑判定順序（互不誤判）：
  /// 1) 置頂無橫跨：keyArray 即前方桶本身（count ≥ 2，但首讀音隸屬提交鍵桶會造成
  ///    泛化判定誤判，故先行排除）。
  /// 2) 跨邊界：候選的「前 n-1 個讀音」逐位隸屬組字器「最後 n-1 個提交鍵」的讀音桶
  ///    （n = keyArray.count ≥ 2），結構性判定候選橫跨最後 n-1 個提交鍵＋前方。
  /// 3) 前方單音節 grams：keyArray.count == 1，兩者皆不成立。
  /// 套用：跨邊界僅插入前方讀音（單鍵）並覆寫 anchor-(n-1) 起的 n 鍵 span；其餘沿用
  /// 既有語義（置頂無橫跨＝讀音桶單一位置多讀音，否則逐讀音單鍵）並覆寫 anchor 起的 span。
  /// 覆寫為 `.withSpecified`＋`isExplicitlyOverridden`；`perceptionHandler` 僅在覆寫成功時
  /// 被呼叫，供「使用者顯式選字」的確認路徑（Shift+選字鍵／滑鼠點選）收集 POM 觀察。
  /// Enter 直遞／高亮預覽不傳入——copilot 未經使用者逐字確認的最佳猜測
  /// 不應寫入漸退記憶模組（否則記憶的短詞會綁架長詞的組句，如「是嗎」綁架
  /// 「是媽媽」→「是嗎嗎」）。空格固化自同日起不再走本函式
  /// （只插聲調桶、不覆寫，保留重切分自由度）。
  /// - Parameter preservingFuzzyKeys: 為 true 時一律插入整組聲調桶（保留 tone-fuzzy
  ///   候選窗），僅以覆寫釘住顯示——用於空格固化的「模擬選字窗選字」路徑。
  @discardableResult
  func applyFuriousFrontCandidate(
    _ candidate: CandidateInState,
    to targetAssembler: Homa.Assembler,
    bucket: [String],
    preservingFuzzyKeys: Bool = false,
    perceptionHandler: ((Homa.PerceptionIntel) -> ())? = nil
  )
    -> FuriousFrontApplyOutcome {
    guard !candidate.value.isEmpty else { return .failed }
    let isBucketPinned = candidate.keyArray == bucket
    var isCrossBoundary = false
    var crossBoundarySpan = 0
    if !isBucketPinned, candidate.keyArray.count >= 2 {
      let span = candidate.keyArray.count - 1
      if targetAssembler.keys.count >= span {
        isCrossBoundary = (0 ..< span).allSatisfy { i in
          targetAssembler.keys[targetAssembler.keys.count - span + i]
            .allValues.contains(candidate.keyArray[i])
        }
        if isCrossBoundary { crossBoundarySpan = span }
      }
    }
    // 目標組字器的游標即新插入 span 的錨點（狂拼語義下位於組字區最前端）。
    let anchor = targetAssembler.cursor
    let inserted: Bool
    if preservingFuzzyKeys {
      inserted = (try? targetAssembler.insertKeys([.multipleKeys(bucket)])) != nil
    } else if isCrossBoundary, let tailReading = candidate.keyArray.last {
      inserted = (try? targetAssembler.insertKeys([.singleKey(tailReading)])) != nil
    } else {
      let keysToInsert: [Homa.PossibleKey] = candidate.keyArray == bucket
        ? [.multipleKeys(bucket)]
        : candidate.keyArray.map { .singleKey($0) }
      inserted = !keysToInsert.isEmpty && (try? targetAssembler.insertKeys(keysToInsert)) != nil
    }
    guard inserted else { return .failed }
    let overrideAnchor = isCrossBoundary
      ? Swift.max(anchor - crossBoundarySpan, 0)
      : anchor
    let overrideSucceeded = (try? targetAssembler.overrideCandidate(
      .init(keyArray: candidate.keyArray, value: candidate.value),
      at: overrideAnchor,
      type: .withSpecified,
      isExplicitlyOverridden: true,
      enforceRetokenization: true,
      perceptionHandler: perceptionHandler
    )) != nil
    return overrideSucceeded ? .overridden : .inserted
  }

  /// 狂拼 copilot 窗的高亮即時預覽：把候選套用至組字器副本（scratch）並以組句結果
  /// 就地更新 session 的顯示狀態（繞過 switchState，避免選字窗重載）。
  /// 不觸碰真組字器、不計 POM、不動 trail、不清注拼槽。
  public func previewFuriousHighlightedCandidate(_ candidate: CandidateInState) {
    guard let session = session else { return }
    // α 路徑（R2-α）：前方無法形成單一音節桶（如「ysxb」）時，以空桶試算簡拼整詞候選。
    let furiousContext: (
      bucket: [String],
      preview: String,
      crossingPair: CandidateInState?,
      assembledMainValues: [String],
      tailReading: String?
    )
    if let context = furiousFrontContext {
      furiousContext = context
    } else {
      guard furiousAbbreviatedCells != nil else { return }
      furiousContext = ([], "", nil, [], nil)
    }
    let scratch = assembler.copy
    let outcome = applyFuriousFrontCandidate(
      candidate, to: scratch, bucket: furiousContext.bucket
    )
    switch outcome {
    case .failed: return // 插入失敗：不更新預覽。
    case .inserted, .overridden: break
    }
    var theState = session.state
    let previewSegments = scratch.assembledSentence.values
    theState.data.displayTextSegments = previewSegments
    theState.data.rawDisplayTextSegments = nil
    theState.data.cursor = previewSegments.joined().count
    theState.data.marker = theState.data.cursor
    session.state = theState // 直接就地取代，不經過 switchState，免得選字窗被重新載入。
    session.updateCompositionBufferDisplay()
  }

  /// 語言模型引導的拼音重切分（furious resegmentation）。
  ///
  /// 當 trail 記錄了至少兩個由自動 chop 提交的讀音鍵時，把 trail 的字母流重新枚舉成
  /// 各種同音節數的合法切分，以組字器副本（scratch）逐一評分，僅在候選的整句路徑總分
  /// 嚴格高於現狀時，才對真組字器做 drop+insert 替換。任何環節不符預期皆靜默退回。
  func resegmentFuriousTrailIfNeeded() {
    // 閘門：與前方預覽共用狂拼守衛，但注拼槽暫存可為空。
    guard isFuriousTypingModeEffective else { return }
    guard furiousTrail.count >= 2 else { return }
    guard assembler.length >= furiousTrail.count else {
      invalidateFuriousTrail()
      return
    }
    guard assembler.isCursorAtAssemblerEdge(direction: .front) else { return }
    guard let readingMap = composer.parser.mapZhuyinPinyin else { return }

    // 組字器尾端必須恰好是 trail 全長（trail 存續本身就是 trail span 無 explicit
    // override 的保證）；不一致時視為 trail 失效，絕不重切動到 trail 以外的內容。
    let trailBuckets: [[String]] = furiousTrail.compactMap { blob in
      guard let zhuyin = readingMap[blob] else { return nil }
      return Tekkon.makeToneInsensitiveVariants(of: zhuyin)
    }
    guard trailBuckets.count == furiousTrail.count else {
      invalidateFuriousTrail()
      return
    }
    let expectedTrailingKeys = trailBuckets.map { Homa.PossibleKey.multipleKeys($0) }
    guard Array(assembler.keys.suffix(furiousTrail.count)) == expectedTrailingKeys else {
      invalidateFuriousTrail()
      return
    }

    // 以 trail 字母流枚舉同音節數的合法切分。
    let letters = furiousTrail.joined()
    let segmentor = FuriousTypingSegmentor(
      isValidSyllable: { readingMap[$0] != nil },
      syllableScore: { [weak self] syllable in
        guard let self, let zhuyin = readingMap[syllable] else {
          return furiousSyllableScoreFloor
        }
        let bucket = Tekkon.makeToneInsensitiveVariants(of: zhuyin)
        let grams = self.currentLM.lookupHub.grams(for: [.multipleKeys(bucket)])
        return grams.map(\.probability).max() ?? furiousSyllableScoreFloor
      }
    )
    var candidates = segmentor.candidateSegmentations(of: letters, syllableCount: furiousTrail.count)
    // 現狀（當前 trail）併入去重，避免 limit 截斷把它排擠掉。
    if !candidates.contains(where: { $0 == furiousTrail }) {
      candidates.append(furiousTrail)
    }
    guard candidates.count > 1 else { return } // 僅有現狀，無從比較。

    // 基線：真組字器目前的整句路徑總分（顯式組句以確保讀取前已刷新）。
    _ = assembler.assemble()
    let baselineScore = assembler.mostRecentPathScore
    var bestCandidate: [String]?
    var bestScore = baselineScore
    for candidate in candidates where candidate != furiousTrail {
      // 逐音節展開六聲調桶，且每個桶都須有在庫命中；驗證失敗整個候選跳過。
      let keyBuckets: [[String]] = candidate.compactMap { blob in
        guard let zhuyin = readingMap[blob] else { return nil }
        return Tekkon.makeToneInsensitiveVariants(of: zhuyin)
      }
      guard keyBuckets.count == candidate.count,
            keyBuckets.allSatisfy({ bucket in
              bucket.contains(where: { currentLM.hasUnigramsForFast(keyArray: [$0]) })
            })
      else { continue }
      // 以組字器副本（scratch）評分：從後方 drop trail 全長、插入候選鍵。
      let scratch = assembler.copy
      var droppedAll = true
      for _ in 0 ..< furiousTrail.count {
        guard (try? scratch.dropKey(direction: .rear)) != nil else {
          droppedAll = false
          break
        }
      }
      guard droppedAll, (try? scratch.insertKeys(keyBuckets)) != nil else { continue }
      _ = scratch.assemble()
      if scratch.mostRecentPathScore > bestScore {
        bestScore = scratch.mostRecentPathScore
        bestCandidate = candidate
      }
    }
    // 嚴格更高才替換；否則維持現狀。
    guard let bestCandidate, bestCandidate != furiousTrail else { return }

    // 替換：對真組字器做同樣的 drop+insert，更新 trail，並重取 POM 建議。
    for _ in 0 ..< furiousTrail.count {
      guard (try? assembler.dropKey(direction: .rear)) != nil else { return }
    }
    let bestKeyBuckets: [[String]] = bestCandidate.compactMap { blob in
      guard let zhuyin = readingMap[blob] else { return nil }
      return Tekkon.makeToneInsensitiveVariants(of: zhuyin)
    }
    guard (try? assembler.insertKeys(bestKeyBuckets)) != nil else {
      // 失敗防禦：復原原 trail 鍵以維持既有組句；trail 一併失效。
      _ = (try? assembler.insertKeys(trailBuckets))
      invalidateFuriousTrail()
      return
    }
    furiousTrail = bestCandidate
    retrievePOMSuggestions(apply: false)
  }
}
