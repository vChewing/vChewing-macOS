// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - 狀態調度 (State Handling)

extension SessionProtocol {
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
  public func switchState(_ newState: State) {
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
  public func handle(state newState: State, replace: Bool) {
    var previous = state
    if replace {
      var newState = newState
      /// IMK 有如下限制：
      /// 1. 內文組字區要想顯示游標的話，所有下劃線的粗細必須相等。
      /// 2. 如果所有線段粗細相等的話，給 client().setMarkedText() 塞入的 selectionRange 的長度必須得是 0。
      /// 不然的話，游標會頑固地出現在內文組字區的正前方（文字輸入順序上的前方）。
      /// 3. 從 macOS 14 開始，粗細相等的相鄰下劃線會顯示成一整個線段。該行為改變恐怕是 macOS 故意所為。
      ///
      /// 於是乎，此處特地針對 .ofInputtingState 專門將內文組字區的 marker 設定到 cursor 的位置。
      /// 這是一招隔山打牛的方法，讓此時的 selectionRange 的長度必定是 0。
      if newState.type == .ofInputting, clientMitigationLevel < 2 {
        newState.data.marker = newState.data.cursor
      }
      state = newState
    }
    switch newState.type {
    case .ofDeactivated:
      // 這裡移除一些處理，轉而交給 commitComposition() 代為執行。
      inputHandler?.clear()
      if ![.ofAbortion, .ofEmpty].contains(previous.type), !previous.displayedText.isEmpty {
        clearInlineDisplay()
      }
    case .ofAbortion, .ofCommitting, .ofEmpty:
      innerCircle: switch newState.type {
      case .ofAbortion:
        previous = .ofEmpty()
        if replace { state = previous }
      case .ofCommitting:
        commit(text: newState.textToCommit)
        if replace { state = .ofEmpty() }
      default: break innerCircle
      }
      candidateUI?.visible = false
      // 全專案用以判斷「.Abortion」的地方僅此一處。
      if previous.hasComposition, ![.ofAbortion, .ofCommitting].contains(newState.type) {
        commit(text: previous.displayedText)
      }
      // 會在工具提示為空的時候自動消除顯示。
      showTooltip(
        newState.tooltip,
        colorState: newState.data.tooltipColorState,
        duration: newState.tooltipDuration
      )
      clearInlineDisplay()
      inputHandler?.clear()
    case .ofInputting:
      candidateUI?.visible = false
      if !newState.textToCommit.isEmpty {
        commit(text: newState.textToCommit)
      }
      setInlineDisplayWithCursor()
      // 會在工具提示為空的時候自動消除顯示。
      showTooltip(
        newState.tooltip,
        colorState: newState.data.tooltipColorState,
        duration: newState.tooltipDuration
      )
      if newState.isCandidateContainer { showCandidates() }
    case .ofMarking:
      candidateUI?.visible = false
      setInlineDisplayWithCursor()
      showTooltip(
        newState.tooltip,
        colorState: newState.data.tooltipColorState
      )
    case .ofAssociates, .ofCandidates, .ofSymbolTable:
      tooltipInstance.hide()
      setInlineDisplayWithCursor()
      showCandidates()
    }
    // 浮動組字窗的顯示判定
    updatePopupDisplayWithCursor()
  }

  public func updateCompositionBufferDisplay() {
    setInlineDisplayWithCursor()
    updatePopupDisplayWithCursor()
  }

  /// 浮動組字窗的顯示判定
  public func updatePopupDisplayWithCursor() {
    if state.hasComposition, clientMitigationLevel >= 2 {
      updateVerticalTypingStatus()
      popupCompositionBuffer.isTypingDirectionVertical = isVerticalTyping
      popupCompositionBuffer.sync(accent: clientAccentColor, locale: localeForFontFallbacks)
      popupCompositionBuffer.show(
        state: state, at: lineHeightRect(zeroCursor: true).origin
      )
    } else {
      popupCompositionBuffer.hide()
    }
  }

  /// 如果當前狀態含有「組字結果內容」、或者有選字窗內容、或者存在正在輸入的字根/讀音，則在組字區內顯示游標。
  public func setInlineDisplayWithCursor() {
    var attrStr: NSAttributedString = attributedStringSecured.value
    // 包括早期版本的騰訊 QQNT 在內，有些客體的 client.setMarkedText() 無法正常處理 .thick 下劃線。
    mitigation: if clientMitigationLevel == 1 {
      guard state.type == .ofMarking || state.isCandidateContainer else { break mitigation }
      if !PrefMgr.shared
        .disableSegmentedThickUnderlineInMarkingModeForManagedClients { break mitigation }
      let neo = NSMutableAttributedString(attributedString: attributedStringSecured.value)
      let rangeNeo = NSRange(location: 0, length: neo.string.utf16.count)
      neo.setAttributes(
        mark(forStyle: kTSMHiliteNoHilite, at: rangeNeo)
          as? [NSAttributedString.Key: Any]
          ?? [.underlineStyle: NSUnderlineStyle.thick.rawValue], range: rangeNeo
      )
      attrStr = neo
    }
    doSetMarkedText(attrStr)
  }

  /// 在處理某些「沒有組字區內容顯示」且「不需要攔截某些按鍵處理」的狀態時使用的函式，會清空螢幕上顯示的組字區。
  public func clearInlineDisplay() {
    doSetMarkedText(NSAttributedString())
  }

  /// 遞交組字區內容。
  /// 注意：必須在 IMK 的 commitComposition 函式當中也間接或者直接執行這個處理。
  private func commit(text: String) {
    guard !text.isEmpty else { return }
    let phE = PrefMgr.shared.phraseReplacementEnabled && text.count > 1
    var text = text.trimmingCharacters(in: .newlines)
    var replaced = false
    if phE, let queried = inputHandler?.currentLM.queryReplacementValue(key: text) {
      replaced = true
      text = queried
    }
    var buffer = ChineseConverter.kanjiConversionIfRequired(text)
    if phE, !replaced, let queried = inputHandler?.currentLM.queryReplacementValue(key: buffer) {
      buffer = ChineseConverter.kanjiConversionIfRequired(queried)
    }

    @Sendable
    func doCommit(_ theBuffer: String) {
      guard let client = client() else { return }
      client.insertText(
        theBuffer, replacementRange: replacementRange()
      )
    }

    if isServingIMEItself {
      asyncOnMain {
        doCommit(buffer)
      }
    } else {
      doCommit(buffer)
    }
  }

  /// 把 setMarkedText 包裝一下，按需啟用 GCD。
  /// - Remark: 內文組字區該在哪裡出現，得由客體軟體來作主。
  /// - Parameters:
  ///   - string: 要設定顯示的內容，必須得是 NSAttributedString（否則不顯示下劃線）且手動定義過下劃線。
  ///   警告：replacementRange 不要亂填，否則會在 Microsoft Office 等軟體內出現故障。
  ///   該功能是給某些想設計「重新組字」功能的輸入法設計的，但一字多音的漢語在注音/拼音輸入這方面不適用這個輸入法特性。
  public func doSetMarkedText(_ string: NSAttributedString, allowAsync: Bool = true) {
    // 得複製一份，因為 NSAttributedString 不支援 Sendable 特性。
    let newString = string.copy() as? NSAttributedString ?? .init(string: string.string)
    // 威注音用不到 replacementRange，所以不用檢查 replacementRange 的異動情況。
    let range = selectionRange()
    guard !(string.isEqual(to: recentMarkedText.text) && recentMarkedText.selectionRange == range)
    else { return }
    recentMarkedText.text = string
    recentMarkedText.selectionRange = range
    if allowAsync, isServingIMEItself || !isActivated {
      asyncOnMain { [weak self] in
        guard let self = self, let client = self.client() else { return }
        client.setMarkedText(
          newString,
          selectionRange: range,
          replacementRange: self.replacementRange()
        )
      }
    } else {
      guard let client = client() else { return }
      client.setMarkedText(
        string, selectionRange: range, replacementRange: replacementRange()
      )
    }
  }
}
