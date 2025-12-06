// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - TypingMethod

public enum TypingMethod: Int, CaseIterable {
  case vChewingFactory // 自動指派: 0
  case codePoint // 自動指派: 1
  case haninKeyboardSymbol // 自動指派: 2
  case romanNumerals // 自動指派: 3

  // MARK: Internal

  mutating func revolveNext() {
    var theInt = rawValue
    theInt.revolveAsIndex(with: Self.allCases)
    guard let nextMethod = Self(rawValue: theInt) else { return }
    self = nextMethod
  }

  func getTooltip(vertical: Bool = false) -> String {
    switch self {
    case .vChewingFactory: return ""
    case .codePoint:
      var commonTerm = ContiguousArray<String>()
      commonTerm.insert("Code Point Input.".i18n, at: 0)
      if !vertical, let initials = IMEApp.currentInputMode.nonUTFEncodingInitials {
        commonTerm.insert("[\(initials)] ", at: 0)
      }
      return commonTerm.joined()
    case .haninKeyboardSymbol:
      return "\("Hanin Keyboard Symbol Input.".i18n)"
    case .romanNumerals:
      return "typingMethod.romanNumerals.tooltip".i18n
    }
  }
}

// MARK: - Handle Rotation Toggles

extension InputHandlerProtocol {
  @discardableResult
  public func revolveTypingMethod(to specifiedMethod: TypingMethod? = nil)
    -> Bool {
    guard let session = session else { return false }
    var newMethod = currentTypingMethod
    if let specified = specifiedMethod {
      newMethod = specified
    } else {
      newMethod.revolveNext()
    }
    /// 接下來這行必須這樣 defer 處理，
    /// 因為再接下來的 switch newMethod 的過程會影響到 currentTypingMethod 參數。
    defer {
      currentTypingMethod = newMethod
    }
    switch newMethod {
    case .vChewingFactory:
      session.switchState(State.ofAbortion())
      return true
    case .codePoint:
      strCodePointBuffer.removeAll()
    case .haninKeyboardSymbol: break
    case .romanNumerals:
      strCodePointBuffer.removeAll()
    }
    var updatedState = generateStateOfInputting(sansReading: true)
    session.switchState(State.ofCommitting(textToCommit: updatedState.displayedText))
    updatedState = generateStateOfInputting(guarded: true)
    updatedState.tooltipDuration = 0
    updatedState.tooltip = newMethod.getTooltip(vertical: session.isVerticalTyping)
    session.switchState(updatedState)
    return true
  }
}
