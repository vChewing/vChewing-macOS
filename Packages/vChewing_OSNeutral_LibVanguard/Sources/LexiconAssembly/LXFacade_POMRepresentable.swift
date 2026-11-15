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
    pomGeneration &+= 1
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

  /// 列出某 head 讀音底下、此刻仍然有效的所有漸退記憶（唯讀）。
  ///
  /// 供「控頻操作之後的查核」判斷有無既存記憶會回頭綁架該讀音的選字：記憶之生效與否
  /// 取決於 head 詞值（見 `LXPerceptor.perceptionsFor` 之 `headValue`），故查核端須同時
  /// 取得 head 詞值與候選，不能只看候選本身。
  public func pomMemories(
    headReading: String,
    timestamp: Double,
    matchMode: LXAssembly.POMQueryMode = .exact
  )
    -> [LXAssembly.POMMemory] {
    lxPerceptor.perceptionsFor(
      headReading: headReading,
      timestamp: timestamp,
      matchMode: matchMode
    ).map {
      LXAssembly.POMMemory(
        headReading: $0.headReading,
        headValue: $0.headValue,
        previous: $0.previous,
        anterior: $0.anterior,
        candidate: $0.candidate,
        probability: $0.probability
      )
    }
  }

  /// 是否啟用急速遺忘模式（縮短 POM 壽命至 12 小時以內）。
  /// 由外部（如 `PrefMgr`）注入，轉發至底層 `lxPerceptor.reducedLifetime`。
  public var pomReducedLifetime: Bool {
    get { lxPerceptor.reducedLifetime }
    set { lxPerceptor.reducedLifetime = newValue }
  }

  public func loadPOMData(fromURL fileURL: URL? = nil) {
    pomGeneration &+= 1
    lxPerceptor.loadData(fromURL: fileURL)
  }

  public func savePOMData(toURL fileURL: URL? = nil) {
    lxPerceptor.saveData(toURL: fileURL)
  }

  public func clearPOMData(withURL fileURL: URL? = nil) {
    pomGeneration &+= 1
    lxPerceptor.clearData(withURL: fileURL)
  }

  /// 清除指定的 POM 建議（基於 context + candidate 對）
  public func bleachSpecifiedPOMSuggestions(
    targets: [(ngramKey: String, candidate: String)],
    saveCallback: (() -> ())? = nil
  ) {
    pomGeneration &+= 1
    lxPerceptor.bleachSpecifiedSuggestions(
      targets: targets, saveCallback: saveCallback
    )
  }

  /// 清除指定的 POM 建議（基於 candidate，移除所有上下文中的該候選詞）
  public func bleachSpecifiedPOMSuggestions(
    targets: [String], saveCallback: (() -> ())? = nil
  ) {
    pomGeneration &+= 1
    lxPerceptor.bleachSpecifiedSuggestions(
      candidateTargets: targets, saveCallback: saveCallback
    )
  }

  /// 清除指定讀音（head reading）底下的所有 POM 建議
  public func bleachSpecifiedPOMSuggestions(
    headReadings: [String],
    saveCallback: (() -> ())? = nil
  ) {
    pomGeneration &+= 1
    lxPerceptor.bleachSpecifiedSuggestions(
      headReadingTargets: headReadings, saveCallback: saveCallback
    )
  }

  public func bleachPOMUnigrams(saveCallback: (() -> ())? = nil) {
    pomGeneration &+= 1
    lxPerceptor.bleachUnigrams(saveCallback: saveCallback)
  }
}
