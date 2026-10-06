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

// 熱鍵：功能鍵（F1–F20）、Command 系未認領熱鍵、copilot 窗之熱鍵隔離。

// MARK: - SS.HotKey

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  /// 狂拼 copilot 候選窗的 tooltip：就地選字需 Shift＋選字鍵，
  /// 候選窗以專屬 Shift 提示取代「⚡️ 快速候選」。
  @Test("SS-HotKey-001 Furious copilot window tooltip shows Shift hint")
  func test_SS_HotKey_001_FuriousCopilotWindowTooltipShowsShiftHint() throws {
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「shijiedaz」：前段自動 chop 提交（世測界測大測），注拼槽暫存「z」。
    typeSentenceOrCandidates("shijiedaz")

    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    #expect(!testSession.state.candidates.isEmpty)
    // 專屬 Shift 提示： HoldShiftToSelect（測試環境無 l10n 資源、`.i18n` 回退為原鍵名，故以鍵名斷言）。
    #expect(testSession.candidateToolTip(shortened: false).contains("HoldShiftToSelect"))
    // `shortened: true` 的場合無須測試了。
  }

  /// 狂拼 copilot 候選窗與 JKHL（VIM 式候選導航）重詮釋的隔離：
  /// copilot 窗為唯讀顯示（選取走 Shift+選字鍵），其顯示中 JKHL 不得把字母鍵
  /// （H/J/K/L）轉為方向鍵——否則 zh/ch/sh 的第二個 romaji「h」會被轉成
  /// LeftArrow、誤觸狂拼「觸發鍵固化」、提早提交未完成讀音並開出正常選字窗
  /// （修復前實測：buffer 清空、keys=1、state=ofCandidates）。
  /// 本測試鎖定縱排與橫排兩種選字窗情境：修復後「h」皆維持字母（buffer「sh」）、
  /// 組字器零改動、copilot 窗持續可見。
  @Test("SS-HotKey-002 Furious copilot window ignores JKHL reinterpretation")
  func test_SS_HotKey_002_FuriousCopilotWindowIgnoresJKHLReinterpretation() throws {
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄙㄢ"], value: "三測", score: 9),
      .init(keyArray: ["ㄕˋ"], value: "是測", score: 8.5),
      .init(keyArray: ["ㄕㄜˋ"], value: "社測", score: 8),
    ]
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.candidateStateJKHLBehavior = 0
      testHandler.prefs.useHorizontalCandidateList = true
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.candidateStateJKHLBehavior = 1 // JKHL 行為 1：HL 翻行列
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    for isVertical in [false, true] {
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.useHorizontalCandidateList = !isVertical
      testHandler.currentLM.syncPrefs()
      handleKeyEvent(.init(chars: "s"))
      #expect(testHandler.composer.romajiBuffer == "s")
      #expect(testSession.isFuriousCopilotCandidateWindowVisible)
      // 修復前：JKHL 把「h」轉為方向鍵 → 固化 → 正常選字窗誤開。
      handleKeyEvent(.init(chars: "h", keyCode: 4))
      #expect(testHandler.composer.romajiBuffer == "sh", "JKHL 不得把字母鍵 h 轉為方向鍵（isVertical=\(isVertical)）")
      #expect(testHandler.assembler.keys.isEmpty)
      #expect(testSession.state.type == .ofInputting)
      #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    }
  }

  /// 組字內容尚未遞交時按功能鍵（F1－F20），輸入法必須就地攔截該鍵：
  /// 既不得遞交任何字元、亦不得令未遞交的讀音消失。
  ///
  /// 病灶原委：`handleKeyDown` 的 Fn 快篩（`fnKeyCheck`）對任何帶 `.function` 旗標、
  /// 且不在「無辜鍵碼」清單內者一律直接放行——功能鍵正落在該清單之外。事件一放行即由
  /// 客體應用接手，客體會以該鍵自身的字元改寫組字區（未遞交的讀音消失、並寫入不可列印
  /// 字元），`InputHandler_TriageInput` 終末處理那道「保護 F1－F12 不干擾組字區」的
  /// 防線因此永遠看不到它。
  ///
  /// 攔截**不得靜默**（否則使用者會以為功能鍵故障）：須發一次專用蜂鳴碼 `F1F20BEE`，
  /// 而**非**終末處理那道泛用碼 `A9BFF20E`。
  @Test("SS-HotKey-003 Function key does not disturb uncommitted reading")
  func test_SS_HotKey_003_FunctionKeyDoesNotDisturbUncommittedReading() throws {
    testHandler.prefs.useSCPCTypingMode = false
    resetToEmptyAndClear()

    typeSentenceOrCandidates("su3")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.hasComposition)
    let compositionBefore = testHandler.assembler.assembledSentence.map(\.value).joined()
    #expect(compositionBefore == "你")

    let handled = testSession.handleEvent(KBEvent.KeyEventData.f5Event.asEvent)
    #expect(handled, "組字內容尚未遞交時，F5 必須被輸入法攔截。")
    #expect(testClientProxy.toString().isEmpty, "F5 不得遞交任何內容至客體。")
    #expect(
      testHandler.assembler.assembledSentence.map(\.value).joined() == compositionBefore,
      "F5 不得改動尚未遞交的組字內容。"
    )
    #expect(
      recordedErrors == ["F1F20BEE"],
      "攔截功能鍵須發專用蜂鳴碼 F1F20BEE（不得靜默、亦不得沿用終末處理之 A9BFF20E），實際得到 \(recordedErrors)"
    )

    // 遞交路徑須完好無損：Enter 仍得「你」。
    press(.dataEnterReturn)
    #expect(testClientProxy.toString() == "你")
  }

  /// 未完成讀音（尚在注拼槽內、未湊成音節）同樣屬「未遞交的內容」，功能鍵不得令其消失。
  @Test("SS-HotKey-004 Function key does not disturb unfinished reading")
  func test_SS_HotKey_004_FunctionKeyDoesNotDisturbUnfinishedReading() throws {
    testHandler.prefs.useSCPCTypingMode = false
    resetToEmptyAndClear()

    typeSentenceOrCandidates("su")
    #expect(testSession.state.type == .ofInputting)
    #expect(testHandler.composer.value == "ㄋㄧ")
    #expect(!testHandler.isComposerOrCalligrapherEmpty)

    let handled = testSession.handleEvent(KBEvent.KeyEventData.f5Event.asEvent)
    #expect(handled, "注拼槽內尚有未完成讀音時，F5 必須被輸入法攔截。")
    #expect(testHandler.composer.value == "ㄋㄧ", "F5 不得清掉未完成的讀音。")
    #expect(testClientProxy.toString().isEmpty, "F5 不得遞交任何內容至客體。")
    #expect(
      recordedErrors == ["F1F20BEE"],
      "攔截功能鍵須發專用蜂鳴碼 F1F20BEE，實際得到 \(recordedErrors)"
    )
  }

  /// 對照組：組字區與注拼槽皆空時，功能鍵照舊放行給系統（這些鍵可能會用來觸發系統功能），
  /// 且不得發任何蜂鳴碼。
  @Test("SS-HotKey-005 Function key passes through when nothing pending")
  func test_SS_HotKey_005_FunctionKeyPassesThroughWhenNothingPending() throws {
    resetToEmptyAndClear()

    let handled = testSession.handleEvent(KBEvent.KeyEventData.f5Event.asEvent)
    #expect(!handled, "組字內容為空時，F5 應放行給系統。")
    #expect(testClientProxy.toString().isEmpty, "F5 不得在空狀態下遞交任何內容。")
    #expect(testSession.state.type == .ofEmpty)
    #expect(recordedErrors.isEmpty, "放行功能鍵時不得發蜂鳴碼，實際得到 \(recordedErrors)")
  }

  /// 攔截範圍僅限功能鍵本身：`Fn` 與其它鍵之組合（如表情符號選擇器 `Fn+E`）維持放行，
  /// 以免 July-2026 那套「略過 Fn 熱鍵」的政策被本修正一併撤除。
  @Test("SS-HotKey-006 Fn non-function-key combination still passes through")
  func test_SS_HotKey_006_FnNonFunctionKeyCombinationStillPassesThrough() throws {
    testHandler.prefs.useSCPCTypingMode = false
    resetToEmptyAndClear()

    typeSentenceOrCandidates("su3")
    #expect(testSession.state.hasComposition)

    let handled = testSession.handleEvent(KBEvent.KeyEventData.fnEWithLetterEvent.asEvent)
    #expect(!handled, "Fn+字母鍵不屬功能鍵，應維持放行。")
    #expect(testClientProxy.toString().isEmpty, "放行 Fn+字母鍵時，輸入法本身不得遞交內容。")
  }

  // MARK: - 輸入法未認領之 Command 系熱鍵（先遞交、後交還客體）

  /// 輸入法自身未認領的 Command 系熱鍵在組字期間**先遞交既有內容、再把事件交還客體**。
  ///
  /// 病灶有兩層：① 分診之終末處理是「誰都沒認領」的終點，原本會將它攔下並發蜂鳴碼
  /// `A9BFF20E`；② **僅交還而不遞交是不夠的**——客體在輸入法仍持有內文組字區（marked text）
  /// 期間不會執行自己的 Command 系熱鍵（Chrome 之 `Cmd+Ctrl+C`／`Cmd+Ctrl+W` 即因此收不到）。
  /// 帶 Command 的組合鍵一律是選單／熱鍵語意、不是文字資料，故先行遞交亦不污染客體文件。
  @Test("SS-HotKey-007 Unclaimed Command shortcuts commit then reach client")
  func test_SS_HotKey_007_UnclaimedCommandShortcutsCommitThenReachClient() throws {
    testHandler.prefs.useSCPCTypingMode = false

    func verifyCommitsAndReleases(_ label: String, _ data: KBEvent.KeyEventData) {
      resetToEmptyAndClear()
      typeSentenceOrCandidates("su3")
      #expect(testSession.state.type == .ofInputting)
      #expect(testSession.state.hasComposition)
      #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "你")

      let handled = testSession.handleEvent(data.asEvent)
      #expect(!handled, "\(label) 屬輸入法未認領的 Command 系熱鍵，必須交還客體。")
      #expect(recordedErrors.isEmpty, "交還 \(label) 不得發蜂鳴碼，實際得到 \(recordedErrors)")
      #expect(
        testClientProxy.toString() == "你",
        "交還 \(label) 之前須先遞交既有組字內容，實際得到 \(testClientProxy.toString())"
      )
      #expect(
        testSession.state.type == .ofEmpty,
        "遞交後應收斂至空狀態（客體方得脫離組字態），實際得到 \(testSession.state.type.rawValue)"
      )
      #expect(testHandler.assembler.isEmpty, "遞交後組字器應已清空。")
    }

    verifyCommitsAndReleases(
      "Cmd+Ctrl+W", .init(flags: [.command, .control], chars: "w", keyCode: 13)
    )
    verifyCommitsAndReleases(
      "Cmd+Ctrl+C", .init(flags: [.command, .control], chars: "c", keyCode: 8)
    )
    verifyCommitsAndReleases("Cmd+W", .init(flags: [.command], chars: "w", keyCode: 13))
  }

  /// 對照組：組字區與注拼槽皆空時，Command 系熱鍵照舊交還，且不遞交任何內容
  /// （既有行為之回歸保證）。
  @Test("SS-HotKey-008 Unclaimed Command shortcuts reach client when nothing pending")
  func test_SS_HotKey_008_UnclaimedCommandShortcutsReachClientWhenNothingPending() throws {
    testHandler.prefs.useSCPCTypingMode = false
    resetToEmptyAndClear()
    #expect(testSession.state.type == .ofEmpty)

    let chords: [(String, KBEvent.KeyEventData)] = [
      ("Cmd+Ctrl+W", .init(flags: [.command, .control], chars: "w", keyCode: 13)),
      ("Cmd+Ctrl+C", .init(flags: [.command, .control], chars: "c", keyCode: 8)),
      ("Cmd+W", .init(flags: [.command], chars: "w", keyCode: 13)),
    ]
    for (label, data) in chords {
      #expect(!testSession.handleEvent(data.asEvent), "\(label) 應交還客體。")
    }
    #expect(recordedErrors.isEmpty, "交還時不得發蜂鳴碼，實際得到 \(recordedErrors)")
    #expect(testClientProxy.toString().isEmpty, "空狀態下不得遞交任何內容。")
  }

  /// 界線：**不帶 Command** 的組合鍵仍屬資料鍵，組字期間照舊攔截
  /// （否則控制字元會漏進客體文件）。
  @Test("SS-HotKey-009 Non-Command chords are still blocked while composing")
  func test_SS_HotKey_009_NonCommandChordsAreStillBlockedWhileComposing() throws {
    testHandler.prefs.useSCPCTypingMode = false
    resetToEmptyAndClear()
    typeSentenceOrCandidates("su3")
    #expect(testSession.state.hasComposition)

    let handled = testSession.handleEvent(
      KBEvent.KeyEventData(flags: [.control], chars: "w", keyCode: 13).asEvent
    )
    #expect(handled, "Ctrl+W 不帶 Command，仍屬資料鍵，組字期間不得交還。")
    #expect(
      recordedErrors == ["A9BFF20E"],
      "攔截資料鍵仍須發終末處理之蜂鳴碼，實際得到 \(recordedErrors)"
    )
    #expect(testSession.state.hasComposition, "攔截不得摧毀組字狀態。")
    #expect(testClientProxy.toString().isEmpty, "攔截時不得遞交任何內容。")
  }

  /// 選字窗內未認領的 Command 系熱鍵亦先遞交、後交還；且不得發出選字窗那道泛用蜂鳴碼
  /// `172A0F81`（該碼屬「已認領而落空」，與本情境有別）。
  @Test("SS-HotKey-010 Unclaimed Command shortcuts commit then reach client in candidate window")
  func test_SS_HotKey_010_UnclaimedCommandShortcutsCommitThenReachClientInCandidateWindow() throws {
    func prepareCandidateWindow() {
      _ = prepareBasicComposition(sequence: "dk ru4")
      press(.dataArrowDown)
      #expect(testSession.state.type == .ofCandidates)
      syncCandidateControllerCount()
    }

    prepareCandidateWindow()
    let handled = testSession.handleEvent(
      KBEvent.KeyEventData(flags: [.command, .control], chars: "w", keyCode: 13).asEvent
    )
    #expect(!handled, "選字窗內未認領的 Cmd+Ctrl+W 必須交還客體。")
    #expect(
      recordedErrors.isEmpty,
      "交還時不得發蜂鳴碼（含 172A0F81），實際得到 \(recordedErrors)"
    )
    #expect(
      testClientProxy.toString() == "科技",
      "交還之前須先遞交既有組字內容，實際得到 \(testClientProxy.toString())"
    )
    #expect(testSession.state.type == .ofEmpty, "遞交後應收斂至空狀態。")

    // 對照組：不帶 Command 的未認領按鍵仍走原路徑（蜂鳴 + 攔截）。
    prepareCandidateWindow()
    let stillBlocked = testSession.handleEvent(
      KBEvent.KeyEventData(flags: [.control], chars: "w", keyCode: 13).asEvent
    )
    #expect(stillBlocked, "選字窗內不帶 Command 的未認領按鍵仍須攔截。")
    #expect(
      recordedErrors == ["172A0F81"],
      "選字窗攔截未認領按鍵仍須發該處之蜂鳴碼，實際得到 \(recordedErrors)"
    )
    #expect(testSession.state.type == .ofCandidates, "攔截不得摧毀選字窗狀態。")
  }

  /// 尚在注拼槽、未成音節之讀音不得因交還而變成原文遞交給客體：遞交與 IMK 之強制遞交
  /// （`commitComposition:`）同源，故未完成讀音之去留照既有偏好 `trimUnfinishedReadingsOnCommit`。
  @Test("SS-HotKey-011 Unfinished reading is trimmed when releasing Command shortcut")
  func test_SS_HotKey_011_UnfinishedReadingIsTrimmedWhenReleasingCommandShortcut() throws {
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.trimUnfinishedReadingsOnCommit = true
    resetToEmptyAndClear()
    typeSentenceOrCandidates("su")
    #expect(testHandler.composer.value == "ㄋㄧ")
    #expect(!testHandler.isComposerOrCalligrapherEmpty)

    let handled = testSession.handleEvent(
      KBEvent.KeyEventData(flags: [.command, .control], chars: "w", keyCode: 13).asEvent
    )
    #expect(!handled, "未完成讀音在場時，Cmd+Ctrl+W 仍須交還客體。")
    #expect(recordedErrors.isEmpty, "交還時不得發蜂鳴碼，實際得到 \(recordedErrors)")
    #expect(testClientProxy.toString().isEmpty, "未完成之讀音不得以原文遞交。")
    #expect(testSession.state.type == .ofEmpty, "遞交後應收斂至空狀態。")
    #expect(testHandler.isComposerOrCalligrapherEmpty, "遞交後注拼槽應已清空。")
  }
}
