// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - Facade

extension SessionProtocol {
  /// 接受所有鍵鼠事件為 NSEvent，讓輸入法判斷是否要處理、該怎樣處理。
  /// 然後再交給 InputHandler.handleEvent() 分診。
  /// - Parameters:
  ///   - event: 裝置操作輸入事件，可能會是 nil。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 回「`true`」以將該按鍵已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  public func handleNSEvent(
    _ event: NSEvent?,
    client sender: Any?
  )
    -> Bool {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。

    // 就這傳入的 NSEvent 都還有可能是 nil，Apple InputMethodKit 團隊到底在搞三小。
    // 只針對特定類型的 client() 進行處理。
    guard let event = event, sender is ClientObj else {
      resetInputHandler(forceComposerCleanup: true)
      return false
    }

    syncCurrentSessionID()

    // 用 Shift 開關半形英數模式，僅對 macOS 10.15 及之後的 macOS 有效。
    // 警告：這裡的 event 必須是原始 event 且不能被 var，否則會影響 Shift 中英模式判定。
    if ui?.shiftKeyUpChecker?.check(event) ?? false {
      toggleAlphanumericalMode()
      // Shift 處理完畢之後也有必要立刻返回處理結果。
      return true
    }

    guard let newEvent = event.copyAsKBEvent else { return false }

    switch newEvent.type {
    case .flagsChanged: return handleKeyDown(event: newEvent)
    case .keyDown:
      let result = handleKeyDown(event: newEvent)
      if result { previouslyHandledEvents.append(newEvent) }
      return result
    case .keyUp: return handleKeyUp(event: newEvent)
    }
  }

  private func handleKeyUp(event: KBEvent) -> Bool {
    guard ![.ofEmpty, .ofAbortion].contains(state.type) else { return false }
    let codes = previouslyHandledEvents.map(\.keyCode)
    if codes.contains(event.keyCode) {
      previouslyHandledEvents = previouslyHandledEvents.filter { prevEvent in
        prevEvent.keyCode != event.keyCode
      }
      return true
    }
    return false
  }

  private func handleKeyDown(event: KBEvent) -> Bool {
    // MARK: 前置處理

    // 先放過一些以 .command 觸發的熱鍵（包括剪貼簿熱鍵）。
    if state.type == .ofEmpty, event.isSingleCommandBasedLetterHotKey { return false }

    // 如果是 deactivated 狀態的話，強制糾正其為 empty()。
    if state.type == .ofDeactivated {
      state = .ofEmpty()
      return handleKeyDown(event: event)
    }

    // Caps Lock 通知與切換處理，要求至少 macOS 12 Monterey。
    if #available(macOS 12, *) {
      if event.type == .flagsChanged, event.keyCode == KeyCode.kCapsLock.rawValue {
        asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) { [weak self] in
          guard let this = self else { return }
          let isCapsLockTurnedOn = this.ui?.capsLockToggler?.isOn ?? false
          if this.prefs.shiftEisuToggleOffTogetherWithCapsLock, !isCapsLockTurnedOn,
             self?.isASCIIMode ?? false {
            self?.isASCIIMode.toggle()
          }
          self?.resetInputHandler()
          guard this.prefs.showNotificationsWhenTogglingCapsLock else { return }
          guard !this.prefs.bypassNonAppleCapsLockHandling else { return }
          let status = "NotificationSwitchRevolver".i18n
          Notifier.notify(
            message: isCapsLockTurnedOn
              ? "[Caps Lock ON] " + "Alphanumerical Input Mode".i18n + "\n" + status
              : "[Caps Lock OFF] " + "Chinese Input Mode".i18n + "\n" + status
          )
        }
      }
    }

    // 用 JIS 鍵盤的英數切換鍵來切換中英文模式。
    if event.type == .keyDown, event.isJISAlphanumericalKey {
      toggleAlphanumericalMode()
      return true // Adobe Photoshop 相容：對 JIS 英數切換鍵傳入事件一律立刻返回 true。
    }

    // MARK: 針對客體的具體處理

    /// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 InputHandler 內修復。
    /// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    /// 同時注意：必須針對 event.type == .flagsChanged 提前返回結果，
    /// 否則，每次處理這種判斷時都會因為讀取 event.characters? 而觸發 NSInternalInconsistencyException。
    if event.isFlagChanged { return true }

    /// 沒有文字輸入客體的話，就不要再往下處理了。
    guard let inputHandler = inputHandler, client() != nil else { return false }

    /// 除非核心辭典有載入，否則一律蜂鳴。
    if !LMMgr.isCoreDBConnected {
      if (event as InputSignalProtocol).isReservedKey { return false }
      var newState: State = .ofEmpty()
      newState.tooltip = "Factory dictionary not loaded yet.".i18n
      newState.tooltipDuration = 1.85
      newState.data.tooltipColorState = .redAlert
      switchState(newState)
      callError("CoreLM not loaded yet.")
      return true
    }

    var eventToDeal = event

    // 如果是方向鍵輸入的話，就想辦法帶上標記資訊、來說明當前是縱排還是橫排。
    if event.isUp || event.isDown || event.isLeft || event.isRight {
      updateVerticalTypingStatus() // 檢查當前環境是否是縱排輸入。
      eventToDeal = event
        .reinitiate(charactersIgnoringModifiers: isVerticalTyping ? "Vertical" : "Horizontal")
    }

    // 使 NSEvent 自翻譯，這樣可以讓 Emacs NSEvent 變成標準 NSEvent。
    // 注意不要針對 Empty 空狀態使用這個轉換，否則會使得相關組合鍵第交出垃圾字元。
    if eventToDeal.isEmacsKey {
      if state.type == .ofEmpty { return false }
      let verticalProcessing = (state.isCandidateContainer) ? isVerticalCandidateWindow :
        isVerticalTyping
      eventToDeal = eventToDeal.convertFromEmacsKeyEvent(isVerticalContext: verticalProcessing)
    }

    // JKHL 鍵翻選字窗行列處理：將組字區游標移動鍵（JK 或 HL）轉換為對應的翻行列鍵（方向鍵）。
    if state.isCandidateContainer, eventToDeal.keyModifierFlags.isEmpty {
      let behavior = prefs.candidateStateJKHLBehavior
      // behavior == 1: JK 移動游標，HL 翻行列
      // behavior == 2: HL 移動游標，JK 翻行列
      let rowFlippingKeyCodes: [UInt16] = behavior == 1 ? [4, 37] : (behavior == 2 ? [38, 40] : [])
      if rowFlippingKeyCodes.contains(eventToDeal.keyCode) {
        // 根據候選窗口佈局（橫向/縱向）決定轉換為哪個方向鍵
        let isVertical = isVerticalCandidateWindow
        let newKeyCode: UInt16
        switch eventToDeal.keyCode {
        case 38: newKeyCode = isVertical ? 125 : 124 // J -> Down(橫) / Right(縱)
        case 40: newKeyCode = isVertical ? 126 : 123 // K -> Up(橫) / Left(縱)
        case 4: newKeyCode = isVertical ? 123 : 126 // H -> Left(橫) / Up(縱)
        case 37: newKeyCode = isVertical ? 124 : 125 // L -> Right(橫) / Down(縱)
        default: newKeyCode = eventToDeal.keyCode
        }
        eventToDeal = eventToDeal.reinitiate(keyCode: newKeyCode)
      }
    }

    // 在啟用注音排列而非拼音輸入的情況下，強制將當前鍵盤佈局翻譯為美規鍵盤（或指定的其它鍵盤佈局）。
    if !inputHandler.isComposerUsingPinyin || IMKHelper.isDynamicBasicKeyboardLayoutEnabled {
      var defaultLayout = LatinKeyboardMappings(rawValue: prefs.basicKeyboardLayout) ??
        .qwerty
      if let parser = KeyboardParser(rawValue: prefs.keyboardParser) {
        switch parser {
        case .ofDachen26, .ofFakeSeigyou, .ofIBM, .ofSeigyou, .ofStandard: defaultLayout = .qwerty
        default: break
        }
      }
      eventToDeal = eventToDeal.layoutTranslated(to: defaultLayout)
    }

    // Apple 數字小鍵盤處理
    if eventToDeal.isNumericPadKey,
       let eventCharConverted = eventToDeal.characters?.applyingTransformFW2HW(reverse: false) {
      eventToDeal = eventToDeal.reinitiate(characters: eventCharConverted)
    } else if [.ofEmpty, .ofInputting].contains(state.type), eventToDeal.isMainAreaNumKey,
              !eventToDeal.isCommandHold, !eventToDeal.isControlHold, eventToDeal.isOptionHold {
      // Alt(+Shift)+主鍵盤區數字鍵 預先處理
      eventToDeal = eventToDeal.reinitiate(characters: eventToDeal.mainAreaNumKeyChar)
    }

    // 準備修飾鍵，用來判定要新增的詞彙是否需要賦以非常低的權重。
    Self.areWeNerfing = eventToDeal.commonKeyModifierFlags == [.shift, .command]

    // 此時追加檢查選字窗是否有在正常顯示。
    if state.isCandidateContainer, !(ui?.candidateUI?.visible ?? false) {
      toggleCandidateUIVisibility(true, refresh: true)
    }

    /// 直接交給 commonEventHandler 來處理。
    let result = inputHandler.triageInput(event: eventToDeal)
    if !result {
      // 除非是 .ofMarking 狀態，否則讓某些不用去抓的按鍵起到「取消工具提示」的作用。
      if [.ofEmpty].contains(state.type) { ui?.tooltipUI?.hide() }

      // 將 Apple 動態鍵盤佈局的 RAW 輸出轉為 ABC 輸出，除非轉換結果與轉換前的內容一致。
      if IMKHelper.isDynamicBasicKeyboardLayoutEnabled, event.text != eventToDeal.text {
        switchState(.ofCommitting(textToCommit: eventToDeal.text))
        return true
      }
    }

    return result
  }

  /// 切換英數模式開關。
  private func toggleAlphanumericalMode() {
    let status = "NotificationSwitchRevolver".i18n
    let oldValue = isASCIIMode
    let newValue = isASCIIMode.toggled()
    Notifier.notify(
      message: newValue
        ? "Alphanumerical Input Mode".i18n + "\n" + status
        : "Chinese Input Mode".i18n + "\n" + status
    )
    if var cplk = ui?.capsLockToggler {
      if prefs.shiftEisuToggleOffTogetherWithCapsLock, oldValue, !newValue,
         cplk.isOn {
        cplk.isOn.toggle()
      }
    }
  }
}
