// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
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

// MARK: - Mock IMEState

/// Mock implementation of IMEState for testing purposes
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

  #if canImport(Darwin)
  public func attributedString(for session: IMKInputControllerProtocol) -> NSAttributedString {
    // Simplified implementation for testing
    return NSAttributedString(string: data.displayedText)
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
}

// MARK: - Mock Session Protocol

/// Mock session protocol for testing
public protocol MockSessionProtocol: AnyObject {
  var state: MockIMEState { get set }
  func switchState(_ newState: MockIMEState)
}

// MARK: - Mock InputHandler

/// Mock implementation of InputHandler for testing purposes
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
    self.assembler.maxSegLength = prefs.maxCandidateLength
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

// MARK: - Mock Session

/// Mock session implementation for testing
public class MockSession: MockSessionProtocol {
  // MARK: Lifecycle

  public init() {
    self.state = MockIMEState()
  }

  // MARK: Public

  public var state: MockIMEState = MockIMEState()
  public var inputHandler: MockInputHandler?

  public func switchState(_ newState: MockIMEState) {
    state = newState
  }
}
