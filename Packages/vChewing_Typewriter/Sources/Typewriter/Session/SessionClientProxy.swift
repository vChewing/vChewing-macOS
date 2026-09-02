// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
