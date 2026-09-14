// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - SessionClientProxy

/// 跨平台可用的客戶端 proxy 抽象。
///
/// Darwin 平台上由 `IMKClientProxyProtocol`（IMKInputSessionController）實作；
/// 非 Darwin 平台可自行注入 mock 實作。Session 邏輯只依賴此協定，
/// 不直接觸及 IMK 型別。
public protocol SessionClientProxy: AnyObject {
  func hasClient() -> Bool
  func clientTextInsertion(with text: String, replacementRange: NSRange)
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
    lineHeightRectangle: UnsafeMutablePointer<CGRect>
  ) -> [AnyHashable: Any]?
  func clientLineHeightRect(forU16CursorPos: UInt) -> CGRect
}
