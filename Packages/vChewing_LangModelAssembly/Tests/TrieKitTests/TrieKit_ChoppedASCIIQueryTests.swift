// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// Phase 156 回歸測試：TextMapTrie 的 "&" 連讀（keysChopped）查詢路徑必須
// 對 ASCII 讀音鍵也能正常運作（decodeUTF8ScalarValue 曾缺 ASCII 分支，
// 導致 initialsMatch 對 ASCII 鍵一律失敗、chopped 查詢回傳空陣列）。

import Foundation
import Testing
@testable import TrieKit

@Suite(.serialized)
struct TrieKitTextMapChoppedASCIIQueryTests {
  // MARK: Internal

  @Test("[TrieKit] Chopped (&) query matches ASCII readings")
  func testChoppedQueryMatchesASCIIReadings() throws {
    let textMap = makeTextMap([
      ("A1-B1", [("factoryHit", -9.9, 5)]),
      ("A1-B2", [("partial", -9.9, 5)]),
    ])

    let trie = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))
    let chs = VanguardTrie.Trie.EntryType(rawValue: 5)

    // 部分匹配（"A" 前綴）的 "&" 連讀查詢。
    let partial = trie.getEntryGroups(keysChopped: ["A&X", "B"], filterType: chs, partiallyMatch: true)
    #expect(partial.count == 2)
    #expect(partial.flatMap(\.entries).map(\.value).sorted() == ["factoryHit", "partial"])

    // 精確匹配的 "&" 連讀查詢。
    let exact = trie.getEntryGroups(keysChopped: ["A1&A2", "B1"], filterType: chs, partiallyMatch: false)
    #expect(exact.count == 1)
    #expect(exact.first?.entries.first?.value == "factoryHit")

    // 對照：queryGrams 走 protocol 預設展開路徑，也應給出一致結果。
    let q = trie.queryGrams(["A&X", "B"], filterType: chs, partiallyMatch: true)
    #expect(q.map(\.value).sorted() == ["factoryHit", "partial"])
  }

  // MARK: Private

  private func makeTextMap(_ entriesByKey: [(String, [(value: String, probability: Double, typeID: Int32)])])
    -> String {
    var valueLines: [String] = []
    var keyLines: [String] = []

    for (key, entries) in entriesByKey {
      let startLine = valueLines.count
      entries.forEach { entry in
        let probabilityText = entry.probability.description.hasSuffix(".0")
          ? String(entry.probability.description.dropLast(2))
          : entry.probability.description
        valueLines.append("\(entry.value)\t\(probabilityText)\t\(entry.typeID)")
      }
      keyLines.append("\(key)\t\(startLine)\t\(entries.count)")
    }

    var result = ""
    result += "#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER\n"
    result += "VERSION\t1.1\n"
    result += "TYPE\tTYPING\n"
    result += "READING_SEPARATOR\t-\n"
    result += "ENTRY_COUNT\t\(valueLines.count)\n"
    result += "KEY_COUNT\t\(keyLines.count)\n"
    result += "#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES\n"
    valueLines.forEach { result += $0 + "\n" }
    result += "#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP\n"
    keyLines.forEach { result += $0 + "\n" }
    return result
  }
}
