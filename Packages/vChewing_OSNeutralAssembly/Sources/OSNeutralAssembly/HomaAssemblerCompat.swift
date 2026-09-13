// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - Homa.Assembler API Compatibility Shims

// These bridge the Megrez.Compositor API surface to Homa.Assembler,
// minimising call-site changes during the Megrez → Homa migration.

extension Homa.Assembler {
  // MARK: - overrideCandidate with `overrideType:` Label (Bool-Returning)

  /// Bool-returning wrapper mapping `overrideType:` label to Homa's `type:`.
  @discardableResult
  public func overrideCandidate(
    _ candidate: Homa.CandidatePair,
    at location: Int,
    overrideType: Homa.Node.OverrideType = .withSpecified,
    isExplicitlyOverridden: Bool = false,
    enforceRetokenization: Bool = false,
    perceptionHandler: ((Homa.PerceptionIntel) -> ())? = nil
  )
    -> Bool {
    (try? overrideCandidate(
      candidate, at: location,
      type: overrideType,
      isExplicitlyOverridden: isExplicitlyOverridden,
      enforceRetokenization: enforceRetokenization,
      perceptionHandler: perceptionHandler
    )) != nil
  }

  @discardableResult
  public func overrideCandidate(
    _ candidate: Homa.CandidatePairWeighted,
    at location: Int,
    overrideType: Homa.Node.OverrideType = .withSpecified,
    isExplicitlyOverridden: Bool = false,
    enforceRetokenization: Bool = false,
    perceptionHandler: ((Homa.PerceptionIntel) -> ())? = nil
  )
    -> Bool {
    (try? overrideCandidate(
      candidate, at: location,
      type: overrideType,
      isExplicitlyOverridden: isExplicitlyOverridden,
      enforceRetokenization: enforceRetokenization,
      perceptionHandler: perceptionHandler
    )) != nil
  }
}

// MARK: - Homa.CandidatePair Compatibility Inits

extension Homa.CandidatePair {
  /// Legacy init taking a string `key` which gets split by the separator.
  @inlinable
  public init(key: String, value: String) {
    let keyArray = key.isEmpty ? ["N/A"] : key.split(separator: "-").map(String.init)
    self.init(keyArray: keyArray, value: value)
  }

  /// Init from CandidateInState tuple `(keyArray: [String], value: String)`.
  @inlinable
  public init(_ tuplet: (keyArray: [String], value: String)) {
    self.init(keyArray: tuplet.keyArray, value: tuplet.value)
  }
}
