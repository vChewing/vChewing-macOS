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

// 啟用／停用：快速路徑、CapsLock 重置、打字模式提示。

// MARK: - SS.Lifecycle

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  /// 測試 CapsLock 中英切換場景下 performServerActivation 的快速路徑。
  ///
  /// 當副本已處於活動狀態、為當前副本、且 inputHandler 存在時，
  /// 重複呼叫 performServerActivation 不應重新建構 inputHandler。
  @Test("SS-Lifecycle-001 Activation fast path skips input-handler init")
  func test_SS_Lifecycle_001_ActivationFastPathSkipsInitInputHandler() throws {
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
  @Test("SS-Lifecycle-002 Deactivation is no-op for current session")
  func test_SS_Lifecycle_002_DeactivationIsNoOpForCurrentSession() throws {
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
  @Test("SS-Lifecycle-003 Rapid reactivation maintains handler identity")
  func test_SS_Lifecycle_003_RapidReactivationMaintainsHandlerIdentity() throws {
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
  @Test("SS-Lifecycle-004 Caps Lock reset commits pending mixed ASCII buffer")
  func test_SS_Lifecycle_004_CapsLockResetCommitsPendingMixedASCIIBuffer() throws {
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

  /// 啟用時 performServerActivation（快速路徑）應以 statusUI 顯示提示並記錄於 state（不經
  /// switchState）。提示經 performServerActivation 的 defer 以 0.05s 延遲脫手顯示；單元
  /// 測試環境 bypass 為同步，故可直接斷言。
  @Test("SS-Lifecycle-005 Mode description hint shown upon activation when enabled")
  func test_SS_Lifecycle_005_ModeDescriptionHintShownUponActivationWhenEnabled() throws {
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
  @Test("SS-Lifecycle-006 Mode description hint suppressed upon activation when disabled")
  func test_SS_Lifecycle_006_ModeDescriptionHintSuppressedUponActivationWhenDisabled() throws {
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
  @Test("SS-Lifecycle-007 Mode description hint shown upon activation in ASCII mode")
  func test_SS_Lifecycle_007_ModeDescriptionHintShownUponActivationInASCIIMode() throws {
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
  @Test("SS-Lifecycle-008 Mode description hint shown upon activation with Caps Lock lit")
  func test_SS_Lifecycle_008_ModeDescriptionHintShownUponActivationWithCapsLockLit() throws {
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
  @Test("SS-Lifecycle-009 Mode description hint shows once despite a post-activation setValue")
  func test_SS_Lifecycle_009_ModeDescriptionHintShownOnceDespitePostActivationSetValue() throws {
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
  @Test("SS-Lifecycle-010 Mode description hint clears popup composition buffer")
  func test_SS_Lifecycle_010_ModeDescriptionHintClearsPopupCompositionBuffer() throws {
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
  @Test("SS-Lifecycle-011 Mode description hint dismissed when composition buffer appears")
  func test_SS_Lifecycle_011_ModeDescriptionHintDismissedWhenCompositionBufferAppears() throws {
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

  /// 對接輸入客體時之啟用流程（`performServerActivation()`；快速路徑）不得令客體之
  /// 內文組字區殘留未提交之標記文字：客體（Spotlight 之類）會於組字途中自發性地重新
  /// 啟用輸入法，此時 Session 既已把組字狀態直接歸零（`state = .ofEmpty()`，不經
  /// `switchState`），客體所見亦須同步歸零。否則其後之 BkSp／Esc 皆因狀態非
  /// `.ofInputting` 而放行給客體（`OmitNSEvent`）、亦不示警，該殘留文字遂無以鍵盤清除。
  @Test("SS-Lifecycle-012 Activation clears the client's stale inline marked text")
  func test_SS_Lifecycle_012_ActivationClearsStaleInlineMarkedText() throws {
    let originalHardened = PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer
    let originalHint = PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer
    defer {
      PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer = originalHardened
      PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = originalHint
    }
    // `clientMitigationLevel < 2`：標記文字方走客體（≥2 走 PCB 之處置態，測不得）。
    PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer = false
    PrefMgr.sharedSansDidSetOps.showModeDescriptionOnActivatingServer = false
    InputSession.current = testSession
    testSession.resetInputHandler(forceComposerCleanup: true)
    testSession.performServerActivation()
    testClientProxy.clear()

    typeSentenceOrCandidates("s")
    #expect(testSession.state.type == .ofInputting)
    #expect(
      testClientProxy.markedTexts.last?.isEmpty == false,
      "組字中應於客體落下標記文字。"
    )

    // 同一客體、同一 Session 之再次啟用（快速路徑）：狀態歸零，客體亦須歸零。
    testSession.performServerActivation()
    #expect(testSession.state.type == .ofEmpty)
    #expect(
      testClientProxy.markedTexts.last?.isEmpty == true,
      "啟用後客體內文組字區不得殘留未提交之標記文字。"
    )
    #expect(
      testHandler.composer.isEmpty && testHandler.assembler.isEmpty,
      "啟用後組字素材（組音器與組字器）亦須一併丟棄，否則下一次組字時復辟。"
    )
  }

  @Test("SS-Lifecycle-013 Stale close-all-panels request retains the visible popup composition buffer")
  func test_SS_Lifecycle_013_StaleCloseAllPanelsRequestRetainsVisiblePopupCompositionBuffer() throws {
    let originalHardened = PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer
    defer {
      PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer = originalHardened
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    // 強化型組字區安全防護迫使客體改用浮動組字窗（clientMitigationLevel >= 2）。
    PrefMgr.sharedSansDidSetOps.securityHardenedCompositionBuffer = true
    InputSession.current = testSession
    testSession.resetInputHandler(forceComposerCleanup: true)
    testSession.performServerActivation()
    testClientProxy.clear()

    typeSentenceOrCandidates("s")
    #expect(testSession.state.hasComposition, "組字中應有組字內容。")
    #expect(testPCB.isShown, "浮動組字窗應顯示組字內容。")
    #expect(testPCB.isRetainedOnCloseRequest, "組字中時，浮動組字窗應對收合請求免疫。")

    // 模擬遲到的「收合所有面板」請求（與 `PopupCompositionBuffer` 之觀察者同式）。
    if !testPCB.isRetainedOnCloseRequest { testPCB.hide() }
    #expect(testPCB.isShown, "遲到之收合請求不得收掉仍欲顯示之浮動組字窗。")

    // 組字狀態歸零後，免疫隨之解除，收合請求方得生效。
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(!testPCB.isRetainedOnCloseRequest, "無組字內容時，浮動組字窗不應對收合請求免疫。")
    if !testPCB.isRetainedOnCloseRequest { testPCB.hide() }
    #expect(!testPCB.isShown, "無組字內容時，收合請求應收掉浮動組字窗。")

    // 啟用路徑係逕行歸零狀態（不經 `switchState`，故不會刷新客體顯示與此免疫值）。
    // 素材既於啟用時丟棄，免疫亦須同步解除；否則遲到的收合請求會因殘留之免疫值
    // 而收不掉一個已無組字內容之浮動組字窗。
    typeSentenceOrCandidates("s")
    #expect(testPCB.isRetainedOnCloseRequest, "組字中時，浮動組字窗應對收合請求免疫。")
    testSession.performServerActivation()
    #expect(!testPCB.isRetainedOnCloseRequest, "啟用後組字素材已丟棄，免疫應一併解除。")
    if !testPCB.isRetainedOnCloseRequest { testPCB.hide() }
    #expect(!testPCB.isShown, "啟用後之收合請求應收掉浮動組字窗。")
  }

  /// 待配首鍵退位（首鍵已顯示、本鍵未經成碼消化而逕落分診）時，不得向客體投機落一筆
  /// **空**標記文字：macOS 26+ 之客體於同一次事件內先見「標記成空（⇒ 組字結束）」、
  /// 再見新標記文字（⇒ 組字開始）時，會白跑一輪 deactivate／reactivate；舊建置之
  /// Spotlight 更會因此顯示殘影（P307 移交稿、`tmp/p307/P302_Handoff_DualpinTransientAbortion.md`）。
  ///
  /// 本測試釘住客體所見之落筆序列：數字鍵落定者只許「首鍵佔位 → 字面節」兩筆、
  /// 中途不得有空筆；非碼鍵者仍以空筆收尾（組字確實結束），惟該筆係本事件末之結算、
  /// 非退位當時之投機。
  @Test("SS-Lifecycle-014 Pending first key retirement shall not clear the client marked text speculatively")
  func test_SS_Lifecycle_014_PendingFirstKeyRetirementShallNotClearClientMarkedTextSpeculatively() throws {
    let originalFurious = PrefMgr.sharedSansDidSetOps.furiousTypingEnabled4Pinyin
    let originalParser = PrefMgr.sharedSansDidSetOps.keyboardParser
    let originalDualpinParser = PrefMgr.sharedSansDidSetOps.keyboardParser4Dualpin
    let originalDualpinEnabled = PrefMgr.sharedSansDidSetOps.dualpinEnabledForPinyinTyping
    let originalDualpinSchema = PrefMgr.sharedSansDidSetOps.dualpinSchemaJSON
    defer {
      PrefMgr.sharedSansDidSetOps.furiousTypingEnabled4Pinyin = originalFurious
      PrefMgr.sharedSansDidSetOps.keyboardParser = originalParser
      PrefMgr.sharedSansDidSetOps.keyboardParser4Dualpin = originalDualpinParser
      PrefMgr.sharedSansDidSetOps.dualpinEnabledForPinyinTyping = originalDualpinEnabled
      PrefMgr.sharedSansDidSetOps.dualpinSchemaJSON = originalDualpinSchema
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    PrefMgr.sharedSansDidSetOps.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    PrefMgr.sharedSansDidSetOps.keyboardParser4Dualpin = KeyboardParser.ofDualpinMSPY.rawValue
    PrefMgr.sharedSansDidSetOps.dualpinEnabledForPinyinTyping = true
    PrefMgr.sharedSansDidSetOps.dualpinSchemaJSON = ""
    testHandler.ensureKeyboardParser()
    InputSession.current = testSession

    for furious in [false, true] {
      testSession.resetInputHandler(forceComposerCleanup: true)
      PrefMgr.sharedSansDidSetOps.furiousTypingEnabled4Pinyin = furious
      testSession.performServerActivation()
      testClientProxy.clear()

      // 甲案：數字鍵落定。首鍵逕捨、數字落為字面節——中途不得有空筆。
      typeSentenceOrCandidates("s")
      #expect(
        testClientProxy.markedTexts.count == 1 && testClientProxy.markedTexts.last?.isEmpty == false,
        "待配首鍵應於客體落下佔位之標記文字（furious＝\(furious)）：\(testClientProxy.markedTexts)"
      )
      typeSentenceOrCandidates("9")
      #expect(
        testClientProxy.markedTexts.allSatisfy { !$0.isEmpty },
        "首鍵退位不得投機落空筆（furious＝\(furious)）：\(testClientProxy.markedTexts)"
      )
      #expect(
        testClientProxy.markedTexts.count == 2,
        "客體所見應恰為「首鍵佔位 → 字面節」兩筆（furious＝\(furious)）：\(testClientProxy.markedTexts)"
      )

      // 乙案：非碼鍵（逗號）。**非狂打**：首鍵逕捨、逗號放行給客體；空筆只許一次、且為收尾之筆。
      // **狂打**（★ P309）：雙拼之標點比照拼音狂打——先結算前方讀音、再以本鍵落組字節，
      // 故本鍵由輸入法消費、組字續存（顯示即「讀音桶，」），亦不得有空筆。
      testSession.resetInputHandler(forceComposerCleanup: true)
      testClientProxy.clear()
      typeSentenceOrCandidates("s")
      if furious {
        handleKeyEvent(KBEvent.KeyEventData(chars: ","), shouldHandle: true)
        #expect(
          testClientProxy.markedTexts.allSatisfy { !$0.isEmpty },
          "狂打之標點不得投機落空筆（furious＝\(furious)）：\(testClientProxy.markedTexts)"
        )
        #expect(
          testSession.state.displayedText.contains("，"),
          "狂打之標點應以組字節落下（furious＝\(furious)）：\(testSession.state.displayedText)"
        )
        #expect(
          !testSession.state.displayedText.contains("s"),
          "讀音既已結算，顯示不得殘留半碼之原文（furious＝\(furious)）：\(testSession.state.displayedText)"
        )
      } else {
        handleKeyEvent(KBEvent.KeyEventData(chars: ","), shouldHandle: false)
        #expect(
          testClientProxy.markedTexts.filter(\.isEmpty).count == 1,
          "非碼鍵之收尾空筆應恰一次（furious＝\(furious)）：\(testClientProxy.markedTexts)"
        )
        #expect(
          testClientProxy.markedTexts.last?.isEmpty == true,
          "收尾空筆應為最後一筆（furious＝\(furious)）：\(testClientProxy.markedTexts)"
        )
        #expect(
          testSession.state.displayedText.isEmpty,
          "退位後不得殘留待配首鍵之顯示（furious＝\(furious)）"
        )
      }
    }
  }

  // MARK: - Test harness

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
}
