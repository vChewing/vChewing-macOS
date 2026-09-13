// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - Non-UserDef bare English → i18n: key mapping

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
