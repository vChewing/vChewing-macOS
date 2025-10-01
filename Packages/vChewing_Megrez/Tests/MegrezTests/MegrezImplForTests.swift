// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Megrez

// MARK: - Megrez Extensions for Test Purposes Only.

extension Megrez.Compositor {
  /// 返回在當前位置的所有候選字詞（以詞音配對的形式）。如果組字器內有幅節、且游標
  /// 位於組字器的（文字輸入順序的）最前方（也就是游標位置的數值是最大合規數值）的
  /// 話，那麼這裡會用到 location - 1、以免去在呼叫該函式後再處理的麻煩。
  /// - Remark: 該函式已被淘汰，因為有「無法徹底清除 node-crossing 內容」的故障。
  /// 現僅用於單元測試、以確認其繼任者是否有給出所有該給出的正常結果。
  /// - Parameter location: 游標位置。
  /// - Returns: 候選字音配對陣列。
  public func fetchCandidatesDeprecated(
    at location: Int,
    filter: CandidateFetchFilter = .all
  )
    -> [Megrez.KeyValuePaired] {
    var result = [Megrez.KeyValuePaired]()
    guard !keys.isEmpty else { return result }
    let location = max(min(location, keys.count - 1), 0) // 防呆
    let anchors: [(location: Int, node: Megrez.Node)] = fetchOverlappingNodes(at: location)
    let keyAtCursor = keys[location]
    anchors.map(\.node).forEach { theNode in
      theNode.unigrams.forEach { gram in
        switch filter {
        case .all:
          // 得加上這道篩選，不然會出現很多無效結果。
          if !theNode.keyArray.contains(keyAtCursor) { return }
        case .beginAt:
          if theNode.keyArray[0] != keyAtCursor { return }
        case .endAt:
          if theNode.keyArray.reversed()[0] != keyAtCursor { return }
        }
        result.append(.init(keyArray: theNode.keyArray, value: gram.value))
      }
    }
    return result
  }
}

extension Megrez.CompositorConfig {
  public var encodedJSON: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    do {
      let encodedData = try encoder.encode(self)
      return String(data: encodedData, encoding: .utf8) ?? ""
    } catch {
      return ""
    }
  }

  public func encodedJSONThrowable() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    let encodedData = try encoder.encode(self)
    return String(data: encodedData, encoding: .utf8) ?? ""
  }
}

extension Megrez.Compositor {
  public var encodedJSON: String { config.encodedJSON }
}
