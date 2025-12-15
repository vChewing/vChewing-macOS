// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - InputHandlerProtocol

/// 該檔案乃輸入調度模組的核心部分，主要承接型別初期化內容、協定內容、以及
/// 被封裝的「與 Megrez 組字引擎和 Tekkon 注拼引擎對接的」各種工具函式。
/// 注意：不要把 composer 注拼槽與 compositor 組字器這兩個概念搞混。
public protocol InputHandlerProtocol: AnyObject, InputHandlerCoreProtocol {
  typealias Composer = Tekkon.Composer
  typealias Assembler = Megrez.Compositor
  typealias KeyValuePaired = Megrez.KeyValuePaired
  typealias Phonabet = Tekkon.Phonabet

  // MARK: - Type Properties

  static var keySeparator: String { get }

  // MARK: - Properties

  /// 委任物件 (SessionCtl)，以便呼叫其中的函式。
  var session: Session? { get set }

  var prefs: PrefMgrProtocol { get set }
  var errorCallback: ((String) -> ())? { get set }
  var notificationCallback: ((String) -> ())? { get set }
  var pomSaveCallback: (() -> ())? { get set }
  var filterabilityChecker: ((_ state: IMEStateData) -> Bool)? { get set }
  var isJISKeyboard: (() -> Bool)? { get set }
  var narrator: (any SpeechNarratorProtocol)? { get set }

  var currentLM: LMAssembly.LMInstantiator { get set }

  /// 用來記錄「叫出選字窗前」的游標位置的變數。
  var backupCursor: Int? { get set }

  /// 當前的打字模式。
  var currentTypingMethod: TypingMethod { get set }

  var strCodePointBuffer: String { get set } // 內碼輸入專用組碼區
  var calligrapher: String { get set } // 磁帶專用組筆區
  var composer: Tekkon.Composer { get set } // 注拼槽
  var assembler: Megrez.Compositor { get set } // 組字器
}

// MARK: - KeyDropContext

/// KeyDropContext：負責封裝在使用者手動覆寫節點時，於執行刪除鍵（dropKey）前所需
/// 的上下文資訊與重覆寫行為。
///
/// 說明：當使用者在候選節點上做手動覆寫（例如在選字窗內選字），之後若使用刪除
/// 鍵以刪除該節點內的一個子鍵（子讀音），有可能造成剩餘的子鍵被 Megrez 重新
/// 分詞或依 LM 權重改選，導致原本手動覆寫不再保有。此結構會在 `dropKey` 被呼叫
/// 時嘗試捕捉目前節點資訊，提供兩種回補策略：
/// 1) `reapplyCombined`：嘗試將刪除後的新鍵陣列（整合後）以整節覆寫套用回組字引擎，
///    使其依然為使用者手動選定的候選。 此方式優先採用，若成功則可保證結果的
///    原子性與一致性。
/// 2) `reapplyPerKey`：當整節覆寫失敗時，退而求其次對刪除後的每個子鍵（remainingKeys）
///    逐一套用單鍵覆寫（single-key override）以重建使用者意圖，避免整節重新分詞
///    造成優先候選不同。
///
/// 注意：這個結構為 `InputHandlerProtocol` 的輔助型別，對 Megrez 與 LM 的互動有
/// 明確依賴；在產生 context 時若無法取得需要的上下文（如被覆寫節點、節點長度
/// 與讀音對齊等），則會回傳 `nil` 表示不進行回補處理。
private struct KeyDropContext {
  /// 節點起始位置（相對於組字鍵陣列的索引）。
  let nodeStart: Int
  /// 節點內部的鍵序陣列（通常為注音或拼音鍵序）。
  let keys: [String]
  /// 節點對應的字串資料值陣列（分割成 char 的原始字元陣列）。
  let values: [String]
  /// 在節點內被移除（刪除）的子鍵索引。
  let removedIndex: Int

  /// 刪除指定子鍵後，節點剩下的鍵序陣列（不含被刪除的鍵）。
  var remainingKeys: [String] {
    keys.enumerated().compactMap { $0.offset == removedIndex ? nil : $0.element }
  }

  /// 刪除指定子鍵後，剩下的字串資料值（結合為一個字串）。
  var remainingValue: String {
    values.enumerated().compactMap { $0.offset == removedIndex ? nil : $0.element }.joined()
  }

  /// 生成手動覆寫 DropKey 的上下文。
  /// - Parameters:
  ///   - direction: DropKey 的方向（前方/後方）。
  ///   - inputHandler: 呼叫者（通常為 InputHandler 的實作）。
  /// - Returns: 當可在目前游標位置判定為「手動覆寫」且該節點可安全回補的情況下，
  ///   回傳 `KeyDropContext`；否則回傳 nil。
  static func getManualOverrideKeyDropContext<T: InputHandlerProtocol>(
    for direction: T.Assembler.TypingDirection,
    from inputHandler: T
  )
    -> Self? {
    guard inputHandler.assembler.keys.count > 1 else { return nil }
    guard !inputHandler.assembler.isCursorAtEdge(direction: direction) else { return nil }
    let currentAssembly = inputHandler.assembler.assembledSentence
    let cursorAfterTask = switch direction {
    case .front: inputHandler.assembler.cursor + 1
    case .rear: inputHandler.assembler.cursor - 1
    }
    guard currentAssembly.isCursorCuttingRegion(
      cursor: cursorAfterTask
    ) else { return nil }
    let affectedRegionID = currentAssembly.cursorRegionMap[cursorAfterTask]
    guard let affectedRegionID else { return nil }
    let affectedRegion = currentAssembly[affectedRegionID]
    guard affectedRegion.isExplicit else { return nil }
    guard !affectedRegion.isReadingMismatched else { return nil }
    let nodeRange = currentAssembly.contextRange(ofGivenCursor: cursorAfterTask)
    let nodeStart = nodeRange.lowerBound
    let nodeLength = nodeRange.count
    guard nodeLength > 0 else { return nil }
    let values = affectedRegion.asCandidatePair.value.map { String($0) }
    guard values.count == nodeLength else { return nil }
    let removedIndex = switch direction {
    case .front: inputHandler.assembler.cursor - nodeStart
    case .rear: inputHandler.assembler.cursor - 1 - nodeStart
    }
    guard (0 ..< nodeLength).contains(removedIndex) else { return nil }
    return .init(
      nodeStart: nodeStart,
      keys: affectedRegion.keyArray,
      values: values,
      removedIndex: removedIndex
    )
  }

  /// 試圖以「整節」覆寫的方式回補刪除後的節點（若節點已被分割或不存在則失敗）。
  /// - Parameters:
  ///   - target: InputHandler 實例目標。
  /// - Returns: 覆寫成功與否的布林值。
  func reapplyCombined<T: InputHandlerProtocol>(to target: T) -> Bool {
    let startPosition = min(max(nodeStart, 0), target.assembler.length)
    return target.assembler.overrideCandidate(
      .init(keyArray: remainingKeys, value: remainingValue),
      at: startPosition,
      overrideType: .withSpecified,
      isExplicitlyOverridden: true, // <- 此處標記為顯式覆寫存有疑義。
      enforceRetokenization: true
    )
  }

  /// 逐鍵覆寫：當整節回補失敗時，對每個剩餘子鍵試圖進行單鍵覆寫，以恢復原先的節點
  /// 中所選定的字面值。該方法不會變動游標或 marker。
  /// - Parameters:
  ///   - target: InputHandler 實例目標。
  func reapplyPerKey<T: InputHandlerProtocol>(to target: T) {
    for (index, key) in keys.enumerated() where index != removedIndex {
      let value = values[index]
      let newPosition = nodeStart + (index > removedIndex ? index - 1 : index)
      _ = target.assembler.overrideCandidate(
        .init(keyArray: [key], value: value),
        at: min(max(newPosition, 0), target.assembler.length),
        overrideType: .withSpecified,
        isExplicitlyOverridden: true, // <- 此處標記為顯式覆寫存有疑義。
        enforceRetokenization: true
      )
    }
  }
}

extension InputHandlerProtocol {
  // MARK: - Functions dealing with Megrez.

  public var isCompositorEmpty: Bool { assembler.isEmpty }

  public var isComposerUsingPinyin: Bool { composer.isPinyinMode }

  public var moveCursorAfterSelectingCandidate: Bool {
    /// prefs.cursorPlacementAfterSelectingCandidate 的參數說明：
    /// 此設定用來指定候選字在選字窗內被確認後，游標應該位於何處。
    /// 請注意，「呼出選字窗之前的游標位置」指的是選字窗出現前所記錄的游標位置。
    /// 如果選擇向前推進一格，實際推進的距離會因您偏好的選字游標操作樣式而有所不同。
    /// 有效值只有 0, 1, 2 這三個值。
    /// 0: 什麼也不做；1: 向前推進一格；2: 復原呼出選字窗之前的游標位置。
    prefs.cursorPlacementAfterSelectingCandidate == 1
  }

  public var restoreCursorAfterSelectingCandidate: Bool {
    prefs.cursorPlacementAfterSelectingCandidate == 2
  }

  // MARK: - Extracted methods and functions (Megrez).

  public var keySeparator: String { assembler.separator }

  public func clear() {
    clearComposerAndCalligrapher()
    assembler.clear()
    currentLM.purgeInputTokenHashMap()
    currentTypingMethod = .vChewingFactory
    backupCursor = nil
  }

  public func removeBackupCursor() {
    backupCursor = nil
  }

  public func dodgeInvalidEdgeCursorForCandidateState() {
    guard !prefs.useSCPCTypingMode else { return }
    guard prefs.dodgeInvalidEdgeCandidateCursorPosition else { return }
    guard isInvalidEdgeCursorSituation() else { return }
    backupCursor = assembler.cursor
    switch prefs.useRearCursorMode {
    case false where !assembler.isCursorAtEdge(direction: .front):
      _ = assembler.moveCursorStepwise(to: .front)
    case true where !assembler.isCursorAtEdge(direction: .rear):
      _ = assembler.moveCursorStepwise(to: .rear)
    default: break
    }
  }

  public func restoreBackupCursor() {
    guard let theBackupCursor = backupCursor else { return }
    assembler.cursor = Swift.max(Swift.min(theBackupCursor, assembler.length), 0)
    backupCursor = nil
  }

  /// 在組字器內，以給定之候選字（詞音配對）、來試圖在給定游標位置所在之處指定選字處理過程。
  /// 然後再將對應的節錨內的節點標記為「已經手動選字過」。我們稱之為「固化節點」。
  /// - Parameters:
  ///   - value: 給定之候選字（詞音配對）。
  ///   - respectCursorPushing: 若該選項為 true，則會在選字之後始終將游標推送至選字後的節錨的前方。
  ///   - preConsolidate: 在固化節點之前，先鞏固上下文。該選項可能會破壞在內文組字區內就地輪替候選字詞時的體驗。
  ///   - skipObservation: 不要讓漸退記憶模組對此做出觀察。
  public func consolidateNode(
    candidate: CandidateInState,
    respectCursorPushing: Bool = true,
    preConsolidate: Bool = false,
    skipObservation: Bool = false,
    explicitlyChosen: Bool = false
  ) {
    let theCandidate: Megrez.KeyValuePaired = .init(candidate)
    let preservedSentenceBeforeConsolidation = assembler.assembledSentence
    let preservedCursorPosition = actualNodeCursorPosition

    /// 必須先鞏固當前組字器游標上下文、以消滅意料之外的影響，但在內文組字區內就地輪替候選字詞時除外。
    if preConsolidate { consolidateCursorContext(with: theCandidate, explicitlyChosen: explicitlyChosen) }

    // 先嘗試用 POM 建議覆寫（如果有完全匹配的記憶）。
    let pomSuggestion = retrievePOMSuggestions(apply: false)
      .first(where: {
        $0.0 == theCandidate.keyArray.joined(separator: assembler.separator)
          && $0.1.value == theCandidate.value
      })
    var overrideTaskResult = false
    if pomSuggestion != nil {
      // 強制 retokenization 並用 withSpecified 覆寫
      overrideTaskResult = assembler.overrideCandidate(
        .init(keyArray: theCandidate.keyArray, value: theCandidate.value),
        at: actualNodeCursorPosition,
        overrideType: .withSpecified,
        isExplicitlyOverridden: explicitlyChosen,
        enforceRetokenization: true
      )
    }
    // 若無 POM 建議或覆寫失敗，走原有覆寫流程
    if !overrideTaskResult {
      var pomObservation: Megrez.PerceptionIntel?
      var pomObservationPrimary: Megrez.PerceptionIntel?
      var pomObservation2ndary: Megrez.PerceptionIntel?
      var attempt = 0
      while attempt < 4, !overrideTaskResult {
        attempt += 1
        let enforce = attempt % 2 == 0 // 偶數次強制 retokenization
        overrideTaskResult = assembler.overrideCandidate(
          theCandidate, at: actualNodeCursorPosition,
          isExplicitlyOverridden: explicitlyChosen,
          enforceRetokenization: enforce
        ) { perceptionIntel in
          if attempt % 2 == 1 {
            pomObservationPrimary = perceptionIntel
          } else {
            pomObservation2ndary = perceptionIntel
          }
        }
        if !overrideTaskResult, attempt == 2 {
          let contextualTargets = [
            pomObservationPrimary
              .map { (ngramKey: $0.contextualizedGramKey, candidate: $0.candidate) },
            pomObservation2ndary
              .map { (ngramKey: $0.contextualizedGramKey, candidate: $0.candidate) },
          ].compactMap { $0 }
          if !contextualTargets.isEmpty {
            currentLM.bleachSpecifiedPOMSuggestions(targets: contextualTargets)
          }
          let candidateTargets = [
            pomObservationPrimary?.candidate,
            pomObservation2ndary?.candidate,
          ].compactMap { $0 }
          if !candidateTargets.isEmpty {
            currentLM.bleachSpecifiedPOMSuggestions(targets: Array(Set(candidateTargets)))
          }
          pomObservationPrimary = nil
          pomObservation2ndary = nil
        }
      }
      if !overrideTaskResult { return }
      pomObservation = pomObservation2ndary ?? pomObservationPrimary
      assemble()
      if let adjustedObservation = Megrez.makePerceptionIntel(
        previouslyAssembled: preservedSentenceBeforeConsolidation,
        currentAssembled: assembler.assembledSentence,
        cursor: preservedCursorPosition
      ) {
        pomObservation = adjustedObservation
      }
      guard let pomObservation else { return }
      pomProcessing: if pomObservation.scoreFromLM > -12,
                        prefs.fetchSuggestionsFromPerceptionOverrideModel {
        if skipObservation { break pomProcessing }
        vCLog("POM: Start Observation.")
        prefs.failureFlagForPOMObservation = true
        currentLM.memorizePerception(
          (pomObservation.contextualizedGramKey, pomObservation.candidate),
          timestamp: Date().timeIntervalSince1970,
          saveCallback: pomSaveCallback
        )
        prefs.failureFlagForPOMObservation = false
      }
    } else {
      assemble()
    }

    if moveCursorAfterSelectingCandidate, respectCursorPushing {
      assembler.jumpCursorBySegment(to: .front)
    }
  }

  public func previewCurrentCandidateAtCompositionBuffer() {
    guard let session = session, session.state.type == .ofCandidates,
          let highlightedPair = session.state.currentCandidate
    else {
      return
    }
    let gridOverrideStatusMirror = assembler.createNodeOverrideStatusMirror()
    let currentAssembledSentence = assembler.assembledSentence
    let (currentCursor, currentMarker) = (assembler.cursor, assembler.marker)
    defer {
      assembler.restoreFromNodeOverrideStatusMirror(gridOverrideStatusMirror)
      assembler.assembledSentence = currentAssembledSentence
      assembler.cursor = currentCursor
      assembler.marker = currentMarker
    }
    var theState = session.state
    consolidateNode(
      candidate: highlightedPair,
      respectCursorPushing: false,
      preConsolidate: prefs.consolidateContextOnCandidateSelection,
      skipObservation: true
    )
    theState.data.displayTextSegments = assembler.assembledSentence.values
    theState.data.cursor = convertCursorForDisplay(assembler.cursor)
    let markerBackup = assembler.marker
    if assembler.isCursorAtEdge(direction: .front) {
      assembler.jumpCursorBySegment(to: .rear, isMarker: true)
    } else if assembler.isCursorAtEdge(direction: .rear) {
      assembler.jumpCursorBySegment(to: .front, isMarker: true)
    } else {
      assembler.jumpCursorBySegment(to: prefs.useRearCursorMode ? .front : .rear, isMarker: true)
    }
    theState.data.marker = assembler.marker
    assembler.marker = markerBackup
    session.state = theState // 直接就地取代，不經過 switchState 處理，免得選字窗被重新載入。
    session.updateCompositionBufferDisplay()
  }

  /// 給注拼槽指定注音排列或拼音輸入種類之後，將注拼槽內容清空。
  public func ensureKeyboardParser() {
    switch currentKeyboardParserType {
    case .ofStandard: composer.ensureParser(arrange: .ofDachen)
    case .ofDachen26: composer.ensureParser(arrange: .ofDachen26)
    case .ofETen: composer.ensureParser(arrange: .ofETen)
    case .ofHsu: composer.ensureParser(arrange: .ofHsu)
    case .ofETen26: composer.ensureParser(arrange: .ofETen26)
    case .ofIBM: composer.ensureParser(arrange: .ofIBM)
    case .ofMiTAC: composer.ensureParser(arrange: .ofMiTAC)
    case .ofFakeSeigyou: composer.ensureParser(arrange: .ofFakeSeigyou)
    case .ofSeigyou: composer.ensureParser(arrange: .ofSeigyou)
    case .ofStarlight: composer.ensureParser(arrange: .ofStarlight)
    case .ofAlvinLiu: composer.ensureParser(arrange: .ofAlvinLiu)
    case .ofHanyuPinyin: composer.ensureParser(arrange: .ofHanyuPinyin)
    case .ofSecondaryPinyin: composer.ensureParser(arrange: .ofSecondaryPinyin)
    case .ofYalePinyin: composer.ensureParser(arrange: .ofYalePinyin)
    case .ofHualuoPinyin: composer.ensureParser(arrange: .ofHualuoPinyin)
    case .ofUniversalPinyin: composer.ensureParser(arrange: .ofUniversalPinyin)
    case .ofWadeGilesPinyin: composer.ensureParser(arrange: .ofWadeGilesPinyin)
    }
    composer.clear()
    composer.phonabetCombinationCorrectionEnabled = prefs.autoCorrectReadingCombination
  }

  public func clearComposerAndCalligrapher() {
    calligrapher.removeAll()
    composer.clear()
    strCodePointBuffer.removeAll()
  }

  /// 就地增刪詞之後，需要就地更新游標上下文單元圖資料。
  public func updateUnigramData() -> Bool {
    let result = assembler.assignNodes(updateExisting: true)
    defer { assemble() }
    return result > 0
  }

  /// 警告：該參數僅代指組音區/組筆區域與組字區在目前狀態下被視為「空」。
  public var isConsideredEmptyForNow: Bool {
    assembler.isEmpty && isComposerOrCalligrapherEmpty && currentTypingMethod == .vChewingFactory
  }

  /// 要拿給 Megrez 使用的特殊游標位址，用於各種與節點判定有關的操作。
  /// - Remark: 自 Megrez 引擎 v2.6.2 開始，該參數不得用於獲取候選字詞清單資料。相關函式僅接收原始 cursor 資料。
  public var actualNodeCursorPosition: Int {
    // 防止指向虛位；`assembler.length` 表示最前端的虛位（cursor 可達）。
    // `actualNodeCursorPosition` 應回傳對應 `assembler.keys.indices` 的真實索引。
    let validIndices = assembler.keys.indices
    let atFrontEdge = assembler.isCursorAtEdge(direction: .front)
    let atRearEdge = assembler.isCursorAtEdge(direction: .rear)
    let delta = ((atFrontEdge || !prefs.useRearCursorMode) && !atRearEdge ? 1 : 0)
    let pos = Swift.min(
      assembler.cursor - delta,
      validIndices.last ?? validIndices.upperBound
    )
    return Swift.max(pos, 0)
  }

  public func activePOMCandidateValues() -> [String] {
    retrievePOMSuggestions(apply: false).map { $0.1.value }
  }

  // MARK: - Extracted methods and functions (Tekkon).

  var isComposerOrCalligrapherEmpty: Bool {
    if !strCodePointBuffer.isEmpty { return false }
    return prefs.cassetteEnabled ? calligrapher.isEmpty : composer.isEmpty
  }

  /// 獲取與當前注音排列或拼音輸入種類有關的標點索引鍵，以英數下畫線「_」結尾。
  var currentKeyboardParser: String { currentKeyboardParserType.name + "_" }
  var currentKeyboardParserType: KeyboardParser {
    .init(rawValue: prefs.keyboardParser) ?? .ofStandard
  }

  /// 返回前一個游標位置的可解析的漢字筆畫。
  /// 返回的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
  var previousParsableCalligraph: String? {
    if assembler.cursor == 0 { return nil }
    let cursorPrevious = max(assembler.cursor - 1, 0)
    return assembler.keys[cursorPrevious]
  }

  /// 返回前一個游標位置的可解析的漢字讀音。
  /// 返回的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
  var previousParsableReading: (String, String, Bool)? {
    if assembler.cursor == 0 { return nil }
    let cursorPrevious = max(assembler.cursor - 1, 0)
    let rawData = assembler.keys[cursorPrevious]
    let components = rawData.map(\.description)
    var hasIntonation = false
    for neta in components {
      let char = neta.unicodeScalars.first
      guard let char else { return nil }
      if !Tekkon.allowedPhonabets.contains(char) || neta == " " { return nil }
      if Tekkon.allowedIntonations.contains(char) { hasIntonation = true }
    }
    if hasIntonation, components.count == 1 { return nil } // 剔除純聲調之情形
    let rawDataSansIntonation = hasIntonation ? components.dropLast(1).joined() : rawData
    return (rawData, rawDataSansIntonation, hasIntonation)
  }

  var readingForDisplay: String {
    if !prefs.cassetteEnabled {
      return composer.getInlineCompositionForDisplay(
        isHanyuPinyin: prefs.showHanyuPinyinInCompositionBuffer
      )
    }
    if !prefs.showTranslatedStrokesInCompositionBuffer { return calligrapher }
    return calligrapher.map(\.description).map {
      currentLM.convertCassetteKeyToDisplay(char: $0)
    }.joined()
  }

  func isInvalidEdgeCursorSituation(givenCursor: Int? = nil) -> Bool {
    let cursorToCheck = givenCursor ?? assembler.cursor
    // prefs.useRearCursorMode 為 0 (false) 時（macOS 注音選字），最後方的游標位置不合邏輯。
    // prefs.useRearCursorMode 為 1 (true) 時（微軟新注音選字），最前方的游標位置不合邏輯。
    // 註：cursor == 0 的時候為最後方。方法遵循 `assembler.isCursorAtEdge(` 的實作。
    switch prefs.useRearCursorMode {
    case false where cursorToCheck == 0: return true
    case true where cursorToCheck == assembler.length: return true
    default: return false
    }
  }

  /// 獲取當前標記得範圍。這個函式只能是函式、而非只讀變數。
  /// - Returns: 當前標記範圍。
  func currentMarkedRange() -> Range<Int> {
    assembler.currentMarkedRange()
  }

  /// 檢測是否出現游標切斷組字區內字符的情況
  func isCursorCuttingChar(isMarker: Bool = false) -> Bool {
    assembler.isCursorCuttingChar(isMarker: isMarker)
  }

  /// 利用給定的讀音鏈來試圖爬取最接近的組字結果（最大相似度估算）。
  ///
  /// 該過程讀取的權重資料是經過 Viterbi 演算法計算得到的結果。
  ///
  /// 該函式的爬取順序是從頭到尾。
  func assemble() {
    assembler.assemble()

    // 在偵錯模式開啟時，將 GraphViz 資料寫入至指定位置。
    if prefs.isDebugModeEnabled {
      let result = assembler.dumpDOT
      let thePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].path
        .appending(
          "/vChewing-visualization.dot"
        )
      do {
        try result.write(toFile: thePath, atomically: true, encoding: .utf8)
      } catch {
        vCLog("Failed from writing dumpDOT results.")
      }
    }
  }

  /// 用以組建關聯詞語陣列的函式，生成的內容不包含重複的結果。
  /// - Parameter pairs: 給定的詞音配對陣列。
  /// - Returns: 抓取到的關聯詞語陣列。
  /// 不會是 nil，但那些負責接收結果的函式會對空白陣列結果做出正確的處理。
  func generateArrayOfAssociates(withPairs pairs: [Megrez.KeyValuePaired]) -> [(
    keyArray: [String],
    value: String
  )] {
    var arrResult: [CandidateInState] = []
    pairs.forEach { pair in
      if currentLM.hasAssociatedPhrasesFor(pair: pair) {
        let arrFetched: [String] = currentLM.associatedPhrasesFor(pair: pair)
        arrFetched.forEach { thingToAdd in
          // keyArray 對關聯詞語候選字詞而言（現階段）毫無意義。這裡只判斷 value。
          if !arrResult.map(\.value).contains(thingToAdd) {
            arrResult.append((keyArray: [""], value: thingToAdd))
          }
        }
      }
    }
    return arrResult
  }

  /// 用以組建關聯詞語陣列的函式，生成的內容不包含重複的結果。
  /// - Parameter pair: 給定的詞音配對。
  /// - Returns: 抓取到的關聯詞語陣列。
  /// 不會是 nil，但那些負責接收結果的函式會對空白陣列結果做出正確的處理。
  func generateArrayOfAssociates(withPair pair: Megrez.KeyValuePaired) -> [(
    keyArray: [String],
    value: String
  )] {
    var pairs = [Megrez.KeyValuePaired]()
    var keyArray = pair.keyArray
    var value = pair.value
    while !keyArray.isEmpty {
      // 關聯詞語處理用不到組字引擎，故不需要 score。
      if keyArray.count == value.count { pairs.append(.init(keyArray: keyArray, value: value)) }
      pairs.append(.init(key: "", value: value)) // 保底。
      keyArray = Array(keyArray.dropFirst())
      value = value.dropFirst().description
    }
    return generateArrayOfAssociates(withPairs: pairs)
  }

  /// 用來計算離當前游標最近的一個節點邊界的距離的函式。
  /// - Parameter direction: 文字輸入方向意義上的方向。
  /// - Returns: 邊界距離。
  func getStepsToNearbyNodeBorder(direction: Megrez.Compositor.TypingDirection) -> Int {
    let (currentCursor, currentMarker) = (assembler.cursor, assembler.marker)
    assembler.jumpCursorBySegment(to: direction)
    let newCursor = assembler.cursor
    let result = abs(newCursor - currentCursor)
    // 還原游標位置。
    assembler.cursor = currentCursor
    assembler.marker = currentMarker
    return result
  }

  /// 獲取候選字詞（包含讀音）陣列資料內容。
  func generateArrayOfCandidates(fixOrder: Bool = true) -> [CandidateInState] {
    /// 警告：不要對游標前置風格使用 nodesCrossing，否則會導致游標行為與 macOS 內建注音輸入法不一致。
    /// 微軟新注音輸入法的游標後置風格也是不允許 nodeCrossing 的。
    var arrCandidates = fetchRawQueriedCandidatesFromAssembler()

    /// 原理：nodes 這個回饋結果包含一堆子陣列，分別對應不同詞長的候選字。
    /// 這裡先對陣列排序、讓最長候選字的子陣列的優先權最高。
    /// 這個過程不會傷到子陣列內部的排序。
    if arrCandidates.isEmpty { return .init() }
    // 決定是否根據漸退記憶模組的建議來調整候選字詞的順序。
    let skipPOMHandling: Bool = fixOrder
      || !prefs.fetchSuggestionsFromPerceptionOverrideModel
      || prefs.useSCPCTypingMode
      || currentTypingMethod != .vChewingFactory
    switch skipPOMHandling {
    case false:
      let arrSuggestedUnigrams: [(String, Megrez.Unigram)] = retrievePOMSuggestions(
        apply: false,
        rawCandidates: arrCandidates
      )
      let arrSuggestedCandidates: [Megrez.KeyValuePaired] = arrSuggestedUnigrams.map {
        Megrez.KeyValuePaired(
          keyArray: $0.1.keyArray,
          value: $0.1.value,
          score: $0.1.score
        )
      }

      let rawCandidateSignatures: Set<Megrez.KeyValuePaired> = Set(
        arrCandidates.map(makeCanonicalPair(from:))
      )
      let filteredSuggestedCandidates = arrSuggestedCandidates.filter {
        rawCandidateSignatures.contains(makeCanonicalPair(from: $0))
      }
      arrCandidates = filteredSuggestedCandidates + arrCandidates
      arrCandidates = deduplicateCandidatesPreservingOrder(arrCandidates)
      arrCandidates = arrCandidates.stableSort { $0.keyArray.count > $1.keyArray.count }
    case true: break
    }

    eTenSequenceEnforcement: if prefs.enforceETenDOSCandidateSequence {
      guard currentTypingMethod == .vChewingFactory else {
        break eTenSequenceEnforcement
      }
      var (arr4SingleSegment, arr4LongerSegments): (
        [Megrez.KeyValuePaired], [Megrez.KeyValuePaired]
      ) = ([], [])
      var singleReadings: [String] = []
      var singleReadingsInserted: Set<Int> = []
      arrCandidates.forEach { currentPair in
        switch currentPair.keyArray.count > 1 {
        case true: arr4LongerSegments.append(currentPair)
        case false:
          if let currentReading = currentPair.keyArray.first {
            let hash = currentReading.hashValue
            if !singleReadingsInserted.contains(hash) {
              singleReadingsInserted.insert(hash)
              singleReadings.append(currentReading)
            }
          }
          arr4SingleSegment.append(currentPair)
        }
      }
      // 當且僅當單漢字讀音只有一種時，套用倚天中文 DOS 的候選字排序。
      guard singleReadings.count == 1, let reading = singleReadings.first else {
        break eTenSequenceEnforcement
      }
      let seq4ETen = currentLM.queryETenDOSSequence(reading: reading)
      guard !seq4ETen.isEmpty else { break eTenSequenceEnforcement }
      let arrSeq4ETen: [Megrez.KeyValuePaired] = seq4ETen.map {
        .init(key: reading, value: $0, score: 0)
      }
      arrCandidates = arr4LongerSegments + deduplicateCandidatesPreservingOrder(
        arrSeq4ETen + arr4SingleSegment
      )
    }
    return arrCandidates.map { ($0.keyArray, $0.value) }
  }

  /// 移除重複候選字詞（以讀音 + 詞值做鍵），維持原順序。
  func deduplicateCandidatesPreservingOrder(
    _ candidates: [Megrez.KeyValuePaired]
  )
    -> [Megrez.KeyValuePaired] {
    var seen = Set<Megrez.KeyValuePaired>()
    return candidates.filter { candidate in
      let signature = makeCanonicalPair(from: candidate)
      if seen.contains(signature) { return false }
      seen.insert(signature)
      return true
    }
  }

  /// 將 POM 建議過濾成適合覆寫的單元圖，會剔除分數低於當前原始候選的項目。
  func filterPOMAppendables(
    from suggestion: LMAssembly.OverrideSuggestion,
    rawCandidates: [Megrez.KeyValuePaired]
  )
    -> [(String, Megrez.Unigram)] {
    guard !suggestion.isEmpty else { return [] }

    let separator = assembler.separator
    let rawLookup = rawCandidates.reduce(into: [Megrez.KeyValuePaired: Double]()) { partialResult, item in
      let signature = makeCanonicalPair(from: item)
      let currentScore = item.score
      if let existingScore = partialResult[signature] {
        partialResult[signature] = max(existingScore, currentScore)
      } else {
        partialResult[signature] = currentScore
      }
    }

    return suggestion.candidates.compactMap { candidate in
      let keyString = candidate.keyArray.joined(separator: separator)
      let suggestedUnigram = Megrez.Unigram(
        keyArray: candidate.keyArray,
        value: candidate.value,
        score: candidate.probability
      )
      let signature = makeCanonicalPair(keyArray: candidate.keyArray, value: suggestedUnigram.value)
      if let rawScore = rawLookup[signature], suggestedUnigram.score < rawScore {
        return nil
      }
      return (keyString, suggestedUnigram)
    }
  }

  /// 向漸退引擎詢問可能的選字建議、且套用給組字器內的當前游標位置。
  @discardableResult
  func retrievePOMSuggestions(
    apply: Bool,
    rawCandidates: [Megrez.KeyValuePaired]? = nil
  )
    -> [(String, Megrez.Unigram)] {
    var arrResult = [(String, Megrez.Unigram)]()
    /// 如果逐字選字模式有啟用的話，直接放棄執行這個函式。
    if prefs.useSCPCTypingMode { return arrResult }
    /// 如果這個開關沒打開的話，直接放棄執行這個函式。
    if !prefs.fetchSuggestionsFromPerceptionOverrideModel { return arrResult }
    /// 獲取來自漸退記憶模組的建議結果
    let suggestion = currentLM.fetchPOMSuggestion(
      assembledResult: assembler.assembledSentence,
      cursor: actualNodeCursorPosition,
      timestamp: Date().timeIntervalSince1970
    )
    // 以組字器實際返回的候選字詞權重來過濾 POM 建議：
    // 若建議的分數比當前候選的最高權重還低，則忽略以避免覆寫。
    let rawCandidates = rawCandidates ?? fetchRawQueriedCandidatesFromAssembler()
    let appendables = filterPOMAppendables(from: suggestion, rawCandidates: rawCandidates)
    arrResult.append(contentsOf: appendables)
    if apply {
      if !suggestion.isEmpty, let newestSuggestedCandidate = suggestion.candidates.last {
        let overrideBehavior: Megrez.Node.OverrideType = suggestion.forceHighScoreOverride
          ? .withSpecified
          : .withTopGramScore
        let suggestedPair: Megrez.KeyValuePaired = .init(
          key: newestSuggestedCandidate.keyArray.joined(separator: assembler.separator),
          value: newestSuggestedCandidate.value,
          score: newestSuggestedCandidate.probability
        )
        let cursorForOverride = suggestion.overrideCursor ?? actualNodeCursorPosition
        if let gramHit = assembler.assembledSentence.findGram(at: cursorForOverride) {
          let existingLen = gramHit.gram.keyArray.count
          let suggestedLen = newestSuggestedCandidate.keyArray.count
          if existingLen > suggestedLen,
             newestSuggestedCandidate.probability <= gramHit.gram.score {
            vCLog(
              "POM: Skip applying suggestion \(suggestedPair.toNGramKey) because the existing longer node has higher score (\(gramHit.gram.score))."
            )
            return arrResult.stableSort { $0.1.score > $1.1.score }
          }
        }
        let ngramKey = suggestedPair.toNGramKey
        vCLog(
          "POM: Applying suggestion \(ngramKey) at \(cursorForOverride) via \(overrideBehavior)"
        )
        _ = assembler.overrideCandidate(
          suggestedPair,
          at: cursorForOverride,
          overrideType: overrideBehavior,
          enforceRetokenization: true
        )
        assemble()
      }
    }
    arrResult = arrResult.stableSort { $0.1.score > $1.1.score }
    return arrResult
  }

  func letComposerAndCalligrapherDoBackSpace() {
    _ =
      prefs.cassetteEnabled
        ? calligrapher = String(calligrapher.dropLast(1))
        : composer.doBackSpace()
  }

  /// 生成標點符號索引鍵頭。
  /// - Parameter input: 輸入的按鍵訊號。
  /// - Returns: 生成的標點符號索引鍵頭。
  func generatePunctuationNamePrefix(withKeyCondition input: InputSignalProtocol) -> String {
    if prefs.halfWidthPunctuationEnabled { return "_half_punctuation_" }
    // 注意：這一行為 SHIFT+ALT+主鍵盤數字鍵專用，強制無視不同地區的鍵盤在這個按鍵組合下的符號輸入差異。
    // 但如果去掉「input.isMainAreaNumKey」這個限定條件的話，可能會影響其他依賴 Shift 鍵輸入的符號。
    if input.isMainAreaNumKey,
       input.commonKeyModifierFlags == [.option, .shift] {
      return "_shift_alt_punctuation_"
    }
    var result = ""
    switch (input.isControlHold, input.isOptionHold) {
    case (true, true): result.append("_alt_ctrl_punctuation_")
    case (true, false): result.append("_ctrl_punctuation_")
    case (false, true): result.append("_alt_punctuation_")
    case (false, false): result.append("_punctuation_")
    }
    return result
  }

  /// 生成用以在詞庫內檢索標點符號按鍵資料的檢索字串陣列。
  /// - Parameter input: 輸入的按鍵訊號。
  /// - Returns: 生成的標點符號索引字串。
  func punctuationQueryStrings(input: InputSignalProtocol) -> [String] {
    /// 如果仍無匹配結果的話，先看一下：
    /// - 是否是針對當前注音排列/拼音輸入種類專門提供的標點符號。
    /// - 是否是需要摁修飾鍵才可以輸入的那種標點符號。
    var result: [String] = []
    let inputText = input.text
    let punctuationNamePrefix: String = generatePunctuationNamePrefix(withKeyCondition: input)
    let parser = currentKeyboardParser
    let arrCustomPunctuations: [String] = [punctuationNamePrefix, parser, inputText]
    let customPunctuation: String = arrCustomPunctuations.joined()
    result.append(customPunctuation)
    /// 如果仍無匹配結果的話，看看這個輸入是否是不需要修飾鍵的那種標點鍵輸入。
    let arrPunctuations: [String] = [punctuationNamePrefix, inputText]
    let punctuation: String = arrPunctuations.joined()
    result.append(punctuation)
    return result
  }

  private func fetchRawQueriedCandidatesFromAssembler(
    filterOverride givenFilter: Assembler.CandidateFetchFilter? = nil
  )
    -> [Megrez.KeyValuePaired] {
    if let givenFilter {
      return assembler.fetchCandidates(filter: givenFilter)
    }
    switch prefs.useRearCursorMode {
    case false,
         true where assembler.isCursorAtEdge(direction: .front):
      return assembler.fetchCandidates(filter: .endAt)
    case true,
         false where assembler.isCursorAtEdge(direction: .rear):
      return assembler.fetchCandidates(filter: .beginAt)
    }
  }
}

extension InputHandlerProtocol {
  /// 鞏固當前組字器游標上下文，防止在當前游標位置固化節點時給作業範圍以外的內容帶來不想要的變化。
  ///
  /// 打比方說輸入法原廠詞庫內有「章太炎」一詞，你敲「章太炎」，然後想把「太」改成「泰」以使其變成「章泰炎」。
  /// **macOS 內建的注音輸入法不會在這個過程對這個詞除了「太」以外的部分有任何變動**，
  /// 但所有 OV 系輸入法都對此有 Bug：會將這些部分全部重設為各自的讀音下的最高原始權重的漢字。
  /// 也就是說，選字之後的結果可能會變成「張泰言」。
  ///
  /// - Remark: 類似的可以拿來測試的詞有「蔡依林」「周杰倫」。
  ///
  /// 測試時請務必也測試「敲長句子、且這種詞在句子中間出現時」的情況。
  ///
  /// 唯音輸入法截至 v1.9.3 SP2 版為止都受到上游的這個 Bug 的影響，且在 v1.9.4 版利用該函式修正了這個缺陷。
  /// 該修正必須搭配至少天權星組字引擎 v2.0.2 版方可生效。算法可能比較囉唆，但至少在常用情形下不會再發生該問題。
  /// - Parameter theCandidate: 要拿來覆寫的詞音配對。
  func consolidateCursorContext(with theCandidate: Megrez.KeyValuePaired, explicitlyChosen: Bool = false) {
    // 計算需要鞏固的範圍
    let result = calculateConsolidationBoundaries(for: theCandidate, explicitlyChosen: explicitlyChosen)
    let consolidationRange = result.range

    // 記錄調試信息
    vCLog(result.debugInfo)

    // 接下來獲取這個範圍內的節點位置陣列。
    var nodeIndices = [Int]() // 僅作統計用。

    let targetCursor = actualNodeCursorPosition
    let candidateKeyCount = max(theCandidate.keyArray.count, 1)
    let candidateRangeUpperBound = min(targetCursor + candidateKeyCount, assembler.length)
    let candidateRange = targetCursor ..< candidateRangeUpperBound

    var position = consolidationRange.lowerBound // 臨時統計用
    while position < consolidationRange.upperBound {
      guard let regionIndex = assembler.assembledSentence.cursorRegionMap[position] else {
        position += 1
        continue
      }
      if !nodeIndices.contains(regionIndex) {
        nodeIndices.append(regionIndex) // 新增統計
        guard assembler.assembledSentence.count > regionIndex else { break } // 防呆
        let currentNode = assembler.assembledSentence[regionIndex]
        let nodeLength = currentNode.keyArray.count
        guard nodeLength > 0 else {
          position += 1
          continue
        }
        let nodeStart = position
        var nextPosition = nodeStart
        let nodeRange = nodeStart ..< (nodeStart + nodeLength)
        let overlapsTarget = nodeRange.overlaps(candidateRange)

        if !overlapsTarget {
          if overrideNodeAsWhole(currentNode, at: nodeStart, explicitlyChosen: explicitlyChosen) {
            nextPosition += nodeLength
            position = nextPosition
            continue
          }
          // 若整節覆寫失敗，退回原邏輯逐字固化以維持穩定性。
          let values = currentNode.asCandidatePair.value.map { String($0) }
          guard values.count == currentNode.keyArray.count else {
            nextPosition += nodeLength
            position = nextPosition
            continue
          }
          for (subPosition, key) in currentNode.keyArray.enumerated() {
            guard values.count > subPosition else { break } // 防呆，應該沒有發生的可能性
            let thePair = Megrez.KeyValuePaired(
              keyArray: [key],
              value: values[subPosition]
            )
            assembler.overrideCandidate(
              thePair,
              at: nextPosition,
              isExplicitlyOverridden: explicitlyChosen
            )
            nextPosition += 1
          }
          position = nextPosition
          continue
        }

        // 針對目標節點保留原先逐字固化行為，以確保覆寫準確性。
        let values = currentNode.asCandidatePair.value.map { String($0) }
        guard values.count == currentNode.keyArray.count else {
          if overrideNodeAsWhole(currentNode, at: nodeStart, explicitlyChosen: explicitlyChosen) {
            nextPosition += nodeLength
            position = nextPosition
            continue
          }
          nextPosition += nodeLength
          position = nextPosition
          continue
        }
        for (subPosition, key) in currentNode.keyArray.enumerated() {
          guard values.count > subPosition else { break }
          let thePair = Megrez.KeyValuePaired(
            keyArray: [key],
            value: values[subPosition]
          )
          assembler.overrideCandidate(
            thePair,
            at: nextPosition,
            isExplicitlyOverridden: explicitlyChosen
          )
          nextPosition += 1
        }
        position = nextPosition
        continue
      }
      position += 1
    }
  }

  /// 刪除鍵（dropKey）處理：該函式會在必要時判定「當前游標旁是否存在被手動覆寫的
  /// 節點（overridden node）」。若該情形成立，則會嘗試以兩個步驟回補使用者的手動
  /// 覆寫意圖，以防止 LM 或 Megrez 重新分詞後導致選字被改變。
  ///
  /// 假設游標/候選/刪除方向的範例為：`(0, A1-B1-C1, front)` 與 `(3, X1-Y1-Z1, rear)`。
  /// 在刪除其中一個鍵後，期望的結果分別為 `(0, B1-C1)` 以及 `(2, X1-Y1)`。
  /// 然而，實際上，由於不同候選項之分數可能會導致排序變化，結果可能會變成
  /// `(0, B2-C2)` 與 `(2, X2-Y2)`。
  /// 類似情形還有：`(1, A1-B1-C1, front)` 與 `(2, X1-Y1-Z1, rear)`，
  /// 預期結果為 `(1, A1-C1)` 與 `(1, X1-Z1)`，但實際上可能因候選分數差異
  /// 而變成 `(1, A2-C2)` 與 `(1, X2-Z2)`。敝 API 得負責避免上述情況發生、
  /// 以維持使用者對手動覆寫（override）之預期行為。
  ///
  /// 回補策略：
  /// 1) 先判斷該刪除是否會導致游標切斷目前覆寫的節點。若是，則產生 KeyDropContext 上下文。
  /// 2) 若產生上下文成功，則先執行 `assembler.dropKey(direction:)`，再依序嘗試：
  ///    a. `reapplyCombined`：以整節新鍵陣列做整體覆寫，若成功則早早返回 true。
  ///    b. `reapplyPerKey`：若整節覆寫失敗，則對剩下每個子鍵做單鍵覆寫，嘗試維持使用者之覆寫意圖。
  ///
  /// 其他注意事項：
  /// - 當上下文無法建立時（例如該節點非手動覆寫、節點長度與讀音不對齊、或游標並非
  ///   位於切斷節點的情況），會回退至直接呼叫 `assembler.dropKey` 的行為。
  @discardableResult
  func dropKey(direction: Assembler.TypingDirection) -> Bool {
    // 先嘗試生成手動覆寫的上下文（如果是從選字窗手動覆寫而來），
    // 若無上下文，直接讓 Megrez 處理 dropKey。
    let context = KeyDropContext.getManualOverrideKeyDropContext(
      for: direction,
      from: self
    )
    guard let context else {
      guard assembler.dropKey(direction: direction) else { return false }
      return true
    }
    guard assembler.dropKey(direction: direction) else { return false }
    guard !context.remainingKeys.isEmpty else { return true }

    if context.reapplyCombined(to: self) {
      return true
    }
    context.reapplyPerKey(to: self)
    return true
  }

  /// 計算鞏固游標上下文時所需的邊界範圍。
  /// - Parameter candidate: 要拿來覆寫的詞音配對。
  /// - Returns: 需要處理的範圍和調試信息。
  private func calculateConsolidationBoundaries(
    for candidate: Megrez.KeyValuePaired,
    explicitlyChosen: Bool = false
  )
    -> (range: Range<Int>, debugInfo: String) {
    let currentAssembledSentence = assembler.assembledSentence

    // 先計算實驗性邊界（如果候選字詞可以被覆蓋的話）
    var frontBoundaryEX = actualNodeCursorPosition + 1
    var rearBoundaryEX = actualNodeCursorPosition
    var debugIntelToPrint = ""

    let gridOverrideStatusMirror = assembler.createNodeOverrideStatusMirror()
    let (currentCursor, currentMarker) = (assembler.cursor, assembler.marker)

    defer {
      assembler.restoreFromNodeOverrideStatusMirror(gridOverrideStatusMirror)
      assembler.assembledSentence = currentAssembledSentence
      assembler.cursor = currentCursor
      assembler.marker = currentMarker
    }

    if assembler.overrideCandidate(
      candidate,
      at: actualNodeCursorPosition,
      isExplicitlyOverridden: false
    ) {
      assembler.assemble()
      let range = assembler.assembledSentence.contextRange(ofGivenCursor: actualNodeCursorPosition)
      rearBoundaryEX = range.lowerBound
      frontBoundaryEX = range.upperBound
      debugIntelToPrint.append("EX: \(rearBoundaryEX)..<\(frontBoundaryEX), ")
    }

    // 獲取初始範圍
    let initialRange = currentAssembledSentence.contextRange(
      ofGivenCursor: actualNodeCursorPosition
    )
    var rearBoundary = min(initialRange.lowerBound, rearBoundaryEX)
    var frontBoundary = max(initialRange.upperBound, frontBoundaryEX)

    debugIntelToPrint.append("INI: \(rearBoundary)..<\(frontBoundary), ")

    // 通過游標移動來精確計算邊界
    let cursorBackup = assembler.cursor
    defer { assembler.cursor = cursorBackup }

    // 計算後邊界
    while assembler.cursor > rearBoundary {
      assembler.jumpCursorBySegment(to: .rear)
    }
    rearBoundary = min(assembler.cursor, rearBoundary)

    // 重置游標位置
    assembler.cursor = cursorBackup

    // 計算前邊界
    while assembler.cursor < frontBoundary {
      assembler.jumpCursorBySegment(to: .front)
    }
    frontBoundary = min(max(assembler.cursor, frontBoundary), assembler.length)

    debugIntelToPrint.append("FIN: \(rearBoundary)..<\(frontBoundary)")

    return (range: rearBoundary ..< frontBoundary, debugInfo: debugIntelToPrint)
  }

  private func overrideNodeAsWhole(
    _ node: Megrez.GramInPath,
    at startPosition: Int,
    explicitlyChosen: Bool = false
  )
    -> Bool {
    let candidate = node.asCandidatePair
    if assembler.overrideCandidate(candidate, at: startPosition, isExplicitlyOverridden: explicitlyChosen) {
      return true
    }
    if assembler.overrideCandidate(
      candidate,
      at: startPosition,
      overrideType: .withSpecified,
      isExplicitlyOverridden: explicitlyChosen,
      enforceRetokenization: true
    ) {
      return true
    }
    vCLog("Consolidation fallback to per-key override for node: \(candidate.value)")
    return false
  }

  private func makeCanonicalPair(from pair: Megrez.KeyValuePaired) -> Megrez.KeyValuePaired {
    makeCanonicalPair(keyArray: pair.keyArray, value: pair.value)
  }

  private func makeCanonicalPair(keyArray: [String], value: String) -> Megrez.KeyValuePaired {
    Megrez.KeyValuePaired(keyArray: keyArray, value: value, score: 0)
  }
}

// MARK: - Components for Popup Composition Buffer (PCB) Window.

/// 組字區文字上限。
/// - Remark: 該選項僅對不支援 IMKTextInput 協定的應用有用，就不交給 PrefMgr 了。
private let compositorWidthLimit = 20

extension InputHandlerProtocol {
  /// 在爬取組字結果之前，先將即將從組字區溢出的內容遞交出去。
  ///
  /// 在理想狀況之下，組字區多長都無所謂。但是，螢幕浮動組字窗的尺寸是有限的。
  /// 於是，有必要限定組字區的長度。超過該長度的內容會在組句之前先遞交出去，
  /// 使其不再記入最大相似度估算的估算對象範圍。
  /// 用比較形象且生動卻有點噁心的解釋的話，蒼蠅一邊吃一邊屙。
  var commitOverflownComposition: String {
    guard !assembler.assembledSentence.isEmpty,
          assembler.length > compositorWidthLimit,
          let session = session,
          session.clientMitigationLevel >= 2
    else { return "" }
    // 回頭在這裡插上對 Steam 的 Client Identifier 的要求。
    var textToCommit = ""
    while assembler.length > compositorWidthLimit {
      var delta = assembler.length - compositorWidthLimit
      let node = assembler.assembledSentence[0]
      if node.isReadingMismatched {
        delta = node.keyArray.count
        textToCommit += node.asCandidatePair.value
      } else {
        delta = min(delta, node.keyArray.count)
        textToCommit += node.asCandidatePair.value.map(\.description)[0 ..< delta].joined()
      }
      let newCursor = max(assembler.cursor - delta, 0)
      assembler.cursor = 0
      if !node.isReadingMismatched { consolidateCursorContext(with: node.asCandidatePair) }
      // 唯音不支援 Bigram，所以無須考慮前後節點「是否需要鞏固」。
      for _ in 0 ..< delta { assembler.dropKey(direction: .front) }
      assembler.cursor = newCursor
      assemble()
    }
    return textToCommit
  }
}
