// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import IMKUtils
import LangModelAssembly
import Megrez
import Shared
import Tekkon
@testable import Typewriter
import XCTest

#if canImport(AppKit)
  import AppKit
#endif

#if canImport(InputMethodKit)
  import InputMethodKit
#endif

// MARK: - MockIMEState

/// 專門用於單元測試的模擬 IMEState 類型。
public struct MockIMEState: IMEStateProtocol {
  // MARK: Lifecycle

  public init(
    _ data: IMEStateData = IMEStateData(),
    type: StateType = .ofEmpty
  ) {
    self.data = data
    self.type = type
  }

  public init(
    _ data: IMEStateData,
    type: StateType = .ofEmpty,
    node: CandidateNode
  ) {
    self.data = data
    self.type = type
    self.node = node
    self.data.candidates = node.members.map { ([""], $0.name) }
  }

  // MARK: Public

  public var type: StateType = .ofEmpty
  public var data: IMEStateData = .init()
  public var node: CandidateNode = .init(name: "")

  // Additional properties required by protocol
  public var displayedTextConverted: String {
    data.displayedText
  }

  public var markedTargetIsCurrentlyFiltered: Bool {
    false
  }

  #if canImport(Darwin)
    public func attributedString(for session: IMKInputControllerProtocol) -> NSAttributedString {
      // Simplified implementation for testing
      NSAttributedString(string: data.displayedText)
    }
  #endif
}

// MARK: - Extension to provide static constructors

extension MockIMEState {
  /// 內部專用初期化函式，僅用於生成「有輸入內容」的狀態。
  fileprivate init(displayTextSegments: [String], cursor: Int) {
    self.init(.init(), type: .ofEmpty)
    data.displayTextSegments = displayTextSegments
    data.cursor = cursor
    data.marker = cursor
  }

  public static func ofDeactivated() -> MockIMEState { .init(type: .ofDeactivated) }
  public static func ofEmpty() -> MockIMEState { .init(type: .ofEmpty) }
  public static func ofAbortion() -> MockIMEState { .init(type: .ofAbortion) }

  public static func ofCommitting(textToCommit: String) -> MockIMEState {
    var result = MockIMEState(type: .ofCommitting)
    result.textToCommit = textToCommit
    return result
  }

  public static func ofAssociates(candidates: [(keyArray: [String], value: String)]) -> MockIMEState {
    var result = MockIMEState(type: .ofAssociates)
    result.candidates = candidates
    return result
  }

  public static func ofInputting(
    displayTextSegments: [String],
    cursor: Int,
    highlightAt highlightAtSegment: Int? = nil
  )
    -> MockIMEState {
    var result = MockIMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofInputting
    if let readingAtSegment = highlightAtSegment {
      result.data.highlightAtSegment = readingAtSegment
    }
    return result
  }

  public static func ofMarking(
    displayTextSegments: [String],
    markedReadings: [String],
    cursor: Int,
    marker: Int
  )
    -> MockIMEState {
    var result = MockIMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofMarking
    result.data.marker = marker
    result.data.markedReadings = markedReadings
    return result
  }

  public static func ofCandidates(
    candidates: [(keyArray: [String], value: String)],
    displayTextSegments: [String],
    cursor: Int
  )
    -> MockIMEState {
    var result = MockIMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofCandidates
    result.data.candidates = candidates
    return result
  }

  public static func ofSymbolTable(node: CandidateNode) -> MockIMEState {
    .init(IMEStateData(), type: .ofSymbolTable, node: node)
  }
}

// MARK: - MockInputHandler

/// 專門用於單元測試的模擬 InputHandler 類型。
public class MockInputHandler: InputHandlerProtocol {
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
    self.assembler = Assembler(with: currentLM, separator: "-")
    assembler.maxSegLength = prefs.maxCandidateLength
    ensureKeyboardParser()
  }

  // MARK: Public

  public typealias State = MockIMEState
  public typealias Session = MockSession

  public static var keySeparator: String { Assembler.theSeparator }

  public weak var session: Session?
  public var prefs: PrefMgrProtocol
  public var errorCallback: ((String) -> ())?
  public var notificationCallback: ((String) -> ())?
  public var pomSaveCallback: (() -> ())?
  public var filterabilityChecker: ((_ state: IMEStateData) -> Bool)?

  public var backupCursor: Int?
  public var currentTypingMethod: TypingMethod = .vChewingFactory

  public var strCodePointBuffer = ""
  public var calligrapher = ""
  public var composer: Tekkon.Composer = .init()
  public var assembler: Megrez.Compositor

  public var currentLM: LMAssembly.LMInstantiator {
    didSet {
      assembler.langModel = currentLM
      clear()
    }
  }
}

// MARK: - MockSession

/// 專門用於單元測試的模擬會話類型。
public class MockSession: SessionCoreProtocol, CtlCandidateDelegate {
  // MARK: Lifecycle

  public init() {
    self.state = MockIMEState()
  }

  // MARK: Public

  public typealias State = MockIMEState
  public typealias Handler = MockInputHandler

  public var state: MockIMEState = .init()
  public var inputHandler: MockInputHandler?
  public var isASCIIMode: Bool = false
  public var clientMitigationLevel: Int = 0
  public var isVerticalTyping: Bool = false
  public var showCodePointForCurrentCandidate: Bool = false
  public var shouldAutoExpandCandidates: Bool = false
  public var isCandidateContextMenuEnabled: Bool = false
  public var showReverseLookupResult: Bool = false
  public var selectionKeys: String = "123456789"
  public var recentCommissions = [String]()
  #if canImport(AppKit)
    public var clientAccentColor: NSColor?
  #endif

  public var isCandidateState: Bool { state.type == .ofCandidates }

  public func switchState(_ newState: MockIMEState) {
    var previous = state
    state = newState
    switch newState.type {
    case .ofDeactivated:
      // 這裡移除一些處理，轉而交給 commitComposition() 代為執行。
      inputHandler?.clear()
    // if ![.ofAbortion, .ofEmpty].contains(previous.type), !previous.displayedText.isEmpty {
    //   clearInlineDisplay()
    // }
    case .ofAbortion, .ofCommitting, .ofEmpty:
      innerCircle: switch newState.type {
      case .ofAbortion:
        previous = .ofEmpty()
        state = previous
      case .ofCommitting:
        recentCommissions.append(newState.textToCommit)
        state = .ofEmpty()
      default: break innerCircle
      }
      // candidateUI?.visible = false
      // 全專案用以判斷「.Abortion」的地方僅此一處。
      // if previous.hasComposition, ![.ofAbortion, .ofCommitting].contains(newState.type) {
      //   commit(text: previous.displayedText)
      // }
      // 會在工具提示為空的時候自動消除顯示。
      // showTooltip(newState.tooltip, duration: newState.tooltipDuration)
      // clearInlineDisplay()
      inputHandler?.clear()
    case .ofInputting: break
    // candidateUI?.visible = false
    // if !newState.textToCommit.isEmpty {
    //   commit(text: newState.textToCommit)
    // }
    // setInlineDisplayWithCursor()
    // 會在工具提示為空的時候自動消除顯示。
    // showTooltip(newState.tooltip, duration: newState.tooltipDuration)
    // if newState.isCandidateContainer { showCandidates() }
    case .ofMarking: break
    // candidateUI?.visible = false
    // setInlineDisplayWithCursor()
    // showTooltip(newState.tooltip)
    case .ofAssociates, .ofCandidates, .ofSymbolTable: break
      // tooltipInstance.hide()
      // setInlineDisplayWithCursor()
      // showCandidates()
    }
    // 浮動組字窗的顯示判定
    // updatePopupDisplayWithCursor()
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
    let separator = inputHandler.keySeparator.isEmpty ? Megrez.Compositor.theSeparator : inputHandler.keySeparator
    let headReading = userPhrase.keyArray.joined(separator: separator)
    if !headReading.isEmpty {
      inputHandler.currentLM.bleachSpecifiedPOMSuggestions(headReadings: [headReading])
    }
    // 清詞完畢
    return true
  }

  @discardableResult
  public func updateVerticalTypingStatus() -> CGRect { .zero }

  // MARK: - CtlCandidateDelegate conformance

  public func candidateController() -> CtlCandidateProtocol? { nil }

  public func candidatePairs(conv _: Bool) -> [(keyArray: [String], value: String)] {
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
        skipObservation: !inputHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel
      )
      var result: State = inputHandler.generateStateOfInputting()
      defer { switchState(result) } // 這是最終輸出結果。
      if inputHandler.prefs.useSCPCTypingMode {
        switchState(.ofCommitting(textToCommit: result.displayedText))
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
      let strToCommitFirst = inputHandler.generateStateOfInputting(sansReading: true).displayedText
      switchState(.ofCommitting(textToCommit: strToCommitFirst + chosenStr))
    default: return
    }
  }

  public func candidatePairHighlightChanged(at index: Int) {}

  public func candidatePairContextMenuActionTriggered(
    at index: Int, action: CandidateContextMenuAction
  ) {}

  public func candidatePairManipulated(
    at index: Int,
    action: CandidateContextMenuAction
  ) {}

  public func candidateToolTip(shortened: Bool) -> String { "" }

  public func resetCandidateWindowOrigin() {}

  public func checkIsMacroTokenResult(_ index: Int) -> Bool { false }

  @discardableResult
  public func reverseLookup(for value: String) -> [String] { [] }

  /// 重設輸入調度模組，會將當前尚未遞交的內容遞交出去。
  public func resetInputHandler(forceComposerCleanup forceCleanup: Bool = false) {
    guard let inputHandler = inputHandler else { return }
    var textToCommit = ""
    // 過濾掉尚未完成拼寫的注音。
    let sansReading: Bool =
      (state.type == .ofInputting)
        && (inputHandler.prefs.trimUnfinishedReadingsOnCommit || forceCleanup)
    if state.hasComposition {
      textToCommit = inputHandler.generateStateOfInputting(
        sansReading: sansReading
      ).displayedText
    }
    // 威注音不再在這裡對 IMKTextInput 客體黑名單當中的應用做資安措施。
    // 有相關需求者，請在切換掉輸入法或者切換至新的客體應用之前敲一下 Shift+Delete。
    switchState(.ofCommitting(textToCommit: textToCommit))
  }
}
