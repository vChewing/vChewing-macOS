// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

@_exported import IMKSwiftModernHeaders

// MARK: - IMKInputSessionController + IMKClientProxyProtocol

extension IMKInputSessionController: IMKClientProxyProtocol {}

// MARK: - IMKClientProxyProtocol

@objc
public protocol IMKClientProxyProtocol: AnyObject {
  func hasClient() -> Bool
  func clientTextInsertion(with: String, replacementRange: NSRange)
  func clientMarkedTextSetup(
    with text: NSAttributedString,
    selectionRange: NSRange,
    replacementRange: NSRange
  )
  func clientBundleIdentifier() -> String?
  func clientSelectMode(withModeIdentifier: String)
  func clientOverrideKeyboard(withName: String)

  func clientAttributesForCharacterIndex(
    atU16Pos: UInt,
    lineHeightRectangle: UnsafeMutablePointer<NSRect>
  ) -> [AnyHashable: Any]?

  func clientLineHeightRect(forU16CursorPos: UInt) -> CGRect
  func clientFirstRect(
    forCharacterRange: NSRange,
    actualRange: UnsafeMutablePointer<NSRange>?
  ) -> CGRect

  func clientString(
    fromRange range: NSRange,
    actualRange: UnsafeMutablePointer<NSRange>?
  ) -> String?

  func clientUniqueIdentifierString() -> String?
  func clientSupportsUnicode() -> Bool
  func clientValidAttributesForMarkedText() -> [Any]?

  func clientCharacterIndex(
    forPoint point: CGPoint,
    tracking: Int,
    inMarkedRange: UnsafeMutablePointer<ObjCBool>?
  ) -> Int

  func clientLength() -> Int
  func clientAttributedSubstring(fromRange range: NSRange) -> NSAttributedString?
  func clientMarkedRange() -> NSRange
  func clientSelectedRange() -> NSRange
  func clientWindowLevel() -> Int32
  func clientSupportsProperty(_ property: UInt32) -> Bool

  // MARK: - IMKTextInput_NSAppearance

  func clientIsDarkMode() -> Bool
}
