// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/// 該檔案乃按鍵調度模組的核心部分，主要承接型別初期化內容、協定內容、以及
/// 被封裝的「與 Megrez 組字引擎和 Tekkon 注拼引擎對接的」各種工具函式。
/// 注意：不要把 composer 注拼槽與 compositor 組字器這兩個概念搞混。

import Cocoa

// MARK: - 委任協定 (Delegate).

/// KeyHandler 委任協定
protocol KeyHandlerDelegate {
  func ctlCandidate() -> ctlCandidate
  func keyHandler(
    _: KeyHandler, didSelectCandidateAt index: Int,
    ctlCandidate controller: ctlCandidate
  )
  func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputState)
    -> Bool
}

// MARK: - 核心 (Kernel).

/// KeyHandler 按鍵調度模組。
class KeyHandler {
  /// 半衰模組的衰減指數
  let kEpsilon: Double = 0.000001

  /// 規定最大動態爬軌範圍。組字器內超出該範圍的節錨都會被自動標記為「已經手動選字過」，減少爬軌運算負擔。
  let kMaxComposingBufferNeedsToWalkSize = Int(max(12, ceil(Double(mgrPrefs.composingBufferSize) / 2)))
  var composer: Tekkon.Composer = .init()  // 注拼槽
  var compositor: Megrez.Compositor  // 組字器
  var currentLM: vChewing.LMInstantiator = .init()  // 當前主語言模組
  var currentUOM: vChewing.LMUserOverride = .init()  // 當前半衰記憶模組
  var walkedAnchors: [Megrez.NodeAnchor] = []  // 用以記錄爬過的節錨的陣列
  /// 委任物件 (ctlInputMethod)，以便呼叫其中的函式。
  var delegate: KeyHandlerDelegate?

  /// InputMode 需要在每次出現內容變更的時候都連帶重設組字器與各項語言模組，
  /// 順帶更新 IME 模組及 UserPrefs 當中對於當前語言模式的記載。
  var inputMode: InputMode = IME.currentInputMode {
    willSet {
      // 這個標籤在下文會用到。
      let isCHS: Bool = (newValue == InputMode.imeModeCHS)
      /// 將新的簡繁輸入模式提報給 ctlInputMethod 與 IME 模組。
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
    walkedAnchors.removeAll()
  }

  // MARK: - Functions dealing with Megrez.

  /// 實際上要拿給 Megrez 使用的的滑鼠游標位址，以方便在組字器最開頭或者最末尾的時候始終能抓取候選字節點陣列。
  ///
  /// 威注音對游標前置與游標後置模式採取的候選字節點陣列抓取方法是分離的，且不使用 Node Crossing。
  var actualCandidateCursorIndex: Int {
    mgrPrefs.useRearCursorMode ? min(compositorCursorIndex, compositorLength - 1) : max(compositorCursorIndex, 1)
  }

  /// 利用給定的讀音鏈來試圖爬取最接近的組字結果（最大相似度估算）。
  ///
  /// 該過程讀取的權重資料是經過 Viterbi 演算法計算得到的結果。
  ///
  /// 該函式的爬取順序是從頭到尾。
  func walk() {
    walkedAnchors = compositor.walk()

    // 在偵錯模式開啟時，將 GraphViz 資料寫入至指定位置。
    if mgrPrefs.isDebugModeEnabled {
      let result = compositor.grid.dumpDOT
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
  var popOverflowComposingTextAndWalk: String {
    var textToCommit = ""
    if compositor.grid.width > mgrPrefs.composingBufferSize {
      if !walkedAnchors.isEmpty {
        let anchor: Megrez.NodeAnchor = walkedAnchors[0]
        if let theNode = anchor.node {
          textToCommit = theNode.currentKeyValue.value
        }
        compositor.removeHeadReadings(count: anchor.spanningLength)
      }
    }
    walk()
    return textToCommit
  }

  /// 用以組建聯想詞陣列的函式。
  /// - Parameter key: 給定的聯想詞的開頭字。
  /// - Returns: 抓取到的聯想詞陣列。
  /// 不會是 nil，但那些負責接收結果的函式會對空白陣列結果做出正確的處理。
  func buildAssociatePhraseArray(withKey key: String) -> [String] {
    var arrResult: [String] = []
    if currentLM.hasAssociatedPhrasesFor(key: key) {
      arrResult.append(contentsOf: currentLM.associatedPhrasesFor(key: key))
    }
    return arrResult
  }

  /// 在組字器內，以給定之候選字字串、來試圖在給定游標位置所在之處指定選字處理過程。
  /// 然後再將對應的節錨內的節點標記為「已經手動選字過」。
  /// - Parameters:
  ///   - value: 給定之候選字字串。
  ///   - respectCursorPushing: 若該選項為 true，則會在選字之後始終將游標推送至選字厚的節錨的前方。
  func fixNode(value: String, respectCursorPushing: Bool = true) {
    let cursorIndex = min(actualCandidateCursorIndex + (mgrPrefs.useRearCursorMode ? 1 : 0), compositorLength)
    compositor.grid.fixNodeSelectedCandidate(location: cursorIndex, value: value)
    // 開始讓半衰模組觀察目前的狀況。
    let selectedNode: Megrez.NodeAnchor = compositor.grid.fixNodeSelectedCandidate(
      location: cursorIndex, value: value
    )
    // 不要針對逐字選字模式啟用臨時半衰記憶模型。
    if !mgrPrefs.useSCPCTypingMode {
      // 所有讀音數與字符數不匹配的情況均不得塞入半衰記憶模組。
      var addToUserOverrideModel = true
      if selectedNode.spanningLength != value.count {
        IME.prtDebugIntel("UOM: SpanningLength != value.count, dismissing.")
        addToUserOverrideModel = false
      }
      if addToUserOverrideModel {
        if let theNode = selectedNode.node {
          // 威注音的 SymbolLM 的 Score 是 -12，符合該條件的內容不得塞入半衰記憶模組。
          if theNode.scoreFor(candidate: value) <= -12 {
            IME.prtDebugIntel("UOM: Score <= -12, dismissing.")
            addToUserOverrideModel = false
          }
        }
      }
      if addToUserOverrideModel {
        IME.prtDebugIntel("UOM: Start Observation.")
        // 令半衰記憶模組觀測給定的 trigram。
        // 這個過程會讓半衰引擎根據當前上下文生成 trigram 索引鍵。
        currentUOM.observe(
          walkedAnchors: walkedAnchors, cursorIndex: cursorIndex, candidate: value,
          timestamp: NSDate().timeIntervalSince1970
        )
      }
    }
    walk()

    /// 若偏好設定內啟用了相關選項，則會在選字之後始終將游標推送至選字厚的節錨的前方。
    if mgrPrefs.moveCursorAfterSelectingCandidate, respectCursorPushing {
      var nextPosition = 0
      for node in walkedAnchors {
        if nextPosition >= cursorIndex { break }
        nextPosition += node.spanningLength
      }
      if nextPosition <= compositorLength {
        compositorCursorIndex = nextPosition
      }
    }
  }

  /// 組字器內超出最大動態爬軌範圍的節錨都會被自動標記為「已經手動選字過」，減少爬軌運算負擔。
  func markNodesFixedIfNecessary() {
    let width = compositor.grid.width
    if width <= kMaxComposingBufferNeedsToWalkSize {
      return
    }
    var index = 0
    for anchor in walkedAnchors {
      guard let node = anchor.node else { break }
      if index >= width - kMaxComposingBufferNeedsToWalkSize { break }
      if node.score < node.kSelectedCandidateScore {
        compositor.grid.fixNodeSelectedCandidate(
          location: index + anchor.spanningLength, value: node.currentKeyValue.value
        )
      }
      index += anchor.spanningLength
    }
  }

  /// 獲取候選字詞陣列資料內容。
  var candidatesArray: [String] {
    var arrCandidates: [String] = []
    var arrNodes: [Megrez.NodeAnchor] = []
    arrNodes.append(contentsOf: rawNodes)

    /// 原理：nodes 這個回饋結果包含一堆子陣列，分別對應不同詞長的候選字。
    /// 這裡先對陣列排序、讓最長候選字的子陣列的優先權最高。
    /// 這個過程不會傷到子陣列內部的排序。
    if !arrNodes.isEmpty {
      // sort the nodes, so that longer nodes (representing longer phrases)
      // are placed at the top of the candidate list
      arrNodes.sort { $0.keyLength > $1.keyLength }

      // then use the Swift trick to retrieve the candidates for each node at/crossing the cursor
      for currentNodeAnchor in arrNodes {
        if let currentNode = currentNodeAnchor.node {
          for currentCandidate in currentNode.candidates {
            arrCandidates.append(currentCandidate.value)
          }
        }
      }
    }
    return arrCandidates
  }

  /// 向半衰引擎詢問可能的選字建議。
  func fetchSuggestionsFromUserOverrideModel() {
    /// 如果這個開關沒打開的話，直接放棄執行這個函式。
    if !mgrPrefs.fetchSuggestionsFromUserOverrideModel { return }
    /// 先就當前上下文讓半衰引擎重新生成 trigram 索引鍵。
    let overrideValue =
      mgrPrefs.useSCPCTypingMode
      ? ""
      : currentUOM.suggest(
        walkedAnchors: walkedAnchors, cursorIndex: compositorCursorIndex,
        timestamp: NSDate().timeIntervalSince1970
      )

    /// 再拿著索引鍵去問半衰模組有沒有選字建議。有的話就遵循之、讓天權星引擎對指定節錨下的節點複寫權重。
    if !overrideValue.isEmpty {
      IME.prtDebugIntel(
        "UOM: Suggestion retrieved, overriding the node score of the selected candidate.")
      compositor.grid.overrideNodeScoreForSelectedCandidate(
        location: min(actualCandidateCursorIndex + (mgrPrefs.useRearCursorMode ? 1 : 0), compositorLength),
        value: overrideValue,
        overridingScore: findHighestScore(nodes: rawNodes, epsilon: kEpsilon)
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
  func findHighestScore(nodes: [Megrez.NodeAnchor], epsilon: Double) -> Double {
    var highestScore: Double = 0
    for currentAnchor in nodes {
      if let theNode = currentAnchor.node {
        let score = theNode.highestUnigramScore
        if score > highestScore {
          highestScore = score
        }
      }
    }
    return highestScore + epsilon
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
  }

  /// 用於網頁 Ruby 的注音需要按照教科書印刷的方式來顯示輕聲。該函式負責這種轉換。
  /// - Parameters:
  ///   - target: 要拿來做轉換處理的讀音鏈。
  ///   - newSeparator: 新的讀音分隔符。
  /// - Returns: 經過轉換處理的讀音鏈。
  func cnvZhuyinKeyToTextbookReading(target: String, newSeparator: String = "-") -> String {
    var arrReturn: [String] = []
    for neta in target.split(separator: "-") {
      var newString = String(neta)
      if String(neta.reversed()[0]) == "˙" {
        newString = String(neta.dropLast())
        newString.insert("˙", at: newString.startIndex)
      }
      arrReturn.append(newString)
    }
    return arrReturn.joined(separator: newSeparator)
  }

  /// 用於網頁 Ruby 的拼音的陰平必須顯示，這裡處理一下。
  /// - Parameters:
  ///   - target: 要拿來做轉換處理的讀音鏈。
  ///   - newSeparator: 新的讀音分隔符。
  /// - Returns: 經過轉換處理的讀音鏈。
  func restoreToneOneInZhuyinKey(target: String, newSeparator: String = "-") -> String {
    var arrReturn: [String] = []
    for neta in target.split(separator: "-") {
      var newNeta = String(neta)
      if !"ˊˇˋ˙".contains(String(neta.reversed()[0])), !neta.contains("_") {
        newNeta += "1"
      }
      arrReturn.append(newNeta)
    }
    return arrReturn.joined(separator: newSeparator)
  }

  // MARK: - Extracted methods and functions (Megrez).

  /// 組字器是否為空。
  var isCompositorEmpty: Bool { compositor.isEmpty }

  /// 獲取原始節錨資料陣列。
  var rawNodes: [Megrez.NodeAnchor] {
    /// 警告：不要對游標前置風格使用 nodesCrossing，否則會導致游標行為與 macOS 內建注音輸入法不一致。
    /// 微軟新注音輸入法的游標後置風格也是不允許 nodeCrossing 的。
    mgrPrefs.useRearCursorMode
      ? compositor.grid.nodesBeginningAt(location: actualCandidateCursorIndex)
      : compositor.grid.nodesEndingAt(location: actualCandidateCursorIndex)
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

  /// 自組字器獲取目前的讀音陣列。
  var currentReadings: [String] { compositor.readings }

  /// 以給定的（讀音）索引鍵，來檢測當前主語言模型內是否有對應的資料在庫。
  func ifLangModelHasUnigrams(forKey reading: String) -> Bool {
    currentLM.hasUnigramsFor(key: reading)
  }

  /// 在組字器的給定游標位置內插入讀音。
  func insertToCompositorAtCursor(reading: String) {
    compositor.insertReadingAtCursor(reading: reading)
  }

  /// 組字器的游標位置。
  var compositorCursorIndex: Int {
    get { compositor.cursorIndex }
    set { compositor.cursorIndex = newValue }
  }

  /// 組字器的目前的長度。
  var compositorLength: Int {
    compositor.length
  }

  /// 在組字器內，朝著與文字輸入方向相反的方向、砍掉一個與游標相鄰的讀音。
  ///
  /// 在威注音的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear）。
  func deleteCompositorReadingAtTheRearOfCursor() {
    compositor.deleteReadingAtTheRearOfCursor()
  }

  /// 在組字器內，朝著往文字輸入方向、砍掉一個與游標相鄰的讀音。
  ///
  /// 在威注音的術語體系當中，「文字輸入方向」為向前（Front）。
  func deleteCompositorReadingToTheFrontOfCursor() {
    compositor.deleteReadingToTheFrontOfCursor()
  }
}
