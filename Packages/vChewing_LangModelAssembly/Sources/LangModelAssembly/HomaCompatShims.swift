// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Homa

// MARK: - Homa.Gram Compatibility Shims

/// Compatibility extensions bridging the legacy Megrez.Unigram field names
/// (`value`, `score`) to Homa.Gram field names (`current`, `probability`).
/// This keeps LangModelAssembly internal code changes minimal during the
/// Megrez → Homa engine migration.
extension Homa.Gram {
  /// Convenience initialiser matching the old Megrez.Unigram signature.
  @inlinable
  nonisolated public init(keyArray: [String] = [], value: String = "", score: Double = 0, id: FIUUID = .init()) {
    self.init(keyArray: keyArray, current: value, previous: nil, probability: score, backoff: 0, id: id)
  }
}

// MARK: - Array<Homa.Gram> Compatibility

extension Array where Element == Homa.Gram {
  /// Given a filter set, deduplicate and filter the gram array in-place.
  /// Ported from legacy `Array<Megrez.Unigram>.consolidate(filter:)`.
  nonisolated public mutating func consolidate(filter theFilter: Set<String> = .init()) {
    var inserted: [String: Double] = [:]
    var insertedArray: [Homa.Gram] = []
    filter { !theFilter.contains($0.current) }.forEach { neta in
      if inserted.keys.contains(neta.current) { return }
      inserted[neta.current] = neta.probability
      insertedArray.append(neta)
    }
    self = insertedArray
  }
}

// MARK: - Homa.CandidatePair Compatibility Shims

/// Compatibility extensions bridging `Megrez.KeyValuePaired` patterns
/// (e.g. `joinedKey`, `toNGramKey`) to `Homa.CandidatePair`.
extension Homa.CandidatePair {
  /// Join keyArray into a single string with the given separator.
  @inlinable
  nonisolated public func joinedKey(by separator: String = "-") -> String {
    keyArray.joined(separator: separator)
  }

  /// Produce the ngram key representation used by perception override.
  @inlinable
  nonisolated public var toNGramKey: String {
    let isValid = !keyArray.joined().isEmpty && !value.isEmpty
    return !isValid ? "()" : "(\(joinedKey()),\(value))"
  }
}

// MARK: - Homa.Assembler Separator Shim

extension Homa.Assembler {
  /// The reading separator, hardcoded to "-". Matches the old `Megrez.Compositor.separator`.
  @inlinable
  nonisolated public var separator: String { Self.theSeparator }

  /// The reading separator, hardcoded to "-". Matches the old `Megrez.Compositor.separator`.
  @inlinable
  nonisolated public static var theSeparator: String { "-" }
}
