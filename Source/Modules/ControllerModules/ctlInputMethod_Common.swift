// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

extension ctlInputMethod {
  /// 完成 handle() 函式本該完成的內容，但去掉了與 IMK 選字窗有關的判斷語句。
  /// 這樣分開處理很有必要，不然 handle() 函式會陷入無限迴圈。
  /// - Parameter event: 由 IMK 選字窗接收的裝置操作輸入事件。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  func commonEventHandler(_ event: NSEvent) -> Bool {
    // 用 Shift 開關半形英數模式，僅對 macOS 10.15 及之後的 macOS 有效。
    let shouldUseHandle =
      (IME.arrClientShiftHandlingExceptionList.contains(clientBundleIdentifier)
        || mgrPrefs.shouldAlwaysUseShiftKeyAccommodation)
    if #available(macOS 10.15, *) {
      if ShiftKeyUpChecker.check(event), !mgrPrefs.disableShiftTogglingAlphanumericalMode {
        if !shouldUseHandle || (!rencentKeyHandledByKeyHandler && shouldUseHandle) {
          NotifierController.notify(
            message: String(
              format: "%@%@%@", NSLocalizedString("Alphanumerical Mode", comment: ""), "\n",
              toggleASCIIMode()
                ? NSLocalizedString("NotificationSwitchON", comment: "")
                : NSLocalizedString("NotificationSwitchOFF", comment: "")
            )
          )
        }
        if shouldUseHandle {
          rencentKeyHandledByKeyHandler = false
        }
        return false
      }
    }

    /// 沒有文字輸入客體的話，就不要再往下處理了。
    guard client() != nil else { return false }

    /// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 KeyHandler 內修復。
    /// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    /// 同時注意：必須在 event.type == .flagsChanged 結尾插入 return false，
    /// 否則，每次處理這種判斷時都會觸發 NSInternalInconsistencyException。
    if event.type == .flagsChanged { return false }

    // 準備修飾鍵，用來判定要新增的詞彙是否需要賦以非常低的權重。
    ctlInputMethod.areWeNerfing = event.modifierFlags.contains([.shift, .command])

    var input = InputSignal(event: event, isVerticalTyping: isVerticalTyping)
    input.isASCIIModeInput = isASCIIMode

    // 無法列印的訊號輸入，一概不作處理。
    // 這個過程不能放在 KeyHandler 內，否則不會起作用。
    if !input.charCode.isPrintable {
      return false
    }

    /// 將按鍵行為與當前輸入法狀態結合起來、交給按鍵調度模組來處理。
    /// 再根據返回的 result bool 數值來告知 IMK「這個按鍵事件是被處理了還是被放行了」。
    /// 這裡不用 keyHandler.handleCandidate() 是因為需要針對聯想詞輸入狀態做額外處理。
    let result = keyHandler.handle(input: input, state: state) { newState in
      self.handle(state: newState)
    } errorCallback: {
      clsSFX.beep()
    }
    if shouldUseHandle {
      rencentKeyHandledByKeyHandler = result
    }
    return result
  }
}
