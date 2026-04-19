// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

extension Homa {
  public typealias CandidatePairRAW = (keyArray: [String], value: String)
  public typealias CandidatePairWeightedRAW = (pair: CandidatePairRAW, weight: Double)
  public typealias GramQuerier = ([String]) -> [GramRAW]
  public typealias GramAvailabilityChecker = ([String]) -> Bool
  public typealias BehaviorPerceptor = (Homa.PerceptionIntel) -> ()

  public typealias GramRAW = (
    keyArray: [String],
    value: String,
    probability: Double,
    previous: String?
  )
}
