// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 注音狂打（狂注）之自動切音節：行為層測試。
//
// 判準本身之逐條移植與其全排列實測見 `ZhuyinAutoChopPredicateTests.swift`；本檔驗的是
// 「判準接上 Handler 之後」之行為。所用讀音一律取自**測試辭典素材自身**（`vanguardTextMap_test.txtMap`
// 內確有之詞條：`ㄍㄠ`＝高（12 同音）、`ㄍㄨㄥ`＝供（19 同音）、`ㄓㄨㄥ`＝中、`ㄒㄧㄣ`＝新）。
//
// - Note: 大千排列之鍵位：ㄍ＝`e`、ㄠ＝`l`、ㄨ＝`j`、ㄥ＝`/`、ㄅ＝`1`、ㄧ＝`u`、ㄢ＝`0`。

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Shared
import Tekkon
import Testing

@testable import LibVanguard

extension LibVanguardTestsRoot.InputHandlerTests {
  /// 以注音狂打鍵入，回傳「組字器實際收到之讀音鍵」。
  ///
  /// - Parameters:
  ///   - keys: 鍵序（大千排列）。
  ///   - zhuyinFurious: 是否開啟注音狂打。
  ///   - parser: 注音排列。
  private func typeZhuyinAndCollectReadingKeys(
    _ keys: String,
    zhuyinFurious: Bool,
    parser: Tekkon.MandarinParser = .ofDachen
  )
    -> [String] {
    guard let testHandler, let testSession else { return [] }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = zhuyinFurious
    testHandler.composer.ensureParser(arrange: parser)
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence(keys)
    return testHandler.assembler.actualKeys
  }

  /// **本 phase 之功能底線**：注音狂打下連續鍵入兩個完整音節，**不必敲聲調、不必按空格**，
  /// 即應各自成鍵入組字器。
  @Test("[IH155] 注音狂打：連打兩音節自動切音節")
  func test_IH155_ZhuyinFuriousAutoChopsConsecutiveSyllables() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    // `el`＝ㄍㄠ；再敲 `e`（ㄍ）時，`ㄍㄠ` 已不可能再延伸 ⇒ 應自動固化，注拼槽重設為 `ㄍ`；
    // 續敲 `j/`＝ㄨㄥ ⇒ 第二音節 `ㄍㄨㄥ`。全程未敲聲調、未按空格。
    var keys = typeZhuyinAndCollectReadingKeys("elej/", zhuyinFurious: true)
    // 第三拍（`e`）時 `ㄍㄠ` 已不可能再延伸 ⇒ 已固化；第二音節 `ㄍㄨㄥ` 尚在注拼槽內
    // （末音節之固化須待下一拍或空格——此與拼音狂拼之末端語義一致）。
    #expect(keys == ["ㄍㄠ"], "實得：\(keys)")
    #expect(testHandler.composer.getComposition() == "ㄍㄨㄥ", "實得：\(testHandler.composer.getComposition())")
    #expect(generateDisplayedText().contains("高"), "組字結果：\(generateDisplayedText())")

    // 以空格固化末音節 ⇒ 兩音節皆入組字器。
    typeSentence(" ")
    keys = testHandler.assembler.actualKeys
    #expect(keys == ["ㄍㄠ", "ㄍㄨㄥ"], "實得：\(keys)")
    let displayed = generateDisplayedText()
    #expect(displayed.contains("高"), "組字結果：\(displayed)")
    #expect(!testSession.recentCommissions.isEmpty || !displayed.isEmpty)
  }

  /// 註音狂打**關閉**時，行為須與今日完全一致：連打兩音節不會自動切音節。
  @Test("[IH164] 注音狂打關閉時之行為與今日完全一致")
  func test_IH164_BehaviourUnchangedWhenZhuyinFuriousIsOff() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    let keys = typeZhuyinAndCollectReadingKeys("elej/", zhuyinFurious: false)
    // 未開狂打 ⇒ 不自動切音節；`e` 覆寫聲母（同值，無觀測變化）、`j` 覆寫介母、`/` 覆寫韻母
    // ⇒ 組字器一個鍵都沒有，且注拼槽停在最後一組按鍵之合成（ㄍㄨㄥ）。
    #expect(keys.isEmpty, "實得：\(keys)")
    // 且注拼槽停在最後一組按鍵之內容（ㄍ 被覆寫為 ㄍ、韻母由 ㄠ 變 ㄥ）。
    #expect(testHandler.composer.getComposition() == "ㄍㄨㄥ", "實得：\(testHandler.composer.getComposition())")
  }

  /// 完整音節之逐鍵不得被誤切：`ㄅㄧ` ＋ `ㄢ` 須續接為 `ㄅㄧㄢ`（§3.2 之條件 ③）。
  @Test("[IH156] 注音狂打：完整音節之逐鍵不被誤切")
  func test_IH156_IncompleteSyllableIsNotChopped() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    // `1`＝ㄅ、`u`＝ㄧ、`0`＝ㄢ。三拍皆不得觸發切音節。
    let keys = typeZhuyinAndCollectReadingKeys("1u0", zhuyinFurious: true)
    #expect(keys.isEmpty, "實得：\(keys)")
    #expect(testHandler.composer.getComposition() == "ㄅㄧㄢ", "實得：\(testHandler.composer.getComposition())")
  }

  /// 動態排列之逐槽覆寫不得被誤切：大千26 之 `qquu`＝ㄅㄚ（§3.2 之 ④d）。
  @Test("[IH157] 注音狂打：大千26 之逐槽覆寫不被誤切")
  func test_IH157_DynamicLayoutSlotOverwriteIsNotChopped() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    let keys = typeZhuyinAndCollectReadingKeys("qquu", zhuyinFurious: true, parser: .ofDachen26)
    #expect(keys.isEmpty, "實得：\(keys)")
    #expect(testHandler.composer.getComposition() == "ㄅㄚ", "實得：\(testHandler.composer.getComposition())")
  }

  /// 聲調鍵之語義不變：判準**永不**對聲調鍵切音節（§3.2 之條件 ②）。
  @Test("[IH158] 注音狂打：聲調鍵永不觸發自動切音節")
  func test_IH158_ToneKeysNeverTriggerAutoChop() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.composer.ensureParser(arrange: .ofDachen)
    // 先令注拼槽非空（ㄍㄠ），否則 ① 會先擋掉。
    testHandler.composer.receiveKey(fromString: "e")
    testHandler.composer.receiveKey(fromString: "l")
    #expect(testHandler.composer.getComposition() == "ㄍㄠ")
    // 大千排列之五個聲調鍵：3＝ˇ、4＝ˋ、6＝ˊ、7＝˙、空格＝陰平。
    for tone in ["3", "4", "6", "7", " "] {
      #expect(
        !testHandler.composer.shouldAutoChopZhuyin(byTyping: Character(tone)),
        "聲調鍵 \(tone) 誤判為切"
      )
    }
  }

  /// SCPC（逐字選字）下注音狂打不生效（沿用既有之 `!prefs.useSCPCTypingMode` 條件）。
  @Test("[IH159] 注音狂打：SCPC 下不生效")
  func test_IH159_ZhuyinFuriousIsInactiveUnderSCPC() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.prefs.useSCPCTypingMode = false
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.composer.ensureParser(arrange: .ofDachen)
    testHandler.prefs.useSCPCTypingMode = false
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)
    #expect(testHandler.isZhuyinFuriousTypingModeEffective)
    testHandler.prefs.useSCPCTypingMode = true
    #expect(testHandler.typingMode == .bopomofoKeyblock)
    #expect(!testHandler.isZhuyinFuriousTypingModeEffective)
  }

  /// 注音狂打**不**寫 `furiousTrail`——trail 是拼音字母 blob，注音鍵流無此概念。
  @Test("[IH163] 注音狂打不寫入 furiousTrail")
  func test_IH163_ZhuyinFuriousDoesNotRecordTrail() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    _ = typeZhuyinAndCollectReadingKeys("elej/", zhuyinFurious: true)
    #expect(testHandler.furiousTrail.isEmpty, "實得：\(testHandler.furiousTrail)")
  }
}
