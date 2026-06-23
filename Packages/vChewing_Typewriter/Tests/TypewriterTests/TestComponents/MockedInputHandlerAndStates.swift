// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import LangModelAssembly
import Shared
import Tekkon
import Testing
@testable import Typewriter

// MARK: - MockInputHandler

/// 專門用於單元測試的模擬 InputHandler 類型。
public final class MockInputHandler: @MainActor InputHandlerProtocol {
  // MARK: Lifecycle

  public init(
    lm: LMAssembly.LMInstantiator,
    pref: PrefMgrProtocol,
    errorCallback: ((_ message: String) -> ())? = nil,
    filterabilityChecker: ((_ state: IMEStateData) -> Bool)? = nil,
    notificationCallback: ((_ message: String) -> ())? = nil,
    pomSaveCallback: (() -> ())? = nil
  ) {
    self.prefs = pref
    self.currentLM = lm
    self.pomSaveCallback = pomSaveCallback
    self.errorCallback = errorCallback
    self.notificationCallback = notificationCallback
    self.filterabilityChecker = filterabilityChecker
    self.assembler = Assembler(
      gramQuerier: { _ in [] }
    )
    assembler.maxSegLength = prefs.maxCandidateLength
    assembler.gramQuerier = { [weak self] keyArray in
      guard let self else { return [] }
      return self.currentLM.lookupHub.grams(for: keyArray)
    }
    ensureKeyboardParser()
  }

  // MARK: Public

  // typealias State removed (inherited from InputHandlerProtocol: State = IMEState)
  public typealias Session = MockSession

  public static var keySeparator: String { Assembler.theSeparator }

  public weak var session: Session?
  public var prefs: PrefMgrProtocol
  public var errorCallback: ((String) -> ())?
  public var notificationCallback: ((String) -> ())?
  public var pomSaveCallback: (() -> ())?
  public var filterabilityChecker: ((_ state: IMEStateData) -> Bool)?
  public var markingTooltipGenerator: ((_ state: State) -> (tooltip: String, colorState: TooltipColorState))?

  public var backupCursor: Int?
  public var currentTypingMethod: TypingMethod = .vChewingFactory

  public var strCodePointBuffer = ""
  public var calligrapher = ""
  public var mixedAlphanumericalBuffer = ""
  public var composer: Tekkon.Composer = .init()
  public var assembler: Homa.Assembler
  public var isJISKeyboard: (() -> Bool)? = { false }
  public var narrator: (any SpeechNarratorProtocol)?

  public var currentLM: LMAssembly.LMInstantiator {
    didSet {
      clear()
    }
  }
}

// MARK: - MockSession

/// 專門用於單元測試的模擬會話類型。
public final class MockSession: @MainActor SessionCoreProtocol {
  // MARK: Lifecycle

  public init() {
    self.state = IMEState()
  }

  // MARK: Public

  // typealias State removed (inherited from SessionCoreProtocol: State = IMEState)
  public typealias Handler = MockInputHandler

  public let id: UUID = .init()
  public var state: IMEState = .init()
  public var inputHandler: MockInputHandler?
  public var isASCIIMode: Bool = false
  public var clientMitigationLevel: Int = 0
  public var isVerticalTyping: Bool = false
  public var showCodePointForCurrentCandidate: Bool = false
  public var shouldAutoExpandCandidates: Bool = false
  public var isCandidateContextMenuEnabled: Bool = false
  public var showReverseLookupResult: Bool = false
  public var ui: SessionUIProtocol?
  public var selectionKeys: String = "123456789"
  public var recentCommissions = [String]()
  public var clientAccentColor: HSBA?

  public var isCandidateState: Bool { state.type == .ofCandidates }

  public var isCandidateWindowSingleLine: Bool { true }

  public var isVerticalCandidateWindow: Bool { false }

  public var localeForFontFallbacks: String { "zh-Hant" }

  public func callError(_ logMessage: String) {
    vCLog(logMessage)
  }

  public func getCandidate(at index: Int) -> CandidateInState? {
    guard state.candidates.indices.contains(index) else { return nil }
    return state.candidates[index]
  }

  public func updateCompositionBufferDisplay() {}

  public func performUserPhraseOperation(addToFilter: Bool) -> Bool {
    guard let inputHandler = inputHandler, state.type == .ofMarking else { return false }
    let kvPair = state.data.userPhraseKVPair
    let userPhrase = UserPhraseInsertable(
      keyArray: kvPair.keyArray,
      value: kvPair.value,
      inputMode: IMEApp.currentInputMode
    )
    inputHandler.currentLM.insertTemporaryData(
      unigram: .init(
        keyArray: userPhrase.keyArray,
        value: userPhrase.value,
        score: userPhrase.weight ?? 0
      ),
      isFiltering: addToFilter
    )
    // 該單元測試僅測試當前函式是否有清除 POM 內部的相關資料。
    // 不然的話，該函式的目的與結果可能會被 POM 既有資料所干涉。
    var pomTargets = inputHandler.activePOMCandidateValues()
    pomTargets.append(userPhrase.value)
    let uniqueTargets = Array(Set(pomTargets.filter { !$0.isEmpty }))
    if !uniqueTargets.isEmpty {
      inputHandler.currentLM.bleachSpecifiedPOMSuggestions(targets: uniqueTargets)
    }
    let separator = inputHandler.keySeparator.isEmpty ? Homa.Assembler.theSeparator : inputHandler.keySeparator
    let headReading = userPhrase.keyArray.joined(separator: separator)
    if !headReading.isEmpty {
      inputHandler.currentLM.bleachSpecifiedPOMSuggestions(headReadings: [headReading])
    }
    // 清詞完畢
    return true
  }

  @discardableResult
  public func updateVerticalTypingStatus() -> CGRect {
    // `textFrame` 的尺寸不能是 0，否則 `attributes()` 在某些客體上的不良實作可能會炸掉客體。
    // 所以需要使用 `CGRect.seniorTheBeast` 作為基底資料值。
    .seniorTheBeast
  }

  // MARK: - CtlCandidateDelegate conformance

  public func candidateController() -> CtlCandidateProtocol? { nil }

  public func candidatePairs(conv _: Bool) -> [CandidateInState] {
    if !state.isCandidateContainer || state.candidates.isEmpty { return [] }
    return state.candidates
  }

  public func candidatePairSelectionConfirmed(at index: Int) {
    guard let inputHandler = inputHandler else { return }
    guard state.isCandidateContainer else { return }
    switch state.type {
    case .ofSymbolTable where (0 ..< state.node.members.count).contains(index):
      let node = state.node.members[index]
      if !node.members.isEmpty {
        switchState(.ofSymbolTable(node: node))
      } else if let serviceNode = node.asServiceMenuNode {
        let rawValue = serviceNode.service.rawValue
        print("Service Node is not available for Mocked Sessions. raw: \(rawValue)")
        switchState(.ofAbortion())
      } else {
        switchState(.ofCommitting(textToCommit: node.name))
      }
    case .ofCandidates where (0 ..< state.candidates.count).contains(index):
      let selectedValue = state.candidates[index]
      inputHandler.consolidateNode(
        candidate: selectedValue,
        respectCursorPushing: true,
        preConsolidate: inputHandler.prefs.consolidateContextOnCandidateSelection,
        skipObservation: !inputHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel,
        explicitlyChosen: true
      )
      var result: State = inputHandler.generateStateOfInputting()
      defer { switchState(result) } // 這是最終輸出結果。
      if inputHandler.prefs.useSCPCTypingMode {
        switchState(.ofCommitting(textToCommit: inputHandler.committableDisplayText(sansReading: true)))
        // 此時是逐字選字模式，所以「selectedValue.value」是單個字、不用追加處理。
        if inputHandler.prefs.associatedPhrasesEnabled {
          let associates = inputHandler.generateStateOfAssociates(
            withPair: .init(keyArray: selectedValue.keyArray, value: selectedValue.value)
          )
          result = associates.candidates.isEmpty ? .ofEmpty() : associates
        } else {
          result = .ofEmpty()
        }
      }
    case .ofAssociates where (0 ..< state.candidates.count).contains(index):
      let selectedValue = state.candidates[index]
      var result: State = .ofEmpty()
      defer { switchState(result) } // 這是最終輸出結果。
      switchState(.ofCommitting(textToCommit: selectedValue.value))
      guard inputHandler.prefs.associatedPhrasesEnabled else { return }
      // 此時是關聯詞語選字模式，所以「selectedValue.value」必須只保留最後一個字。
      // 不然的話，一旦你選中了由多個字組成的聯想候選詞，則連續聯想會被打斷。
      guard let valueKept = selectedValue.value.last?.description else { return }
      let associates = inputHandler.generateStateOfAssociates(
        withPair: .init(keyArray: selectedValue.keyArray, value: valueKept)
      )
      if !associates.candidates.isEmpty { result = associates }
    case .ofInputting where (0 ..< state.candidates.count).contains(index):
      let chosenStr = state.candidates[index].value
      guard !chosenStr.isEmpty, chosenStr != inputHandler.currentLM.nullCandidateInCassette else {
        vCTestLog("TEST SESSION ERROR: 907F9F64")
        return
      }
      let strToCommitFirst = inputHandler.committableDisplayText(sansReading: true)
      switchState(.ofCommitting(textToCommit: strToCommitFirst + chosenStr))
    default: return
    }
  }

  public func candidatePairHighlightChanged(at theIndex: Int?) {
    guard let inputHandler = inputHandler else { return }
    guard state.highlightedCandidateIndex != theIndex else { return }
    state.highlightedCandidateIndex = theIndex
    guard state.isCandidateContainer, let theIndex else { return }
    switch state.type {
    case .ofCandidates where (0 ..< state.candidates.count).contains(theIndex):
      inputHandler.previewCurrentCandidateAtCompositionBuffer()
    case .ofSymbolTable where (0 ..< state.node.members.count).contains(theIndex):
      let node = state.node.members[theIndex]
      if node.members.isEmpty {
        state.data.displayedText = node.name
        state.data.cursor = node.name.count
      } else {
        state.data.displayedText.removeAll()
        state.data.cursor = 0
      }
      updateCompositionBufferDisplay()
    default: break
    }
  }

  public func candidatePairContextMenuActionTriggered(
    at index: Int, action: CandidateContextMenuAction
  ) {}

  public func candidatePairManipulated(
    at index: Int,
    action: CandidateContextMenuAction
  ) {}

  public func candidateToolTip(shortened: Bool) -> String { "" }

  public func resetCandidateWindowOrigin() {}

  public func candidateWindowOriginInfo() -> (topLeft: CGPoint, heightDelta: Double) {
    (topLeft: CGPoint(x: 0, y: 0), heightDelta: 0)
  }

  public func checkIsMacroTokenResult(_ index: Int) -> Bool { false }

  @discardableResult
  public func reverseLookup(for value: String) -> [String] { [] }

  public func toggleCandidateUIVisibility(_: Bool, refresh _: Bool) {}
  public func commit(text: String, clearDisplayBeforeCommit _: Bool) {
    guard !text.isEmpty else { return }
    recentCommissions.append(text)
  }

  public func getMitigatedState(_ givenState: State) -> State { givenState }
  public func showTooltip(_: String?, colorState _: TooltipColorState, duration _: Double) {}

  // MARK: Internal

  /// 覆寫 SessionCoreProtocol 的 debugLogCondition，
  /// 維持單元測試既有的 log 輸出行為。
  var debugLogCondition: Bool {
    PrefMgr.sharedSansDidSetOps.isDebugModeEnabled
  }
}

// MARK: - MockSpeechNarrator

/// 專門用於單元測試的模擬語音朗讀器，可記錄最後一次朗讀的文本。
public final class MockSpeechNarrator: SpeechNarratorProtocol {
  public static var shared: MockSpeechNarrator = .init()

  public private(set) var lastNarratedText: String?
  public private(set) var narrateCallCount: Int = 0

  public func refreshStatus() {}

  public func narrate(_ text: String, allowDuplicates: Bool = true) {
    narrateCallCount += 1
    lastNarratedText = text
  }

  public func reset() {
    lastNarratedText = nil
    narrateCallCount = 0
  }
}
