// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CocoaExtension
import IMKUtils
import InputMethodKit
import NotifierUI
import Shared

// MARK: - Facade

extension SessionCtl {
  /// 接受所有鍵鼠事件為 NSEvent，讓輸入法判斷是否要處理、該怎樣處理。
  /// - Parameters:
  ///   - event: 裝置操作輸入事件，可能會是 nil。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  @objc(handleEvent:client:) public override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。

    // MARK: 前置處理

    // 如果是 deactivated 狀態的話，強制糾正其為 empty()。
    if let client = client(), state.type == .ofDeactivated {
      handle(state: IMEState.ofEmpty())
      return handle(event, client: client)
    }

    // 更新此時的靜態狀態標記。
    state.isASCIIMode = isASCIIMode
    state.isVerticalTyping = isVerticalTyping

    // 就這傳入的 NSEvent 都還有可能是 nil，Apple InputMethodKit 團隊到底在搞三小。
    // 只針對特定類型的 client() 進行處理。
    guard let event = event, sender is IMKTextInput else {
      resetKeyHandler()
      return false
    }

    // Caps Lock 通知與切換處理，要求至少 macOS 12 Monterey。
    if #available(macOS 12, *) {
      if event.type == .flagsChanged, event.keyCode == KeyCode.kCapsLock.rawValue {
        DispatchQueue.main.async {
          let isCapsLockTurnedOn = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock)
          let status = NSLocalizedString("NotificationSwitchASCII", comment: "")
          if PrefMgr.shared.showNotificationsWhenTogglingCapsLock {
            Notifier.notify(
              message: isCapsLockTurnedOn
                ? "Caps Lock" + NSLocalizedString("Alphanumerical Input Mode", comment: "") + "\n" + status
                : NSLocalizedString("Chinese Input Mode", comment: "") + "\n" + status
            )
          }
          self.isASCIIMode = isCapsLockTurnedOn
        }
      }
    }

    // 用 Shift 開關半形英數模式，僅對 macOS 10.15 及之後的 macOS 有效。
    let shouldUseShiftToggleHandle: Bool = {
      switch PrefMgr.shared.shiftKeyAccommodationBehavior {
        case 0: return false
        case 1: return Shared.arrClientShiftHandlingExceptionList.contains(clientBundleIdentifier)
        case 2: return true
        default: return false
      }
    }()

    /// 警告：這裡的 event 必須是原始 event 且不能被 var，否則會影響 Shift 中英模式判定。
    if #available(macOS 10.15, *) {
      if Self.theShiftKeyDetector.check(event), !PrefMgr.shared.disableShiftTogglingAlphanumericalMode {
        if !shouldUseShiftToggleHandle || (!rencentKeyHandledByKeyHandlerEtc && shouldUseShiftToggleHandle) {
          let status = NSLocalizedString("NotificationSwitchASCII", comment: "")
          Notifier.notify(
            message: isASCIIMode.toggled()
              ? NSLocalizedString("Alphanumerical Input Mode", comment: "") + "\n" + status
              : NSLocalizedString("Chinese Input Mode", comment: "") + "\n" + status
          )
        }
        if shouldUseShiftToggleHandle {
          rencentKeyHandledByKeyHandlerEtc = false
        }
        return false
      }
    }

    // MARK: 針對客體的具體處理

    // 不再讓威注音處理由 Shift 切換到的英文模式的按鍵輸入。
    if isASCIIMode, !isCapsLocked { return false }

    /// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 KeyHandler 內修復。
    /// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    /// 同時注意：必須在 event.type == .flagsChanged 結尾插入 return false，
    /// 否則，每次處理這種判斷時都會觸發 NSInternalInconsistencyException。
    if event.type == .flagsChanged { return false }

    /// 沒有文字輸入客體的話，就不要再往下處理了。
    guard client() != nil else { return false }

    var eventToDeal = event

    // 如果是方向鍵輸入的話，就想辦法帶上標記資訊、來說明當前是縱排還是橫排。
    if event.isUp || event.isDown || event.isLeft || event.isRight {
      eventToDeal = event.reinitiate(charactersIgnoringModifiers: isVerticalTyping ? "Vertical" : "Horizontal") ?? event
    }

    // 使 NSEvent 自翻譯，這樣可以讓 Emacs NSEvent 變成標準 NSEvent。
    if eventToDeal.isEmacsKey {
      let verticalProcessing = (state.isCandidateContainer) ? state.isVerticalCandidateWindow : state.isVerticalTyping
      eventToDeal = eventToDeal.convertFromEmacsKeyEvent(isVerticalContext: verticalProcessing)
    }

    // 在啟用注音排列而非拼音輸入的情況下，強制將當前鍵盤佈局翻譯為美規鍵盤。
    if keyHandler.composer.parser.rawValue < 100 {
      eventToDeal = eventToDeal.inAppleABCStaticForm
    }

    // Apple 數字小鍵盤處理
    if eventToDeal.isNumericPadKey,
      let eventCharConverted = eventToDeal.characters?.applyingTransform(.fullwidthToHalfwidth, reverse: false)
    {
      eventToDeal = eventToDeal.reinitiate(characters: eventCharConverted) ?? eventToDeal
    }

    // 準備修飾鍵，用來判定要新增的詞彙是否需要賦以非常低的權重。
    Self.areWeNerfing = eventToDeal.modifierFlags.contains([.shift, .command])

    // IMK 選字窗處理，當且僅當啟用了 IMK 選字窗的時候才會生效。
    if let result = imkCandidatesEventPreHandler(event: eventToDeal) {
      if shouldUseShiftToggleHandle { rencentKeyHandledByKeyHandlerEtc = result }
      return result
    }

    /// 剩下的 NSEvent 直接交給 commonEventHandler 來處理。
    /// 這樣可以與 IMK 選字窗共用按鍵處理資源，維護起來也比較方便。
    let result = commonEventHandler(eventToDeal)
    if shouldUseShiftToggleHandle {
      rencentKeyHandledByKeyHandlerEtc = result
    }
    return result
  }
}

// MARK: - Private functions

extension SessionCtl {
  /// 完成 handle() 函式本該完成的內容，但去掉了與 IMK 選字窗有關的判斷語句。
  /// 這樣分開處理很有必要，不然 handle() 函式會陷入無限迴圈。
  /// - Parameter event: 由 IMK 選字窗接收的裝置操作輸入事件。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  private func commonEventHandler(_ event: NSEvent) -> Bool {
    // 無法列印的訊號輸入，一概不作處理。
    // 這個過程不能放在 KeyHandler 內，否則不會起作用。
    if !event.charCode.isPrintable { return false }

    /// 將按鍵行為與當前輸入法狀態結合起來、交給按鍵調度模組來處理。
    /// 再根據返回的 result bool 數值來告知 IMK「這個按鍵事件是被處理了還是被放行了」。
    /// 這裡不用 keyHandler.handleCandidate() 是因為需要針對聯想詞輸入狀態做額外處理。
    let result = keyHandler.handle(input: event, state: state) { newState in
      self.handle(state: newState)
    } errorCallback: { errorString in
      vCLog(errorString)
      IMEApp.buzz()
    }
    return result
  }

  /// 完成 handle() 函式本該完成的內容，但專門處理與 IMK 選字窗有關的判斷語句。
  /// 這樣分開處理很有必要，不然 handle() 函式會陷入無限迴圈。
  /// - Parameter event: 由 IMK 選字窗接收的裝置操作輸入事件。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  private func imkCandidatesEventPreHandler(event eventToDeal: NSEvent) -> Bool? {
    // IMK 選字窗處理，當且僅當啟用了 IMK 選字窗的時候才會生效。
    // 這樣可以讓 interpretKeyEvents() 函式自行判斷：
    // - 是就地交給 imkCandidates.interpretKeyEvents() 處理？
    // - 還是藉由 delegate 扔回 SessionCtl 給 KeyHandler 處理？
    if let imkCandidates = ctlCandidateCurrent as? CtlCandidateIMK, imkCandidates.visible {
      let event: NSEvent = CtlCandidateIMK.replaceNumPadKeyCodes(target: eventToDeal) ?? eventToDeal

      // Shift+Enter 是個特殊情形，不提前攔截處理的話、會有垃圾參數傳給 delegate 的 keyHandler 從而崩潰。
      // 所以這裡直接將 Shift Flags 清空。
      if event.isShiftHold, event.isEnter {
        guard let newEvent = event.reinitiate(modifierFlags: []) else {
          NSSound.beep()
          return true
        }

        return imkCandidatesEventSubHandler(event: newEvent)
      }

      // 聯想詞選字。
      if let newChar = CtlCandidateIMK.defaultIMKSelectionKey[event.keyCode],
        event.isShiftHold, state.type == .ofAssociates,
        let newEvent = event.reinitiate(modifierFlags: [], characters: newChar)
      {
        if #available(macOS 10.14, *) {
          imkCandidates.handleKeyboardEvent(newEvent)
        } else {
          imkCandidates.interpretKeyEvents([newEvent])
        }
        return true
      }

      return imkCandidatesEventSubHandler(event: event)
    }
    return nil
  }

  private func imkCandidatesEventSubHandler(event: NSEvent) -> Bool {
    let eventArray = [event]
    guard let imkC = ctlCandidateCurrent as? CtlCandidateIMK else { return false }
    if event.isEsc || event.isBackSpace || event.isDelete || (event.isShiftHold && !event.isSpace) {
      return commonEventHandler(event)
    } else if event.isSymbolMenuPhysicalKey {
      // 符號鍵的行為是固定的，不受偏好設定影響。
      switch imkC.currentLayout {
        case .horizontal: _ = event.isShiftHold ? imkC.moveUp(self) : imkC.moveDown(self)
        case .vertical: _ = event.isShiftHold ? imkC.moveLeft(self) : imkC.moveRight(self)
        @unknown default: break
      }
      return true
    } else if event.isSpace {
      switch PrefMgr.shared.specifyShiftSpaceKeyBehavior {
        case true: _ = event.isShiftHold ? imkC.highlightNextCandidate() : imkC.showNextPage()
        case false: _ = event.isShiftHold ? imkC.showNextPage() : imkC.highlightNextCandidate()
      }
      return true
    } else if event.isTab {
      switch PrefMgr.shared.specifyShiftTabKeyBehavior {
        case true: _ = event.isShiftHold ? imkC.showPreviousPage() : imkC.showNextPage()
        case false: _ = event.isShiftHold ? imkC.highlightPreviousCandidate() : imkC.highlightNextCandidate()
      }
      return true
    } else {
      if let newChar = CtlCandidateIMK.defaultIMKSelectionKey[event.keyCode] {
        /// 根據 KeyCode 重新換算一下選字鍵的 NSEvent，糾正其 Character 數值。
        /// 反正 IMK 選字窗目前也沒辦法修改選字鍵。
        let newEvent = event.reinitiate(characters: newChar)
        if let newEvent = newEvent {
          if PrefMgr.shared.useSCPCTypingMode, state.type == .ofAssociates {
            // 註：input.isShiftHold 已經在 Self.handle() 內處理，因為在那邊處理才有效。
            return event.isShiftHold ? true : commonEventHandler(event)
          } else {
            if #available(macOS 10.14, *) {
              imkC.handleKeyboardEvent(newEvent)
            } else {
              imkC.interpretKeyEvents([newEvent])
            }
            return true
          }
        }
      }

      if PrefMgr.shared.useSCPCTypingMode, !event.isReservedKey {
        return commonEventHandler(event)
      }

      if state.type == .ofAssociates,
        !event.isPageUp, !event.isPageDown, !event.isCursorForward, !event.isCursorBackward,
        !event.isCursorClockLeft, !event.isCursorClockRight, !event.isSpace,
        !event.isEnter || !PrefMgr.shared.alsoConfirmAssociatedCandidatesByEnter
      {
        return commonEventHandler(event)
      }
      imkC.interpretKeyEvents(eventArray)
      return true
    }
  }
}
