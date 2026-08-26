// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

@testable import Tekkon
import Testing

// MARK: - TekkonTestsUtilities

@MainActor
@Suite(.serialized)
struct TekkonTestsUtilities {
  @Test("[Tekkon] HasString_EdgeCases")
  func testHasStringEdgeCases() async throws {
    #expect("ㄅㄧㄢˋ".has(string: "ㄧㄢ"))
    #expect(!"ㄅㄧㄢˋ".has(string: "ㄧㄥ"))
    #expect("aaa".has(string: "aa"))
    #expect(!"x".has(string: "xyz"))
    // 空目標的既有語義：僅當自身為空時為 true。
    #expect("".has(string: ""))
    #expect(!"a".has(string: ""))
    #expect(!"".has(string: "a"))
  }

  @Test("[Tekkon] MakeToneInsensitiveVariants_Basic")
  func testMakeToneInsensitiveVariantsBasic() async throws {
    // 無調讀音展開為同音節聲調候選桶：陰平以空字串表示，
    // 順序依 `allowedIntonations`（" ", "ˊ", "ˇ", "ˋ", "˙"）。
    let result = Tekkon.makeToneInsensitiveVariants(of: "ㄕ")
    #expect(result == ["ㄕ", "ㄕˊ", "ㄕˇ", "ㄕˋ", "ㄕ˙"])
    // 去重守衛：回傳內容不得重複。
    #expect(result.count == Tekkon.allowedIntonations.count)
    #expect(Set(result).count == result.count)
  }

  @Test("[Tekkon] MakeToneInsensitiveVariants_EmptyReading")
  func testMakeToneInsensitiveVariantsEmptyReading() async throws {
    let result = Tekkon.makeToneInsensitiveVariants(of: "")
    #expect(result == ["", "ˊ", "ˇ", "ˋ", "˙"])
  }

  @Test("[Tekkon] HasScalar_Basic")
  func testHasScalarBasic() async throws {
    #expect("ㄅㄧㄢˋ".has(scalar: "ˋ"))
    #expect(!"ㄅㄧㄢ".has(scalar: "ˋ"))
  }

  @Test("[Tekkon] Swapping_EdgeCases")
  func testSwappingEdgeCases() async throws {
    #expect("a-b-c".swapping("-", with: "+") == "a+b+c")
    #expect("ㄅㄧㄢ".swapping("ㄧㄢ", with: "ian") == "ㄅian")
    // 空替換內容等同於刪除目標。
    #expect("a-b-c".swapping("-", with: "") == "abc")
    // 空目標的既有語義：原樣回傳自身。
    #expect("abc".swapping("", with: "x") == "abc")
    // 目標自體重疊時採不重疊比對：自左向右、命中即跳過整段目標。
    #expect("aaaa".swapping("aa", with: "b") == "bb")
    #expect("aaa".swapping("aa", with: "b") == "ba")
    // 無命中時原樣回傳。
    #expect("abc".swapping("xyz", with: "b") == "abc")
  }

  @Test("[Tekkon] RestoreToneOneInPhona_EdgeCases")
  func testRestoreToneOneEdgeCases() async throws {
    // 空字串防呆（先前實作會在取用末字時崩潰）。
    #expect(Tekkon.restoreToneOneInPhona(target: "") == "")
    #expect(Tekkon.restoreToneOneInPhona(target: "ㄉㄧㄠ") == "ㄉㄧㄠ1")
    #expect(Tekkon.restoreToneOneInPhona(target: "ㄉㄧㄠˋ") == "ㄉㄧㄠˋ")
    #expect(Tekkon.restoreToneOneInPhona(target: "ㄉㄧㄠ˙") == "ㄉㄧㄠ˙")
    // 含底線時不恢復陰平。
    #expect(Tekkon.restoreToneOneInPhona(target: "ㄉ_ㄠ") == "ㄉ_ㄠ")
  }

  @Test("[Tekkon] CnvPhonaToHanyuPinyin_FullTableSweep")
  func testPhonaToPinyinFullTableSweep() async throws {
    // 對照表全表掃描：bucket 化之後每筆條目仍須精確命中。
    for (phona, pinyin) in Tekkon.arrPhonaToHanyuPinyin {
      #expect(Tekkon.cnvPhonaToHanyuPinyin(targetJoined: phona) == pinyin)
    }
  }

  @Test("[Tekkon] CnvPhonaToHanyuPinyin_LongestMatch")
  func testPhonaToPinyinLongestMatch() async throws {
    // 最長比對優先：三字組合不得被拆成「聲母＋韻母」。
    #expect(Tekkon.cnvPhonaToHanyuPinyin(targetJoined: "ㄅㄧㄥ") == "bing")
    #expect(Tekkon.cnvPhonaToHanyuPinyin(targetJoined: "ㄅㄧㄥˋ") == "bing4")
    // 未命中條目的字元原樣保留。
    #expect(Tekkon.cnvPhonaToHanyuPinyin(targetJoined: "幹") == "幹")
  }

  @Test("[Tekkon] CnvHanyuPinyinToPhona_Compound")
  func testPinyinToPhonaCompound() async throws {
    #expect(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "shang4") == "ㄕㄤˋ")
    #expect(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "zhang1") == "ㄓㄤ")
    #expect(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "zhang1", newToneOne: " ") == "ㄓㄤ ")
    // 含不允許字元（非半形英數）時放棄轉換、原樣回傳。
    #expect(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "nǐ") == "nǐ")
  }
}
