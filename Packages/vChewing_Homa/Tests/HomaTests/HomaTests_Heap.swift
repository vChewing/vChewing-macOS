// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import HomaSharedTestComponents
import Testing

@testable import Homa

#if canImport(Darwin)
  import Darwin
#endif

// MARK: - HomaTests_Heap

/// 鎖定 Homa 組字器對「小 / 中型值型別」的記憶體行為：
/// 節點必須維持值語義（Struct），反覆重新組句的堆分配次數必須收斂於有界常數。
struct HomaTests_Heap: HomaTestSuite {
  /// 節點必須是值型別：修改值拷貝不得影響原始節點。
  /// （若有人把 Node 改回 Class，此測試會因引用共享而失敗。）
  @Test("[Homa] NodeValueSemantics")
  func testNodeValueSemantics() {
    let keyArray = ["a"]
    let gram = Homa.Gram(keyArray: keyArray, current: "甲", previous: nil, probability: -1.0)
    var node = Homa.Node(keyArray: keyArray, grams: [gram])
    let snapshot = node
    node.overrideStatus = .init(
      overridingScore: 999.0,
      currentOverrideType: .withSpecified,
      isExplicitlyOverridden: true,
      currentUnigramIndex: 0
    )
    // 修改前取得的拷貝必須維持原狀；Class 語義（引用共享）下此斷言會失敗。
    #expect(snapshot.overrideStatus.overridingScore != node.overrideStatus.overridingScore)
    #expect(snapshot.currentOverrideType == nil)
    #expect(node.currentOverrideType == .withSpecified)
  }

  #if canImport(Darwin)
    /// 反覆「組句 → 清空」循環時，malloc 保留區必須收斂、不得隨輪數成長。
    ///
    /// 暖機後測量 200 輪循環前後的 `size_allocated` 增量；本測試作為洩漏哨兵，
    /// 鎖定「反覆重組句不會留下未釋放的堆積」。Node 維持值語義的結構性保證
    /// 由 `testNodeValueSemantics` 鎖定（macOS allocator 重用良好，保留區增量
    /// 無法區分 Class/Struct 的分配次數差異）。
    @Test("[Homa] RepeatedRecompositionAllocConvergence")
    func testRepeatedRecompositionAllocConvergence() throws {
      let mockLM = TestLM(rawData: HomaTests.strLMSampleDataLitch)
      let assembler = Homa.Assembler(
        gramQuerier: { mockLM.queryGrams($0) }
      )
      let keys: [Homa.PossibleKey] =
        ["chao1", "shang1", "da4", "qian2", "tian1"].map { .singleKey($0) }

      func recompose() throws {
        try assembler.insertKeys(keys)
        _ = assembler.assemble()
        while !assembler.isEmpty {
          try assembler.dropKey(direction: .rear)
        }
        _ = assembler.assemble()
      }

      // 暖機：讓查詢快取、字典與陣列容量進入穩定狀態。
      for _ in 0 ..< 50 {
        try recompose()
      }

      func currentSizeAllocated() -> Int {
        var stats = malloc_statistics_t()
        malloc_zone_statistics(malloc_default_zone(), &stats)
        return stats.size_allocated
      }

      let sizeBefore = currentSizeAllocated()
      let rounds = 200
      for _ in 0 ..< rounds {
        try recompose()
      }
      let sizeAfter = currentSizeAllocated()
      let delta = sizeAfter > sizeBefore ? Int(sizeAfter - sizeBefore) : 0
      // 洩漏哨兵：反覆重組句後 malloc 保留區不得隨輪數成長。
      // （注意：macOS allocator 對「分配 → 釋放 → 重用」的回收極佳，本指標無法
      // 區分 Class/Struct 節點的分配次數差異——那是 malloc 次數層面的差異，SDK
      // 精簡後的 malloc_statistics_t 已無累計次數欄位；Node 必須維持值語義這件
      // 事的結構性保證由 testNodeValueSemantics 鎖定。此處閾值僅防「每輪洩漏」。）
      #expect(delta < 4 * 1_024 * 1_024, "200 輪重組句後 malloc 保留區擴張過大：\(delta) bytes")
    }
  #endif
}
