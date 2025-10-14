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
  public func memorizePerception(
    _ perception: (ngramKey: String, candidate: String),
    timestamp: Double,
    saveCallback: (() -> ())? = nil
  ) {
    lmPerceptionOverride.memorizePerception(
      perception,
      timestamp: timestamp,
      saveCallback: saveCallback
    )
  }

  public func fetchPOMSuggestion(
    assembledResult: [Megrez.GramInPath],
    cursor: Int,
    timestamp: Double
  )
    -> LMAssembly.OverrideSuggestion {
    lmPerceptionOverride.fetchSuggestion(
      assembledResult: assembledResult,
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

  /// 清除指定的 POM 建議（基於 context + candidate 對）
  public func bleachSpecifiedPOMSuggestions(
    targets: [(ngramKey: String, candidate: String)],
    saveCallback: (() -> ())? = nil
  ) {
    lmPerceptionOverride.bleachSpecifiedSuggestions(
      targets: targets, saveCallback: saveCallback
    )
  }

  /// 清除指定的 POM 建議（基於 candidate，移除所有上下文中的該候選詞）
  public func bleachSpecifiedPOMSuggestions(
    targets: [String], saveCallback: (() -> ())? = nil
  ) {
    lmPerceptionOverride.bleachSpecifiedSuggestions(
      candidateTargets: targets, saveCallback: saveCallback
    )
  }

  /// 清除指定讀音（head reading）底下的所有 POM 建議
  public func bleachSpecifiedPOMSuggestions(
    headReadings: [String],
    saveCallback: (() -> ())? = nil
  ) {
    lmPerceptionOverride.bleachSpecifiedSuggestions(
      headReadingTargets: headReadings, saveCallback: saveCallback
    )
  }

  public func bleachPOMUnigrams(saveCallback: (() -> ())? = nil) {
    lmPerceptionOverride.bleachUnigrams(saveCallback: saveCallback)
  }
}
