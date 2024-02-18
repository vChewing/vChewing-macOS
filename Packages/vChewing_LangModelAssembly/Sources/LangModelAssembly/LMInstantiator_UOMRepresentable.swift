// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez

public extension LMAssembly.LMInstantiator {
  func performUOMObservation(
    walkedBefore: [Megrez.Node],
    walkedAfter: [Megrez.Node],
    cursor: Int,
    timestamp: Double,
    saveCallback: (() -> Void)? = nil
  ) {
    lmUserOverride.performObservation(
      walkedBefore: walkedBefore,
      walkedAfter: walkedAfter,
      cursor: cursor,
      timestamp: timestamp,
      saveCallback: saveCallback
    )
  }

  func fetchUOMSuggestion(
    currentWalk: [Megrez.Node],
    cursor: Int,
    timestamp: Double
  ) -> LMAssembly.OverrideSuggestion {
    lmUserOverride.fetchSuggestion(
      currentWalk: currentWalk,
      cursor: cursor,
      timestamp: timestamp
    )
  }

  func loadUOMData(fromURL fileURL: URL? = nil) {
    lmUserOverride.loadData(fromURL: fileURL)
  }

  func saveUOMData(toURL fileURL: URL? = nil) {
    lmUserOverride.saveData(toURL: fileURL)
  }

  func clearUOMData(withURL fileURL: URL? = nil) {
    lmUserOverride.clearData(withURL: fileURL)
  }

  func bleachSpecifiedUOMSuggestions(targets: [String], saveCallback: (() -> Void)? = nil) {
    lmUserOverride.bleachSpecifiedSuggestions(targets: targets, saveCallback: saveCallback)
  }

  func bleachUOMUnigrams(saveCallback: (() -> Void)? = nil) {
    lmUserOverride.bleachUnigrams(saveCallback: saveCallback)
  }
}
