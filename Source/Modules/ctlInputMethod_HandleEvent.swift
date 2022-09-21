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
  func imkCandidatesEventHandler(event eventToDeal: NSEvent) -> Bool? {
    // IMK 選字窗處理，當且僅當啟用了 IMK 選字窗的時候才會生效。
    // 這樣可以讓 interpretKeyEvents() 函式自行判斷：
    // - 是就地交給 super.interpretKeyEvents() 處理？
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
        imkCandidates.interpretKeyEvents([newEvent])
        return true
      }

      // 聯想詞選字。
      if let newChar = ctlCandidateIMK.defaultIMKSelectionKey[event.keyCode],
        event.isShiftHold, isAssociatedPhrasesState,
        let newEvent = event.reinitiate(modifierFlags: [], characters: newChar)
      {
        if #available(macOS 10.14, *) {
          imkCandidates.handleKeyboardEvent(newEvent)
        } else {
          imkCandidates.superInterpretKeyEvents([newEvent])
        }
      }

      imkCandidates.interpretKeyEvents([event])
      return true
    }
    return nil
  }
}
