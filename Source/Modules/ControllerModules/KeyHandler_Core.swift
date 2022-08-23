// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃按鍵調度模組的核心部分，主要承接型別初期化內容、協定內容、以及
/// 被封裝的「與 Megrez 組字引擎和 Tekkon 注拼引擎對接的」各種工具函式。
/// 注意：不要把 composer 注拼槽與 compositor 組字器這兩個概念搞混。

import Foundation

// MARK: - 委任協定 (Delegate).

/// KeyHandler 委任協定
protocol KeyHandlerDelegate {
  var clientBundleIdentifier: String { get }
  func ctlCandidate() -> ctlCandidateProtocol
  func keyHandler(
    _: KeyHandler, didSelectCandidateAt index: Int,
    ctlCandidate controller: ctlCandidateProtocol
  )
  func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputStateProtocol, addToFilter: Bool)
    -> Bool
}

// MARK: - 核心 (Kernel).

/// KeyHandler 按鍵調度模組。
public class KeyHandler {
  /// 半衰模組的衰減指數
  let kEpsilon: Double = 0.000001
  /// 檢測是否出現游標切斷組字圈內字符的情況
  var isCursorCuttingChar = false
  /// 檢測是否內容為空（注拼槽與組字器都是空的）
  var isTypingContentEmpty: Bool { composer.isEmpty && compositor.isEmpty }

  var composer: Tekkon.Composer = .init()  // 注拼槽
  var compositor: Megrez.Compositor  // 組字器
  var currentLM: vChewing.LMInstantiator = .init()  // 當前主語言模組
  var currentUOM: vChewing.LMUserOverride = .init()  // 當前半衰記憶模組
  /// 委任物件 (ctlInputMethod)，以便呼叫其中的函式。
  var delegate: KeyHandlerDelegate?

  /// InputMode 需要在每次出現內容變更的時候都連帶重設組字器與各項語言模組，
  /// 順帶更新 IME 模組及 UserPrefs 當中對於當前語言模式的記載。
  var inputMode: InputMode = IME.currentInputMode {
    willSet {
      // 這個標籤在下文會用到。
      let isCHS: Bool = (newValue == InputMode.imeModeCHS)
      /// 將新的簡繁輸入模式提報給 Prefs 與 IME 模組。
      IME.currentInputMode = newValue
      mgrPrefs.mostRecentInputMode = IME.currentInputMode.rawValue
      /// 重設所有語言模組。這裡不需要做按需重設，因為對運算量沒有影響。
      currentLM = isCHS ? mgrLangModel.lmCHS : mgrLangModel.lmCHT
      currentUOM = isCHS ? mgrLangModel.uomCHS : mgrLangModel.uomCHT
      /// 將與主語言模組有關的選項同步至主語言模組內。
      syncBaseLMPrefs()
      /// 重建新的組字器，且清空注拼槽＋同步最新的注拼槽排列設定。
      /// 組字器只能藉由重建才可以與當前新指派的語言模組對接。
      ensureCompositor()
      ensureParser()
    }
  }

  /// 初期化。
  public init() {
    /// 組字器初期化。因為是首次初期化變數，所以這裡不能用 ensureCompositor() 代勞。
    compositor = Megrez.Compositor(with: currentLM, separator: "-")
    /// 注拼槽初期化。
    ensureParser()
    /// 讀取最近的簡繁體模式、且將該屬性內容塞到 inputMode 當中。
    /// 這句必須用 defer 來處理，否則不會觸發其 willSet 部分的內容。
    defer { inputMode = IME.currentInputMode }
  }

  func clear() {
    composer.clear()
    compositor.clear()
  }

  // MARK: - Functions dealing with Megrez.

  /// 實際上要拿給 Megrez 使用的的滑鼠游標位址，以方便在組字器最開頭或者最末尾的時候始終能抓取候選字節點陣列。
  ///
  /// 威注音對游標前置與游標後置模式採取的候選字節點陣列抓取方法是分離的，且不使用 Node Crossing。
  var actualCandidateCursor: Int {
    compositor.cursor
      - ((compositor.cursor == compositor.width || !mgrPrefs.useRearCursorMode) && compositor.cursor > 0 ? 1 : 0)
  }

  /// 利用給定的讀音鏈來試圖爬取最接近的組字結果（最大相似度估算）。
  ///
  /// 該過程讀取的權重資料是經過 Viterbi 演算法計算得到的結果。
  ///
  /// 該函式的爬取順序是從頭到尾。
  func walk() {
    compositor.walk()

    // 在偵錯模式開啟時，將 GraphViz 資料寫入至指定位置。
    if mgrPrefs.isDebugModeEnabled {
      let result = compositor.dumpDOT
      do {
        try result.write(
          toFile: "/private/var/tmp/vChewing-visualization.dot",
          atomically: true, encoding: .utf8
        )
      } catch {
        IME.prtDebugIntel("Failed from writing dumpDOT results.")
      }
    }
  }

  /// 用以組建聯想詞陣列的函式。
  /// - Parameter key: 給定的聯想詞的開頭字。
  /// - Returns: 抓取到的聯想詞陣列。
  /// 不會是 nil，但那些負責接收結果的函式會對空白陣列結果做出正確的處理。
  func buildAssociatePhraseArray(withPair pair: Megrez.KeyValuePaired) -> [(String, String)] {
    var arrResult: [(String, String)] = []
    if currentLM.hasAssociatedPhrasesFor(pair: pair) {
      arrResult = currentLM.associatedPhrasesFor(pair: pair).map { ("", $0) }
    }
    return arrResult
  }

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
  /// 威注音輸入法截至 v1.9.3 SP2 版為止都受到上游的這個 Bug 的影響，且在 v1.9.4 版利用該函式修正了這個缺陷。
  /// 該修正必須搭配至少天權星組字引擎 v2.0.2 版方可生效。算法可能比較囉唆，但至少在常用情形下不會再發生該問題。
  /// - Parameter theCandidate: 要拿來覆寫的詞音配對。
  func consolidateCursorContext(with theCandidate: Megrez.Compositor.Candidate) {
    let grid = compositor
    var frontBoundaryEX = compositor.width - 1
    var rearBoundaryEX = 0
    if grid.overrideCandidate(theCandidate, at: actualCandidateCursor) {
      guard let node = compositor.walkedNodes.findNode(at: actualCandidateCursor, target: &frontBoundaryEX) else {
        return
      }
      rearBoundaryEX = max(0, frontBoundaryEX - node.keyArray.count)
    }

    var frontBoundary = 0
    guard let node = compositor.walkedNodes.findNode(at: actualCandidateCursor, target: &frontBoundary) else { return }

    var rearBoundary = min(max(0, frontBoundary - node.keyArray.count), rearBoundaryEX)  // 防呆
    frontBoundary = max(min(frontBoundary, compositor.width), frontBoundaryEX)  // 防呆。

    let cursorBackup = compositor.cursor
    while compositor.cursor > rearBoundary { compositor.jumpCursorBySpan(to: .rear) }
    rearBoundary = min(compositor.cursor, rearBoundary)
    compositor.cursor = cursorBackup  // 游標歸位，再接著計算。
    while compositor.cursor < frontBoundary { compositor.jumpCursorBySpan(to: .front) }
    frontBoundary = max(compositor.cursor, frontBoundary)
    compositor.cursor = cursorBackup  // 計算結束，游標歸位。

    // 接下來獲取這個範圍內的媽的都不知道該怎麼講了。
    var nodeIndices = [Int]()  // 僅作統計用。

    var position = rearBoundary  // 臨時統計用
    while position < frontBoundary {
      guard let regionIndex = compositor.cursorRegionMap[position] else {
        position += 1
        continue
      }
      if !nodeIndices.contains(regionIndex) {
        nodeIndices.append(regionIndex)  // 新增統計
        guard compositor.walkedNodes.count > regionIndex else { break }  // 防呆
        let currentNode = compositor.walkedNodes[regionIndex]
        guard currentNode.keyArray.count == currentNode.value.count else {
          compositor.overrideCandidate(currentNode.currentPair, at: position)
          position += currentNode.keyArray.count
          continue
        }
        let values = currentNode.currentPair.value.charComponents
        for (subPosition, key) in currentNode.keyArray.enumerated() {
          guard values.count > subPosition else { break }  // 防呆，應該沒有發生的可能性
          let thePair = Megrez.Compositor.Candidate(
            key: key, value: values[subPosition]
          )
          compositor.overrideCandidate(thePair, at: position)
          position += 1
        }
        continue
      }
      position += 1
    }
  }

  /// 在組字器內，以給定之候選字（詞音配對）、來試圖在給定游標位置所在之處指定選字處理過程。
  /// 然後再將對應的節錨內的節點標記為「已經手動選字過」。我們稱之為「固化節點」。
  /// - Parameters:
  ///   - value: 給定之候選字（詞音配對）。
  ///   - respectCursorPushing: 若該選項為 true，則會在選字之後始終將游標推送至選字後的節錨的前方。
  ///   - consolidate: 在固化節點之前，先鞏固上下文。該選項可能會破壞在內文組字區內就地輪替候選字詞時的體驗。
  func fixNode(candidate: (String, String), respectCursorPushing: Bool = true, preConsolidate: Bool = false) {
    let theCandidate: Megrez.Compositor.Candidate = .init(key: candidate.0, value: candidate.1)

    /// 必須先鞏固當前組字器游標上下文、以消滅意料之外的影響，但在內文組字區內就地輪替候選字詞時除外。
    if preConsolidate {
      consolidateCursorContext(with: theCandidate)
    }

    // 回到正常流程。

    if !compositor.overrideCandidate(theCandidate, at: actualCandidateCursor) { return }
    let previousWalk = compositor.walkedNodes
    // 開始爬軌。
    walk()
    let currentWalk = compositor.walkedNodes

    // 在可行的情況下更新使用者半衰記憶模組。
    var accumulatedCursor = 0
    let currentNode = currentWalk.findNode(at: actualCandidateCursor, target: &accumulatedCursor)
    guard let currentNode = currentNode else { return }

    if currentNode.currentUnigram.score > -12, mgrPrefs.fetchSuggestionsFromUserOverrideModel {
      IME.prtDebugIntel("UOM: Start Observation.")
      // 這個過程可能會因為使用者半衰記憶模組內部資料錯亂、而導致輸入法在選字時崩潰。
      // 於是在這裡引入災後狀況察覺專用變數，且先開啟該開關。順利執行完觀察後會關閉。
      // 一旦輸入法崩潰，會在重啟時發現這個開關是開著的，屆時 AppDelegate 會做出應對。
      mgrPrefs.failureFlagForUOMObservation = true
      // 令半衰記憶模組觀測給定的三元圖。
      // 這個過程會讓半衰引擎根據當前上下文生成三元圖索引鍵。
      currentUOM.performObservation(
        walkedBefore: previousWalk, walkedAfter: currentWalk, cursor: actualCandidateCursor,
        timestamp: Date().timeIntervalSince1970, saveCallback: { mgrLangModel.saveUserOverrideModelData() }
      )
      // 如果沒有出現崩框的話，那就將這個開關復位。
      mgrPrefs.failureFlagForUOMObservation = false
    }

    /// 若偏好設定內啟用了相關選項，則會在選字之後始終將游標推送至選字後的節錨的前方。
    if mgrPrefs.moveCursorAfterSelectingCandidate, respectCursorPushing {
      // compositor.cursor = accumulatedCursor
      compositor.jumpCursorBySpan(to: .front)
    }
  }

  /// 獲取候選字詞（包含讀音）陣列資料內容。
  func getCandidatesArray(fixOrder: Bool = true) -> [(String, String)] {
    /// 警告：不要對游標前置風格使用 nodesCrossing，否則會導致游標行為與 macOS 內建注音輸入法不一致。
    /// 微軟新注音輸入法的游標後置風格也是不允許 nodeCrossing 的。
    var arrCandidates: [Megrez.Compositor.Candidate] = {
      switch mgrPrefs.useRearCursorMode {
        case false:
          return compositor.fetchCandidates(at: actualCandidateCursor, filter: .endAt)
        case true:
          return compositor.fetchCandidates(at: actualCandidateCursor, filter: .beginAt)
      }
    }()

    /// 原理：nodes 這個回饋結果包含一堆子陣列，分別對應不同詞長的候選字。
    /// 這裡先對陣列排序、讓最長候選字的子陣列的優先權最高。
    /// 這個過程不會傷到子陣列內部的排序。
    if arrCandidates.isEmpty { return .init() }

    // 決定是否根據半衰記憶模組的建議來調整候選字詞的順序。
    if !mgrPrefs.fetchSuggestionsFromUserOverrideModel || mgrPrefs.useSCPCTypingMode || fixOrder {
      return arrCandidates.map { ($0.key, $0.value) }
    }

    let arrSuggestedUnigrams: [(String, Megrez.Unigram)] = fetchSuggestionsFromUOM(apply: false)
    let arrSuggestedCandidates: [Megrez.Compositor.Candidate] = arrSuggestedUnigrams.map {
      Megrez.Compositor.Candidate(key: $0.0, value: $0.1.value)
    }
    arrCandidates = arrSuggestedCandidates.filter { arrCandidates.contains($0) } + arrCandidates
    arrCandidates = arrCandidates.deduplicate
    arrCandidates = arrCandidates.stableSort { $0.key.split(separator: "-").count > $1.key.split(separator: "-").count }
    return arrCandidates.map { ($0.key, $0.value) }
  }

  /// 向半衰引擎詢問可能的選字建議、且套用給組字器內的當前游標位置。
  @discardableResult func fetchSuggestionsFromUOM(apply: Bool) -> [(String, Megrez.Unigram)] {
    var arrResult = [(String, Megrez.Unigram)]()
    /// 如果逐字選字模式有啟用的話，直接放棄執行這個函式。
    if mgrPrefs.useSCPCTypingMode { return arrResult }
    /// 如果這個開關沒打開的話，直接放棄執行這個函式。
    if !mgrPrefs.fetchSuggestionsFromUserOverrideModel { return arrResult }
    /// 獲取來自半衰記憶模組的建議結果
    let suggestion = currentUOM.fetchSuggestion(
      currentWalk: compositor.walkedNodes, cursor: actualCandidateCursor, timestamp: Date().timeIntervalSince1970
    )
    arrResult.append(contentsOf: suggestion.candidates)
    if apply {
      /// 再看有沒有選字建議。有的話就遵循之、讓天權星引擎對指定節錨下的節點複寫權重。
      if !suggestion.isEmpty, let newestSuggestedCandidate = suggestion.candidates.last {
        let overrideBehavior: Megrez.Compositor.Node.OverrideType =
          suggestion.forceHighScoreOverride ? .withHighScore : .withTopUnigramScore
        let suggestedPair: Megrez.Compositor.Candidate = .init(
          key: newestSuggestedCandidate.0, value: newestSuggestedCandidate.1.value
        )
        IME.prtDebugIntel(
          "UOM: Suggestion retrieved, overriding the node score of the selected candidate: \(suggestedPair.toNGramKey)")
        if !compositor.overrideCandidate(suggestedPair, at: actualCandidateCursor, overrideType: overrideBehavior) {
          compositor.overrideCandidateLiteral(
            newestSuggestedCandidate.1.value, at: actualCandidateCursor, overrideType: overrideBehavior
          )
        }
        walk()
      }
    }
    arrResult = arrResult.stableSort { $0.1.score > $1.1.score }
    return arrResult
  }

  // MARK: - Extracted methods and functions (Tekkon).

  /// 獲取與當前注音排列或拼音輸入種類有關的標點索引鍵，以英數下畫線「_」結尾。
  var currentMandarinParser: String {
    mgrPrefs.mandarinParserName + "_"
  }

  /// 給注拼槽指定注音排列或拼音輸入種類之後，將注拼槽內容清空。
  func ensureParser() {
    switch mgrPrefs.mandarinParser {
      case MandarinParser.ofStandard.rawValue:
        composer.ensureParser(arrange: .ofDachen)
      case MandarinParser.ofDachen26.rawValue:
        composer.ensureParser(arrange: .ofDachen26)
      case MandarinParser.ofETen.rawValue:
        composer.ensureParser(arrange: .ofETen)
      case MandarinParser.ofHsu.rawValue:
        composer.ensureParser(arrange: .ofHsu)
      case MandarinParser.ofETen26.rawValue:
        composer.ensureParser(arrange: .ofETen26)
      case MandarinParser.ofIBM.rawValue:
        composer.ensureParser(arrange: .ofIBM)
      case MandarinParser.ofMiTAC.rawValue:
        composer.ensureParser(arrange: .ofMiTAC)
      case MandarinParser.ofFakeSeigyou.rawValue:
        composer.ensureParser(arrange: .ofFakeSeigyou)
      case MandarinParser.ofSeigyou.rawValue:
        composer.ensureParser(arrange: .ofSeigyou)
      case MandarinParser.ofStarlight.rawValue:
        composer.ensureParser(arrange: .ofStarlight)
      case MandarinParser.ofHanyuPinyin.rawValue:
        composer.ensureParser(arrange: .ofHanyuPinyin)
      case MandarinParser.ofSecondaryPinyin.rawValue:
        composer.ensureParser(arrange: .ofSecondaryPinyin)
      case MandarinParser.ofYalePinyin.rawValue:
        composer.ensureParser(arrange: .ofYalePinyin)
      case MandarinParser.ofHualuoPinyin.rawValue:
        composer.ensureParser(arrange: .ofHualuoPinyin)
      case MandarinParser.ofUniversalPinyin.rawValue:
        composer.ensureParser(arrange: .ofUniversalPinyin)
      default:
        composer.ensureParser(arrange: .ofDachen)
        mgrPrefs.mandarinParser = MandarinParser.ofStandard.rawValue
    }
    composer.clear()
    composer.phonabetCombinationCorrectionEnabled = mgrPrefs.autoCorrectReadingCombination
  }

  /// 返回前一個游標位置的可解析的漢字讀音。
  /// 返回的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
  var previousParsableReading: (String, String, Bool)? {
    if compositor.cursor == 0 { return nil }
    let cursorPrevious = max(compositor.cursor - 1, 0)
    let rawData = compositor.keys[cursorPrevious]
    let components = rawData.charComponents
    var hasIntonation = false
    for neta in components {
      if !Tekkon.allowedPhonabets.contains(neta) || neta == " " { return nil }
      if Tekkon.allowedIntonations.contains(neta) { hasIntonation = true }
    }
    if hasIntonation, components.count == 1 { return nil }  // 剔除純聲調之情形
    let rawDataSansIntonation = hasIntonation ? components.dropLast(1).joined() : rawData
    return (rawData, rawDataSansIntonation, hasIntonation)
  }

  /// 檢測某個傳入的按鍵訊號是否為聲調鍵。
  /// - Parameter input: 傳入的按鍵訊號。
  /// - Returns: 判斷結果：是否為聲調鍵。
  func isIntonationKey(_ input: InputSignal) -> Bool {
    var theComposer = composer  // 複製一份用來做實驗。
    theComposer.clear()  // 清空各種槽的內容。
    theComposer.receiveKey(fromCharCode: input.charCode)
    return theComposer.hasToneMarker(withNothingElse: true)
  }

  // MARK: - Extracted methods and functions (Megrez).

  /// 將輸入法偏好設定同步至語言模組內。
  func syncBaseLMPrefs() {
    currentLM.isPhraseReplacementEnabled = mgrPrefs.phraseReplacementEnabled
    currentLM.isCNSEnabled = mgrPrefs.cns11643Enabled
    currentLM.isSymbolEnabled = mgrPrefs.symbolInputEnabled
  }

  /// 令組字器重新初期化，使其與被重新指派過的主語言模組對接。
  func ensureCompositor() {
    // 每個漢字讀音都由一個西文半形減號分隔開。
    compositor = Megrez.Compositor(with: currentLM, separator: "-")
  }

  /// 生成標點符號索引鍵。
  /// - Parameter input: 輸入的按鍵訊號。
  /// - Returns: 生成的標點符號索引鍵。
  func generatePunctuationNamePrefix(withKeyCondition input: InputSignal) -> String {
    if mgrPrefs.halfWidthPunctuationEnabled {
      return "_half_punctuation_"
    }
    switch (input.isControlHold, input.isOptionHold) {
      case (true, true): return "_alt_ctrl_punctuation_"
      case (true, false): return "_ctrl_punctuation_"
      case (false, true): return "_alt_punctuation_"
      case (false, false): return "_punctuation_"
    }
  }
}
