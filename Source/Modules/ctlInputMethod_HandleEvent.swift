// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import Shared

extension ctlInputMethod {
  /// 完成 handle() 函式本該完成的內容，但去掉了與 IMK 選字窗有關的判斷語句。
  /// 這樣分開處理很有必要，不然 handle() 函式會陷入無限迴圈。
  /// - Parameter event: 由 IMK 選字窗接收的裝置操作輸入事件。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  func commonEventHandler(_ event: NSEvent) -> Bool {
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
  func imkCandidatesEventPreHandler(event eventToDeal: NSEvent) -> Bool? {
    // IMK 選字窗處理，當且僅當啟用了 IMK 選字窗的時候才會生效。
    // 這樣可以讓 interpretKeyEvents() 函式自行判斷：
    // - 是就地交給 imkCandidates.interpretKeyEvents() 處理？
    // - 還是藉由 delegate 扔回 ctlInputMethod 給 KeyHandler 處理？
    if let imkCandidates = ctlInputMethod.ctlCandidateCurrent as? ctlCandidateIMK, imkCandidates.visible {
      let event: NSEvent = ctlCandidateIMK.replaceNumPadKeyCodes(target: eventToDeal) ?? eventToDeal

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
      if let newChar = ctlCandidateIMK.defaultIMKSelectionKey[event.keyCode],
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

  func imkCandidatesEventSubHandler(event: NSEvent) -> Bool {
    let eventArray = [event]
    guard let imkC = Self.ctlCandidateCurrent as? ctlCandidateIMK else { return false }
    if event.isEsc || event.isBackSpace || event.isDelete || (event.isShiftHold && !event.isSpace) {
      return commonEventHandler(event)
    } else if event.isSymbolMenuPhysicalKey {
      // 符號鍵的行為是固定的，不受偏好設定影響。
      switch imkC.currentLayout {
        case .horizontal: _ = event.isShiftHold ? imkC.moveUp(self) : imkC.moveDown(self)
        case .vertical: _ = event.isShiftHold ? imkC.moveLeft(self) : imkC.moveRight(self)
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
      if let newChar = ctlCandidateIMK.defaultIMKSelectionKey[event.keyCode] {
        /// 根據 KeyCode 重新換算一下選字鍵的 NSEvent，糾正其 Character 數值。
        /// 反正 IMK 選字窗目前也沒辦法修改選字鍵。
        let newEvent = event.reinitiate(characters: newChar)
        if let newEvent = newEvent {
          if PrefMgr.shared.useSCPCTypingMode, state.type == .ofAssociates {
            // 註：input.isShiftHold 已經在 ctlInputMethod.handle() 內處理，因為在那邊處理才有效。
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
