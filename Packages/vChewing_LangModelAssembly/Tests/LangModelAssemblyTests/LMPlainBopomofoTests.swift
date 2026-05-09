// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing

@testable import LangModelAssembly

// MARK: - LMPlainBopomofoTests

@Suite(.serialized)
struct LMPlainBopomofoTests {
  /// 測試 isExclusive 針對簡體特有字（S 有、T 無）的行為。
  ///
  /// 資料來源：倚天中文 DOS 注音表
  /// "ㄅㄚ˙": {"S":"吧罢琶杷","T":"吧罷琶杷"}
  /// `罢` 只在 S 中出現（T 對應 `罷`），故為簡體特有。
  @Test("[LMPlainBopomofo] isExclusive: S-only character returns true for isCHS=true")
  func testIsExclusiveSOnly() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    // `罢` 是簡體特有字（對應繁體 `罷`）
    let result = lm.isExclusive(isCHS: true, reading: "ㄅㄚ˙", target: "罢")
    #expect(result == true)
  }

  /// 測試 isExclusive 針對繁體特有字（T 有、S 無）的行為。
  ///
  /// "ㄅㄚ˙": {"S":"吧罢琶杷","T":"吧罷琶杷"}
  /// `罷` 只在 T 中出現（S 對應 `罢`），故為繁體特有。
  @Test("[LMPlainBopomofo] isExclusive: T-only character returns true for isCHS=false")
  func testIsExclusiveTOnly() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    // `罷` 是繁體特有字（對應簡體 `罢`）
    let result = lm.isExclusive(isCHS: false, reading: "ㄅㄚ˙", target: "罷")
    #expect(result == true)
  }

  /// 測試簡體特有字在 isCHS=false（查繁體特有）時應回傳 false。
  @Test("[LMPlainBopomofo] isExclusive: S-only character returns false for isCHS=false")
  func testIsExclusiveSOnlyQueriedAsTraditional() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    let result = lm.isExclusive(isCHS: false, reading: "ㄅㄚ˙", target: "罢")
    #expect(result == false)
  }

  /// 測試繁體特有字在 isCHS=true（查簡體特有）時應回傳 false。
  @Test("[LMPlainBopomofo] isExclusive: T-only character returns false for isCHS=true")
  func testIsExclusiveTOnlyQueriedAsSimplified() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    let result = lm.isExclusive(isCHS: true, reading: "ㄅㄚ˙", target: "罷")
    #expect(result == false)
  }

  /// 測試「兩邊都有」的字應回傳 false。
  ///
  /// "ㄅㄚ˙" 中 `吧` 同時存在於 S 與 T，因此既非簡體特有也非繁體特有。
  @Test("[LMPlainBopomofo] isExclusive: character in both S and T returns false")
  func testIsExclusiveCommonCharacter() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    // `吧` 在 S 和 T 中都有
    #expect(lm.isExclusive(isCHS: true, reading: "ㄅㄚ˙", target: "吧") == false)
    #expect(lm.isExclusive(isCHS: false, reading: "ㄅㄚ˙", target: "吧") == false)
  }

  /// 測試 S 與 T 完全相同時（無任何特有字），查詢任意字應回傳 nil。
  ///
  /// "ㄅㄚ": {"S":"八捌巴...","T":"八捌巴..."} ← S == T
  @Test("[LMPlainBopomofo] isExclusive: S==T reading returns nil")
  func testIsExclusiveIdenticalST() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    // "ㄅㄚ" 的 S 與 T 完全一致，不會被加入 distinctionTables
    let result = lm.isExclusive(isCHS: true, reading: "ㄅㄚ", target: "八")
    #expect(result == nil)
  }

  /// 測試不存在的讀音應回傳 nil。
  @Test("[LMPlainBopomofo] isExclusive: nonexistent reading returns nil")
  func testIsExclusiveNonexistentReading() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    let result = lm.isExclusive(isCHS: true, reading: "ㄅㄧㄤ", target: "貓")
    #expect(result == nil)
  }

  /// 測試 target 為 nil 時應回傳 nil。
  @Test("[LMPlainBopomofo] isExclusive: nil target returns nil")
  func testIsExclusiveNilTarget() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    let result = lm.isExclusive(isCHS: true, reading: "ㄅㄚ˙", target: nil)
    #expect(result == nil)
  }

  /// 測試某讀音只有 T-only 字而無 S-only 字時的行為。
  ///
  /// "ㄨㄤˋ": {"S":"忘妄望旺王望迋莣","T":"忘妄望旺王朢迋莣"}
  /// `朢` 是 T-only，S-only 為空集合。
  @Test("[LMPlainBopomofo] isExclusive: reading with only T-only chars (no S-only)")
  func testIsExclusiveOnlyTOnlyAvailable() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    // `朢` 是 T-only
    #expect(lm.isExclusive(isCHS: false, reading: "ㄨㄤˋ", target: "朢") == true)
    // `忘` 是兩邊都有 → false
    #expect(lm.isExclusive(isCHS: false, reading: "ㄨㄤˋ", target: "忘") == false)
    // 查簡體特有 → false（因為 S-only 為空）
    #expect(lm.isExclusive(isCHS: true, reading: "ㄨㄤˋ", target: "忘") == false)
    #expect(lm.isExclusive(isCHS: true, reading: "ㄨㄤˋ", target: "朢") == false)
  }

  /// 測試另一個簡繁互異的讀音。
  ///
  /// "ㄅㄚˇ": {"S":"把靶钯","T":"把靶鈀"}
  /// `钯` 是 S-only，`鈀` 是 T-only。
  @Test("[LMPlainBopomofo] isExclusive: another reading with distinct chars")
  func testIsExclusiveAnotherReading() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    #expect(lm.isExclusive(isCHS: true, reading: "ㄅㄚˇ", target: "钯") == true)
    #expect(lm.isExclusive(isCHS: false, reading: "ㄅㄚˇ", target: "鈀") == true)
    #expect(lm.isExclusive(isCHS: true, reading: "ㄅㄚˇ", target: "把") == false)
  }

  /// 測試 distinctionTables 結構的完整性：表格中至少應包含一些已知的讀音。
  @Test("[LMPlainBopomofo] distinctionTables contains expected readings")
  func testDistinctionTablesContainsExpectedReadings() throws {
    let lm = LMAssembly.LMPlainBopomofo()
    // "ㄅㄚ˙" 有簡繁差異，應在表格中
    let result = lm.isExclusive(isCHS: true, reading: "ㄅㄚ˙", target: "罢")
    #expect(result != nil)
  }

  /// 測試 generateDistinctionHashTables 靜態方法的正確性。
  @Test("[LMPlainBopomofo] generateDistinctionHashTables correctness")
  func testGenerateDistinctionHashTables() throws {
    let sampleData: LMAssembly.LMPlainBopomofo.DataMap = [
      "ㄓㄜˋ": ["S": "这", "T": "這"],
      "ㄊㄚ": ["S": "他她它", "T": "他她它"],
    ]
    let tables = LMAssembly.LMPlainBopomofo.generateDistinctionHashTables(using: sampleData)

    // "ㄓㄜˋ": S-only 有 `这`, T-only 有 `這`
    #expect(tables["ㄓㄜˋ"]?[true]?.contains("这") == true)
    #expect(tables["ㄓㄜˋ"]?[false]?.contains("這") == true)
    #expect(tables["ㄓㄜˋ"]?[true]?.contains("這") == false)
    #expect(tables["ㄓㄜˋ"]?[false]?.contains("这") == false)

    // "ㄊㄚ": S==T，不應出現在表格中
    #expect(tables["ㄊㄚ"] == nil)
  }
}
