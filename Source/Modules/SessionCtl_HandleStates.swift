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

public extension SessionCtl {
  /// 針對傳入的新狀態進行調度、且將當前會話控制器的狀態切換至新狀態。
  ///
  /// 先將舊狀態單獨記錄起來，再將新舊狀態作為參數，
  /// 根據新狀態本身的狀態種類來判斷交給哪一個專門的函式來處理。
  /// - Remark: ⚠️ 任何在這個函式當中被改變的變數均不得是靜態 (Static) 變數。
  /// 針對某一個客體的 deactivateServer() 可能會在使用者切換到另一個客體應用
  /// 且開始敲字之後才會執行。這個過程會使得不同的 SessionCtl 副本之間出現
  /// 不必要的互相干涉、打斷彼此的工作。
  /// - Note: 本來不用這麼複雜的，奈何 Swift Protocol 不允許給參數指定預設值。
  /// - Parameter newState: 新狀態。
  func switchState(_ newState: IMEStateProtocol) {
    handle(state: newState, replace: true)
  }

  /// 針對傳入的新狀態進行調度。
  ///
  /// 先將舊狀態單獨記錄起來，再將新舊狀態作為參數，
  /// 根據新狀態本身的狀態種類來判斷交給哪一個專門的函式來處理。
  /// - Remark: ⚠️ 任何在這個函式當中被改變的變數均不得是靜態 (Static) 變數。
  /// 針對某一個客體的 deactivateServer() 可能會在使用者切換到另一個客體應用
  /// 且開始敲字之後才會執行。這個過程會使得不同的 SessionCtl 副本之間出現
  /// 不必要的互相干涉、打斷彼此的工作。
  /// - Parameters:
  ///   - newState: 新狀態。
  ///   - replace: 是否取代現有狀態。
  func handle(state newState: IMEStateProtocol, replace: Bool) {
    var previous = state
    if replace { state = newState }
    switch newState.type {
    case .ofDeactivated:
      // 這裡移除一些處理，轉而交給 commitComposition() 代為執行。
      // 這裡不需要 clearInlineDisplay() ，否則會觸發無限迴圈。
      // 對於 IMK 選字窗的顯示狀態糾正的行為交給 inputMode.didSet() 來處理。
      hidePalettes()
      inputHandler?.clear()
      if ![.ofAbortion, .ofEmpty].contains(previous.type), !previous.displayedText.isEmpty {
        clearInlineDisplay()
      }
    case .ofEmpty, .ofAbortion, .ofCommitting:
      innerCircle: switch newState.type {
      case .ofAbortion:
        previous = IMEState.ofEmpty()
        if replace { state = previous }
      case .ofCommitting:
        commit(text: newState.textToCommit)
        if replace { state = IMEState.ofEmpty() }
      default: break innerCircle
      }
      candidateUI?.visible = false
      // 全專案用以判斷「.Abortion」的地方僅此一處。
      if previous.hasComposition, ![.ofAbortion, .ofCommitting].contains(newState.type) {
        commit(text: previous.displayedText)
      }
      // 會在工具提示為空的時候自動消除顯示。
      showTooltip(newState.tooltip, duration: newState.tooltipDuration)
      clearInlineDisplay()
      inputHandler?.clear()
    case .ofInputting:
      candidateUI?.visible = false
      if !newState.textToCommit.isEmpty { commit(text: newState.textToCommit) }
      setInlineDisplayWithCursor()
      // 會在工具提示為空的時候自動消除顯示。
      showTooltip(newState.tooltip, duration: newState.tooltipDuration)
    case .ofMarking:
      candidateUI?.visible = false
      setInlineDisplayWithCursor()
      showTooltip(newState.tooltip)
    case .ofCandidates, .ofAssociates, .ofSymbolTable:
      tooltipInstance.hide()
      setInlineDisplayWithCursor()
      showCandidates()
    }
    // 浮動組字窗的顯示判定
    updatePopupDisplayWithCursor()
  }

  /// 浮動組字窗的顯示判定
  func updatePopupDisplayWithCursor() {
    if state.hasComposition, clientMitigationLevel >= 2 {
      updateVerticalTypingStatus()
      popupCompositionBuffer.isTypingDirectionVertical = isVerticalTyping
      popupCompositionBuffer.show(
        state: state, at: lineHeightRect(zeroCursor: true).origin
      )
    } else {
      popupCompositionBuffer.hide()
    }
  }

  /// 如果當前狀態含有「組字結果內容」、或者有選字窗內容、或者存在正在輸入的字根/讀音，則在組字區內顯示游標。
  func setInlineDisplayWithCursor() {
    var attrStr: NSAttributedString = attributedStringSecured.value
    var theRange: NSRange = attributedStringSecured.range
    // 包括早期版本的騰訊 QQNT 在內，有些客體的 client.setMarkedText() 無法正常處理 .thick 下劃線。
    mitigation: if clientMitigationLevel == 1, state.type == .ofMarking {
      if !PrefMgr.shared.disableSegmentedThickUnderlineInMarkingModeForManagedClients { break mitigation }
      let neo = NSMutableAttributedString(attributedString: attributedStringSecured.value)
      let rangeNeo = NSRange(location: 0, length: neo.string.utf16.count)
      neo.setAttributes(
        mark(forStyle: kTSMHiliteSelectedConvertedText, at: rangeNeo)
          as? [NSAttributedString.Key: Any]
          ?? [.underlineStyle: NSUnderlineStyle.thick.rawValue], range: rangeNeo
      )
      attrStr = neo
      theRange = NSRange.zero
    }
    /// 所謂選區「selectionRange」，就是「可見游標位置」的位置，只不過長度
    /// 是 0 且取代範圍（replacementRange）為「NSNotFound」罷了。
    /// 也就是說，內文組字區該在哪裡出現，得由客體軟體來作主。
    doSetMarkedText(attrStr, selectionRange: theRange)
  }

  /// 在處理某些「沒有組字區內容顯示」且「不需要攔截某些按鍵處理」的狀態時使用的函式，會清空螢幕上顯示的組字區。
  func clearInlineDisplay() {
    doSetMarkedText(
      NSAttributedString(), selectionRange: NSRange.zero
    )
  }

  /// 遞交組字區內容。
  /// 注意：必須在 IMK 的 commitComposition 函式當中也間接或者直接執行這個處理。
  private func commit(text: String) {
    let text = text.trimmingCharacters(in: .newlines)
    let buffer = ChineseConverter.kanjiConversionIfRequired(text)
    if isServingIMEItself {
      DispatchQueue.main.async {
        guard let client = self.client() else { return }
        client.insertText(
          buffer, replacementRange: NSRange.notFound
        )
      }
    } else {
      guard let client = client() else { return }
      client.insertText(
        buffer, replacementRange: NSRange.notFound
      )
    }
  }

  /// 把 setMarkedText 包裝一下，按需啟用 GCD。
  /// - Parameters:
  ///   - string: 要設定顯示的內容，必須得是 NSAttributedString（否則不顯示下劃線）且手動定義過下劃線。
  ///   - selectionRange: 高亮選區範圍。該範圍只會在下劃線為 .thick 的時候在某些客體軟體當中生效。
  ///   - replacementRange: 要替換掉的既有文本的範圍。
  ///   警告：replacementRange 不要亂填，否則會在 Microsoft Office 等軟體內出現故障。
  ///   該功能是給某些想設計「重新組字」功能的輸入法設計的，但一字多音的漢語在注音/拼音輸入這方面不適用這個輸入法特性。
  func doSetMarkedText(
    _ string: NSAttributedString, selectionRange: NSRange,
    replacementRange: NSRange = .notFound
  ) {
    if isServingIMEItself || !isActivated {
      DispatchQueue.main.async {
        guard let client = self.client() else { return }
        client.setMarkedText(string, selectionRange: selectionRange, replacementRange: replacementRange)
      }
    } else {
      guard let client = client() else { return }
      client.setMarkedText(string, selectionRange: selectionRange, replacementRange: replacementRange)
    }
  }
}
