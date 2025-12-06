// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - RomanNumeralTypewriter

/// 處理羅馬數字輸入狀態（Handle Roman Numeral Inputs）
@frozen
public struct RomanNumeralTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public let handler: Handler

  /// 處理羅馬數字輸入。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard !input.isReservedKey else { return nil }
    guard let session = handler.session, input.text.count == 1 else { return nil }
    let char = input.text

    func handleErrorState(msg: String) {
      var newErrorState = State.ofAbortion()
      if !msg.isEmpty {
        newErrorState.tooltip = msg
        newErrorState.tooltipDuration = 2
        newErrorState.data.tooltipColorState = .redAlert
        session.switchState(newErrorState)
      }
    }

    // 以空白鍵遞交已經組成的數字。
    if input.isSpace {
      if !handler.strCodePointBuffer.isEmpty {
        return handler.commitRomanNumeral(session: session)
      } else {
        errorCallback("CC9346D5")
        return true
      }
    }

    // 驗證輸入：首位數字必須是 1-9，其餘數字可以是 0-9
    guard char.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil else {
      handleErrorState(msg: "typingMethod.romanNumerals.error.invalidCharacter".i18n)
      errorCallback("FC7EF8CD")
      return true
    }

    // 首位數字不能是 0
    if handler.strCodePointBuffer.isEmpty, char == "0" {
      handleErrorState(msg: "typingMethod.romanNumerals.error.invalidCharacter".i18n)
      errorCallback("7B09F1E4")
      return true
    }

    // 將字元追加至緩衝區
    handler.strCodePointBuffer.append(char)

    // 檢查是否需要自動提交（第 4 個字元時）
    if handler.strCodePointBuffer.count >= 4 {
      return handler.commitRomanNumeral(session: session)
    }

    // 更新狀態並顯示當前緩衝區內容
    var updatedState = handler.generateStateOfInputting(guarded: true)
    updatedState.tooltipDuration = 0
    updatedState.tooltip = TypingMethod.romanNumerals.getTooltip(vertical: session.isVerticalTyping)
    session.switchState(updatedState)
    return true
  }
}
