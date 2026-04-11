// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl
import Testing

@testable import TDK4AppKit

@Suite(.serialized)
struct TDK4AppKitTests {
  let variableCandidatesINMU: [CandidateInState] = [
    "二十四歲是學生", "二十四歲", "昏睡紅茶", "食雪漢", "意味深", "學生", "便乗",
    "迫真", "驚愕", "論證", "正論", "惱", "悲", "屑", "食", "雪", "漢", "意", "味",
    "深", "二", "十", "四", "歲", "是", "學", "生", "昏", "睡", "紅", "茶", "便", "乗",
    "嗯", "哼", "啊",
  ].map { candidate in
    let keys: [String] = .init(repeating: "", count: candidate.count)
    return (keys, candidate)
  }

  let wideCandidates: [CandidateInState] = [
    "八月中秋山林涼", "風吹大地草枝擺", "甘霖老母趕羚羊", "來年羊毛超級賣",
    "庭院織芭為君開", "督蘭山曉金桔擺", "天摇地動舟渡嵐", "嗚呼甘霖老師埋",
  ].map { candidate in
    let keys: [String] = .init(repeating: "", count: candidate.count)
    return (keys, candidate)
  }

  @Test
  func testPoolHorizontal() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, selectionKeys: "123456", layout: .horizontal
    )
    var strOutput = ""
    pool.candidateLines.forEach {
      $0.forEach {
        strOutput += $0.displayedText + ", "
      }
      strOutput += "\n"
    }
    print("The matrix:")
    print(strOutput)
  }

  @Test
  func testPoolVertical() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, selectionKeys: "123456", layout: .vertical
    )
    var strOutput = ""
    pool.candidateLines.forEach {
      $0.forEach {
        strOutput += $0.displayedText + ", "
      }
      strOutput += "\n"
    }
    print("The matrix:")
    print(strOutput)
  }

  // MARK: - 動態行容量測試

  /// 驗證：當 `_maxLinesPerPage == 1` (lines: 1) 時，
  /// 橫向排列的 pool 仍需根據候選字詞的實際寬度動態調整每行容量。
  /// 若含有長詞的行仍塞滿 maxLineCapacity 個候選字，則代表故障存在。
  @Test
  func testHorizontalDynamicRowCapacity_SingleLineShouldStillAdjust() throws {
    // lines: 4（多行模式）作為對照組。
    let poolMultiLine = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )
    // lines: 1（單行模式）作為實驗組。
    let poolSingleLine = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 1,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )

    print("=== Multi-line (lines: 4) candidateLines ===")
    for (i, line) in poolMultiLine.candidateLines.enumerated() {
      let texts = line.map(\.displayedText).joined(separator: ", ")
      print("  Line \(i): [\(line.count) items] \(texts)")
    }

    print("=== Single-line (lines: 1) candidateLines ===")
    for (i, line) in poolSingleLine.candidateLines.enumerated() {
      let texts = line.map(\.displayedText).joined(separator: ", ")
      print("  Line \(i): [\(line.count) items] \(texts)")
    }

    // 對照組第一行包含 "二十四歲是學生"（7 chars）等寬候選字，
    // 動態調整後該行的項數應少於 maxLineCapacity（6）。
    let multiLineFirstRowCount = poolMultiLine.candidateLines[0].count
    #expect(multiLineFirstRowCount < 6, "對照組第一行應因寬候選字而少於 6 個項目")

    // 實驗組的行分佈應與對照組完全一致——
    // 因為行容量計算只取決於 maxRowWidth 與各候選字寬度，與 _maxLinesPerPage 無關。
    #expect(
      poolSingleLine.candidateLines.count == poolMultiLine.candidateLines.count,
      "單行模式與多行模式的總行數應一致"
    )
    for i in 0 ..< min(poolSingleLine.candidateLines.count, poolMultiLine.candidateLines.count) {
      let singleLineRow = poolSingleLine.candidateLines[i].map(\.displayedText)
      let multiLineRow = poolMultiLine.candidateLines[i].map(\.displayedText)
      #expect(
        singleLineRow == multiLineRow,
        "第 \(i) 行的候選字分佈應一致：single=\(singleLineRow) vs multi=\(multiLineRow)"
      )
    }
  }

  /// 驗證：含有不同寬度候選字的行應該被動態分配，
  /// 而非一律填滿 maxLineCapacity 個詞。
  @Test
  func testHorizontalDynamicRowCapacity_WideItemsReduceRowCount() throws {
    // 全部使用長字詞。
    let wideCandidates: [CandidateInState] = [
      "八月中秋山林涼", "風吹大地草枝擺", "甘霖老母趕羚羊", "來年羊毛超級賣",
      "庭院織芭為君開", "督蘭山曉金桔擺", "天摇地動舟渡嵐", "嗚呼甘霖老師埋",
    ].map { candidate in
      let keys: [String] = .init(repeating: "", count: candidate.count)
      return (keys, candidate)
    }

    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: wideCandidates,
      lines: 1,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )

    print("=== Wide candidates (lines: 1) ===")
    for (i, line) in pool.candidateLines.enumerated() {
      let texts = line.map(\.displayedText).joined(separator: ", ")
      print("  Line \(i): [\(line.count) items] \(texts)")
    }

    // 寬字詞不可能全部塞進一行，應產生多於 2 行。
    #expect(
      pool.candidateLines.count > 2,
      "含 9 個七字詞時，行數應大於 2，但目前為 \(pool.candidateLines.count)"
    )

    // 每行的項數應隨寬度而減少（不應都等於 6）。
    let maxItemsPerLine = pool.candidateLines.map(\.count).max() ?? 0
    #expect(
      maxItemsPerLine < 6,
      "七字詞組成的行不該有 6 個項目，但最大行項數為 \(maxItemsPerLine)"
    )
  }

  // MARK: - isExpanded 狀態保留測試

  /// 驗證：reinit 時傳入的 isExpanded 值不該被 cleanDataOnMain 覆寫。
  /// 此場景模擬「選字窗已展開，使用者移動游標後觸發 reloadData → reinit」的情形。
  @Test
  func testIsExpandedPreservedAfterReinit() throws {
    // 先建一個展開的 pool。
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(pool.isExpanded == true, "初始化後應處於展開狀態")
    #expect(pool.maxLinesPerPage == 4, "展開時 maxLinesPerPage 應為 4")

    // 模擬 reloadData：用 reinit 重建，保持 isExpanded: true。
    pool.reinit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(pool.isExpanded == true, "reinit 後 isExpanded 應被正確保留為 true")
    #expect(pool.maxLinesPerPage == 4, "reinit 後 maxLinesPerPage 應仍為 4")

    // 再模擬 reloadData：isExpanded: false（使用者未手動展開）。
    pool.reinit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: false,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(pool.isExpanded == false, "reinit 傳入 false 後 isExpanded 應為 false")
    #expect(pool.maxLinesPerPage == 1, "未展開時 maxLinesPerPage 應為 1")
  }

  /// 驗證：init 構造時 isExpanded 也應被正確保留。
  @Test
  func testIsExpandedCorrectAfterInit() throws {
    let poolExpanded = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(poolExpanded.isExpanded == true)
    #expect(poolExpanded.maxLinesPerPage == 4)

    let poolCollapsed = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: false,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(poolCollapsed.isExpanded == false)
    #expect(poolCollapsed.maxLinesPerPage == 1)
  }
}
