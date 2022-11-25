// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import LangModelAssembly
import Megrez
import Shared
import Tekkon

/// 該檔案乃輸入調度模組的核心部分，主要承接型別初期化內容、協定內容、以及
/// 被封裝的「與 Megrez 組字引擎和 Tekkon 注拼引擎對接的」各種工具函式。
/// 注意：不要把 composer 注拼槽與 compositor 組字器這兩個概念搞混。

// MARK: - InputHandler 自身協定 (Protocol).

public protocol InputHandlerProtocol {
  var currentLM: vChewingLM.LMInstantiator { get set }
  var currentUOM: vChewingLM.LMUserOverride { get set }
  var delegate: InputHandlerDelegate? { get set }
  var composer: Tekkon.Composer { get set }
  var isCompositorEmpty: Bool { get }
  var isComposerUsingPinyin: Bool { get }
  func clear()
  func clearComposerAndCalligrapher()
  func ensureKeyboardParser()
  func handleEvent(_ event: NSEvent) -> Bool
  func generateStateOfInputting() -> IMEStateProtocol
  func generateStateOfAssociates(withPair pair: Megrez.Compositor.KeyValuePaired) -> IMEStateProtocol
  func consolidateNode(candidate: (String, String), respectCursorPushing: Bool, preConsolidate: Bool)
}

// MARK: - 委任協定 (Delegate).

/// InputHandler 委任協定
public protocol InputHandlerDelegate {
  var isVerticalTyping: Bool { get }
  var selectionKeys: String { get }
  var state: IMEStateProtocol { get set }
  var clientBundleIdentifier: String { get }
  func callError(_ logMessage: String)
  func switchState(_ newState: IMEStateProtocol)
  func candidateController() -> CtlCandidateProtocol
  func candidateSelectionCalledByInputHandler(at index: Int)
  func performUserPhraseOperation(addToFilter: Bool)
    -> Bool
}

// MARK: - 核心 (Kernel).

/// InputHandler 輸入調度模組。
public class InputHandler: InputHandlerProtocol {
  /// 委任物件 (SessionCtl)，以便呼叫其中的函式。
  public var delegate: InputHandlerDelegate?
  public var prefs: PrefMgrProtocol

  /// 半衰模組的衰減指數
  let kEpsilon: Double = 0.000_001

  public var calligrapher = ""  // 磁帶專用組筆區
  public var composer: Tekkon.Composer = .init()  // 注拼槽
  public var compositor: Megrez.Compositor  // 組字器
  public var currentUOM: vChewingLM.LMUserOverride
  public var currentLM: vChewingLM.LMInstantiator {
    didSet {
      compositor.langModel = .init(withLM: currentLM)
      clear()
    }
  }

  /// 初期化。
  public init(lm: vChewingLM.LMInstantiator, uom: vChewingLM.LMUserOverride, pref: PrefMgrProtocol) {
    prefs = pref
    currentLM = lm
    currentUOM = uom
    /// 同步組字器單個詞的幅位長度上限。
    Megrez.Compositor.maxSpanLength = prefs.maxCandidateLength
    /// 組字器初期化。因為是首次初期化變數，所以這裡不能用 ensureCompositor() 代勞。
    compositor = Megrez.Compositor(with: currentLM, separator: "-")
    /// 注拼槽初期化。
    ensureKeyboardParser()
  }

  public func clear() {
    clearComposerAndCalligrapher()
    compositor.clear()
  }

  // MARK: - Functions dealing with Megrez.

  public var isCompositorEmpty: Bool { compositor.isEmpty }

  /// 獲取當前標記得範圍。這個函式只能是函式、而非只讀變數。
  /// - Returns: 當前標記範圍。
  func currentMarkedRange() -> Range<Int> {
    min(compositor.cursor, compositor.marker)..<max(compositor.cursor, compositor.marker)
  }

  /// 檢測是否出現游標切斷組字區內字符的情況
  func isCursorCuttingChar(isMarker: Bool = false) -> Bool {
    let index = isMarker ? compositor.marker : compositor.cursor
    var isBound = (index == compositor.walkedNodes.contextRange(ofGivenCursor: index).lowerBound)
    if index == compositor.width { isBound = true }
    let rawResult = compositor.walkedNodes.findNode(at: index)?.isReadingMismatched ?? false
    return !isBound && rawResult
  }

  /// 實際上要拿給 Megrez 使用的的游標位址，以方便在組字器最開頭或者最末尾的時候始終能抓取候選字節點陣列。
  ///
  /// 威注音對游標前置與游標後置模式採取的候選字節點陣列抓取方法是分離的，且不使用 Node Crossing。
  var cursorForCandidate: Int {
    compositor.cursor
      - ((compositor.cursor == compositor.width || !prefs.useRearCursorMode) && compositor.cursor > 0 ? 1 : 0)
  }

  /// 利用給定的讀音鏈來試圖爬取最接近的組字結果（最大相似度估算）。
  ///
  /// 該過程讀取的權重資料是經過 Viterbi 演算法計算得到的結果。
  ///
  /// 該函式的爬取順序是從頭到尾。
  func walk() {
    compositor.walk()

    // 在偵錯模式開啟時，將 GraphViz 資料寫入至指定位置。
    if prefs.isDebugModeEnabled {
      let result = compositor.dumpDOT
      let thePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].path.appending(
        "/vChewing-visualization.dot")
      do {
        try result.write(toFile: thePath, atomically: true, encoding: .utf8)
      } catch {
        vCLog("Failed from writing dumpDOT results.")
      }
    }
  }

  /// 用以組建聯想詞陣列的函式。
  /// - Parameter key: 給定的聯想詞的開頭字。
  /// - Returns: 抓取到的聯想詞陣列。
  /// 不會是 nil，但那些負責接收結果的函式會對空白陣列結果做出正確的處理。
  func generateArrayOfAssociates(withPair pair: Megrez.Compositor.KeyValuePaired) -> [(String, String)] {
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
  func consolidateCursorContext(with theCandidate: Megrez.Compositor.KeyValuePaired) {
    var grid = compositor
    var frontBoundaryEX = cursorForCandidate + 1
    var rearBoundaryEX = cursorForCandidate
    var debugIntelToPrint = ""
    if grid.overrideCandidate(theCandidate, at: cursorForCandidate) {
      grid.walk()
      let range = grid.walkedNodes.contextRange(ofGivenCursor: cursorForCandidate)
      rearBoundaryEX = range.lowerBound
      frontBoundaryEX = range.upperBound
      debugIntelToPrint.append("EX: \(rearBoundaryEX)..<\(frontBoundaryEX), ")
    }

    let range = compositor.walkedNodes.contextRange(ofGivenCursor: cursorForCandidate)
    var rearBoundary = min(range.lowerBound, rearBoundaryEX)
    var frontBoundary = max(range.upperBound, frontBoundaryEX)

    debugIntelToPrint.append("INI: \(rearBoundary)..<\(frontBoundary), ")

    let cursorBackup = compositor.cursor
    while compositor.cursor > rearBoundary { compositor.jumpCursorBySpan(to: .rear) }
    rearBoundary = min(compositor.cursor, rearBoundary)
    compositor.cursor = cursorBackup  // 游標歸位，再接著計算。
    while compositor.cursor < frontBoundary { compositor.jumpCursorBySpan(to: .front) }
    frontBoundary = min(max(compositor.cursor, frontBoundary), compositor.width)
    compositor.cursor = cursorBackup  // 計算結束，游標歸位。

    debugIntelToPrint.append("FIN: \(rearBoundary)..<\(frontBoundary)")
    vCLog(debugIntelToPrint)

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
          let thePair = Megrez.Compositor.KeyValuePaired(
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
  public func consolidateNode(
    candidate: (String, String), respectCursorPushing: Bool = true, preConsolidate: Bool = false
  ) {
    let theCandidate: Megrez.Compositor.KeyValuePaired = .init(key: candidate.0, value: candidate.1)

    /// 必須先鞏固當前組字器游標上下文、以消滅意料之外的影響，但在內文組字區內就地輪替候選字詞時除外。
    if preConsolidate { consolidateCursorContext(with: theCandidate) }

    // 回到正常流程。
    if !compositor.overrideCandidate(theCandidate, at: cursorForCandidate) { return }
    let previousWalk = compositor.walkedNodes
    // 開始爬軌。
    walk()
    let currentWalk = compositor.walkedNodes

    // 在可行的情況下更新使用者半衰記憶模組。
    var accumulatedCursor = 0
    let currentNode = currentWalk.findNode(at: cursorForCandidate, target: &accumulatedCursor)
    guard let currentNode = currentNode else { return }

    if currentNode.currentUnigram.score > -12, prefs.fetchSuggestionsFromUserOverrideModel {
      vCLog("UOM: Start Observation.")
      // 這個過程可能會因為使用者半衰記憶模組內部資料錯亂、而導致輸入法在選字時崩潰。
      // 於是在這裡引入災後狀況察覺專用變數，且先開啟該開關。順利執行完觀察後會關閉。
      // 一旦輸入法崩潰，會在重啟時發現這個開關是開著的，屆時 AppDelegate 會做出應對。
      prefs.failureFlagForUOMObservation = true
      // 令半衰記憶模組觀測給定的三元圖。
      // 這個過程會讓半衰引擎根據當前上下文生成三元圖索引鍵。
      currentUOM.performObservation(
        walkedBefore: previousWalk, walkedAfter: currentWalk, cursor: cursorForCandidate,
        timestamp: Date().timeIntervalSince1970, saveCallback: { self.currentUOM.saveData() }
      )
      // 如果沒有出現崩框的話，那就將這個開關復位。
      prefs.failureFlagForUOMObservation = false
    }

    /// 若偏好設定內啟用了相關選項，則會在選字之後始終將游標推送至選字後的節錨的前方。
    if prefs.moveCursorAfterSelectingCandidate, respectCursorPushing {
      // compositor.cursor = accumulatedCursor
      compositor.jumpCursorBySpan(to: .front)
    }
  }

  /// 獲取候選字詞（包含讀音）陣列資料內容。
  func generateArrayOfCandidates(fixOrder: Bool = true) -> [(String, String)] {
    /// 警告：不要對游標前置風格使用 nodesCrossing，否則會導致游標行為與 macOS 內建注音輸入法不一致。
    /// 微軟新注音輸入法的游標後置風格也是不允許 nodeCrossing 的。
    var arrCandidates: [Megrez.Compositor.KeyValuePaired] = {
      switch prefs.useRearCursorMode {
        case false: return compositor.fetchCandidates(at: cursorForCandidate, filter: .endAt)
        case true: return compositor.fetchCandidates(at: cursorForCandidate, filter: .beginAt)
      }
    }()

    /// 原理：nodes 這個回饋結果包含一堆子陣列，分別對應不同詞長的候選字。
    /// 這裡先對陣列排序、讓最長候選字的子陣列的優先權最高。
    /// 這個過程不會傷到子陣列內部的排序。
    if arrCandidates.isEmpty { return .init() }

    // 決定是否根據半衰記憶模組的建議來調整候選字詞的順序。
    if !prefs.fetchSuggestionsFromUserOverrideModel || prefs.useSCPCTypingMode || fixOrder {
      return arrCandidates.map { ($0.key, $0.value) }
    }

    let arrSuggestedUnigrams: [(String, Megrez.Unigram)] = retrieveUOMSuggestions(apply: false)
    let arrSuggestedCandidates: [Megrez.Compositor.KeyValuePaired] = arrSuggestedUnigrams.map {
      Megrez.Compositor.KeyValuePaired(key: $0.0, value: $0.1.value)
    }
    arrCandidates = arrSuggestedCandidates.filter { arrCandidates.contains($0) } + arrCandidates
    arrCandidates = arrCandidates.deduplicated
    arrCandidates = arrCandidates.stableSort { $0.key.split(separator: "-").count > $1.key.split(separator: "-").count }
    return arrCandidates.map { ($0.key, $0.value) }
  }

  /// 向半衰引擎詢問可能的選字建議、且套用給組字器內的當前游標位置。
  @discardableResult func retrieveUOMSuggestions(apply: Bool) -> [(String, Megrez.Unigram)] {
    var arrResult = [(String, Megrez.Unigram)]()
    /// 如果逐字選字模式有啟用的話，直接放棄執行這個函式。
    if prefs.useSCPCTypingMode { return arrResult }
    /// 如果這個開關沒打開的話，直接放棄執行這個函式。
    if !prefs.fetchSuggestionsFromUserOverrideModel { return arrResult }
    /// 獲取來自半衰記憶模組的建議結果
    let suggestion = currentUOM.fetchSuggestion(
      currentWalk: compositor.walkedNodes, cursor: cursorForCandidate, timestamp: Date().timeIntervalSince1970
    )
    arrResult.append(contentsOf: suggestion.candidates)
    if apply {
      /// 再看有沒有選字建議。有的話就遵循之、讓天權星引擎對指定節錨下的節點複寫權重。
      if !suggestion.isEmpty, let newestSuggestedCandidate = suggestion.candidates.last {
        let overrideBehavior: Megrez.Compositor.Node.OverrideType =
          suggestion.forceHighScoreOverride ? .withHighScore : .withTopUnigramScore
        let suggestedPair: Megrez.Compositor.KeyValuePaired = .init(
          key: newestSuggestedCandidate.0, value: newestSuggestedCandidate.1.value
        )
        vCLog(
          "UOM: Suggestion received, overriding the node score of the selected candidate: \(suggestedPair.toNGramKey)")
        if !compositor.overrideCandidate(suggestedPair, at: cursorForCandidate, overrideType: overrideBehavior) {
          compositor.overrideCandidateLiteral(
            newestSuggestedCandidate.1.value, at: cursorForCandidate, overrideType: overrideBehavior
          )
        }
        walk()
      }
    }
    arrResult = arrResult.stableSort { $0.1.score > $1.1.score }
    return arrResult
  }

  // MARK: - Extracted methods and functions (Tekkon).

  var isComposerOrCalligrapherEmpty: Bool { prefs.cassetteEnabled ? calligrapher.isEmpty : composer.isEmpty }

  /// 獲取與當前注音排列或拼音輸入種類有關的標點索引鍵，以英數下畫線「_」結尾。
  var currentKeyboardParser: String { currentKeyboardParserType.name + "_" }
  var currentKeyboardParserType: KeyboardParser { .init(rawValue: prefs.keyboardParser) ?? .ofStandard }

  /// 給注拼槽指定注音排列或拼音輸入種類之後，將注拼槽內容清空。
  public func ensureKeyboardParser() {
    switch currentKeyboardParserType {
      case KeyboardParser.ofStandard: composer.ensureParser(arrange: .ofDachen)
      case KeyboardParser.ofDachen26: composer.ensureParser(arrange: .ofDachen26)
      case KeyboardParser.ofETen: composer.ensureParser(arrange: .ofETen)
      case KeyboardParser.ofHsu: composer.ensureParser(arrange: .ofHsu)
      case KeyboardParser.ofETen26: composer.ensureParser(arrange: .ofETen26)
      case KeyboardParser.ofIBM: composer.ensureParser(arrange: .ofIBM)
      case KeyboardParser.ofMiTAC: composer.ensureParser(arrange: .ofMiTAC)
      case KeyboardParser.ofFakeSeigyou: composer.ensureParser(arrange: .ofFakeSeigyou)
      case KeyboardParser.ofSeigyou: composer.ensureParser(arrange: .ofSeigyou)
      case KeyboardParser.ofStarlight: composer.ensureParser(arrange: .ofStarlight)
      case KeyboardParser.ofHanyuPinyin: composer.ensureParser(arrange: .ofHanyuPinyin)
      case KeyboardParser.ofSecondaryPinyin: composer.ensureParser(arrange: .ofSecondaryPinyin)
      case KeyboardParser.ofYalePinyin: composer.ensureParser(arrange: .ofYalePinyin)
      case KeyboardParser.ofHualuoPinyin: composer.ensureParser(arrange: .ofHualuoPinyin)
      case KeyboardParser.ofUniversalPinyin: composer.ensureParser(arrange: .ofUniversalPinyin)
    }
    composer.clear()
    composer.phonabetCombinationCorrectionEnabled = prefs.autoCorrectReadingCombination
  }

  public var isComposerUsingPinyin: Bool { composer.parser.rawValue >= 100 }

  public func clearComposerAndCalligrapher() {
    calligrapher.removeAll()
    composer.clear()
  }

  func letComposerAndCalligrapherDoBackSpace() {
    _ = prefs.cassetteEnabled ? calligrapher = String(calligrapher.dropLast(1)) : composer.doBackSpace()
  }

  /// 返回前一個游標位置的可解析的漢字筆畫。
  /// 返回的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
  var previousParsableCalligraph: String? {
    if compositor.cursor == 0 { return nil }
    let cursorPrevious = max(compositor.cursor - 1, 0)
    return compositor.keys[cursorPrevious]
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
  func isIntonationKey(_ input: InputSignalProtocol) -> Bool {
    var theComposer = composer  // 複製一份用來做實驗。
    theComposer.clear()  // 清空各種槽的內容。
    theComposer.receiveKey(fromString: input.text)
    return theComposer.hasIntonation(withNothingElse: true)
  }

  var readingForDisplay: String {
    if !prefs.cassetteEnabled {
      return composer.getInlineCompositionForDisplay(isHanyuPinyin: prefs.showHanyuPinyinInCompositionBuffer)
    }
    if !prefs.showTranslatedStrokesInCompositionBuffer { return calligrapher }
    var result = calligrapher.charComponents
    for idx in 0..<result.count {
      result[idx] = currentLM.currentCassette.convertKeyToDisplay(char: result[idx])
    }
    return result.joined()
  }

  // MARK: - Extracted methods and functions (Megrez).

  /// 生成標點符號索引鍵。
  /// - Parameter input: 輸入的按鍵訊號。
  /// - Returns: 生成的標點符號索引鍵。
  func generatePunctuationNamePrefix(withKeyCondition input: InputSignalProtocol) -> String {
    if prefs.halfWidthPunctuationEnabled { return "_half_punctuation_" }
    switch (input.isControlHold, input.isOptionHold) {
      case (true, true): return "_alt_ctrl_punctuation_"
      case (true, false): return "_ctrl_punctuation_"
      case (false, true): return "_alt_punctuation_"
      case (false, false): return "_punctuation_"
    }
  }
}

// MARK: - Components for Popup Composition Buffer (PCB) Window.

/// 組字區文字上限。
/// - Remark: 該選項僅對不支援 IMKTextInput 協定的應用有用，就不交給 PrefMgr 了。
private let compositorWidthLimit = 20

extension InputHandler {
  /// 在爬取組字結果之前，先將即將從組字區溢出的內容遞交出去。
  ///
  /// 在理想狀況之下，組字區多長都無所謂。但是，螢幕浮動組字窗的尺寸是有限的。
  /// 於是，有必要限定組字區的長度。超過該長度的內容會在爬軌之前先遞交出去，
  /// 使其不再記入最大相似度估算的估算對象範圍。
  /// 用比較形象且生動卻有點噁心的解釋的話，蒼蠅一邊吃一邊屙。
  var commitOverflownComposition: String {
    guard !compositor.walkedNodes.isEmpty,
      compositor.width > compositorWidthLimit,
      let identifier = delegate?.clientBundleIdentifier,
      prefs.clientsIMKTextInputIncapable.contains(identifier)
    else { return "" }
    // 回頭在這裡插上對 Steam 的 Client Identifier 的要求。
    var textToCommit = ""
    while compositor.width > compositorWidthLimit {
      var delta = compositor.width - compositorWidthLimit
      let node = compositor.walkedNodes[0]
      if node.isReadingMismatched {
        delta = node.keyArray.count
        textToCommit += node.currentPair.value
      } else {
        delta = min(delta, node.keyArray.count)
        textToCommit += node.currentPair.value.charComponents[0..<delta].joined()
      }
      let newCursor = max(compositor.cursor - delta, 0)
      compositor.cursor = 0
      if !node.isReadingMismatched { consolidateCursorContext(with: node.currentPair) }
      // 威注音不支援 Bigram，所以無須考慮前後節點「是否需要鞏固」。
      for _ in 0..<delta { compositor.dropKey(direction: .front) }
      compositor.cursor = newCursor
      walk()
    }
    return textToCommit
  }
}
