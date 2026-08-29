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

/// 狂拼 α 自動套用（R3-a）的「顯著勝出」門檻：頂級候選與次級候選的 log-prob 差
/// 低於此值時視為模稜兩可、不自動套用，避免誤自動。
private let kFuriousAbbreviationDominanceThreshold: Double = 3.0

// MARK: - FuriousResegmentationCandidate

/// 狂拼 trail 重切的替代切分候選（P164）：已通過「桶存在性驗證＋組字器副本
/// 試算」的同音節數切分。`topReading`／`topValue` 為該切分組句時 trail 段最後
/// 節點的讀音與詞值（copilot 窗聯合重切的顯示與身分比對用）。
/// 因暫存於 `InputHandlerProtocol`（public）的屬性而需為 public 型別。
public struct FuriousResegmentationCandidate {
  let blobs: [String]
  let keyBuckets: [[String]]
  let scratchScore: Double
  let topReading: [String]
  let topValue: String
}

// MARK: - FuriousCoSegmentedOffer

/// 狂拼 copilot 窗的「trail＋注拼槽聯合重切」offer（P164）。
/// `keyArray`／`value` 為替代切分的整詞候選（組句 top-1）；`blobs` 為切分 blob
/// 序列（選取時 drop trail＋insert 音節桶＋trail 更新）；`weight` 為該候選的
/// 查詢分數（copilot 窗候選排序用）。
/// 因暫存於 `InputHandlerProtocol`（public）的屬性而需為 public 型別。
public struct FuriousCoSegmentedOffer {
  let keyArray: [String]
  let value: String
  let blobs: [String]
  let weight: Double
}

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
  /// α 路徑（R2-α）：注拼槽整段無法展開成單一音節桶（如「xqr」→「星期日」）時，
  /// 改以整詞簡拼候選之首的「實際讀音」單鍵插入組字器（同樣不覆寫、保留 LM 重切分
  /// 自由度），簡拼前綴非完整音節故 trail 失效——固化語義與單音節前綴一致。
  /// 失敗時靜默退回、不主動 switchState（後續正常流程會生成新狀態）。
  func solidifyFuriousFrontReading() {
    guard let furiousContext = furiousFrontContext else {
      solidifyAbbreviatedFrontReading()
      return
    }
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
      // 注意：此處不做重切分——單音節 trail（如「xian」）在打字中途即被拆開會
      // 誤傷「先生」類的後續多音節組句（「xian 空格 sheng」應為「先生」而非
      // 「西 安 生」）。重切分僅由 auto-chop 提交路徑觸發、且 trail 至少兩段時
      // 才執行（見 `resegmentFuriousTrailIfNeeded`）。
    } else {
      invalidateFuriousTrail()
    }
    retrievePOMSuggestions(apply: true)
  }

  /// 狂拼 α 路徑（R2-α）的前方固化：把整詞簡拼候選之首的實際讀音以單鍵插入組字器。
  ///
  /// 對應單音節前綴的「只插讀音、不覆寫」語義；查無候選時靜默退回（注拼槽保留，
  /// 由呼叫端依 `hasFuriousFrontPending` 決定是否直接消費觸發鍵）。
  private func solidifyAbbreviatedFrontReading() {
    guard let cells = furiousAbbreviatedCells else { return }
    let romaji = composer.romajiBuffer
    guard !romaji.isEmpty else { return }
    guard let topCandidate = buildFuriousAbbreviatedCandidates(cells: cells).first else { return }
    let readings = topCandidate.keyArray
    guard !readings.isEmpty else { return }
    guard (try? assembler.insertKeys(readings.map { .singleKey($0) })) != nil else { return }
    composer.replacePinyinBuffer(with: "")
    furiousHighlightOverride = nil // 高亮覆寫僅供當拍消費。
    invalidateFuriousTrail() // 簡拼前綴非完整音節：trail 失效（同「z」政策）。
  }

  /// 狂拼 α 路徑（R3-a）的自動套用：注拼槽整段（含本拍字元）無法展開成完整音節
  /// 序列、但整詞簡拼查詢有「明確勝出」的頂級候選時，自動把其實際讀音以單鍵序列
  /// 插入組字器——使「ysxb」類輸入全程自動出整詞「野獸先輩」、不必等使用者
  /// Shift+選字鍵確認。
  ///
  /// 明確勝出條件（避免誤自動）：
  /// 1) 頂級候選的讀音數與簡拼段數一致（整詞完全匹配；「ysx」只命中四字詞前綴時
  ///    不得自動套用、仍留在 copilot 窗供使用者確認）；
  /// 2) 無其他候選（唯一匹配），或頂級候選分數顯著高於次級（log-prob 差 ≥ 3.0，
  ///    即「一世雄霸」類近分競爭者不得自動套用）。
  /// 套用語義與 `solidifyAbbreviatedFrontReading` 一致：不覆寫、保留 LM 重切分自由度、
  /// 清空注拼槽、trail 失效（簡拼前綴非完整音節）。自動套用為「最佳猜測」、非使用者
  /// 顯式選字，故不觸發 POM 觀察；「模稜兩可不得自動」由上述條件 2 把守。
  /// - Parameter inputText: 本拍正在處理的拼音字元（尚未送入注拼槽）——cells 計算
  ///   須涵蓋之，否則最後一鍵永遠不被納入簡拼整詞判定。
  /// - Returns: 是否已自動套用（true＝本拍已被消費，呼叫端不再把按鍵送入注拼槽）。
  @discardableResult
  func autoApplyFuriousAbbreviationIfClearWinner(appending inputText: String) -> Bool {
    guard isFuriousTypingModeEffective else { return false }
    guard composer.intonation.isEmpty else { return false }
    guard assembler.isCursorAtAssemblerEdge(direction: .front) else { return false }
    let romaji = composer.romajiBuffer + inputText
    guard !romaji.isEmpty else { return false }
    guard let cells = furiousAbbreviatedCells(romaji: romaji) else { return false }
    let grams = currentLM.lookupHub.abbreviatedWordCandidates(keysChopped: cells)
    guard let top = grams.first, !top.current.isEmpty else { return false }
    // 條件 1：整詞完全匹配（讀音數與簡拼段數一致），攔截「前綴殘缺」的自動套用。
    guard top.keyArray.count == cells.count else { return false }
    // 條件 2：唯一匹配或顯著勝出。
    if grams.count >= 2 {
      let runnerUp = grams[1]
      guard top.probability - runnerUp.probability >= kFuriousAbbreviationDominanceThreshold else {
        return false
      }
    }
    // 套用：以實際讀音單鍵序列插入組字器（不覆寫）。
    guard (try? assembler.insertKeys(top.keyArray.map { .singleKey($0) })) != nil else { return false }
    composer.replacePinyinBuffer(with: "")
    furiousHighlightOverride = nil // 高亮覆寫僅供當拍消費。
    invalidateFuriousTrail() // 簡拼前綴非完整音節：trail 失效（同「z」政策）。
    session?.switchState(generateStateOfInputting())
    return true
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

  /// 枚舉 trail 的同音節數替代切分（共用於自動重切與重切候選入窗，P164）。
  ///
  /// 閘門與驗證沿襲 `resegmentFuriousTrailIfNeeded`：trail ≥ 2、組字器尾端與 trail
  /// 逐段對應（trail span 無 explicit override 的保證）、每段桶皆有在庫命中；每個
  /// 替代切分以組字器副本（scratch）drop trail 全長＋insert 候選桶試算，並取組句時
  /// trail 段最後節點的讀音／詞值。回傳按 scratch 整句路徑總分降冪排序（不含現狀
  /// trail）。任何環節不符預期時回傳空陣列（不失效 trail——失效與否由呼叫方依語義
  /// 決定）。
  func enumerateFuriousResegmentationCandidates() -> [FuriousResegmentationCandidate] {
    guard isFuriousTypingModeEffective else { return [] }
    guard furiousTrail.count >= 2 else { return [] }
    guard assembler.length >= furiousTrail.count else {
      invalidateFuriousTrail() // 自癒：trail 與組字器鍵數脫鉤時失效。
      return []
    }
    guard assembler.isCursorAtAssemblerEdge(direction: .front) else { return [] }
    guard let readingMap = composer.parser.mapZhuyinPinyin else { return [] }

    // 組字器尾端必須恰好是 trail 全長（trail 存續本身就是 trail span 無 explicit
    // override 的保證）；不一致時視為 trail 失效，絕不重切動到 trail 以外的內容。
    let trailBuckets: [[String]] = furiousTrail.compactMap { blob in
      guard let zhuyin = readingMap[blob] else { return nil }
      return Tekkon.makeToneInsensitiveVariants(of: zhuyin)
    }
    guard trailBuckets.count == furiousTrail.count else {
      invalidateFuriousTrail() // 自癒：trail 含無法展開的段時失效。
      return []
    }
    let expectedTrailingKeys = trailBuckets.map { Homa.PossibleKey.multipleKeys($0) }
    guard Array(assembler.keys.suffix(furiousTrail.count)) == expectedTrailingKeys else {
      invalidateFuriousTrail() // 自癒：組字器尾鍵與 trail 不符時失效。
      return []
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
    var candidates = segmentor.candidateSegmentations(
      of: letters, syllableCount: furiousTrail.count
    )
    // 現狀（當前 trail）併入去重，避免 limit 截斷把它排擠掉（供排除比較用）。
    if !candidates.contains(where: { $0 == furiousTrail }) {
      candidates.append(furiousTrail)
    }
    guard candidates.count > 1 else { return [] } // 僅有現狀，無從比較。

    var result: [FuriousResegmentationCandidate] = []
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
      result.append(.init(
        blobs: candidate,
        keyBuckets: keyBuckets,
        scratchScore: scratch.mostRecentPathScore,
        topReading: scratch.assembledSentence.last?.keyArray ?? [],
        topValue: scratch.assembledSentence.last?.value ?? ""
      ))
    }
    return result.sorted { $0.scratchScore > $1.scratchScore }
  }

  /// 構建狂拼 copilot 窗的「trail＋注拼槽聯合重切」offers（P164）：
  /// 把 trail 字母流與注拼槽字母流合併、以 `FuriousTypingSegmentor` 枚舉「同音節數」
  /// （trail 段數＋1——copilot 語義下注拼槽整段為一音節）的合法切分，每個替代切分
  /// 以「整詞查詢」（切分全部段的音節桶、只取整段匹配的完整詞）取組句 top-1 詞為
  /// offer——使「fangan」連打（trail=fang、注拼槽=an）時 copilot 窗即呈現「反感」
  /// （fan|gan）類候選，與「fan gan」分開打的體驗一致。同音節數約束延續 P163 收斂：
  /// 不產生拆開型重切（「xiansheng」→「xi, an, sheng」為 3 音節、被過濾）。
  func buildFuriousCoSegmentedOffers() -> [FuriousCoSegmentedOffer] {
    guard isFuriousTypingModeEffective else { return [] }
    guard composer.intonation.isEmpty else { return [] }
    let romaji = composer.romajiBuffer
    guard !romaji.isEmpty else { return [] }
    guard !furiousTrail.isEmpty else { return [] }
    guard assembler.isCursorAtAssemblerEdge(direction: .front) else { return [] }
    guard let readingMap = composer.parser.mapZhuyinPinyin else { return [] }
    // 現狀切分：trail 段＋注拼槽整段（copilot 語義下 1 段）。
    let currentSegmentation = furiousTrail + [romaji]
    let letters = furiousTrail.joined() + romaji
    let expectedSyllableCount = furiousTrail.count + 1
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
    let segmentations = segmentor.candidateSegmentations(
      of: letters, syllableCount: expectedSyllableCount
    )
    var result: [FuriousCoSegmentedOffer] = []
    for candidate in segmentations where candidate != currentSegmentation {
      // 逐段展開六聲調桶，且每個桶都須有在庫命中；驗證失敗整個切分跳過。
      let keyBuckets: [[String]] = candidate.compactMap { blob in
        guard let zhuyin = readingMap[blob] else { return nil }
        return Tekkon.makeToneInsensitiveVariants(of: zhuyin)
      }
      guard keyBuckets.count == candidate.count,
            keyBuckets.allSatisfy({ bucket in
              bucket.contains(where: { currentLM.hasUnigramsForFast(keyArray: [$0]) })
            })
      else { continue }
      // 整詞查詢：該切分全部段的音節桶——只取「整段匹配」的完整詞（段數一致）。
      let grams = currentLM.lookupHub.grams(for: keyBuckets.map { .multipleKeys($0) })
      guard let top = grams
        .filter({ $0.keyArray.count == candidate.count })
        .max(by: { $0.probability < $1.probability }),
        !top.current.isEmpty
      else { continue }
      result.append(.init(
        keyArray: top.keyArray, value: top.current, blobs: candidate, weight: top.probability
      ))
    }
    return result
  }

  /// 聯合重切候選確認（P164 補修）：被選 copilot 候選匹配「聯合重切 offer」時，
  /// drop trail 全長＋insert 替代切分音節桶＋清空注拼槽＋trail 更新為新切分——
  /// 「fangan」連打選中「反感」後組字器變為 fan|gan 桶、組句「反感」。
  /// 不遞交、不寫 POM 觀察（讀音層變更、非字詞確認）；失敗防禦復原 trail 鍵。
  /// - Returns: 是否已處理（true＝呼叫端不應再走普通前方候選確認）。
  @discardableResult
  func applyFuriousCoSegmentedOfferIfAny(candidate: CandidateInState) -> Bool {
    guard let offer = furiousCoSegmentedOffers.first(where: {
      $0.keyArray == candidate.keyArray && $0.value == candidate.value
    }) else { return false }
    guard !furiousTrail.isEmpty, !composer.romajiBuffer.isEmpty else { return false }
    guard let readingMap = composer.parser.mapZhuyinPinyin else { return false }
    let keyBuckets: [[String]] = offer.blobs.compactMap { blob in
      guard let zhuyin = readingMap[blob] else { return nil }
      return Tekkon.makeToneInsensitiveVariants(of: zhuyin)
    }
    guard keyBuckets.count == offer.blobs.count else { return false }
    // 替換：drop trail 全長、insert 替代切分音節桶。
    for _ in 0 ..< furiousTrail.count {
      guard (try? assembler.dropKey(direction: .rear)) != nil else { return false }
    }
    guard (try? assembler.insertKeys(keyBuckets)) != nil else {
      // 失敗防禦：復原原 trail 鍵；trail 一併失效。
      _ = (try? assembler.insertKeys(furiousTrailKeyBuckets()))
      invalidateFuriousTrail()
      return true // 已嘗試處理：呼叫端不應再走普通前方候選確認。
    }
    composer.replacePinyinBuffer(with: "")
    furiousHighlightOverride = nil // 高亮覆寫僅供當拍消費。
    furiousTrail = offer.blobs
    retrievePOMSuggestions(apply: false)
    return true
  }

  /// 將 trail 展開為音節桶序列（與 auto-chop／空格固化插入語義一致；失敗防禦用）。
  private func furiousTrailKeyBuckets() -> [[String]] {
    guard let readingMap = composer.parser.mapZhuyinPinyin else { return [] }
    return furiousTrail.compactMap { blob in
      guard let zhuyin = readingMap[blob] else { return nil }
      return Tekkon.makeToneInsensitiveVariants(of: zhuyin)
    }
  }

  /// 語言模型引導的拼音重切分（furious resegmentation）。
  ///
  /// 當 trail 記錄了至少兩個由自動 chop 提交的讀音鍵時，把 trail 的字母流重新枚舉成
  /// 各種同音節數的合法切分，以組字器副本（scratch）逐一評分，僅在候選的整句路徑總分
  /// 嚴格高於現狀時，才對真組字器做 drop+insert 替換。任何環節不符預期皆靜默退回。
  /// 候選枚舉與試算統一交由 `enumerateFuriousResegmentationCandidates`（與重切候選
  /// 入窗共用；P164）。
  ///
  /// **範圍收斂（P163 補修）**：本函式刻意只做「同音節數」重切、且 trail 至少兩段——
  /// 跨音節數重切（`xian`→`[xi, an]`）在打字中途即把單音節 trail 拆開，會誤傷
  /// 「先生」類的後續多音節組句（「xian 空格 sheng」被拆成「西 安 生」）；「每音節
  /// 平均」正規化亦偏好多音節切分（普通單字平均分高於合併詞）。跨音節數的枚舉能力
  /// 仍保留於 `FuriousTypingSegmentor.candidateSegmentations(of:syllableCount: nil)`，
  /// 供今後經設計的觸發條件使用。
  func resegmentFuriousTrailIfNeeded() {
    // 閘門與候選枚舉（含 scratch 試算）統一交由共用 helper。
    let candidates = enumerateFuriousResegmentationCandidates()
    guard !candidates.isEmpty else { return }
    // 基線：真組字器目前的整句路徑總分（顯式組句以確保讀取前已刷新）。
    _ = assembler.assemble()
    let baselineScore = assembler.mostRecentPathScore
    // 嚴格更高才替換；否則維持現狀（enumerate 已按分數降冪）。
    guard let bestCandidate = candidates.first(where: { $0.scratchScore > baselineScore }) else {
      return
    }

    // 替換：對真組字器做同樣的 drop+insert，更新 trail，並重取 POM 建議。
    for _ in 0 ..< furiousTrail.count {
      guard (try? assembler.dropKey(direction: .rear)) != nil else { return }
    }
    guard (try? assembler.insertKeys(bestCandidate.keyBuckets)) != nil else {
      // 失敗防禦：復原原 trail 鍵以維持既有組句；trail 一併失效。
      _ = (try? assembler.insertKeys(furiousTrailKeyBuckets()))
      invalidateFuriousTrail()
      return
    }
    furiousTrail = bestCandidate.blobs
    retrievePOMSuggestions(apply: false)
  }
}
