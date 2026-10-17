// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

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

  /// 跨模組注入：清除 Trie 查詢快取的回呼閉包。
  /// 由 MainAssembly 注入，LibVanguard 層不直接依賴 LXMgr。
  var trieCacheFlushHandler: (() -> ())? { get set }
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
    if debugLogCondition || OSUtils.isRunningUnitTests {
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
        // 正規化時須帶上暫定標記：客體尚未見過此狀態，換成非暫定之 `.ofEmpty()` 的話，
        // 本輪之結算（`settleProvisionalStateIfNeeded()`）將無從認出而未補寫顯示。
        state = .ofEmpty(isProvisional: state.data.isProvisional)
      }
    case .ofInputting:
      commit(text: next.textToCommit, clearDisplayBeforeCommit: true)
    case .ofMarking: break
    case .ofAssociates, .ofCandidates, .ofSymbolTable:
      showTooltip(nil)
    }
    // 先讓客體收到本狀態的內文組字區內容，再擺放各面板：
    // Tooltip 與選字窗之錨定皆以「客體對其內文組字區某座標所量得的行高矩形」為準
    // （`attributesForCharacterIndex:lineHeightRectangle:`，索引係相對於內文組字區）。
    // 若搶在 `updateCompositionBufferDisplay()` 之前量測，客體的內文組字區還是上一個
    // 狀態的內容——此時傳入本狀態的索引即屬越界，客體將無從量得而回報無效值
    // （`clientLineHeightRectForU16CursorPos:` 對無效值會逐位遞減探測，遂一律退回至
    // 前一個字元之座標）；症狀即為「面板擺在應有位置後方隔著一個字元的距離」。
    // 暫定狀態（見 `ofAbortion(isProvisional:)`）刻意不寫客體之組字區顯示：本輪事件尚未派送
    // 完畢，此刻之內容多半旋即被同一輪之新狀態取代，寫入徒生「組字結束旋即重新開始」之
    // 閃爍（macOS 26 之客體會白跑一輪 deactivate／reactivate，舊版 Spotlight 則顯殘影）。
    // 補寫之責落在派送結束時之結算：`settleProvisionalStateIfNeeded()`。
    if !state.data.isProvisional {
      updateCompositionBufferDisplay()
    }
    toggleCandidateUIVisibility(state.isCandidateContainer)
    showTooltip(
      state.tooltip,
      colorState: state.data.tooltipColorState,
      duration: state.tooltipDuration
    )
  }

  // MARK: settleProvisionalStateIfNeeded

  /// 結算暫定狀態：當前狀態若為「尚未知會客體」之暫定者，則切換至 `.ofEmpty()`，使
  /// `switchState` 補寫客體之組字區顯示。
  ///
  /// 暫定狀態由 `ofAbortion(isProvisional:)` 一族生成（`switchState` 會將其正規化為帶標記之
  /// `.ofEmpty()`），專供「同一輪事件內先作廢、後落本鍵」之場合——目前唯一生成處為
  /// `Typewriter_Dualpin.delegateToBPMF`。各宿主之事件入口應於派送結束時呼叫本函式：
  /// 不結算的話，暫定狀態雖無害，客體卻會停在上一輪之顯示而不知所終。
  public func settleProvisionalStateIfNeeded() {
    guard state.data.isProvisional else { return }
    switchState(.ofEmpty())
  }

  // MARK: resetInputHandler

  /// 重設輸入調度模組，會將當前尚未遞交的內容遞交出去。
  /// - Parameters:
  ///   - forceComposerCleanup: 是否強制清空注拼槽（即使有未完成拼寫的讀音）。
  ///   - commitExisting: 設為 `false` 時僅切換至 Empty 狀態、不提交既有內容。
  public func resetInputHandler(
    forceComposerCleanup: Bool = false,
    commitExisting: Bool = true,
    flushCaches: Bool = false
  ) {
    if flushCaches { trieCacheFlushHandler?() }
    guard let inputHandler else { return }
    // 閂滯態不越出輸入會話之邊界：本函式為「輸入調度模組重設」之共同入口
    // （繁簡切換、`commitComposition()`、輸入法關閉、`performServerDeactivation()` 等皆經此），
    // 故一律靜默解除。
    inputHandler.releaseLatchedAlnumState(announce: false)
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

// MARK: - 狂拼模式共用判定（Furious Typing Common Gates）

extension SessionCoreProtocol {
  /// 狂拼 copilot 候選窗是否可見：Inputting 狀態、附帶候選清單、且注拼槽尚有未完成
  /// 拼裝的拼音字母流（`inputHandler.hasFuriousFrontPending`）。
  public var isFuriousCopilotCandidateWindowVisible: Bool {
    state.type == .ofInputting && state.isCandidateContainer
      && (inputHandler?.hasFuriousFrontPending ?? false)
  }
}
