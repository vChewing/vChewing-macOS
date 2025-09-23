// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez

extension LMAssembly.LMInstantiator {
  public func performPOMObservation(
    walkedBefore: [Megrez.GramInPath],
    walkedAfter: [Megrez.GramInPath],
    cursor: Int,
    timestamp: Double,
    saveCallback: (() -> ())? = nil
  ) {
    lmPerceptionOverride.performObservation(
      walkedBefore: walkedBefore,
      walkedAfter: walkedAfter,
      cursor: cursor,
      timestamp: timestamp,
      saveCallback: saveCallback
    )
  }

  public func fetchPOMSuggestion(
    currentWalk: [Megrez.GramInPath],
    cursor: Int,
    timestamp: Double
  )
    -> LMAssembly.OverrideSuggestion {
    lmPerceptionOverride.fetchSuggestion(
      currentWalk: currentWalk,
      cursor: cursor,
      timestamp: timestamp
    )
  }

  public func loadPOMData(fromURL fileURL: URL? = nil) {
    lmPerceptionOverride.loadData(fromURL: fileURL)
  }

  public func savePOMData(toURL fileURL: URL? = nil) {
    lmPerceptionOverride.saveData(toURL: fileURL)
  }

  public func clearPOMData(withURL fileURL: URL? = nil) {
    lmPerceptionOverride.clearData(withURL: fileURL)
  }

  public func bleachSpecifiedPOMSuggestions(targets: [String], saveCallback: (() -> ())? = nil) {
    lmPerceptionOverride.bleachSpecifiedSuggestions(targets: targets, saveCallback: saveCallback)
  }

  public func bleachPOMUnigrams(saveCallback: (() -> ())? = nil) {
    lmPerceptionOverride.bleachUnigrams(saveCallback: saveCallback)
  }
}
