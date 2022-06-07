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

import Cocoa

public enum InputMode: String {
  case imeModeCHS = "org.atelierInmu.inputmethod.vChewing.IMECHS"
  case imeModeCHT = "org.atelierInmu.inputmethod.vChewing.IMECHT"
  case imeModeNULL = ""
}

// MARK: - Delegate.

protocol KeyHandlerDelegate {
  func ctlCandidate() -> ctlCandidate
  func keyHandler(
    _: KeyHandler, didSelectCandidateAt index: Int,
    ctlCandidate controller: ctlCandidate
  )
  func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputState)
    -> Bool
}

// MARK: - Kernel.

class KeyHandler {
  let kEpsilon: Double = 0.000001
  let kMaxComposingBufferNeedsToWalkSize: Int = 10
  var _composer: Tekkon.Composer = .init()
  var _inputMode: String = ""
  var _languageModel: vChewing.LMInstantiator = .init()
  var _userOverrideModel: vChewing.LMUserOverride = .init()
  var _builder: Megrez.BlockReadingBuilder
  var _walkedNodes: [Megrez.NodeAnchor] = []

  var delegate: KeyHandlerDelegate?

  var inputMode: InputMode {
    get {
      switch _inputMode {
        case "org.atelierInmu.inputmethod.vChewing.IMECHS":
          return InputMode.imeModeCHS
        case "org.atelierInmu.inputmethod.vChewing.IMECHT":
          return InputMode.imeModeCHT
        default:
          return InputMode.imeModeNULL
      }
    }
    set {
      let isCHS: Bool = (newValue == InputMode.imeModeCHS)

      // 緊接著將新的簡繁輸入模式提報給 ctlInputMethod:
      ctlInputMethod.currentInputMode = isCHS ? InputMode.imeModeCHS.rawValue : InputMode.imeModeCHT.rawValue
      mgrPrefs.mostRecentInputMode = ctlInputMethod.currentInputMode

      // 拿當前的 _inputMode 與 ctlInputMethod 的提報結果對比，不同的話則套用新設定：
      if _inputMode != ctlInputMethod.currentInputMode {
        // Reinitiate language models if necessary
        _languageModel = isCHS ? mgrLangModel.lmCHS : mgrLangModel.lmCHT
        _userOverrideModel = isCHS ? mgrLangModel.uomCHS : mgrLangModel.uomCHT

        // Synchronize the sub-languageModel state settings to the new LM.
        syncBaseLMPrefs()

        // Create new grid builder and clear the composer.
        createNewBuilder()
        _composer.clear()
      }
      // 直接寫到衛星模組內，省得類型轉換
      _inputMode = ctlInputMethod.currentInputMode
    }
  }

  public init() {
    _builder = Megrez.BlockReadingBuilder(lm: _languageModel, separator: "-")
    ensureParser()
    inputMode = InputMode(rawValue: ctlInputMethod.currentInputMode) ?? InputMode.imeModeNULL
  }

  func clear() {
    _composer.clear()
    _builder.clear()
    _walkedNodes.removeAll()
  }

  // MARK: - Functions dealing with Megrez.

  func walk() {
    // Retrieve the most likely grid, i.e. a Maximum Likelihood Estimation
    // of the best possible Mandarin characters given the input syllables,
    // using the Viterbi algorithm implemented in the Megrez library.
    // The walk() traces the grid to the end.
    _walkedNodes = _builder.walk()

    // if DEBUG mode is enabled, a GraphViz file is written to kGraphVizOutputfile.
    if mgrPrefs.isDebugModeEnabled {
      let result = _builder.grid.dumpDOT
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

  var popOverflowComposingTextAndWalk: String {
    // In ideal situations we can allow users to type infinitely in a buffer.
    // However, Viberti algorithm has a complexity of O(N^2), the walk will
    // become slower as the number of nodes increase. Therefore, we need to
    // auto-commit overflown texts which usually lose their influence over
    // the whole MLE anyway -- so that when the user type along, the already
    // composed text in the rear side of the buffer will be committed out.
    // (i.e. popped out.)

    var poppedText = ""
    if _builder.grid.width > mgrPrefs.composingBufferSize {
      if !_walkedNodes.isEmpty {
        let anchor: Megrez.NodeAnchor = _walkedNodes[0]
        if let theNode = anchor.node {
          poppedText = theNode.currentKeyValue.value
        }
        _builder.removeHeadReadings(count: anchor.spanningLength)
      }
    }
    walk()
    return poppedText
  }

  func buildAssociatePhraseArray(withKey key: String) -> [String] {
    var arrResult: [String] = []
    if _languageModel.hasAssociatedPhrasesForKey(key) {
      arrResult.append(contentsOf: _languageModel.associatedPhrasesForKey(key))
    }
    return arrResult
  }

  func fixNode(value: String, respectCursorPushing: Bool = true) {
    let cursorIndex = min(actualCandidateCursorIndex + (mgrPrefs.useRearCursorMode ? 1 : 0), builderLength)
    _builder.grid.fixNodeSelectedCandidate(location: cursorIndex, value: value)
    //  // 因半衰模組失能，故禁用之。
    // let selectedNode: Megrez.NodeAnchor = _builder.grid.fixNodeSelectedCandidate(
    //  location: cursorIndex, value: value
    // )
    //  // 不要針對逐字選字模式啟用臨時半衰記憶模型。
    // if !mgrPrefs.useSCPCTypingMode {
    //  // If the length of the readings and the characters do not match,
    //  // it often means it is a special symbol and it should not be stored
    //  // in the user override model.
    //  var addToUserOverrideModel = true
    //  if selectedNode.spanningLength != value.count {
    //    IME.prtDebugIntel("UOM: SpanningLength != value.count, dismissing.")
    //    addToUserOverrideModel = false
    //  }
    //  if addToUserOverrideModel {
    //    if let theNode = selectedNode.node {
    //      // 威注音的 SymbolLM 的 Score 是 -12。
    //      if theNode.scoreFor(candidate: value) <= -12 {
    //        IME.prtDebugIntel("UOM: Score <= -12, dismissing.")
    //        addToUserOverrideModel = false
    //      }
    //    }
    //  }
    //  if addToUserOverrideModel {
    //    IME.prtDebugIntel("UOM: Start Observation.")
    //    _userOverrideModel.observe(
    //      walkedNodes: _walkedNodes, cursorIndex: cursorIndex, candidate: value,
    //      timestamp: NSDate().timeIntervalSince1970
    //    )
    //  }
    // }
    walk()

    if mgrPrefs.moveCursorAfterSelectingCandidate, respectCursorPushing {
      var nextPosition = 0
      for node in _walkedNodes {
        if nextPosition >= cursorIndex { break }
        nextPosition += node.spanningLength
      }
      if nextPosition <= builderLength {
        builderCursorIndex = nextPosition
      }
    }
  }

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

  func dealWithOverrideModelSuggestions() {
    let overrideValue =
      mgrPrefs.useSCPCTypingMode
      ? ""
      : _userOverrideModel.suggest(
        walkedNodes: _walkedNodes, cursorIndex: builderCursorIndex,
        timestamp: NSDate().timeIntervalSince1970
      )

    if !overrideValue.isEmpty {
      IME.prtDebugIntel(
        "UOM: Suggestion retrieved, overriding the node score of the selected candidate.")
      _builder.grid.overrideNodeScoreForSelectedCandidate(
        location: min(actualCandidateCursorIndex + (mgrPrefs.useRearCursorMode ? 1 : 0), builderLength),
        value: overrideValue,
        overridingScore: findHighestScore(nodes: rawNodes, epsilon: kEpsilon)
      )
    } else {
      IME.prtDebugIntel("UOM: Blank suggestion retrieved, dismissing.")
    }
  }

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

  func ensureParser() {
    switch mgrPrefs.mandarinParser {
      case MandarinParser.ofStandard.rawValue:
        _composer.ensureParser(arrange: .ofDachen)
      case MandarinParser.ofDachen26.rawValue:
        _composer.ensureParser(arrange: .ofDachen26)
      case MandarinParser.ofEten.rawValue:
        _composer.ensureParser(arrange: .ofEten)
      case MandarinParser.ofHsu.rawValue:
        _composer.ensureParser(arrange: .ofHsu)
      case MandarinParser.ofEten26.rawValue:
        _composer.ensureParser(arrange: .ofEten26)
      case MandarinParser.ofIBM.rawValue:
        _composer.ensureParser(arrange: .ofIBM)
      case MandarinParser.ofMiTAC.rawValue:
        _composer.ensureParser(arrange: .ofMiTAC)
      case MandarinParser.ofFakeSeigyou.rawValue:
        _composer.ensureParser(arrange: .ofFakeSeigyou)
      case MandarinParser.ofHanyuPinyin.rawValue:
        _composer.ensureParser(arrange: .ofHanyuPinyin)
      case MandarinParser.ofSecondaryPinyin.rawValue:
        _composer.ensureParser(arrange: .ofSecondaryPinyin)
      case MandarinParser.ofYalePinyin.rawValue:
        _composer.ensureParser(arrange: .ofYalePinyin)
      case MandarinParser.ofHualuoPinyin.rawValue:
        _composer.ensureParser(arrange: .ofHualuoPinyin)
      case MandarinParser.ofUniversalPinyin.rawValue:
        _composer.ensureParser(arrange: .ofUniversalPinyin)
      default:
        _composer.ensureParser(arrange: .ofDachen)
        mgrPrefs.mandarinParser = MandarinParser.ofStandard.rawValue
    }
    _composer.clear()
  }

  // MARK: - Extracted methods and functions (Megrez).

  var isBuilderEmpty: Bool { _builder.grid.width == 0 }

  var rawNodes: [Megrez.NodeAnchor] {
    /// 警告：不要對游標前置風格使用 nodesCrossing，否則會導致游標行為與 macOS 內建注音輸入法不一致。
    /// 微軟新注音輸入法的游標後置風格也是不允許 nodeCrossing 的。
    mgrPrefs.useRearCursorMode
      ? _builder.grid.nodesBeginningAt(location: actualCandidateCursorIndex)
      : _builder.grid.nodesEndingAt(location: actualCandidateCursorIndex)
  }

  func syncBaseLMPrefs() {
    _languageModel.isPhraseReplacementEnabled = mgrPrefs.phraseReplacementEnabled
    _languageModel.isCNSEnabled = mgrPrefs.cns11643Enabled
    _languageModel.isSymbolEnabled = mgrPrefs.symbolInputEnabled
  }

  func createNewBuilder() {
    // Each Mandarin syllable is separated by a hyphen.
    _builder = Megrez.BlockReadingBuilder(lm: _languageModel, separator: "-")
  }

  var currentReadings: [String] { _builder.readings }

  func ifLangModelHasUnigrams(forKey reading: String) -> Bool {
    _languageModel.hasUnigramsFor(key: reading)
  }

  func insertReadingToBuilderAtCursor(reading: String) {
    _builder.insertReadingAtCursor(reading: reading)
  }

  var builderCursorIndex: Int {
    get { _builder.cursorIndex }
    set { _builder.cursorIndex = newValue }
  }

  var builderLength: Int {
    _builder.length
  }

  func deleteBuilderReadingInFrontOfCursor() {
    _builder.deleteReadingAtTheRearOfCursor()
  }

  func deleteBuilderReadingToTheFrontOfCursor() {
    _builder.deleteReadingToTheFrontOfCursor()
  }

  var keyLengthAtIndexZero: Int {
    _walkedNodes[0].node?.currentKeyValue.value.count ?? 0
  }
}
