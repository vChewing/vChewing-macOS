// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SwiftExtension

// MARK: - Typing Method

public extension InputHandler {
  enum TypingMethod: Int, CaseIterable {
    case vChewingFactory // 自動指派: 0
    case codePoint // 自動指派: 1
    case haninKeyboardSymbol // 自動指派: 2

    mutating func revolveNext() {
      var theInt = rawValue
      theInt.revolveAsIndex(with: Self.allCases)
      guard let nextMethod = TypingMethod(rawValue: theInt) else { return }
      self = nextMethod
    }

    func getTooltip(vertical: Bool = false) -> String {
      switch self {
      case .vChewingFactory: return ""
      case .codePoint:
        let commonTerm = NSMutableString()
        commonTerm.insert("Code Point Input.".localized, at: 0)
        if !vertical {
          switch IMEApp.currentInputMode {
          case .imeModeCHS: commonTerm.insert("[GB] ", at: 0)
          case .imeModeCHT: commonTerm.insert("[Big5] ", at: 0)
          default: break
          }
        }
        return commonTerm.description
      case .haninKeyboardSymbol:
        return "\("Hanin Keyboard Symbol Input.".localized)"
      }
    }
  }
}

// MARK: - Handle Rotation Toggles

public extension InputHandler {
  @discardableResult func revolveTypingMethod(to specifiedMethod: TypingMethod? = nil) -> Bool {
    guard let delegate = delegate else { return false }
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
      delegate.switchState(IMEState.ofAbortion())
      return true
    case .codePoint:
      strCodePointBuffer.removeAll()
    case .haninKeyboardSymbol: break
    }
    var updatedState = generateStateOfInputting(sansReading: true)
    delegate.switchState(IMEState.ofCommitting(textToCommit: updatedState.displayedText))
    updatedState = generateStateOfInputting(guarded: true)
    updatedState.tooltipDuration = 0
    updatedState.tooltip = newMethod.getTooltip(vertical: delegate.isVerticalTyping)
    delegate.switchState(updatedState)
    return true
  }
}
