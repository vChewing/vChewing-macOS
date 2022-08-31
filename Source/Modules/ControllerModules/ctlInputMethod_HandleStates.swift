// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - 狀態調度 (State Handling)

extension ctlInputMethod {
  /// 針對傳入的新狀態進行調度。
  ///
  /// 先將舊狀態單獨記錄起來，再將新舊狀態作為參數，
  /// 根據新狀態本身的狀態種類來判斷交給哪一個專門的函式來處理。
  /// - Parameter newState: 新狀態。
  func handle(state newState: InputStateProtocol) {
    let prevState = state
    state = newState

    switch newState {
      case let newState as InputState.Deactivated:
        handle(state: newState, previous: prevState)
      case let newState as InputState.Empty:
        handle(state: newState, previous: prevState)
      case let newState as InputState.EmptyIgnoringPreviousState:
        handle(state: newState, previous: prevState)
      case let newState as InputState.Committing:
        handle(state: newState, previous: prevState)
      case let newState as InputState.Inputting:
        handle(state: newState, previous: prevState)
      case let newState as InputState.Marking:
        handle(state: newState, previous: prevState)
      case let newState as InputState.ChoosingCandidate:
        handle(state: newState, previous: prevState)
      case let newState as InputState.AssociatedPhrases:
        handle(state: newState, previous: prevState)
      case let newState as InputState.SymbolTable:
        handle(state: newState, previous: prevState)
      default: break
    }
  }

  /// 針對受 .NotEmpty() 管轄的非空狀態，在組字區內顯示游標。
  func setInlineDisplayWithCursor() {
    guard let client = client() else { return }
    if let state = state as? InputState.AssociatedPhrases {
      client.setMarkedText(
        state.attributedString, selectionRange: NSRange(location: 0, length: 0),
        replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
      )
      return
    }

    guard let state = state as? InputState.NotEmpty else {
      clearInlineDisplay()
      return
    }

    var identifier: AnyObject {
      switch IME.currentInputMode {
        case InputMode.imeModeCHS:
          if #available(macOS 12.0, *) {
            return "zh-Hans" as AnyObject
          }
        case InputMode.imeModeCHT:
          if #available(macOS 12.0, *) {
            return (mgrPrefs.shiftJISShinjitaiOutputEnabled || mgrPrefs.chineseConversionEnabled)
              ? "ja" as AnyObject : "zh-Hant" as AnyObject
          }
        default:
          break
      }
      return "" as AnyObject
    }

    // [Shiki's Note] This might needs to be bug-reported to Apple:
    // The LanguageIdentifier attribute of an NSAttributeString designated to
    // IMK Client().SetMarkedText won't let the actual font respect your languageIdentifier
    // settings. Still, this might behaves as Apple's current expectation, I'm afraid.
    if #available(macOS 12.0, *) {
      state.attributedString.setAttributes(
        [.languageIdentifier: identifier],
        range: NSRange(
          location: 0,
          length: state.composingBuffer.utf16.count
        )
      )
    }

    /// 所謂選區「selectionRange」，就是「可見游標位置」的位置，只不過長度
    /// 是 0 且取代範圍（replacementRange）為「NSNotFound」罷了。
    /// 也就是說，內文組字區該在哪裡出現，得由客體軟體來作主。
    client.setMarkedText(
      state.attributedString, selectionRange: NSRange(location: state.cursorIndex, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
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
    let buffer = IME.kanjiConversionIfRequired(text)
    if buffer.isEmpty {
      return
    }
    client.insertText(
      buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  private func handle(state: InputState.Deactivated, previous: InputStateProtocol) {
    _ = state  // 防止格式整理工具毀掉與此對應的參數。
    ctlInputMethod.ctlCandidateCurrent.delegate = nil
    ctlInputMethod.ctlCandidateCurrent.visible = false
    ctlInputMethod.tooltipController.hide()
    if let previous = previous as? InputState.NotEmpty {
      commit(text: previous.committingBufferConverted)
    }
    clearInlineDisplay()
    // 最後一道保險
    keyHandler.clear()
  }

  private func handle(state: InputState.Empty, previous: InputStateProtocol) {
    _ = state  // 防止格式整理工具毀掉與此對應的參數。
    ctlInputMethod.ctlCandidateCurrent.visible = false
    ctlInputMethod.tooltipController.hide()
    // 全專案用以判斷「.EmptyIgnoringPreviousState」的地方僅此一處。
    if let previous = previous as? InputState.NotEmpty,
      !(state is InputState.EmptyIgnoringPreviousState)
    {
      commit(text: previous.committingBufferConverted)
    }
    // 在這裡手動再取消一次選字窗與工具提示的顯示，可謂雙重保險。
    ctlInputMethod.ctlCandidateCurrent.visible = false
    ctlInputMethod.tooltipController.hide()
    clearInlineDisplay()
    // 最後一道保險
    keyHandler.clear()
  }

  private func handle(
    state: InputState.EmptyIgnoringPreviousState, previous: InputStateProtocol
  ) {
    _ = state  // 防止格式整理工具毀掉與此對應的參數。
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    // 這個函式就是去掉 previous state 使得沒有任何東西可以 commit。
    handle(state: InputState.Empty())
  }

  private func handle(state: InputState.Committing, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlInputMethod.ctlCandidateCurrent.visible = false
    ctlInputMethod.tooltipController.hide()
    let textToCommit = state.textToCommit
    if !textToCommit.isEmpty {
      commit(text: textToCommit)
    }
    clearInlineDisplay()
    // 最後一道保險
    keyHandler.clear()
  }

  private func handle(state: InputState.Inputting, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlInputMethod.ctlCandidateCurrent.visible = false
    ctlInputMethod.tooltipController.hide()
    let textToCommit = state.textToCommit
    if !textToCommit.isEmpty {
      commit(text: textToCommit)
    }
    setInlineDisplayWithCursor()
    if !state.tooltip.isEmpty {
      show(
        tooltip: state.tooltip, composingBuffer: state.composingBuffer,
        cursorIndex: state.cursorIndex
      )
    }
  }

  private func handle(state: InputState.Marking, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlInputMethod.ctlCandidateCurrent.visible = false
    setInlineDisplayWithCursor()
    if state.tooltip.isEmpty {
      ctlInputMethod.tooltipController.hide()
    } else {
      show(
        tooltip: state.tooltip, composingBuffer: state.composingBuffer,
        cursorIndex: state.markerIndex
      )
    }
  }

  private func handle(state: InputState.ChoosingCandidate, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlInputMethod.tooltipController.hide()
    setInlineDisplayWithCursor()
    show(candidateWindowWith: state)
  }

  private func handle(state: InputState.SymbolTable, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlInputMethod.tooltipController.hide()
    setInlineDisplayWithCursor()
    show(candidateWindowWith: state)
  }

  private func handle(state: InputState.AssociatedPhrases, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlInputMethod.tooltipController.hide()
    setInlineDisplayWithCursor()
    show(candidateWindowWith: state)
  }
}
