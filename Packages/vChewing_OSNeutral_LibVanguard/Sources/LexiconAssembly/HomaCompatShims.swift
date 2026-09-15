// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa

// MARK: - Homa.Gram Compatibility Shims

/// Compatibility extensions bridging the legacy Megrez.Unigram field names
/// (`value`, `score`) to Homa.Gram field names (`current`, `probability`).
/// This keeps LexiconAssembly internal code changes minimal during the
/// Megrez → Homa engine migration.
extension Homa.Gram {
  /// Convenience initialiser matching the old Megrez.Unigram signature.
  @inlinable
  public init(
    keyArray: [String] = [],
    value: String = "",
    score: Double = 0,
    id: FIUUID = .init(),
    previous: String? = nil,
    anterior: String? = nil
  ) {
    self.init(
      keyArray: keyArray, current: value,
      previous: previous, anterior: anterior,
      probability: score, backoff: 0, id: id
    )
  }
}

// MARK: - Array<Homa.Gram> Compatibility

extension Array where Element == Homa.Gram {
  /// Given a filter set, deduplicate and filter the gram array in-place.
  /// Ported from legacy `Array<Megrez.Unigram>.consolidate(filter:)`.
  public mutating func consolidate(filter theFilter: Set<String> = .init()) {
    var inserted: [String: Double] = [:]
    var insertedArray: [Homa.Gram] = []
    for neta in self {
      if theFilter.contains(neta.current) { continue }
      if inserted.keys.contains(neta.current) { continue }
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
  public func joinedKey(by separator: String = "-") -> String {
    keyArray.joined(separator: separator)
  }

  /// Produce the ngram key representation used by perception override.
  @inlinable
  public var toNGramKey: String {
    let isValid = !keyArray.joined().isEmpty && !value.isEmpty
    return !isValid ? "()" : "(\(joinedKey()),\(value))"
  }
}

// MARK: - Homa.Assembler Separator Shim

extension Homa.Assembler {
  /// The reading separator, hardcoded to "-". Matches the old `Megrez.Compositor.separator`.
  @inlinable
  public var separator: String { Self.theSeparator }

  /// The reading separator, hardcoded to "-". Matches the old `Megrez.Compositor.separator`.
  @inlinable
  public static var theSeparator: String { "-" }
}
