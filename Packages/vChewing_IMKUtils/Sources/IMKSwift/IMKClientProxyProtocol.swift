// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

@_exported import IMKSwiftModernHeaders

// MARK: - IMKInputSessionController + IMKClientProxyProtocol

extension IMKInputSessionController: IMKClientProxyProtocol {}

// MARK: - IMKClientProxyProtocol

@objc
public protocol IMKClientProxyProtocol: AnyObject {
  func clientAddress() -> UInt
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
}
