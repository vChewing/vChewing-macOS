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
  let kMaxComposingBufferNeedsToWalkSize = Int(max(12, ceil(Double(mgrPrefs.composingBufferSize) / 2)))
  var composer: Tekkon.Composer = .init()
  var compositor: Megrez.Compositor
  var currentLM: vChewing.LMInstantiator = .init()
  var currentUOM: vChewing.LMUserOverride = .init()
  var walkedAnchors: [Megrez.NodeAnchor] = []

  var delegate: KeyHandlerDelegate?

  var inputMode: InputMode = IME.currentInputMode {
    willSet {
      // 將新的簡繁輸入模式提報給 ctlInputMethod:
      IME.currentInputMode = newValue
      mgrPrefs.mostRecentInputMode = IME.currentInputMode.rawValue

      let isCHS: Bool = (newValue == InputMode.imeModeCHS)
      // Reinitiate language models if necessary
      currentLM = isCHS ? mgrLangModel.lmCHS : mgrLangModel.lmCHT
      currentUOM = isCHS ? mgrLangModel.uomCHS : mgrLangModel.uomCHT

      // Synchronize the sub-languageModel state settings to the new LM.
      syncBaseLMPrefs()

      // Create new compositor and clear the composer.
      // When it recreates, it adapts to the latest imeMode settings.
      // This allows it to work with correct LMs.
      reinitCompositor()
      composer.clear()
    }
  }

  public init() {
    compositor = Megrez.Compositor(lm: currentLM, separator: "-")
    ensureParser()
    // 下面這句必須用 defer，否則不會觸發其 willSet 部分的內容。
    defer { inputMode = IME.currentInputMode }
  }

  func clear() {
    composer.clear()
    compositor.clear()
    walkedAnchors.removeAll()
  }

  // MARK: - Functions dealing with Megrez.

  func walk() {
    // Retrieve the most likely grid, i.e. a Maximum Likelihood Estimation
    // of the best possible Mandarin characters given the input syllables,
    // using the Viterbi algorithm implemented in the Megrez library.
    // The walk() traces the grid to the end.
    walkedAnchors = compositor.walk()

    // if DEBUG mode is enabled, a GraphViz file is written to kGraphVizOutputfile.
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

  var popOverflowComposingTextAndWalk: String {
    // In ideal situations we can allow users to type infinitely in a buffer.
    // However, Viberti algorithm has a complexity of O(N^2), the walk will
    // become slower as the number of nodes increase. Therefore, we need to
    // auto-commit overflown texts which usually lose their influence over
    // the whole MLE anyway -- so that when the user type along, the already
    // composed text in the rear side of the buffer will be committed out.
    // (i.e. popped out.)

    var poppedText = ""
    if compositor.grid.width > mgrPrefs.composingBufferSize {
      if !walkedAnchors.isEmpty {
        let anchor: Megrez.NodeAnchor = walkedAnchors[0]
        if let theNode = anchor.node {
          poppedText = theNode.currentKeyValue.value
        }
        compositor.removeHeadReadings(count: anchor.spanningLength)
      }
    }
    walk()
    return poppedText
  }

  func buildAssociatePhraseArray(withKey key: String) -> [String] {
    var arrResult: [String] = []
    if currentLM.hasAssociatedPhrasesForKey(key) {
      arrResult.append(contentsOf: currentLM.associatedPhrasesForKey(key))
    }
    return arrResult
  }

  func fixNode(value: String, respectCursorPushing: Bool = true) {
    let cursorIndex = min(actualCandidateCursorIndex + (mgrPrefs.useRearCursorMode ? 1 : 0), compositorLength)
    compositor.grid.fixNodeSelectedCandidate(location: cursorIndex, value: value)
    //  // 因半衰模組失能，故禁用之。
    // let selectedNode: Megrez.NodeAnchor = compositor.grid.fixNodeSelectedCandidate(
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
    //    currentUOM.observe(
    //      walkedNodes: walkedAnchors, cursorIndex: cursorIndex, candidate: value,
    //      timestamp: NSDate().timeIntervalSince1970
    //    )
    //  }
    // }
    walk()

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

  func markNodesFixedIfNecessary() {
    let width = compositor.grid.width
    if width <= kMaxComposingBufferNeedsToWalkSize {
      return
    }
    var index: Int = 0
    for anchor in walkedAnchors {
      guard let node = anchor.node else { break }
      if index >= width - kMaxComposingBufferNeedsToWalkSize { break }
      if node.score < node.kSelectedCandidateScore {
        compositor.grid.fixNodeSelectedCandidate(
          location: index + anchor.spanningLength, value: node.currentKeyValue.value)
      }
      index += anchor.spanningLength
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
      : currentUOM.suggest(
        walkedNodes: walkedAnchors, cursorIndex: compositorCursorIndex,
        timestamp: NSDate().timeIntervalSince1970
      )

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

  // MARK: - Extracted methods and functions (Megrez).

  var isCompositorEmpty: Bool { compositor.grid.width == 0 }

  var rawNodes: [Megrez.NodeAnchor] {
    /// 警告：不要對游標前置風格使用 nodesCrossing，否則會導致游標行為與 macOS 內建注音輸入法不一致。
    /// 微軟新注音輸入法的游標後置風格也是不允許 nodeCrossing 的。
    mgrPrefs.useRearCursorMode
      ? compositor.grid.nodesBeginningAt(location: actualCandidateCursorIndex)
      : compositor.grid.nodesEndingAt(location: actualCandidateCursorIndex)
  }

  func syncBaseLMPrefs() {
    currentLM.isPhraseReplacementEnabled = mgrPrefs.phraseReplacementEnabled
    currentLM.isCNSEnabled = mgrPrefs.cns11643Enabled
    currentLM.isSymbolEnabled = mgrPrefs.symbolInputEnabled
  }

  func reinitCompositor() {
    // Each Mandarin syllable is separated by a hyphen.
    compositor = Megrez.Compositor(lm: currentLM, separator: "-")
  }

  var currentReadings: [String] { compositor.readings }

  func ifLangModelHasUnigrams(forKey reading: String) -> Bool {
    currentLM.hasUnigramsFor(key: reading)
  }

  func insertToCompositorAtCursor(reading: String) {
    compositor.insertReadingAtCursor(reading: reading)
  }

  var compositorCursorIndex: Int {
    get { compositor.cursorIndex }
    set { compositor.cursorIndex = newValue }
  }

  var compositorLength: Int {
    compositor.length
  }

  func deleteBuilderReadingInFrontOfCursor() {
    compositor.deleteReadingAtTheRearOfCursor()
  }

  func deleteBuilderReadingToTheFrontOfCursor() {
    compositor.deleteReadingToTheFrontOfCursor()
  }

  var keyLengthAtIndexZero: Int {
    walkedAnchors[0].node?.currentKeyValue.value.count ?? 0
  }
}
