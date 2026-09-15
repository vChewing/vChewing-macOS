// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa

extension LXAssembly.LXFacade {
  public func memorizePerception(
    _ perception: (ngramKey: String, candidate: String),
    timestamp: Double,
    saveCallback: (() -> ())? = nil
  ) {
    Self.pomGeneration &+= 1
    lxPerceptor.memorizePerception(
      perception,
      timestamp: timestamp,
      saveCallback: saveCallback
    )
  }

  public func fetchPOMSuggestion(
    assembledResult: [Homa.GramInPath],
    cursor: Int,
    timestamp: Double,
    matchMode: LXAssembly.POMQueryMode = .exact
  )
    -> LXAssembly.OverrideSuggestion {
    lxPerceptor.fetchSuggestion(
      assembledResult: assembledResult,
      cursor: cursor,
      timestamp: timestamp,
      matchMode: matchMode
    )
  }

  /// 是否啟用急速遺忘模式（縮短 POM 壽命至 12 小時以內）。
  /// 由外部（如 `PrefMgr`）注入，轉發至底層 `lxPerceptor.reducedLifetime`。
  public var pomReducedLifetime: Bool {
    get { lxPerceptor.reducedLifetime }
    set { lxPerceptor.reducedLifetime = newValue }
  }

  public func loadPOMData(fromURL fileURL: URL? = nil) {
    Self.pomGeneration &+= 1
    lxPerceptor.loadData(fromURL: fileURL)
  }

  public func savePOMData(toURL fileURL: URL? = nil) {
    lxPerceptor.saveData(toURL: fileURL)
  }

  public func clearPOMData(withURL fileURL: URL? = nil) {
    Self.pomGeneration &+= 1
    lxPerceptor.clearData(withURL: fileURL)
  }

  /// 清除指定的 POM 建議（基於 context + candidate 對）
  public func bleachSpecifiedPOMSuggestions(
    targets: [(ngramKey: String, candidate: String)],
    saveCallback: (() -> ())? = nil
  ) {
    Self.pomGeneration &+= 1
    lxPerceptor.bleachSpecifiedSuggestions(
      targets: targets, saveCallback: saveCallback
    )
  }

  /// 清除指定的 POM 建議（基於 candidate，移除所有上下文中的該候選詞）
  public func bleachSpecifiedPOMSuggestions(
    targets: [String], saveCallback: (() -> ())? = nil
  ) {
    Self.pomGeneration &+= 1
    lxPerceptor.bleachSpecifiedSuggestions(
      candidateTargets: targets, saveCallback: saveCallback
    )
  }

  /// 清除指定讀音（head reading）底下的所有 POM 建議
  public func bleachSpecifiedPOMSuggestions(
    headReadings: [String],
    saveCallback: (() -> ())? = nil
  ) {
    Self.pomGeneration &+= 1
    lxPerceptor.bleachSpecifiedSuggestions(
      headReadingTargets: headReadings, saveCallback: saveCallback
    )
  }

  public func bleachPOMUnigrams(saveCallback: (() -> ())? = nil) {
    Self.pomGeneration &+= 1
    lxPerceptor.bleachUnigrams(saveCallback: saveCallback)
  }
}
