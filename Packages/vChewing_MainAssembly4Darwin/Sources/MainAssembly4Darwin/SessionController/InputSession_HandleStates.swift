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
  public func switchState(_ newState: State, caller: StaticString, line: Int) {
    if prefs.isDebugModeEnabled || UserDefaults.pendingUnitTests {
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
        // `commit()` 會自行完成 JIS / 康熙轉換。
        commit(text: next.textToCommit)
      } else if next.type == .ofEmpty, previous.hasComposition {
        // `commit()` 會自行完成 JIS / 康熙轉換。
        commit(text: previous.displayedText)
      }
      inputHandler?.clear()
      if state.type != .ofEmpty {
        state = .ofEmpty()
      }
    case .ofInputting:
      commit(text: next.textToCommit, clearDisplayBeforeCommit: true)
    case .ofMarking: break // 採統一後置處理。
    case .ofAssociates, .ofCandidates, .ofSymbolTable:
      showTooltip(nil)
    }
    // 會在工具提示為空的時候自動消除顯示。
    showTooltip(
      state.tooltip,
      colorState: state.data.tooltipColorState,
      duration: state.tooltipDuration
    )
    toggleCandidateUIVisibility(state.isCandidateContainer)
    updateCompositionBufferDisplay()
  }

  public func updateCompositionBufferDisplay() {
    let display: Bool? = switch state.type {
    case .ofDeactivated: nil // macOS 不處理這個狀態。
    case .ofAbortion, .ofCommitting, .ofEmpty: false
    case .ofInputting: true
    case .ofMarking: true
    case .ofAssociates, .ofCandidates, .ofSymbolTable: true
    }
    guard let display else { return }
    if display {
      setInlineDisplayWithCursor()
    } else {
      clearInlineDisplay()
    }
    updatePopupDisplayWithCursor()
  }

  /// 浮動組字窗的顯示判定
  public func updatePopupDisplayWithCursor() {
    guard isCurrentSession else { return }
    if state.hasComposition, clientMitigationLevel >= 2 {
      updateVerticalTypingStatus()
      ui?.pcb?.isTypingDirectionVertical = isVerticalTyping
      ui?.pcb?.sync(
        accent: clientAccentColor,
        locale: localeForFontFallbacks
      )
      ui?.pcb?.show(
        state: state, at: lineHeightRect(zeroCursor: true).origin
      )
    } else {
      ui?.pcb?.hide()
    }
  }

  /// 如果當前狀態含有「組字結果內容」、或者有選字窗內容、或者存在正在輸入的字根/讀音，則在組字區內顯示游標。
  public func setInlineDisplayWithCursor() {
    var attrStr: NSAttributedString = attributedStringSecured.value
    // 包括早期版本的騰訊 QQNT 在內，有些客體的 client.setMarkedText() 無法正常處理 .thick 下劃線。
    mitigation: if clientMitigationLevel == 1 {
      guard state.type == .ofMarking || state.isCandidateContainer else { break mitigation }
      if !prefs
        .disableSegmentedThickUnderlineInMarkingModeForManagedClients { break mitigation }
      let neo = NSMutableAttributedString(attributedString: attributedStringSecured.value)
      let rangeNeo = NSRange(location: 0, length: neo.string.utf16.count)
      // 不能用 .thick，否則會看不到游標；setAttributes 會替換掉既有的 attributes。
      neo.setAttributes(IMEStateData.AttrStrULStyle.single.getDict(), range: rangeNeo)
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
  public func commit(text: String, clearDisplayBeforeCommit: Bool) {
    guard !text.isEmpty else { return }
    // WeChat 相容所需。
    if clearDisplayBeforeCommit {
      clearInlineDisplay()
    }
    let phE = prefs.phraseReplacementEnabled && text.count > 1
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

    func doCommit(_ theBuffer: String) {
      guard let client = client() else { return }
      client.insertText(
        theBuffer, replacementRange: replacementRange()
      )
    }

    asyncOnMain(bypassAsync: !isServingIMEItself || UserDefaults.pendingUnitTests) {
      doCommit(buffer)
    }
  }

  /// IMK 有如下限制：
  /// 1. 內文組字區要想顯示游標的話，所有下劃線的粗細必須相等。
  /// 2. 如果所有線段粗細相等的話，給 client().setMarkedText() 塞入的 selectionRange 的長度必須得是 0。
  /// 不然的話，游標會頑固地出現在內文組字區的正前方（文字輸入順序上的前方）。
  /// 3. 從 macOS 14 開始，粗細相等的相鄰下劃線會顯示成一整個線段。該行為改變恐怕是 macOS 故意所為。
  ///
  /// 於是乎，此處特地針對 .ofInputtingState 專門將內文組字區的 marker 設定到 cursor 的位置。
  /// 這是一招隔山打牛的方法，讓此時的 selectionRange 的長度必定是 0。
  public func getMitigatedState(_ givenState: State) -> State {
    var givenState = givenState
    if givenState.type == .ofInputting, clientMitigationLevel < 2 {
      givenState.data.marker = givenState.data.cursor
    }
    return givenState
  }

  /// 把 setMarkedText 包裝一下，按需啟用 GCD。
  /// - Remark: 內文組字區該在哪裡出現，得由客體軟體來作主。
  /// - Parameters:
  ///   - string: 要設定顯示的內容，必須得是 NSAttributedString（否則不顯示下劃線）且手動定義過下劃線。
  ///   警告：replacementRange 不要亂填，否則會在 Microsoft Office 等軟體內出現故障。
  ///   該功能是給某些想設計「重新組字」功能的輸入法設計的，但一字多音的漢語在注音/拼音輸入這方面不適用這個輸入法特性。
  public func doSetMarkedText(_ string: NSAttributedString, allowAsync: Bool = true) {
    let isRecentMarkEmpty = recentMarkedText.text?.string.isEmpty ?? true
    if string.string.isEmpty, isRecentMarkEmpty {
      // No-op.
      return
    }
    // 唯音用不到 replacementRange，所以不用檢查 replacementRange 的異動情況。
    let range = attributedStringSecured.range
    guard !(string.isEqual(to: recentMarkedText.text) && recentMarkedText.selectionRange == range)
    else { return }
    recentMarkedText = (string, range)
    // 得複製一份，因為 NSAttributedString 不支援 Sendable 特性。
    let newString = string.copy() as? NSAttributedString ?? .init(string: string.string)
    var async = allowAsync && !UserDefaults.pendingUnitTests
    async = async && (isServingIMEItself || !isActivated)
    asyncOnMain(bypassAsync: !async) { [weak self] in
      guard let this = self, let client = this.client() else { return }
      client.setMarkedText(
        newString,
        selectionRange: range,
        replacementRange: this.replacementRange()
      )
    }
  }
}
