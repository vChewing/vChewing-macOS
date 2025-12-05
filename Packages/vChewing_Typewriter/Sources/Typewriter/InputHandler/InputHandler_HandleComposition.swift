// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。

import Foundation

extension InputHandlerProtocol {
  /// 用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleComposition(input: InputSignalProtocol) -> Bool? {
    // 不處理任何包含不可列印字元的訊號。
    let hardRequirementMet = !input.text.isEmpty && input.charCode.isPrintableUniChar
    switch currentTypingMethod {
    case .codePoint where hardRequirementMet:
      return CodePointTypewriter(self).handle(input)
    case .romanNumerals where hardRequirementMet:
      return RomanNumeralTypewriter(self).handle(input)
    case .haninKeyboardSymbol where [[], .shift].contains(input.keyModifierFlags):
      return HaninSymbolTypewriter(self).handle(input)
    case .vChewingFactory where hardRequirementMet && prefs.cassetteEnabled:
      return CassetteTypewriter(self).handle(input)
    case .vChewingFactory where hardRequirementMet && !prefs.cassetteEnabled:
      return PhonabetTypewriter(self).handle(input)
    default: return nil
    }
  }
}
