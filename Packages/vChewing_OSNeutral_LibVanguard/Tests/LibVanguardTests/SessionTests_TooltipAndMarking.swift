// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Shared
import SwiftExtension
import Tekkon
import Testing

import HomaSharedTestComponents
@testable import LexiconAssembly
@testable import LibVanguard

// Tooltip 與標記：標記態提示、混打讀音樣式、錨點與組字區強化。

// MARK: - SS.TooltipAndMarking

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  /// 驗證 marking state 的 tooltip 在 switchState 中正確生成。
  /// 此測試防禦：ofMarking() 的 call site 在 LibVanguard 層（不連結 MainAssembly），
  /// 無法看到 generateTooltipForMarking()，因此 tooltip 須在 switchState 中產生。
  @Test("SS-TooltipAndMarking-001 Marking state tooltip generated in switch state")
  func test_SS_TooltipAndMarking_001_MarkingStateTooltipGeneratedInSwitchState() throws {
    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    testSession.switchState(.ofAbortion())
    testClientProxy.clear()

    // 使用雙字詞來測試 marking state（確保 markedRange 至少有 2 個字）。
    _ = prepareBasicComposition(sequence: "wu40j4qi4 ")
    // 確認有 composition 後，按 Shift+Left 進入 marking state。
    #expect(testSession.state.hasComposition)
    press(.shiftLeftEvent)
    press(.shiftLeftEvent)
    #expect(testSession.state.type == .ofMarking)
    #expect(!testSession.state.markedRange.isEmpty, "Marked range must be non-empty for tooltip to appear")

    // 核心驗證：tooltip 非空（若為空，showTooltip 會改為 hide）。
    let tooltip = testSession.state.tooltip
    #expect(!tooltip.isEmpty, "Tooltip should be non-empty after entering marking state, but was empty")
    // 驗證 tooltip 顏色狀態為正常（非 denial / error）。
    #expect(
      testSession.state.data.tooltipColorState == .normal || testSession.state.data.tooltipColorState == .prompt,
      "Tooltip color state should be normal or prompt for a new phrase"
    )
  }

  /// 中英混打模式 Tooltip 之讀音呈現：注音以教科書式呈現（輕聲前置）；
  /// 僅當「以漢語拼音顯示組字區讀音」啟用、且該 Tooltip 以橫排呈現時，才改以漢語拼音呈現
  /// ——而該式即**組字區讀音欄那一式**（數字標調附於尾端、`ü` 作 `v`），兩處所見遂一致。
  /// ※ 混打之 ASCII 原文不入 Tooltip（其已由組字區讀音欄承載），故 Tooltip 僅此一項內容。
  /// ※ 教材式標調（`mo3` ⇒ `mǒ`）屬**完整讀音**之呈現（如 `readingThreadForDisplay`），
  ///   未完成讀音側不採（事主 2026-09-29 明示）。
  @Test("SS-TooltipAndMarking-002 Mixed tooltip reading preview style")
  func test_SS_TooltipAndMarking_002_MixedTooltipReadingPreviewStyle() throws {
    let originalCurrent = InputSession.current
    let originalMixed = testHandler.prefs.mixedAlphanumericalEnabled
    let originalHanyuPinyin = testHandler.prefs.showHanyuPinyinInCompositionBuffer
    let originalAlwaysHorizontal = testHandler.prefs.alwaysShowTooltipTextsHorizontally
    let originalVertical = testSession.isVerticalTyping
    defer {
      InputSession.current = originalCurrent
      testHandler.prefs.mixedAlphanumericalEnabled = originalMixed
      testHandler.prefs.showHanyuPinyinInCompositionBuffer = originalHanyuPinyin
      testHandler.prefs.alwaysShowTooltipTextsHorizontally = originalAlwaysHorizontal
      testSession.isVerticalTyping = originalVertical
      testHandler.clear()
    }

    InputSession.current = testSession
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = false
    testSession.isVerticalTyping = false

    // 直驅注拼槽至「ㄇㄛˇ」，避開混輸 auto-split 對鍵序之依賴。
    var composer = testHandler.composer
    composer.clear()
    composer.receiveSequence("ai3", isRomaji: false)
    #expect(composer.getComposition(isHanyuPinyin: false) == "ㄇㄛˇ")
    testHandler.composer = composer
    testHandler.mixedAlphanumericalBuffer = "ai3"

    // 停用「以漢語拼音顯示組字區讀音」：以教科書式注音呈現。
    let bpmfPreview = testHandler.generateStateOfInputting().tooltip
    #expect(bpmfPreview == "ㄇㄛˇ", "實際得到：\(bpmfPreview)")

    // 啟用該偏好且為橫排：改以漢語拼音呈現——即組字區讀音欄那一式。
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = true
    let pinyinPreview = testHandler.generateStateOfInputting().tooltip
    #expect(pinyinPreview == "mo3", "實際得到：\(pinyinPreview)")
    // 對照：與組字區自身之呈現逐字相同（同一轉換函式、不經教材式標調）。
    #expect(composer.getComposition(isHanyuPinyin: true) == "mo3")
    // 混打之 ASCII 原文不入 Tooltip：其已由組字區之讀音欄承載。
    let stateWithMixBuffer = testHandler.generateStateOfInputting()
    #expect(
      stateWithMixBuffer.displayedText.contains("ai3"),
      "實際得到：\(stateWithMixBuffer.displayedText)"
    )

    // 直排輸入且未強制橫排 Tooltip 時，退回教科書式注音。
    testSession.isVerticalTyping = true
    let verticalPreview = testHandler.generateStateOfInputting().tooltip
    #expect(verticalPreview == "ㄇㄛˇ", "實際得到：\(verticalPreview)")

    // 直排但強制 Tooltip 橫排時，仍以漢語拼音呈現。
    testHandler.prefs.alwaysShowTooltipTextsHorizontally = true
    let verticalForcedHorizontal = testHandler.generateStateOfInputting().tooltip
    #expect(verticalForcedHorizontal == "mo3", "實際得到：\(verticalForcedHorizontal)")
    testHandler.prefs.alwaysShowTooltipTextsHorizontally = false
  }

  /// 中英混打模式下，內文 Tooltip 須錨在「未完成讀音（此際即注拼槽所消化之注音）後方之
  /// 游標位置」上——與選字窗之錨定（`u16MarkedRange.lowerBound`）同源，故能跟著該位置
  /// 同步移動自身的位置；而非恆錨在組字區最前方（既有行為）。
  ///
  /// 該位置另存於 `IMEState`：`.ofInputting` 狀態的 `marker` 會被 `getMitigatedState(_:)`
  /// 拉平至 `cursor`，故此測試同時釘死「marker 已拉平、錨點資訊仍在」之狀態形制。
  ///
  /// - Note: 混打之 Tooltip 只承載讀音、不承載 ASCII 原文（原文由組字區讀音欄承載），
  ///   故本靶以「進注拼槽之小寫鍵」造出 Tooltip：大寫鍵（如 `T`）不進注拼槽 ⇒ 無讀音可示
  ///   ⇒ 根本無 Tooltip 可錨（該態另由 `IH-MixedAlnum-039` 釘住）。
  @Test("SS-TooltipAndMarking-003 Mixed alnum tooltip anchors at cursor pos behind reading")
  func test_SS_TooltipAndMarking_003_MixedAlnumTooltipAnchorsAtCursorPosBehindReading() throws {
    let tooltipUI = MockTooltipUI()
    let originalTooltipUI = testUI.tooltipUI
    let originalMixed = testHandler.prefs.mixedAlphanumericalEnabled
    defer {
      testUI.tooltipUI = originalTooltipUI
      testHandler.prefs.mixedAlphanumericalEnabled = originalMixed
      testClientProxy.lineHeightRectProvider = nil
      testClientProxy.clear()
      testHandler.clear()
    }
    testUI.tooltipUI = tooltipUI
    testHandler.prefs.mixedAlphanumericalEnabled = true
    // 逐分量斷言錨點（`CGPoint` 於跨平台環境不一定遵從 `Equatable`）。
    func expectAnchor(_ expectedX: CGFloat, _ expectedY: CGFloat, _ label: String) {
      #expect(
        tooltipUI.shownPoint?.x == expectedX && tooltipUI.shownPoint?.y == expectedY,
        "\(label)：實際得到：\(String(describing: tooltipUI.shownPoint))"
      )
    }
    // 以座標自身作為行高矩形之 x 值（×10）與 y 值（100）：錨在哪個座標一目了然。
    // 如此亦與既有錨定（客體未提供量測值時的零矩形，x = 0、y = 0）可資區別。
    testClientProxy.lineHeightRectProvider = { u16CursorPos in
      CGRect(
        origin: CGPoint(x: CGFloat(u16CursorPos) * 10, y: 100),
        size: CGSize(width: 10, height: 20)
      )
    }

    resetToAbortionAndClear()

    // 先組出中文「你」（注音 ㄋㄧˇ），再鍵入小寫 ASCII「s」（大千排列之 ㄋ，進注拼槽 ⇒
    // Tooltip 有讀音可示；其 ASCII 原文則由組字區之讀音欄承載）。
    typeSentenceOrCandidates("su3")
    #expect(testSession.state.displayedText == "你", "實際得到：\(testSession.state.displayedText)")
    typeSentenceOrCandidates("s")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "你s", "實際得到：\(testSession.state.displayedText)")

    // 未完成讀音（消化自混打緩衝之注音）後方之游標位置 = 1（緊隨「你」之後）；marker 已被拉平至 cursor。
    #expect(testSession.state.data.cursorPosRightBehindTheUnfinishedReading == 1)
    #expect(testSession.state.data.u16CursorPosRightBehindTheUnfinishedReading == 1)
    #expect(
      testSession.state.marker == testSession.state.cursor,
      "`.ofInputting` 狀態之 marker 應已被拉平至 cursor，故該起點須另存一份"
    )

    // 錨點：該位置（u16 = 1）之矩形原點為 (10, 100)；若仍錨在組字區最前方則會得到 (0, 0)。
    // Tooltip 之內容即該讀音（混打之 ASCII 原文不入 Tooltip）。
    #expect(tooltipUI.shownTooltip == "ㄋ", "實際得到：\(String(describing: tooltipUI.shownTooltip))")
    expectAnchor(10, 100, "混輸 Tooltip 應錨在未完成讀音後方之游標位置上")
    #expect(
      testClientProxy.queriedU16CursorPositions.contains(1),
      "應以混輸起點（u16 = 1）向客體量測行高矩形；實查座標：\(testClientProxy.queriedU16CursorPositions)"
    )
    // 次序：錨點之座標量測必須發生在客體收到本狀態之組字區內容之後。
    // 否則客體的內文組字區還是上一個狀態的內容，本狀態的索引對其即屬越界
    // （`clientLineHeightRectForU16CursorPos:` 對越界值會逐位遞減探測），錨點遂落在前者。
    let markedSetupIdx = testClientProxy.calls.lastIndex(of: .markedTextSetup("你s"))
    let anchorQueryIdx = testClientProxy.calls.lastIndex(of: .lineHeightQuery(1))
    #expect(markedSetupIdx != nil && anchorQueryIdx != nil)
    #expect(
      (markedSetupIdx ?? 0) < (anchorQueryIdx ?? 0),
      "座標量測須晚於組字區內容落地；實查呼叫序列：\(testClientProxy.calls)"
    )

    // 對照組一：未完成讀音自組字區最前方起算時（空組字區），錨點 = 座標 0 之矩形。
    tooltipUI.hide()
    resetToAbortionAndClear()
    typeSentenceOrCandidates("s")
    #expect(testSession.state.data.u16CursorPosRightBehindTheUnfinishedReading == 0)
    #expect(tooltipUI.shownTooltip == "ㄋ", "實際得到：\(String(describing: tooltipUI.shownTooltip))")
    expectAnchor(0, 100, "未完成讀音自組字區最前方起算時應錨在座標 0")

    // 對照組一之二：混打緩衝非空、而注拼槽無讀音可示時（大寫鍵不進注拼槽），
    // Tooltip 既無內容即整窗收起——原文仍見於組字區之讀音欄。
    tooltipUI.hide()
    resetToAbortionAndClear()
    let showCountBeforeUppercase = tooltipUI.showCount
    typeSentenceOrCandidates("T")
    #expect(testSession.state.displayedText == "T", "實際得到：\(testSession.state.displayedText)")
    #expect(
      tooltipUI.showCount == showCountBeforeUppercase,
      "無讀音可示時不得以 ASCII 原文充作 Tooltip 內容"
    )

    // 對照組二：非輸入狀態（標記狀態）之 Tooltip 仍錨在既有錨定（組字區最前方之矩形）
    // ——該類狀態不由 `generateStateOfInputting()` 生成，故不帶「未完成讀音後方之游標位置」。
    testHandler.prefs.mixedAlphanumericalEnabled = false
    _ = prepareBasicComposition(sequence: "wu40j4qi4 ")
    press(.shiftLeftEvent)
    #expect(testSession.state.type == .ofMarking)
    #expect(
      testSession.state.data.u16CursorPosRightBehindTheUnfinishedReading == nil,
      "標記狀態不應承載該游標位置"
    )
    expectAnchor(0, 0, "非輸入狀態應沿用既有錨定")

    // 對照組三：輸入狀態之未完成讀音為空時，該值繼承當前輸入游標位置，錨點隨之落在
    // 該游標位置上（而非組字區最前方）——此乃「輸入狀態一律賦值」之行為面。
    resetToAbortionAndClear()
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄋㄧˇ") }
    testSession.switchState(testHandler.generateStateOfInputting())
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "你", "實際得到：\(testSession.state.displayedText)")
    #expect(
      testSession.state.data.cursorPosRightBehindTheUnfinishedReading == testSession.state.cursor,
      "未完成讀音為空時應繼承當前輸入游標位置"
    )
    // 該狀態之 Tooltip 本為空（不開窗），故直接注入一段文案以驗證錨定路徑。
    var stateWithTooltip = testHandler.generateStateOfInputting()
    stateWithTooltip.tooltip = "injected"
    let anchorU16Pos = stateWithTooltip.data.u16CursorPosRightBehindTheUnfinishedReading ?? -1
    #expect(anchorU16Pos == 1, "繼承所得之 UTF-16 座標應為 1；實際得到：\(anchorU16Pos)")
    testSession.switchState(stateWithTooltip)
    #expect(tooltipUI.shownTooltip == "injected")
    expectAnchor(
      CGFloat(anchorU16Pos) * 10, 100,
      "未完成讀音為空時應錨在當前輸入游標位置上"
    )
  }

  /// 安全強化組字區（`clientMitigationLevel >= 2`）下，`getMitigatedState(_:)` 不會把
  /// `.ofInputting` 狀態的 `marker` 拉平至 `cursor`，故既有之不變量成立：
  /// 「未完成讀音後方之游標位置」＝`marker`，且 marked range 恰為該讀音所占之區段。
  /// 浮動組字窗（PCB）即依此二者繪製——`update(using:)` 以 `state.u16MarkedRange` 決定
  /// 標記區域的底色、以 `state.u16Cursor` 擺放閃爍游標；故 PCB 內「整段 reading 皆顯示為
  /// marked range」乃此狀態形制之直接結果。
  @Test("SS-TooltipAndMarking-004 Hardened buffer keeps marker equal to cursor pos behind reading")
  func test_SS_TooltipAndMarking_004_HardenedBufferKeepsMarkerEqualToCursorPosBehindReading() throws {
    let originalHardened = testHandler.prefs.securityHardenedCompositionBuffer
    let originalMixed = testHandler.prefs.mixedAlphanumericalEnabled
    defer {
      testHandler.prefs.securityHardenedCompositionBuffer = originalHardened
      testHandler.prefs.mixedAlphanumericalEnabled = originalMixed
      testHandler.clear()
    }
    testHandler.prefs.mixedAlphanumericalEnabled = false
    testHandler.prefs.securityHardenedCompositionBuffer = true
    #expect(testSession.clientMitigationLevel >= 2, "偏好設定後應進入 PCB 路徑")

    resetToAbortionAndClear()
    // 先讓組字區有「你」（讀音 ㄋㄧˇ 固化進組字器），再開始組新讀音「ㄋ」（注音鍵 s）。
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄋㄧˇ") }
    typeSentenceOrCandidates("s")
    var state = testSession.state
    #expect(state.type == .ofInputting)
    #expect(state.displayedText == "你ㄋ", "實際得到：\(state.displayedText)")

    let anchor = state.data.cursorPosRightBehindTheUnfinishedReading
    #expect(anchor == 1, "實際得到：\(String(describing: anchor))")
    #expect(
      state.marker == anchor,
      "安全強化組字區下 marker 不應被拉平：marker \(state.marker)／anchor \(String(describing: anchor))"
    )
    #expect(state.markedRange == 1 ..< 2, "marked range 應恰為該讀音所占之區段")
    #expect(state.u16MarkedRange.lowerBound == state.data.u16CursorPosRightBehindTheUnfinishedReading)
    // 閃爍游標（PCB 之 `currentCaretIndex`）位於 marked range 之終點，而非該欄位本身。
    #expect(state.u16Cursor == state.u16MarkedRange.upperBound)

    // 對照：一般客體（`clientMitigationLevel < 2`）下 marker 會被拉平至 cursor，
    // 故 marked range 為空、且與該欄位不再同值（除非未完成讀音為空）。
    testHandler.prefs.securityHardenedCompositionBuffer = false
    #expect(testSession.clientMitigationLevel < 2)
    testSession.switchState(testHandler.generateStateOfInputting())
    state = testSession.state
    #expect(state.marker == state.cursor, "一般客體下 marker 應被拉平至 cursor")
    #expect(state.markedRange.isEmpty)
    #expect(state.data.cursorPosRightBehindTheUnfinishedReading == 1)
  }
}
