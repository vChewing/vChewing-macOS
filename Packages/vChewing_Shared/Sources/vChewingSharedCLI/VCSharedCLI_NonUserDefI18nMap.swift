// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - Phase 75: Non-UserDef bare English → i18n: key mapping

/// Explicit mapping table for i18n keys that are **not** part of the `UserDef` system.
///
/// Unlike `UserDef.i18nKeyConvMapTotal` (which uses `Mirror` to automatically derive
/// old→new key pairs from `MetaData` fields), these keys have no programmatic
/// relationship between their old bare‑English form and their new `i18n:` form.
/// They must be mapped explicitly.
///
/// Keys are the **actual unescaped** string values (as they appear in Swift code).
/// The CLI uses `escapeForLiteralSearch(_:)` to match them in `.strings` files and
/// Swift source code.
enum NonUserDefI18nMap {
  /// `[bareEnglishOldValue: newI18nKey]`
  static let keyMap: [String: String] = [:]
}
