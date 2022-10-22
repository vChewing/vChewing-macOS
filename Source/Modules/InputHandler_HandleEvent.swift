// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃輸入調度模組當中用來預處理 NSEvent 的模組。

import InputMethodKit
import Shared

// MARK: - § 根據狀態調度按鍵輸入 (Handle Input with States)

extension InputHandler {
  /// 分診函式，會先確認是否是 IMK 選字窗要處理的事件、然後再決定處理步驟。
  /// - Parameter event: 由 IMK 選字窗接收的裝置操作輸入事件。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  public func handleEvent(_ event: NSEvent) -> Bool {
    imkCandidatesEventPreHandler(event: event) ?? handleInput(event: event)
  }

  /// 專門處理與 IMK 選字窗有關的判斷語句。
  /// 這樣分開處理很有必要，不然 handle() 函式會陷入無限迴圈。
  /// - Parameter event: 由 IMK 選字窗接收的裝置操作輸入事件。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  private func imkCandidatesEventPreHandler(event eventToDeal: NSEvent) -> Bool? {
    guard let delegate = delegate else { return false }

    // IMK 選字窗處理，當且僅當啟用了 IMK 選字窗的時候才會生效。
    // 這樣可以讓 interpretKeyEvents() 函式自行判斷：
    // - 是就地交給 imkCandidates.interpretKeyEvents() 處理？
    // - 還是藉由 delegate 扔回 SessionCtl 給 InputHandler 處理？
    if let imkCandidates = delegate.candidateController() as? CtlCandidateIMK, imkCandidates.visible {
      let event: NSEvent = CtlCandidateIMK.replaceNumPadKeyCodes(target: eventToDeal) ?? eventToDeal

      // Shift+Enter 是個特殊情形，不提前攔截處理的話、會有垃圾參數傳給 delegate 的 inputHandler 從而崩潰。
      // 所以這裡直接將 Shift Flags 清空。
      if event.isShiftHold, event.isEnter {
        guard let newEvent = event.reinitiate(modifierFlags: []) else {
          IMEApp.buzz()
          return true
        }

        return imkCandidatesEventSubHandler(event: newEvent)
      }

      // 聯想詞選字。
      if let newChar = CtlCandidateIMK.defaultIMKSelectionKey[event.keyCode],
        event.isShiftHold, delegate.state.type == .ofAssociates,
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
    guard let delegate = delegate else { return false }
    let eventArray = [event]
    guard let imkC = delegate.candidateController() as? CtlCandidateIMK else { return false }
    if event.isEsc || event.isBackSpace || event.isDelete || (event.isShiftHold && !event.isSpace) {
      return handleInput(event: event)
    } else if event.isSymbolMenuPhysicalKey {
      // 符號鍵的行為是固定的，不受偏好設定影響。
      switch imkC.currentLayout {
        case .horizontal: _ = event.isShiftHold ? imkC.moveUp(self) : imkC.moveDown(self)
        case .vertical: _ = event.isShiftHold ? imkC.moveLeft(self) : imkC.moveRight(self)
        @unknown default: break
      }
      return true
    } else if event.isSpace {
      switch prefs.specifyShiftSpaceKeyBehavior {
        case true: _ = event.isShiftHold ? imkC.highlightNextCandidate() : imkC.showNextPage()
        case false: _ = event.isShiftHold ? imkC.showNextPage() : imkC.highlightNextCandidate()
      }
      return true
    } else if event.isTab {
      switch prefs.specifyShiftTabKeyBehavior {
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
          if prefs.useSCPCTypingMode, delegate.state.type == .ofAssociates {
            // 註：input.isShiftHold 已經在 Self.handle() 內處理，因為在那邊處理才有效。
            return event.isShiftHold ? true : handleInput(event: event)
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

      if prefs.useSCPCTypingMode, !event.isReservedKey {
        return handleInput(event: event)
      }

      if delegate.state.type == .ofAssociates,
        !event.isPageUp, !event.isPageDown, !event.isCursorForward, !event.isCursorBackward,
        !event.isCursorClockLeft, !event.isCursorClockRight, !event.isSpace,
        !event.isEnter || !prefs.alsoConfirmAssociatedCandidatesByEnter
      {
        return handleInput(event: event)
      }
      imkC.interpretKeyEvents(eventArray)
      return true
    }
  }
}
