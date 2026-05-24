// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

// MARK: - SessionCoreProtocol

/// 所有輸入法會話（Session）的基底協議。
///
/// 宣告抽象介面（`commit`、`toggleCandidateUIVisibility` 等平台差異方法），
/// 並提供 `switchState()` 與 `resetInputHandler()` 的預設實作。
///
/// 各平台只需實作五個抽象方法：
/// `commit()` / `toggleCandidateUIVisibility()` / `showTooltip()` /
/// `getMitigatedState()` / `updateCompositionBufferDisplay()`。
///
/// 透過 `debugLogCondition` computed property 讓各平台自訂 debug log 條件。
public protocol SessionCoreProtocol: AnyObject & CtlCandidateDelegate {
  associatedtype Handler: InputHandlerProtocol
    where Handler.Session == Self
  typealias State = IMEState

  // MARK: Identity & State

  /// 僅用來決定 UI 面板先照顧哪個 Session 用，不宜用來判斷 isActivated。
  var id: UUID { get }
  /// 用以記錄當前輸入法狀態的變數。(有 DidSet)
  var state: IMEState { get set }
  var isASCIIMode: Bool { get }
  var clientMitigationLevel: Int { get }
  var ui: SessionUIProtocol? { get }

  // MARK: Handler

  /// 輸入調度模組的副本。
  var inputHandler: Handler? { get set }

  // MARK: Abstract — Platform-specific

  func updateCompositionBufferDisplay()
  func performUserPhraseOperation(addToFilter: Bool) -> Bool
  @discardableResult
  func updateVerticalTypingStatus() -> CGRect

  func toggleCandidateUIVisibility(_ newValue: Bool, refresh: Bool)
  func commit(text: String, clearDisplayBeforeCommit: Bool)
  func showTooltip(
    _ string: String?,
    colorState: TooltipColorState,
    duration: Double
  )
  func getMitigatedState(_ givenState: IMEState) -> IMEState

  // MARK: State Transition

  func switchState(_ newState: IMEState, caller: StaticString, line: Int)
}

// MARK: - Default Implementations

extension SessionCoreProtocol {
  /// Debug log 條件判斷。各平台可透過覆寫此 computed property 來自訂判斷邏輯。
  /// 預設為 `false`（不輸出 debug log）。
  /// - MockSession: 使用 `PrefMgr.sharedSansDidSetOps.isDebugModeEnabled`
  /// - Darwin Session: 使用 `prefs.isDebugModeEnabled`
  var debugLogCondition: Bool { false }

  // MARK: switchState

  /// 針對傳入的新狀態進行調度、且將當前會話控制器的狀態切換至新狀態。
  /// - Parameters:
  ///   - newState: 新狀態。
  ///   - caller: 呼叫來源（自動推導為 #function）。
  ///   - line: 呼叫行號（自動推導為 #line）。
  public func switchState(_ newState: IMEState, caller: StaticString = #function, line: Int = #line) {
    if debugLogCondition || UserDefaults.pendingUnitTests {
      let stateStr = "\(state.type.rawValue) -> \(newState.type.rawValue)"
      let callerTag = "\(caller)@[L\(line)]"
      let stack = Thread.callStackSymbols.prefix(7).joined(separator: "\n")
      vCLog("StateChanging: \(stateStr), tag: \(callerTag);\nstack: \(stack)")
    }
    // 正式處理。
    let previous = state
    let next = getMitigatedState(newState)
    state = next
    switch next.type {
    case .ofDeactivated: break // macOS 不再處理 deactivated 狀態。
    case .ofAbortion, .ofCommitting, .ofEmpty:
      if next.type == .ofCommitting {
        commit(text: next.textToCommit)
      } else if next.type == .ofEmpty, previous.hasComposition, let inputHandler {
        let textToCommit = inputHandler.committableDisplayText(
          sansReading: previous.type != .ofInputting
        )
        commit(text: textToCommit)
      }
      inputHandler?.clear()
      if state.type != .ofEmpty {
        state = .ofEmpty()
      }
    case .ofInputting:
      commit(text: next.textToCommit, clearDisplayBeforeCommit: true)
    case .ofMarking: break
    case .ofAssociates, .ofCandidates, .ofSymbolTable:
      showTooltip(nil)
    }
    showTooltip(
      state.tooltip,
      colorState: state.data.tooltipColorState,
      duration: state.tooltipDuration
    )
    toggleCandidateUIVisibility(state.isCandidateContainer)
    updateCompositionBufferDisplay()
  }

  // MARK: resetInputHandler

  /// 重設輸入調度模組，會將當前尚未遞交的內容遞交出去。
  /// - Parameters:
  ///   - forceComposerCleanup: 是否強制清空注拼槽（即使有未完成拼寫的讀音）。
  ///   - commitExisting: 設為 `false` 時僅切換至 Empty 狀態、不提交既有內容。
  public func resetInputHandler(
    forceComposerCleanup: Bool = false,
    commitExisting: Bool = true
  ) {
    guard let inputHandler else { return }
    guard commitExisting else {
      switchState(.ofEmpty())
      return
    }
    var textToCommit = ""
    let sansReading: Bool =
      (state.type == .ofInputting)
        && (inputHandler.prefs.trimUnfinishedReadingsOnCommit || forceComposerCleanup)
    if state.hasComposition {
      textToCommit = inputHandler.committableDisplayText(sansReading: sansReading)
    }
    if !inputHandler.mixedAlphanumericalBuffer.isEmpty {
      textToCommit += inputHandler.mixedAlphanumericalBuffer
    }
    switchState(.ofCommitting(textToCommit: textToCommit))
  }
}

// MARK: - Convenience Overloads

extension SessionCoreProtocol {
  public var isCurrentSession: Bool {
    id == ui?.currentSessionID
  }

  public var isServiceMenuState: Bool {
    state.type == .ofSymbolTable && state.node.containsCandidateServices
  }

  public func toggleCandidateUIVisibility(_ newValue: Bool, refresh: Bool = true) {
    toggleCandidateUIVisibility(newValue, refresh: refresh)
  }

  public func commit(text: String, clearDisplayBeforeCommit: Bool = false) {
    commit(text: text, clearDisplayBeforeCommit: clearDisplayBeforeCommit)
  }

  public func showTooltip(
    _ string: String?,
    colorState: TooltipColorState = .normal,
    duration: Double = 0
  ) {
    showTooltip(string, colorState: colorState, duration: duration)
  }
}
