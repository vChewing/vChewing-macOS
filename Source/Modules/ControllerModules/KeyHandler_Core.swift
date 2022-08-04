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

import Cocoa

// MARK: - 委任協定 (Delegate).

/// KeyHandler 委任協定
protocol KeyHandlerDelegate {
  func ctlCandidate() -> ctlCandidateProtocol
  func keyHandler(
    _: KeyHandler, didSelectCandidateAt index: Int,
    ctlCandidate controller: ctlCandidateProtocol
  )
  func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputStateProtocol)
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

  /// 規定最大動態爬軌範圍。組字器內超出該範圍的節錨都會被自動標記為「已經手動選字過」，減少爬軌運算負擔。
  let kMaxComposingBufferNeedsToWalkSize = Int(max(12, ceil(Double(mgrPrefs.composingBufferSize) / 2)))
  var composer: Tekkon.Composer = .init()  // 注拼槽
  var compositor: Megrez.Compositor  // 組字器
  var currentLM: vChewing.LMInstantiator = .init()  // 當前主語言模組
  var currentUOM: vChewing.LMUserOverride = .init()  // 當前半衰記憶模組
  var walkedAnchors: [Megrez.NodeAnchor] { compositor.walkedAnchors }  // 用以記錄爬過的節錨的陣列
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
    compositor = Megrez.Compositor(lm: currentLM, separator: "-")
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
    mgrPrefs.useRearCursorMode ? min(compositor.cursor, compositor.length - 1) : max(compositor.cursor, 1)
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

  /// 在爬取組字結果之前，先將即將從組字區溢出的內容遞交出去。
  ///
  /// 在理想狀況之下，組字區多長都無所謂。但是，Viterbi 演算法使用 O(N^2)，
  /// 會使得運算壓力隨著節錨數量的增加而增大。於是，有必要限定組字區的長度。
  /// 超過該長度的內容會在爬軌之前先遞交出去，使其不再記入最大相似度估算的
  /// 估算對象範圍。用比較形象且生動卻有點噁心的解釋的話，蒼蠅一邊吃一邊屙。
  var commitOverflownCompositionAndWalk: String {
    var textToCommit = ""
    if compositor.width > mgrPrefs.composingBufferSize, !walkedAnchors.isEmpty {
      let anchor: Megrez.NodeAnchor = walkedAnchors[0]
      textToCommit = anchor.node.currentPair.value
      compositor.removeHeadReadings(count: anchor.spanLength)
    }
    walk()
    return textToCommit
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

  /// 在組字器內，以給定之候選字字串、來試圖在給定游標位置所在之處指定選字處理過程。
  /// 然後再將對應的節錨內的節點標記為「已經手動選字過」。
  /// - Parameters:
  ///   - value: 給定之候選字字串。
  ///   - respectCursorPushing: 若該選項為 true，則會在選字之後始終將游標推送至選字後的節錨的前方。
  func fixNode(candidate: (String, String), respectCursorPushing: Bool = true) {
    let theCandidate: Megrez.KeyValuePaired = .init(key: candidate.0, value: candidate.1)
    let adjustedCursor = max(0, min(actualCandidateCursor + (mgrPrefs.useRearCursorMode ? 1 : 0), compositor.length))
    // 開始讓半衰模組觀察目前的狀況。
    let selectedNode: Megrez.NodeAnchor = compositor.fixNodeWithCandidate(theCandidate, at: adjustedCursor)
    // 不要針對逐字選字模式啟用臨時半衰記憶模型。
    if !mgrPrefs.useSCPCTypingMode {
      var addToUserOverrideModel = true
      // 所有讀音數與字符數不匹配的情況均不得塞入半衰記憶模組。
      if selectedNode.spanLength != theCandidate.value.count {
        IME.prtDebugIntel("UOM: SpanningLength != value.count, dismissing.")
        addToUserOverrideModel = false
      }
      if addToUserOverrideModel {
        // 威注音的 SymbolLM 的 Score 是 -12，符合該條件的內容不得塞入半衰記憶模組。
        if selectedNode.node.scoreForPaired(candidate: theCandidate) <= -12 {
          IME.prtDebugIntel("UOM: Score <= -12, dismissing.")
          addToUserOverrideModel = false
        }
      }
      if addToUserOverrideModel, mgrPrefs.fetchSuggestionsFromUserOverrideModel {
        IME.prtDebugIntel("UOM: Start Observation.")
        // 這個過程可能會因為使用者半衰記憶模組內部資料錯亂、而導致輸入法在選字時崩潰。
        // 於是在這裡引入災後狀況察覺專用變數，且先開啟該開關。順利執行完觀察後會關閉。
        // 一旦輸入法崩潰，會在重啟時發現這個開關是開著的，屆時 AppDelegate 會做出應對。
        mgrPrefs.failureFlagForUOMObservation = true
        // 令半衰記憶模組觀測給定的三元圖。
        // 這個過程會讓半衰引擎根據當前上下文生成三元圖索引鍵。
        currentUOM.observe(
          walkedAnchors: walkedAnchors, cursorIndex: adjustedCursor, candidate: theCandidate.value,
          timestamp: NSDate().timeIntervalSince1970, saveCallback: { mgrLangModel.saveUserOverrideModelData() }
        )
        // 如果沒有出現崩框的話，那就將這個開關復位。
        mgrPrefs.failureFlagForUOMObservation = false
      }
    }

    // 開始爬軌。
    walk()

    /// 若偏好設定內啟用了相關選項，則會在選字之後始終將游標推送至選字後的節錨的前方。
    if mgrPrefs.moveCursorAfterSelectingCandidate, respectCursorPushing {
      compositor.jumpCursorBySpan(to: .front)
    }
  }

  /// 組字器內超出最大動態爬軌範圍的節錨都會被自動標記為「已經手動選字過」，減少爬軌運算負擔。
  func markNodesFixedIfNecessary() {
    let width = compositor.width
    if width <= kMaxComposingBufferNeedsToWalkSize {
      return
    }
    var index = 0
    for anchor in walkedAnchors {
      if index >= width - kMaxComposingBufferNeedsToWalkSize { break }
      if anchor.node.score < Megrez.Node.kSelectedCandidateScore {
        compositor.fixNodeWithCandidate(anchor.node.currentPair, at: index + anchor.spanLength)
      }
      index += anchor.spanLength
    }
  }

  /// 獲取候選字詞（包含讀音）陣列資料內容。
  func getCandidatesArray(fixOrder: Bool = true) -> [(String, String)] {
    var arrAnchors: [Megrez.NodeAnchor] = rawAnchorsOfNodes
    var arrCandidates: [Megrez.KeyValuePaired] = .init()

    /// 原理：nodes 這個回饋結果包含一堆子陣列，分別對應不同詞長的候選字。
    /// 這裡先對陣列排序、讓最長候選字的子陣列的優先權最高。
    /// 這個過程不會傷到子陣列內部的排序。
    if arrAnchors.isEmpty { return .init() }

    // 讓更長的節錨排序靠前。
    arrAnchors = arrAnchors.stableSort { $0.spanLength > $1.spanLength }

    // 將節錨內的候選字詞資料拓印到輸出陣列內。
    for currentCandidate in arrAnchors.map(\.node.candidates).joined() {
      // 選字窗的內容的康熙轉換 / JIS 轉換不能放在這裡處理，會影響選字有效性。
      // 選字的原理是拿著具體的候選字詞的字串去當前的節錨下找出對應的候選字詞（Ｘ元圖）。
      // 一旦在這裡轉換了，節錨內的某些元圖就無法被選中。
      arrCandidates.append(currentCandidate)
    }
    // 決定是否根據半衰記憶模組的建議來調整候選字詞的順序。
    if !mgrPrefs.fetchSuggestionsFromUserOverrideModel || mgrPrefs.useSCPCTypingMode || fixOrder {
      return arrCandidates.map { ($0.key, $0.value) }
    }

    let arrSuggestedUnigrams: [Megrez.Unigram] = fetchSuggestedCandidates().stableSort { $0.score > $1.score }
    let arrSuggestedCandidates: [Megrez.KeyValuePaired] = arrSuggestedUnigrams.map(\.keyValue)
    arrCandidates = arrSuggestedCandidates.filter { arrCandidates.contains($0) } + arrCandidates
    arrCandidates = arrCandidates.deduplicate
    arrCandidates = arrCandidates.stableSort { $0.key.split(separator: "-").count > $1.key.split(separator: "-").count }
    return arrCandidates.map { ($0.key, $0.value) }
  }

  /// 向半衰引擎詢問可能的選字建議。拿到的結果會是一個單元圖陣列。
  func fetchSuggestedCandidates() -> [Megrez.Unigram] {
    currentUOM.suggest(
      walkedAnchors: walkedAnchors, cursorIndex: compositor.cursor,
      timestamp: NSDate().timeIntervalSince1970
    )
  }

  /// 向半衰引擎詢問可能的選字建議、且套用給組字器內的當前游標位置。
  func fetchAndApplySuggestionsFromUserOverrideModel() {
    /// 如果逐字選字模式有啟用的話，直接放棄執行這個函式。
    if mgrPrefs.useSCPCTypingMode { return }
    /// 如果這個開關沒打開的話，直接放棄執行這個函式。
    if !mgrPrefs.fetchSuggestionsFromUserOverrideModel { return }
    /// 先就當前上下文讓半衰引擎重新生成三元圖索引鍵。
    let overrideValue = fetchSuggestedCandidates().first?.keyValue.value ?? ""

    /// 再拿著索引鍵去問半衰模組有沒有選字建議。有的話就遵循之、讓天權星引擎對指定節錨下的節點複寫權重。
    if !overrideValue.isEmpty {
      IME.prtDebugIntel(
        "UOM: Suggestion retrieved, overriding the node score of the selected candidate.")
      compositor.overrideNodeScoreForSelectedCandidate(
        location: min(actualCandidateCursor + (mgrPrefs.useRearCursorMode ? 1 : 0), compositor.length),
        value: overrideValue,
        overridingScore: findHighestScore(nodeAnchors: rawAnchorsOfNodes, epsilon: kEpsilon)
      )
    } else {
      IME.prtDebugIntel("UOM: Blank suggestion retrieved, dismissing.")
    }
  }

  /// 就給定的節錨陣列，根據半衰模組的衰減指數，來找出最高權重數值。
  /// - Parameters:
  ///   - nodes: 給定的節錨陣列。
  ///   - epsilon: 半衰模組的衰減指數。
  /// - Returns: 尋獲的最高權重數值。
  func findHighestScore(nodeAnchors: [Megrez.NodeAnchor], epsilon: Double) -> Double {
    nodeAnchors.map(\.node.highestUnigramScore).max() ?? 0 + epsilon
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

  // MARK: - Extracted methods and functions (Megrez).

  /// 獲取原始節錨資料陣列。
  var rawAnchorsOfNodes: [Megrez.NodeAnchor] {
    /// 警告：不要對游標前置風格使用 nodesCrossing，否則會導致游標行為與 macOS 內建注音輸入法不一致。
    /// 微軟新注音輸入法的游標後置風格也是不允許 nodeCrossing 的。
    mgrPrefs.useRearCursorMode
      ? compositor.nodesBeginningAt(location: actualCandidateCursor)
      : compositor.nodesEndingAt(location: actualCandidateCursor)
  }

  /// 將輸入法偏好設定同步至語言模組內。
  func syncBaseLMPrefs() {
    currentLM.isPhraseReplacementEnabled = mgrPrefs.phraseReplacementEnabled
    currentLM.isCNSEnabled = mgrPrefs.cns11643Enabled
    currentLM.isSymbolEnabled = mgrPrefs.symbolInputEnabled
  }

  /// 令組字器重新初期化，使其與被重新指派過的主語言模組對接。
  func ensureCompositor() {
    // 每個漢字讀音都由一個西文半形減號分隔開。
    compositor = Megrez.Compositor(lm: currentLM, separator: "-")
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
