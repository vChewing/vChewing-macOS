// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

extension UserDef.MetaData {
  /// Returns `true` when any localizable field still holds a bare string instead of
  /// an `i18n:`-prefixed key, signalling that manual i18n migration is still needed.
  ///
  /// Uses `Mirror` to enumerate stored properties, keeping this check aligned with
  /// `UserDef.i18nKeyConvMap` without duplicating the field list.
  public var hasFieldPendingManualUpdate: Bool {
    let caseName = String(describing: userDef)
    let mirror = Mirror(reflecting: self)
    let skippedLabels: Set<String> = ["userDef", "minimumOS"]

    for child in mirror.children {
      guard let label = child.label, !skippedLabels.contains(label) else { continue }

      if label == "options" {
        guard let options = child.value as? [Int: String], !options.isEmpty else { continue }
        let stem = "i18n:UserDef.\(caseName).option"
        for idx in options.keys.sorted() {
          guard let oldVal = options[idx] else { continue }
          if "\(stem).\(idx)" != oldVal { return true }
        }
      } else if let oldString = child.value as? String {
        if "i18n:UserDef.\(caseName).\(label)" != oldString { return true }
      }
    }

    return false
  }
}

extension UserDef {
  public var isMetadataPendingManualUpdate: Bool {
    metaData?.hasFieldPendingManualUpdate ?? false
  }

  /// Generates a mapping table of `i18n:`-formatted new keys → current bare-string values
  /// for all localizable `MetaData` fields that have not yet been migrated.
  ///
  /// Uses `Mirror` to enumerate `MetaData` stored properties, so that new fields added
  /// to `MetaData` are automatically covered without manual bookkeeping.
  ///
  /// - Returns: `nil` when the case has no `MetaData` or when all fields are already
  ///   using the `i18n:` prefix format.
  public var i18nKeyConvMap: [String: String]? {
    guard let metaData else { return nil }
    var result = [String: String]()
    let caseName = String(describing: self)
    let mirror = Mirror(reflecting: metaData)

    // These MetaData fields are not localizable strings and must be skipped.
    let skippedLabels: Set<String> = ["userDef", "minimumOS"]

    for child in mirror.children {
      guard let label = child.label, !skippedLabels.contains(label) else { continue }

      if label == "options" {
        guard let options = child.value as? [Int: String] else { continue }
        guard !options.isEmpty else { continue }
        let stem = "i18n:UserDef.\(caseName).option"
        for idx in options.keys.sorted() {
          guard let oldVal = options[idx] else { continue }
          let newKey = "\(stem).\(idx)"
          guard newKey != oldVal else { continue }
          result[newKey] = oldVal
        }
      } else if let oldString = child.value as? String {
        let newKey = "i18n:UserDef.\(caseName).\(label)"
        guard newKey != oldString else { continue }
        result[newKey] = oldString
      }
    }

    return result.isEmpty ? nil : result
  }

  public static var i18nKeyConvMapTotal: [String: String] {
    Self.allCases.reduce(into: [String: String]()) { result, userDef in
      guard let map = userDef.i18nKeyConvMap else { return }
      result.merge(map) { _, new in new }
    }
  }
}
