// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Testing

@testable import LexiconAssembly

/// 使用者片語辭典之 `#NGRAM:前文鏈` 列（P335）。
///
/// 契約四條：① 前兩格與第 2 格之語義一位元不動；② 僅當某標籤格以 ASCII `NGRAM`
/// （不分大小寫）起首時，該列才作 multigram 解讀；③ 宣告了卻寫壞之列**整列不生效**、
/// 不得落回單元圖；④ 無閘門者一律按單元圖讀取（縱使其餘格看起來像前文鏈）。
private func makeUserPhraseStore(_ text: String) -> LXAssembly.LXCoreEX {
  var store = LXAssembly.LXCoreEX(
    reverse: true,
    consolidate: false,
    defaultScore: { _ in 0 },
    forceDefaultScore: false
  )
  store.replaceData(textData: text)
  return store
}

// MARK: - LXCoreEXNGramTagTests

@Suite(.serialized)
struct LXCoreEXNGramTagTests {
  @Test
  func parsesBigramRow() {
    let store = makeUserPhraseStore("這樣 ㄓㄜˋ-ㄧㄤˋ -2.844 #NGRAM:再\n")
    let grams = store.unigramsFor(key: "ㄓㄜˋ-ㄧㄤˋ")
    #expect(grams.count == 1)
    #expect(grams.first?.current == "這樣")
    #expect(grams.first?.previous == "再")
    #expect(grams.first?.anterior == nil)
    #expect(grams.first?.chainLength == 2)
    #expect(grams.first?.probability == -2.844)
  }

  @Test
  func parsesGapRow() {
    let store = makeUserPhraseStore("的 ㄉㄜ˙ -1.497 #NGRAM:在|*\n")
    let grams = store.unigramsFor(key: "ㄉㄜ˙")
    #expect(grams.count == 1)
    #expect(grams.first?.previous == "*")
    #expect(grams.first?.anterior == "在")
    #expect(grams.first?.chainLength == 2)
    #expect(grams.first?.probability == -1.497)
  }

  @Test
  func parsesTrigramRow() {
    let store = makeUserPhraseStore("館 ㄍㄨㄢˇ -0.362 #NGRAM:圖|書\n")
    let grams = store.unigramsFor(key: "ㄍㄨㄢˇ")
    #expect(grams.count == 1)
    #expect(grams.first?.previous == "書")
    #expect(grams.first?.anterior == "圖")
    #expect(grams.first?.chainLength == 3)
  }

  @Test
  func missingScoreFallsBackToDefaultScore() {
    let store = makeUserPhraseStore("的 ㄉㄜ˙ #NGRAM:在|*\n")
    let grams = store.unigramsFor(key: "ㄉㄜ˙")
    #expect(grams.count == 1)
    #expect(grams.first?.probability == 0)
    #expect(grams.first?.previous == "*")
  }

  @Test
  func gateIsPositionIndependent() {
    let atScoreSlot = makeUserPhraseStore("的 ㄉㄜ˙ #NGRAM:在|*\n")
    let atLineTail = makeUserPhraseStore("的 ㄉㄜ˙ #手調 #NGRAM:在|*\n")
    let lhs = atScoreSlot.unigramsFor(key: "ㄉㄜ˙").first
    let rhs = atLineTail.unigramsFor(key: "ㄉㄜ˙").first
    #expect(lhs?.previous == rhs?.previous)
    #expect(lhs?.anterior == rhs?.anterior)
    #expect(lhs?.probability == rhs?.probability)
  }

  @Test
  func ngramTagIsAsciiCaseInsensitive() {
    for tag in ["#NGRAM:在|*", "#Ngram:在|*", "#ngram:在|*"] {
      let store = makeUserPhraseStore("的 ㄉㄜ˙ -1.497 \(tag)\n")
      #expect(store.unigramsFor(key: "ㄉㄜ˙").first?.previous == "*", "應受理 \(tag)")
    }
  }

  @Test
  func malformedChainDisablesWholeRow() {
    // `*` 不得單獨成鏈、不得居非末位；前文鏈不得逾兩詞；`:` 之後不得為空。
    let fixtures = [
      "的 ㄉㄜ˙ -1.497 #NGRAM:*\n",
      "的 ㄉㄜ˙ -1.497 #NGRAM:*|在\n",
      "的 ㄉㄜ˙ -1.497 #NGRAM:甲|乙|丙\n",
      "的 ㄉㄜ˙ -1.497 #NGRAM:\n",
      "的 ㄉㄜ˙ -1.497 #NGRAM\n",
      "的 ㄉㄜ˙ -1.497 #NGRAM2:在|*\n",
      "的 ㄉㄜ˙ -1.497 #NGRAM:在||*\n",
    ]
    for fixture in fixtures {
      let store = makeUserPhraseStore(fixture)
      #expect(
        store.unigramsFor(key: "ㄉㄜ˙").isEmpty,
        "不合格之 n-gram 列須整列不生效（不得落回單元圖）：\(fixture)"
      )
    }
  }

  @Test
  func rowsWithoutGateStayUnigrams() {
    // 形似前文鏈卻無閘門者，依「當且僅當」一律按單元圖讀取。
    let store = makeUserPhraseStore("的 ㄉㄜ˙ -1.497 在|*\n")
    let grams = store.unigramsFor(key: "ㄉㄜ˙")
    #expect(grams.count == 1)
    #expect(grams.first?.isUnigram == true)
    #expect(grams.first?.probability == -1.497)
  }

  @Test
  func existingRowShapesAreUnchanged() {
    let store = makeUserPhraseStore("""
    封堵 ㄈㄥ-ㄉㄨˇ
    不下 ㄅㄨˋ-ㄒㄧㄚˋ -114.514 #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎 #𝙷𝚞𝚖𝚊𝚗𝙲𝚑𝚎𝚌𝚔𝚁𝚎𝚚𝚞𝚒𝚛𝚎𝚍
    自卑情結 ㄗˋ-ㄅㄟ-ㄑㄧㄥˊ-ㄐㄧㄝˊ #𝙷𝚞𝚖𝚊𝚗𝙲𝚑𝚎𝚌𝚔𝚁𝚎𝚚𝚞𝚒𝚛𝚎𝚍
    """)
    #expect(store.unigramsFor(key: "ㄈㄥ-ㄉㄨˇ").first?.probability == 0)
    #expect(store.unigramsFor(key: "ㄈㄥ-ㄉㄨˇ").first?.isUnigram == true)
    #expect(store.unigramsFor(key: "ㄅㄨˋ-ㄒㄧㄚˋ").first?.probability == -114.514)
    #expect(store.unigramsFor(key: "ㄅㄨˋ-ㄒㄧㄚˋ").first?.isUnigram == true)
    #expect(store.unigramsFor(key: "ㄗˋ-ㄅㄟ-ㄑㄧㄥˊ-ㄐㄧㄝˊ").first?.probability == 0)
  }

  @Test
  func consolidatorKeepsNGramRowVerbatim() {
    var text = """
    # 𝙵𝙾𝚁𝙼𝙰𝚃 𝚘𝚛𝚐.𝚊𝚝𝚎𝚕𝚒𝚎𝚛𝙸𝚗𝚖𝚞.𝚟𝚌𝚑𝚎𝚠𝚒𝚗𝚐.𝚞𝚜𝚎𝚛𝙻𝚊𝚗𝚐𝚞𝚊𝚐𝚎𝙼𝚘𝚍𝚎𝚕𝙳𝚊𝚝𝚊.𝚏𝚘𝚛𝚖𝚊𝚝𝚝𝚎𝚍
    的 ㄉㄜ˙ -1.497 #NGRAM:在|* #手調
    # 孤立的井號行
    #
    """
    let before = text
    LXAssembly.LXConsolidator.consolidate(text: &text, pragma: false)
    #expect(text.contains("的 ㄉㄜ˙ -1.497 #NGRAM:在|* #手調"))
    #expect(text != before) // 至少重排了 pragma 標頭
  }
}
