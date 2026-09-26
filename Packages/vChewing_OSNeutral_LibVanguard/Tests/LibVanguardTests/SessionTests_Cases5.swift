// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LexiconAssembly
import Shared
import SwiftExtension
import Tekkon
import Testing

@testable import LibVanguard

// MARK: - Session 層個案（編號沿用 MainAssembly 測試案）

/// 本檔將原本以 `NSEvent` 驅動真 `InputSession` 的個案，移植到跨平台的
/// `SessionTests` harness（真 `InputSession` + 真 `InputHandler` + `MockClientProxy`）。
/// 個案編號沿用原檔，方便與 `MainAssembly4Darwin` 的既有案例互相對照。
extension LibVanguardTestsRoot.InputHandlerTests.Session {
  /// 建立帶有可攔截 statusUI 的 SessionUI 替身，對應 Darwin 端的
  /// `MockSessionUI4ModeDescriptionHint`：可控 Caps Lock 燈態與（可選的）PCB。
  func makeModeDescriptionHintUI(
    capsLockIsOn: Bool,
    pcb: MockPCB? = nil
  )
    -> (ui: MockSessionUI, status: MockTooltipUI) {
    let ui = MockSessionUI()
    let status = MockTooltipUI()
    ui.statusUI = status
    ui.capsLockToggler = MockCapsLockToggler(isOn: capsLockIsOn)
    ui.pcb = pcb
    return (ui, status)
  }

  /// 測試 CapsLock 中英切換場景下 performServerActivation 的快速路徑。
  ///
  /// 當副本已處於活動狀態、為當前副本、且 inputHandler 存在時，
  /// 重複呼叫 performServerActivation 不應重新建構 inputHandler。
  @Test
  func test501_ActivationFastPath_SkipsInitInputHandler() throws {
    // 確保 testSession 已初期化且處於活動狀態。
    #expect(testSession.isActivated)
    #expect(testSession.inputHandler != nil)

    // 將 testSession 設為 current（模擬正常啟用狀態）。
    InputSession.current = testSession

    // 記錄當前 inputHandler 的身份（使用 ObjectIdentifier）。
    let handlerBefore = testSession.inputHandler
    let identityBefore = ObjectIdentifier(handlerBefore!)

    // 模擬 CapsLock 切換回來：呼叫 performServerActivation。
    // 由於 isActivated == true、Self.current?.id == id、inputHandler != nil，
    // 應命中快速路徑，不會呼叫 initInputHandler()。
    testSession.performServerActivation()

    // 驗證 inputHandler 未被重新建構。
    let handlerAfter = testSession.inputHandler
    let identityAfter = ObjectIdentifier(handlerAfter!)
    #expect(
      identityBefore == identityAfter,
      "快速路徑不應重新建構 inputHandler，但 inputHandler 身份已變更。"
    )

    // 驗證副本仍處於活動狀態。
    #expect(testSession.isActivated)
    #expect(testSession.state.type == .ofEmpty)
  }

  /// 測試 performServerDeactivation 對當前副本為 no-op。
  ///
  /// 當 Self.current?.id == self.id 時，performServerDeactivation 應提前返回，
  /// 不改變 isActivated 狀態，也不重設 inputHandler。
  @Test
  func test502_DeactivationIsNoOpForCurrentSession() throws {
    #expect(testSession.isActivated)
    #expect(testSession.inputHandler != nil)

    InputSession.current = testSession

    let handlerBefore = testSession.inputHandler

    // 呼叫 deactivation；因 Self.current?.id == id，應為 no-op。
    testSession.performServerDeactivation()

    // 驗證 isActivated 未被改變（仍為 true）。
    #expect(
      testSession.isActivated,
      "performServerDeactivation 對當前副本應為 no-op，isActivated 不應被改變。"
    )

    // 驗證 inputHandler 仍然存在。
    #expect(testSession.inputHandler != nil)
    let handlerAfter = testSession.inputHandler
    #expect(
      ObjectIdentifier(handlerBefore!) == ObjectIdentifier(handlerAfter!),
      "performServerDeactivation 對當前副本不應影響 inputHandler。"
    )
  }

  /// 測試快速路徑下的反覆啟用不會累積額外開銷。
  ///
  /// 模擬使用者快速按壓 CapsLock 多次切換中英的場景：
  /// 連續呼叫 performServerActivation 多次，驗證每次都命中快速路徑。
  @Test
  func test503_RapidReactivation_MaintainsHandlerIdentity() throws {
    #expect(testSession.isActivated)
    InputSession.current = testSession

    let identityBefore = ObjectIdentifier(testSession.inputHandler!)

    // 模擬 20 次快速切換（每次 deactivate + activate）。
    for _ in 0 ..< 20 {
      testSession.performServerDeactivation() // no-op（current session）
      testSession.performServerActivation() // 快速路徑
    }

    let identityAfter = ObjectIdentifier(testSession.inputHandler!)
    #expect(
      identityBefore == identityAfter,
      "經過 20 次快速切換後，inputHandler 不應被重新建構。"
    )
    #expect(testSession.isActivated)
    #expect(testSession.state.type == .ofEmpty)
  }

  /// 回歸：CapsLock 切換中英文時會走 resetInputHandler。
  /// reset 時提交內容必須包含尚未遞交的 mixed ASCII buffer。
  @Test
  func test504_CapsLockResetCommitsPendingMixedASCIIBuffer() throws {
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClientProxy.clear()
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentenceOrCandidates("abc")

    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "abc")
    #expect(testClientProxy.toString().isEmpty)

    // 模擬 CapsLock 切換路徑中的 resetInputHandler() 行為。
    testSession.resetInputHandler()

    #expect(testClientProxy.toString() == "abc")
    #expect(testSession.state.type == .ofEmpty)
  }

  /// 狂拼 copilot 候選窗的 tooltip：就地選字需 Shift＋選字鍵，
  /// 候選窗以專屬 Shift 提示取代「⚡️ 快速候選」。
  @Test
  func test505_FuriousCopilotWindowTooltipShowsShiftHint() throws {
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
  @Test
  func test507_FuriousCopilotWindowIgnoresJKHLReinterpretation() throws {
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

  /// 啟用時 performServerActivation（快速路徑）應以 statusUI 顯示提示並記錄於 state（不經
  /// switchState）。提示經 performServerActivation 的 defer 以 0.05s 延遲脫手顯示；單元
  /// 測試環境 bypass 為同步，故可直接斷言。
  @Test
  func test508_ModeDescriptionHintShownUponActivationWhenEnabled() throws {
    let originalPref = PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer
    let originalUI = testSession.ui
    defer {
      PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = originalPref
      testSession.ui = originalUI
    }
    PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = true
    let hintUI = makeModeDescriptionHintUI(capsLockIsOn: false)
    testSession.ui = hintUI.ui
    InputSession.current = testSession
    testSession.performServerActivation()
    #expect(testSession.state.type == .ofEmpty)
    #expect(!testSession.state.tooltip.isEmpty)
    #expect(hintUI.status.shownTooltip?.hasPrefix("► ") == true)
    #expect(hintUI.status.shownTooltip?.contains("i18n:TypingMode.i18nKey4InlineModeHint.") == true)
    #expect(hintUI.status.shownDuration == 0.7)
    #expect(hintUI.status.showCount == 1)
    #expect(hintUI.status.syncCount == 1)
  }

  /// 關閉（預設為啟用，此處顯式關閉）時 performServerActivation 不得產生打字模式提示。
  @Test
  func test509_ModeDescriptionHintSuppressedUponActivationWhenDisabled() throws {
    let originalPref = PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer
    let originalUI = testSession.ui
    defer {
      PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = originalPref
      testSession.ui = originalUI
    }
    PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = false
    let hintUI = makeModeDescriptionHintUI(capsLockIsOn: false)
    testSession.ui = hintUI.ui
    InputSession.current = testSession
    testSession.performServerActivation()
    #expect(testSession.state.type == .ofEmpty)
    #expect(hintUI.status.shownTooltip == nil)
  }

  /// 啟用且英數模式時提示須用 ASCII 專屬 key（測試環境無 l10n、`.i18n` 回退鍵名）。
  @Test
  func test510_ModeDescriptionHintShownUponActivationInASCIIMode() throws {
    let originalPref = PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer
    let originalASCIIMode = testSession.isASCIIMode
    let originalUI = testSession.ui
    defer {
      PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = originalPref
      testSession.isASCIIMode = originalASCIIMode
      testSession.ui = originalUI
    }
    PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = true
    testSession.isASCIIMode = true
    let hintUI = makeModeDescriptionHintUI(capsLockIsOn: false)
    testSession.ui = hintUI.ui
    InputSession.current = testSession
    testSession.performServerActivation()
    #expect(testSession.state.type == .ofEmpty)
    #expect(hintUI.status.shownTooltip == "► i18n:TypingMode.i18nKey4InlineModeHint.ascii")
    #expect(hintUI.status.shownDuration == 0.7)
  }

  /// 啟用、非英數、Caps Lock 亮燈時提示須用 asciiCpLk 專屬 key（此際字母鍵可直接敲小寫英數）。
  @Test
  func test511_ModeDescriptionHintShownUponActivationWithCapsLockLit() throws {
    let originalPref = PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer
    let originalBypass = PrefMgr.sharedSansDidSetOps.bypassNonAppleCapsLockHandling
    let originalASCIIMode = testSession.isASCIIMode
    let originalUI = testSession.ui
    defer {
      PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = originalPref
      PrefMgr.sharedSansDidSetOps.bypassNonAppleCapsLockHandling = originalBypass
      testSession.isASCIIMode = originalASCIIMode
      testSession.ui = originalUI
    }
    PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = true
    PrefMgr.sharedSansDidSetOps.bypassNonAppleCapsLockHandling = false
    testSession.isASCIIMode = false
    let hintUI = makeModeDescriptionHintUI(capsLockIsOn: true)
    testSession.ui = hintUI.ui
    InputSession.current = testSession
    testSession.performServerActivation()
    #expect(testSession.state.type == .ofEmpty)
    #expect(hintUI.status.shownTooltip == "► i18n:TypingMode.i18nKey4InlineModeHint.asciiCpLk")
    #expect(hintUI.status.shownDuration == 0.7)
  }

  /// 提示以 0.05s 延遲脫手顯示、排在 IMK 隨後的 setValue（內含 hidePalettes）之後——
  /// 立即呼叫 setValue 模擬該連續技，提示仍應恰好顯示一次、不被蓋掉（flicker 回歸）。
  @Test
  func test512_ModeDescriptionHintShownOnceDespitePostActivationSetValue() throws {
    let originalPref = PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer
    let originalUI = testSession.ui
    defer {
      PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = originalPref
      testSession.ui = originalUI
    }
    PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = true
    let hintUI = makeModeDescriptionHintUI(capsLockIsOn: false)
    testSession.ui = hintUI.ui
    InputSession.current = testSession
    testSession.performServerActivation()
    testSession.setValue(nil, forTag: 0)
    #expect(testSession.state.type == .ofEmpty)
    #expect(!testSession.state.tooltip.isEmpty)
    #expect(hintUI.status.showCount == 1)
    #expect(hintUI.status.shownTooltip?.hasPrefix("► ") == true)
    #expect(hintUI.status.shownTooltip?.contains("i18n:TypingMode.i18nKey4InlineModeHint.") == true)
  }

  /// 浮動組字窗（PCB）顯示中且其頂端高於打字列頂端時，提示給定點應上抬至 PCB 頂端之上、
  /// 避免與 PCB 重疊；PCB 頂端不高於打字列頂端時點位維持不變（max 比較自然不變）。
  @Test
  func test513_ModeDescriptionHintClearsPopupCompositionBuffer() throws {
    let originalPref = PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer
    let originalUI = testSession.ui
    defer {
      PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = originalPref
      testSession.ui = originalUI
    }
    PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = true
    let pcbMock = MockPCB()
    pcbMock.isShown = true
    pcbMock.frame = CGRect(origin: CGPoint(x: 12, y: 100), size: CGSize(width: 96, height: 24)) // maxY = 124
    let hintUI = makeModeDescriptionHintUI(capsLockIsOn: false, pcb: pcbMock)
    testSession.ui = hintUI.ui
    InputSession.current = testSession
    testSession.performServerActivation()
    #expect(hintUI.status.shownTooltip?.contains("i18n:TypingMode.i18nKey4InlineModeHint.") == true)
    #expect(hintUI.status.shownPoint?.y == 124)
    // PCB 頂端不高於打字列頂端 → 點位維持打字列頂端不變。
    pcbMock.frame = CGRect(origin: CGPoint(x: 12, y: 0), size: CGSize(width: 96, height: 0.2)) // maxY = 0.2
    testSession.performServerActivation()
    let topOfLineHeightRect = testSession.updateVerticalTypingStatus()
    #expect(hintUI.status.shownPoint?.y == topOfLineHeightRect.origin.y + topOfLineHeightRect.size.height)
  }

  /// 組字開始（浮動組字窗 PCB 顯示）時，仍在顯示中的打字模式提示應被收起——PCB 於
  /// activation 之後才出現、顯示當下的抬升避讓鞭長莫及，直接收起避免提示窗擋住 PCB。
  @Test
  func test514_ModeDescriptionHintDismissedWhenCompositionBufferAppears() throws {
    let originalPref = PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer
    let originalHardened = PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer
    let originalMixedASCII = testHandler.prefs.mixedAlphanumericalEnabled
    let originalUI = testSession.ui
    defer {
      PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = originalPref
      PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer = originalHardened
      testHandler.prefs.mixedAlphanumericalEnabled = originalMixedASCII
      testSession.ui = originalUI
    }
    PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = true
    PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer = true // clientMitigationLevel → 2（PCB 路徑）
    let pcbMock = MockPCB()
    let hintUI = makeModeDescriptionHintUI(capsLockIsOn: false, pcb: pcbMock)
    testSession.ui = hintUI.ui
    InputSession.current = testSession
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClientProxy.clear()
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testSession.performServerActivation()
    #expect(hintUI.status.showCount == 1)
    #expect(hintUI.status.isShown == true)
    typeSentenceOrCandidates("abc")
    #expect(testSession.state.type == .ofInputting)
    #expect(pcbMock.showCount >= 1, "PCB 應於組字時顯示")
    #expect(hintUI.status.isShown == false, "PCB 顯示時模式提示應被收起")
  }

  /// 就地加詞（升權／降權／過濾）必須立刻在**當前的 Homa 組字器實例**內生效。
  ///
  /// 生效機制是使用者片語辭庫的「臨時資料插入」：`performUserPhraseOperation` 於寫檔之後
  /// 先 `insertTemporaryData`、再 `updateUnigramData()` 就地熱重載組字器。
  /// 次序若顛倒（或熱重載拿到過時快取），本測試即紅：組字器會停在舊的元圖快照上，
  /// 直到遞交組字區才改觀。
  @Test
  func test515_InPlaceUserPhraseOperationsApplyToCurrentAssemblerImmediately() throws {
    testHandler.prefs.useSCPCTypingMode = false
    let originalFilterabilityChecker = testHandler.filterabilityChecker
    testHandler.filterabilityChecker = { _ in true }
    // 復刻宿主（`UserPhraseImpl`）在 marking 按鍵下指派權重的契約：
    // 升權不填權重（視為 0）、降權賦以極端低權重、過濾不填權重。
    SessionHost.shared.updateUserPhraseWeight = { phrase, action in
      var phrase = phrase
      switch action {
      case .toBoost: phrase.weight = nil
      case .toNerf: phrase.weight = -114.514
      case .toFilter: phrase.weight = nil
      }
      return phrase
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.currentLM.clearTemporaryData(isFiltering: true)
      testHandler.filterabilityChecker = originalFilterabilityChecker
      SessionHost.shared.updateUserPhraseWeight = { phrase, _ in phrase }
    }

    /// 以較低權重預置「年中」後敲出該讀音，作為就地加詞的觀測對象。
    func prepareCompositionWithYearMid() -> String {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.currentLM.clearTemporaryData(isFiltering: true)
      testHandler.currentLM.insertTemporaryData(
        unigram: .init(keyArray: ["ㄋㄧㄢˊ", "ㄓㄨㄥ"], current: "年中", probability: -4.329),
        isFiltering: false
      )
      return prepareBasicComposition(sequence: "su065j/ ")
    }

    /// 讀取當前組字器內「年中」一詞的元圖權重（無此記錄時回 nil）。
    func yearMidScore() -> Double? {
      let keyArray = ["ㄋㄧㄢˊ", "ㄓㄨㄥ"]
      for segment in testHandler.assembler.segments {
        for (_, node) in segment {
          for gram in node.grams where gram.keyArray == keyArray && gram.current == "年中" {
            return gram.probability
          }
        }
      }
      return nil
    }

    func enterMarkingState() {
      press(.shiftLeftEvent)
      press(.shiftLeftEvent)
      #expect(testSession.state.type == .ofMarking)
      #expect(testSession.state.markedRange == 0 ..< 2)
    }

    // ① 升權（Enter）：權重立刻升為臨時資料所給的 0。
    #expect(prepareCompositionWithYearMid() == "年中")
    #expect(yearMidScore() == -4.329)
    enterMarkingState()
    press(.dataEnterReturn)
    #expect(testSession.state.type == .ofInputting)
    #expect(yearMidScore() == 0, "升權後，當前組字器節點內「年中」的權重應立刻變成臨時資料的 0。")
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "年中")

    // ② 降權（Shift+Command+Enter）：權重立刻降為 -114.514，組句立刻改用另一競品。
    #expect(prepareCompositionWithYearMid() == "年中")
    #expect(yearMidScore() == -4.329)
    enterMarkingState()
    var nerfEnter = KBEvent.KeyEventData.dataEnterReturn
    nerfEnter.flags = [.shift, .command]
    press(nerfEnter)
    #expect(testSession.state.type == .ofInputting)
    #expect(yearMidScore() == -114.514, "降權後，當前組字器節點內「年中」的權重應立刻變成 -114.514。")
    #expect(
      testHandler.assembler.assembledSentence.map(\.value).joined() == "年終",
      "降權後，當前組字結果應立刻改用另一競品，無需遞交組字區。"
    )

    // ③ 過濾（Backspace）：該詞立刻自當前組字器節點內除名，組句立刻改用另一競品。
    #expect(prepareCompositionWithYearMid() == "年中")
    enterMarkingState()
    press(.backspaceEvent)
    #expect(testSession.state.type == .ofInputting)
    #expect(yearMidScore() == nil, "過濾後，當前組字器節點內不應再留有「年中」。")
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "年終")
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
  @Test
  func test516_FunctionKeyDoesNotDisturbUncommittedReading() throws {
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
  @Test
  func test517_FunctionKeyDoesNotDisturbUnfinishedReading() throws {
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
  @Test
  func test518_FunctionKeyPassesThroughWhenNothingPending() throws {
    resetToEmptyAndClear()

    let handled = testSession.handleEvent(KBEvent.KeyEventData.f5Event.asEvent)
    #expect(!handled, "組字內容為空時，F5 應放行給系統。")
    #expect(testClientProxy.toString().isEmpty, "F5 不得在空狀態下遞交任何內容。")
    #expect(testSession.state.type == .ofEmpty)
    #expect(recordedErrors.isEmpty, "放行功能鍵時不得發蜂鳴碼，實際得到 \(recordedErrors)")
  }

  /// 攔截範圍僅限功能鍵本身：`Fn` 與其它鍵之組合（如表情符號選擇器 `Fn+E`）維持放行，
  /// 以免 July-2026 那套「略過 Fn 熱鍵」的政策被本修正一併撤除。
  @Test
  func test519_FnNonFunctionKeyCombinationStillPassesThrough() throws {
    testHandler.prefs.useSCPCTypingMode = false
    resetToEmptyAndClear()

    typeSentenceOrCandidates("su3")
    #expect(testSession.state.hasComposition)

    let handled = testSession.handleEvent(KBEvent.KeyEventData.fnEWithLetterEvent.asEvent)
    #expect(!handled, "Fn+字母鍵不屬功能鍵，應維持放行。")
    #expect(testClientProxy.toString().isEmpty, "放行 Fn+字母鍵時，輸入法本身不得遞交內容。")
  }
}
