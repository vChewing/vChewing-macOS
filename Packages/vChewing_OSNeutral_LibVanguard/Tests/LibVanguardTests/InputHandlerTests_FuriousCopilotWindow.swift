// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 狂打（狂拼／狂注）copilot 候選窗之閘門與「未完成讀音」顯示源：行為層測試。
//
// 本檔驗的是「注音狂打接入 copilot 窗」這條線：`hasFuriousFrontPending` 之兩側分流、
// `unfinishedReading` 之分流、以及既有 6 個前方讀取點在注音下之語義。
// 判準（何時自動切音節）之測試在 `InputHandlerTests_ZhuyinFurious.swift` 與
// `ZhuyinAutoChopPredicateTests.swift`。
//
// - Note: 大千排列之鍵位：ㄍ＝`e`、ㄠ＝`l`。測試辭典內 `ㄍㄠ`＝高（同音 12 條）。

import Foundation
import Shared
import Tekkon
import Testing

@testable import LibVanguard

extension LibVanguardTestsRoot.InputHandlerTests {
  // MARK: - 環境設置

  /// 把測試環境切成注音狂打（其餘輸入法一律關閉），並重置組字狀態。
  private func enterZhuyinFuriousTestEnvironment(
    parser: Tekkon.MandarinParser = .ofDachen
  ) {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false // 免 POM 擾動置頂序。
    testHandler.composer.ensureParser(arrange: parser)
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  /// 把測試環境切成拼音狂拼（其餘輸入法一律關閉），並重置組字狀態。
  private func enterPinyinFuriousTestEnvironment() {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.ensureKeyboardParser()
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  /// 還原環境：兩側狂打開關歸零、鍵盤排列回標準注音。
  private func leaveFuriousTestEnvironment() {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  // MARK: - 未完成讀音之分流

  /// 注音狂打之「未完成讀音」顯示源即注拼槽內當前音節；空槽時為 `nil`。
  ///
  /// 並釘住判準之單一性：`hasFuriousFrontPending` 與 `furiousFrontUnfinishedReading != nil`
  /// 必須恆等（否則會出現「copilot 窗開了、頂部 pane 卻無讀音可示」之狀態）。
  @Test("[IH160] 注音狂打：未完成讀音之分流與判準一致性")
  func test_IH160_UnfinishedReadingIsTheComposerSyllableInZhuyinFurious() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    enterZhuyinFuriousTestEnvironment()
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)

    // 空槽：無讀音可示 ⇒ 顯示源與旗子皆落。
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == nil)

    // 只有聲調、尚無聲介韻：注拼槽「非空」但無讀音可示 —— 顯示源仍為 nil
    // （此即注音側「未完成讀音」與「注拼槽非空」之分野）。
    testHandler.composer.receiveKey(fromString: "3") // 大千排列之 3＝ˇ
    #expect(!testHandler.composer.isEmpty)
    #expect(testHandler.composer.getComposition() == "ˇ")
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)

    // 逐鍵：ㄍ → ㄍㄠ，顯示源即該音節之注音原字串。
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("e")
    #expect(testHandler.composer.getComposition() == "ㄍ")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄍ")
    #expect(testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == "ㄍ")

    typeSentence("l")
    #expect(testHandler.composer.getComposition() == "ㄍㄠ")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄍㄠ")
    #expect(testSession.unfinishedReading == "ㄍㄠ")

    // 固化（空格）之後：顯示源與旗子同步落回 nil。
    typeSentence(" ")
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == nil)
  }

  /// 拼音狂拼之 `hasFuriousFrontPending` 語意**不得**因注音側之分流而改變。
  @Test("[IH165] 拼音狂拼：未完成讀音語意不變（回歸護欄）")
  func test_IH165_PinyinFuriousPendingSemanticsUnchanged() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    enterPinyinFuriousTestEnvironment()
    #expect(testHandler.typingMode == .pinyinFuriousTyping)

    // 狂拼停用時：字母流非空亦不得視為「前方待確認讀音」（沿用舊語意）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    typeSentence("gao")
    #expect(testHandler.composer.romajiBuffer == "gao")
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 狂拼啟用時：字母流即顯示源。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    typeSentence("gao")
    #expect(testHandler.composer.romajiBuffer == "gao")
    #expect(testHandler.furiousFrontUnfinishedReading == "gao")
    #expect(testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == "gao")

    // 固化後（空格）旗子落回。
    typeSentence(" ")
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == nil)
  }

  // MARK: - copilot 窗與就地選字

  /// 注音狂打且有未完成音節時，copilot 候選窗成立、置頂為該音節之組句預覽；
  /// 就地選字（滑鼠點選／Shift＋選字鍵同此路徑）把該音節以所選值寫入組字器。
  @Test("[IH161] 注音狂打：copilot 窗成立與就地選字")
  func test_IH161_ZhuyinFuriousCopilotWindowAndInPlaceSelection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    enterZhuyinFuriousTestEnvironment()
    clearTestPOM()

    // 空槽：窗不成立。
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)

    // ㄍㄠ 尚在注拼槽（未固化）⇒ copilot 窗成立，置頂為組句預覽「高」。
    typeSentence("el")
    #expect(testHandler.composer.getComposition() == "ㄍㄠ")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    #expect(testSession.unfinishedReading == "ㄍㄠ")
    guard testSession.state.candidates.count >= 2 else {
      Issue.record("ㄍㄠ 之 copilot 候選不足兩筆：\(testSession.state.candidates.map(\.value))")
      return
    }
    #expect(testSession.state.candidates.first?.value == "高")

    // 就地選字：挑一筆「非置頂」候選，確認後組字器須呈現該值（證明覆寫生效，
    // 而非僅是語言模型自己也會選的置頂值）。
    let target = testSession.state.candidates[1]
    testSession.candidatePairSelectionConfirmed(at: 1)
    #expect(testHandler.composer.isEmpty, "就地選字後注拼槽應清空。")
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(generateDisplayedText() == target.value, "實得：\(generateDisplayedText())")
    // 音節既已入組字器，前方上下文消失 ⇒ copilot 窗不再成立。
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)
    #expect(testSession.unfinishedReading == nil)
  }

  // MARK: - 既有前方讀取點於注音下之語義

  /// 既有 6 個 `hasFuriousFrontPending` 讀取點，在注音狂打下逐一驗其語義。
  ///
  /// 空格／Tab／Enter／標點／方向鍵皆為「先固化前方讀音，再走各自既有語義」——
  /// 注音側悉數沿用，無一改動（§3.5 之表）。
  @Test("[IH162] 注音狂打：空格／Tab／Enter／標點／方向鍵之固化語義")
  func test_IH162_FrontReadPointsUnderZhuyinFurious() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    clearTestPOM()

    /// 重置環境、鍵入 `ㄍㄠ`（前方待確認讀音成立）。
    func prepareTwoPendingKeys() {
      enterZhuyinFuriousTestEnvironment()
      typeSentence("el")
      #expect(testHandler.composer.getComposition() == "ㄍㄠ")
      #expect(testHandler.hasFuriousFrontPending)
    }

    // ① 空格：固化前方讀音並消費本拍空格（語義為「插入讀音」而非「輪替候選／遞交空格」）。
    prepareTwoPendingKeys()
    typeSentence(" ")
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(generateDisplayedText() == "高", "實得：\(generateDisplayedText())")
    #expect(testHandler.composer.isEmpty)
    #expect(!generateDisplayedText().contains(" "))

    // ② Enter：固化前方讀音、停留在輸入狀態（不直接遞交全部內容）。
    prepareTwoPendingKeys()
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.state.type == .ofInputting, "實得：\(testSession.state.type)")

    // ③ Tab：先固化前方讀音，再讓本事件續走正常流程（注拼槽既空，輪替留給該流程）。
    prepareTwoPendingKeys()
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent)
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.state.type == .ofInputting, "實得：\(testSession.state.type)")

    // ④ 無修飾前後方向鍵（W3 規則）：固化前方讀音＋開出正常選字窗。
    prepareTwoPendingKeys()
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent)
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.state.isCandidateContainer, "實得：\(testSession.state.type)")

    // ⑤ 標點：固化前方讀音之後才處理標點（未完成讀音不再擋下標點輸入）。
    // 註：大千排列之 `,` 本身就是注音符號鍵（ㄝ），故 `,` 走的是自動切音節鏈路、
    // 而非標點鏈路；標點讀取點須以「非注音鍵之標點」驅動。
    prepareTwoPendingKeys()
    typeSentence("[")
    #expect(
      testHandler.assembler.actualKeys == ["ㄍㄠ", "_punctuation_["],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.composer.isEmpty,
      "實得：\(testHandler.composer.getComposition())；狀態：\(testSession.state.type)"
    )

    // ⑤′ 大千排列之 `,`＝ㄝ：新音節不可能接續 `ㄍㄠ` ⇒ 自動切音節先固化 `ㄍㄠ`，
    // 該鍵再作為新音節之韻母進入注拼槽（與標點鏈路無涉）。
    prepareTwoPendingKeys()
    typeSentence(",")
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(
      testHandler.composer.getComposition() == "ㄝ",
      "實得：\(testHandler.composer.getComposition())"
    )
  }
}
