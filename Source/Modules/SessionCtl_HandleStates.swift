// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import PopupCompositionBuffer
import Shared

// MARK: - 狀態調度 (State Handling)

extension SessionCtl {
  /// 針對傳入的新狀態進行調度。
  ///
  /// 先將舊狀態單獨記錄起來，再將新舊狀態作為參數，
  /// 根據新狀態本身的狀態種類來判斷交給哪一個專門的函式來處理。
  /// - Parameter newState: 新狀態。
  func handle(state newState: IMEStateProtocol) {
    let previous = state
    state = newState
    switch state.type {
      case .ofDeactivated:
        Self.ctlCandidateCurrent.delegate = nil
        Self.ctlCandidateCurrent.visible = false
        Self.tooltipInstance.hide()
        if previous.hasComposition {
          commit(text: previous.displayedText)
        }
        clearInlineDisplay()
        // 最後一道保險
        keyHandler.clear()
      case .ofEmpty, .ofAbortion:
        var previous = previous
        if state.type == .ofAbortion {
          state = IMEState.ofEmpty()
          previous = state
        }
        Self.ctlCandidateCurrent.visible = false
        Self.tooltipInstance.hide()
        // 全專案用以判斷「.Abortion」的地方僅此一處。
        if previous.hasComposition, state.type != .ofAbortion {
          commit(text: previous.displayedText)
        }
        // 在這裡手動再取消一次選字窗與工具提示的顯示，可謂雙重保險。
        Self.ctlCandidateCurrent.visible = false
        Self.tooltipInstance.hide()
        clearInlineDisplay()
        // 最後一道保險
        keyHandler.clear()
      case .ofCommitting:
        Self.ctlCandidateCurrent.visible = false
        Self.tooltipInstance.hide()
        let textToCommit = state.textToCommit
        if !textToCommit.isEmpty { commit(text: textToCommit) }
        clearInlineDisplay()
        // 最後一道保險
        keyHandler.clear()
      case .ofInputting:
        Self.ctlCandidateCurrent.visible = false
        Self.tooltipInstance.hide()
        let textToCommit = state.textToCommit
        if !textToCommit.isEmpty { commit(text: textToCommit) }
        setInlineDisplayWithCursor()
        if !state.tooltip.isEmpty {
          show(tooltip: state.tooltip)
        }
      case .ofMarking:
        Self.ctlCandidateCurrent.visible = false
        setInlineDisplayWithCursor()
        if state.tooltip.isEmpty {
          Self.tooltipInstance.hide()
        } else {
          show(tooltip: state.tooltip)
        }
      case .ofCandidates, .ofAssociates, .ofSymbolTable:
        Self.tooltipInstance.hide()
        setInlineDisplayWithCursor()
        showCandidates()
      default: break
    }
    // 浮動組字窗的顯示判定
    if state.hasComposition, PrefMgr.shared.clientsIMKTextInputIncapable.contains(clientBundleIdentifier) {
      Self.popupCompositionBuffer.isTypingDirectionVertical = isVerticalTyping
      Self.popupCompositionBuffer.show(
        state: state, at: lineHeightRect(zeroCursor: true).origin
      )
    } else {
      Self.popupCompositionBuffer.hide()
    }
  }

  /// 針對受 .NotEmpty() 管轄的非空狀態，在組字區內顯示游標。
  func setInlineDisplayWithCursor() {
    guard let client = client() else { return }
    if state.type == .ofAssociates {
      client.setMarkedText(
        state.data.attributedStringPlaceholder, selectionRange: NSRange(location: 0, length: 0),
        replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
      )
      return
    }

    if state.hasComposition || state.isCandidateContainer {
      /// 所謂選區「selectionRange」，就是「可見游標位置」的位置，只不過長度
      /// 是 0 且取代範圍（replacementRange）為「NSNotFound」罷了。
      /// 也就是說，內文組字區該在哪裡出現，得由客體軟體來作主。
      client.setMarkedText(
        attributedStringSecured.0, selectionRange: attributedStringSecured.1,
        replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
      )
      return
    }

    // 其它情形。
    clearInlineDisplay()
  }

  /// 在處理不受 .NotEmpty() 管轄的狀態時可能要用到的函式，會清空螢幕上顯示的內文組字區。
  /// 當 setInlineDisplayWithCursor() 在錯誤的狀態下被呼叫時，也會觸發這個函式。
  private func clearInlineDisplay() {
    guard let theClient = client() else { return }
    theClient.setMarkedText(
      "", selectionRange: NSRange(location: 0, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  /// 遞交組字區內容。
  /// 注意：必須在 IMK 的 commitComposition 函式當中也間接或者直接執行這個處理。
  private func commit(text: String) {
    guard let client = client() else { return }
    let buffer = ChineseConverter.kanjiConversionIfRequired(text)
    if buffer.isEmpty {
      return
    }
    client.insertText(
      buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }
}
