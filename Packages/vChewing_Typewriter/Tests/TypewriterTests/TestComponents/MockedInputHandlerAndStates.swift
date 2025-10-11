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
        // commit(text: newState.textToCommit)
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

  public func performUserPhraseOperation(addToFilter: Bool) -> Bool { false }

  @discardableResult
  public func updateVerticalTypingStatus() -> CGRect { .zero }

  // MARK: - CtlCandidateDelegate conformance

  public func candidateController() -> CtlCandidateProtocol? { nil }

  public func candidatePairs(conv: Bool) -> [(keyArray: [String], value: String)] { [] }

  public func candidatePairSelectionConfirmed(at index: Int) {}

  public func candidatePairHighlightChanged(at index: Int) {}

  public func candidatePairRightClicked(at index: Int, action: CandidateContextMenuAction) {}

  public func candidateToolTip(shortened: Bool) -> String { "" }

  public func resetCandidateWindowOrigin() {}

  public func checkIsMacroTokenResult(_ index: Int) -> Bool { false }

  @discardableResult
  public func reverseLookup(for value: String) -> [String] { [] }
}
