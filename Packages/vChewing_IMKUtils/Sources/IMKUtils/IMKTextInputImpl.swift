// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(InputMethodKit)

  import InputMethodKit

  extension Optional where Wrapped == IMKTextInput {
    /// Constant for IMKTextOrientationName
    /// A constant string used to reference text orientation for IMKTextInput.
    public static var imkTextOrientationName: String { "IMKTextOrientationName" }

    public func updateCurrentTextInputDirection(isVertical isVerticalTyping: inout Bool) {
      guard let client = self else {
        isVerticalTyping = false
        return
      }
      var textFrame = CGRect.zero
      let attributes: [AnyHashable: Any]? = client.attributes(
        forCharacterIndex: 0, lineHeightRectangle: &textFrame
      )
      let result = (attributes?[Self.imkTextOrientationName] as? NSNumber)?.intValue == 0 || false
      isVerticalTyping = result
    }
  }

  extension IMKTextInput {
    public func lineHeightRect(u16Cursor: Int) -> CGRect {
      var lineHeightRect = CGRect.zero
      var u16Cursor = u16Cursor
      // iMessage 的話，據此算出來的 lineHeightRect 結果的橫向座標起始點不準確。目前無解。
      while lineHeightRect.origin == .zero, u16Cursor >= 0 {
        _ = attributes(
          forCharacterIndex: u16Cursor, lineHeightRectangle: &lineHeightRect
        )
        u16Cursor -= 1
      }
      return lineHeightRect
    }
  }

#endif
