// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 使用者資料之增量套用（P346）：落盤成功後只把該列收進記憶體索引，不整檔重載。
//
// 本套房釘死兩件事：
// ① 增量收列即時生效，且**不得與**先前為「即時生效」而插入之臨時記錄**重複**出現
//    （整檔重載本會清空臨時表，增量路徑須自行補做）；
// ② 增量移出（濾除清單）即時放行該詞音配對，記憶體之 NUL 覆寫與落盤端同語義。

import Foundation
import Homa
import Testing

@testable import LexiconAssembly

// MARK: - LXFacadeIncrementalUserDataTests

@Suite(.serialized)
struct LXFacadeIncrementalUserDataTests {
  @Test("增量收列：即時生效，且不與同值之臨時記錄重複")
  func insertUserDataRowAppliesImmediately() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lx = LXAssembly.LXFacade(isCHS: false)
    let keyArray = ["ㄉㄜ˙", "ㄉㄜ˙", "ㄉㄜ˙"]
    let keyChain = keyArray.joined(separator: "-")
    let value = "乂乂乂"

    #expect(lx.lxQuerier.grams(for: keyArray).isEmpty)

    // 模擬就地加詞之即時生效機制：先插臨時記錄。
    lx.insertTemporaryData(
      unigram: .init(keyArray: keyArray, value: value, score: 0),
      isFiltering: false
    )
    #expect(lx.lxQuerier.grams(for: keyArray).map(\.current) == [value])

    // 落盤成功之後增量收列。
    let applied = lx.insertUserDataRow("\(value) \(keyChain) 0.0", isFiltering: false)
    #expect(applied)
    #expect(
      lx.lxQuerier.grams(for: keyArray).map(\.current) == [value],
      "正式資料與臨時記錄並存時，同一詞不得重複出現。"
    )
    #expect(lx.retrieveData(from: .thePhrases).contains(value), "該列應已進入正式資料。")
  }

  @Test("增量移出：濾除清單即時放行")
  func removeFilteredUserDataRowAppliesImmediately() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lx = LXAssembly.LXFacade(isCHS: false)
    let keyArray = ["ㄉㄜ˙", "ㄉㄜ˙", "ㄉㄜ˙"]
    let keyChain = keyArray.joined(separator: "-")
    let value = "乂乂乂"
    let row = "\(value) \(keyChain)"
    let pair = Homa.CandidatePair(keyArray: keyArray, value: value)

    let filtered = lx.insertUserDataRow(row, isFiltering: true)
    #expect(filtered)
    #expect(lx.lxQuerier.isPairFiltered(pair: pair))

    let unfiltered = lx.removeFilteredUserDataRow(row)
    #expect(unfiltered)
    #expect(!lx.lxQuerier.isPairFiltered(pair: pair))
  }

  @Test("增量收列：輸入不合規時據實回報失敗")
  func insertUserDataRowReportsInvalidRow() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lx = LXAssembly.LXFacade(isCHS: false)
    let invalidRowApplied = lx.insertUserDataRow("# 註解列", isFiltering: false)
    #expect(!invalidRowApplied)
  }
}
