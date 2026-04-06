// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

// MARK: - 符號表資料建構器

/// 符號表資料建構器：將 `CandidateNode` 樹狀符號資料轉換為 `[SymbolTableCategory]`。
public enum SymbolTableData {

  /// 從目前的 `CandidateNode.root` 建構符號表分類列表。
  /// 每一個頂層 child node（有 symbols 的）對應一個 `SymbolTableCategory`。
  /// 只包含具有 symbol members 的節點（排除純空白、空節點）。
  public static func buildCategories() -> [SymbolTableCategory] {
    let root = CandidateNode.root
    var result: [SymbolTableCategory] = []
    for node in root.members {
      let symbols = node.flatSymbols
      guard !symbols.isEmpty else { continue }
      result.append(SymbolTableCategory(name: node.name, symbols: symbols))
    }
    return result
  }
}

// MARK: - CandidateNode + flatSymbols

extension CandidateNode {
  /// 遞迴展平節點內所有符號字串（leaf node 的 name 值）。
  /// Leaf node 定義：members 為空的節點，其 name 即為符號本身。
  var flatSymbols: [String] {
    if members.isEmpty {
      // 這是葉節點，name 本身就是符號值
      // 排除純空白、根節點佔位符
      let n = name.trimmingCharacters(in: .whitespaces)
      return n.isEmpty || n == "/" ? [] : [name]
    }
    // 遞迴子節點
    var result: [String] = []
    for child in members {
      result += child.flatSymbols
    }
    return result
  }
}
