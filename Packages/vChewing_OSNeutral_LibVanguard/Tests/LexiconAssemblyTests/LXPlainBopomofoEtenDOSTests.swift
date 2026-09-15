// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import LexiconAssembly

// MARK: - LXPlainBopomofoEtenDOSTests

@Suite(.serialized)
struct LXPlainBopomofoEtenDOSTests {
  /// 倚天中文 DOS 注音表沒有「ㄉㄨㄟˇ」這個讀音，故其亦不供應「㨃」。
  @Test("[LXPlainBopomofo] EtenDOS table has no ㄉㄨㄟˇ reading")
  func testEtenDOSHasNoThirdToneDui() throws {
    let lx = LXAssembly.LXPlainBopomofo()
    #expect(lx.hasValuesFor(key: "ㄉㄨㄟˇ") == false)
  }

  /// 全匹配查詢只回該讀音自身的候選字。
  @Test("[LXPlainBopomofo] Exact query keeps the reading's own candidates only")
  func testExactQueryKeepsOwnCandidatesOnly() throws {
    let lx = LXAssembly.LXPlainBopomofo()
    #expect(lx.valuesFor(key: "ㄉㄨㄟ", isCHS: false) == ["堆", "頧", "痽"])
  }

  /// 前綴匹配查詢的候選字次序即倚天表自身的注音排序。
  @Test("[LXPlainBopomofo] Prefix query keeps the EtenDOS ordering")
  func testPrefixQueryKeepsEtenDOSOrdering() throws {
    let lx = LXAssembly.LXPlainBopomofo()
    let partials = lx.partiallyMatchedValuesFor(prefix: "ㄉㄨㄟ", isCHS: false)
    #expect(partials.joined() == "堆頧痽對隊兌碓懟譈濧薱轛濻瀩憝")
  }
}
