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
    let originalPref = testHandler.prefs.showModeDescriptionOnActivatingServer
    let originalUI = testSession.ui
    defer {
      testHandler.prefs.showModeDescriptionOnActivatingServer = originalPref
      testSession.ui = originalUI
    }
    testHandler.prefs.showModeDescriptionOnActivatingServer = true
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
    let originalPref = testHandler.prefs.showModeDescriptionOnActivatingServer
    let originalUI = testSession.ui
    defer {
      testHandler.prefs.showModeDescriptionOnActivatingServer = originalPref
      testSession.ui = originalUI
    }
    testHandler.prefs.showModeDescriptionOnActivatingServer = false
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
    let originalPref = testHandler.prefs.showModeDescriptionOnActivatingServer
    let originalASCIIMode = testSession.isASCIIMode
    let originalUI = testSession.ui
    defer {
      testHandler.prefs.showModeDescriptionOnActivatingServer = originalPref
      testSession.isASCIIMode = originalASCIIMode
      testSession.ui = originalUI
    }
    testHandler.prefs.showModeDescriptionOnActivatingServer = true
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
    let originalPref = testHandler.prefs.showModeDescriptionOnActivatingServer
    let originalBypass = testHandler.prefs.bypassNonAppleCapsLockHandling
    let originalASCIIMode = testSession.isASCIIMode
    let originalUI = testSession.ui
    defer {
      testHandler.prefs.showModeDescriptionOnActivatingServer = originalPref
      testHandler.prefs.bypassNonAppleCapsLockHandling = originalBypass
      testSession.isASCIIMode = originalASCIIMode
      testSession.ui = originalUI
    }
    testHandler.prefs.showModeDescriptionOnActivatingServer = true
    testHandler.prefs.bypassNonAppleCapsLockHandling = false
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
    let originalPref = testHandler.prefs.showModeDescriptionOnActivatingServer
    let originalUI = testSession.ui
    defer {
      testHandler.prefs.showModeDescriptionOnActivatingServer = originalPref
      testSession.ui = originalUI
    }
    testHandler.prefs.showModeDescriptionOnActivatingServer = true
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
    let originalPref = testHandler.prefs.showModeDescriptionOnActivatingServer
    let originalUI = testSession.ui
    defer {
      testHandler.prefs.showModeDescriptionOnActivatingServer = originalPref
      testSession.ui = originalUI
    }
    testHandler.prefs.showModeDescriptionOnActivatingServer = true
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
    let originalPref = testHandler.prefs.showModeDescriptionOnActivatingServer
    let originalHardened = testHandler.prefs.securityHardenedCompositionBuffer
    let originalMixedASCII = testHandler.prefs.mixedAlphanumericalEnabled
    let originalUI = testSession.ui
    defer {
      testHandler.prefs.showModeDescriptionOnActivatingServer = originalPref
      testHandler.prefs.securityHardenedCompositionBuffer = originalHardened
      testHandler.prefs.mixedAlphanumericalEnabled = originalMixedASCII
      testSession.ui = originalUI
    }
    testHandler.prefs.showModeDescriptionOnActivatingServer = true
    testHandler.prefs.securityHardenedCompositionBuffer = true // clientMitigationLevel → 2（PCB 路徑）
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
    let originalHardened = testHandler.prefs.securityHardenedCompositionBuffer
    let originalHint = testHandler.prefs.showModeDescriptionOnActivatingServer
    defer {
      testHandler.prefs.securityHardenedCompositionBuffer = originalHardened
      testHandler.prefs.showModeDescriptionOnActivatingServer = originalHint
    }
    // `clientMitigationLevel < 2`：標記文字方走客體（≥2 走 PCB 之處置態，測不得）。
    testHandler.prefs.securityHardenedCompositionBuffer = false
    testHandler.prefs.showModeDescriptionOnActivatingServer = false
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
    let originalHardened = testHandler.prefs.securityHardenedCompositionBuffer
    defer {
      testHandler.prefs.securityHardenedCompositionBuffer = originalHardened
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    // 強化型組字區安全防護迫使客體改用浮動組字窗（clientMitigationLevel >= 2）。
    testHandler.prefs.securityHardenedCompositionBuffer = true
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

  // MARK: - SS-Lifecycle-014 / 015（P311：暫定狀態）

  /// 暫定狀態（`isProvisional`）之契約：`switchState` 略去其客體顯示寫入，留待本輪派送
  /// 結束時之結算補寫。如此，同一輪內旋即到來之新組字顯示只會落一次筆，客體遂免於
  /// 「先見組字結束、再見組字開始」之閃爍。
  @Test("SS-Lifecycle-014 Provisional state withholds the client display write until settled")
  func test_SS_Lifecycle_014() throws {
    InputSession.current = testSession
    testSession.resetInputHandler(forceComposerCleanup: true)
    testSession.performServerActivation()
    testClientProxy.clear()

    // ① 對照組：非暫定之作廢，客體當即收到空筆。
    testSession.switchState(.ofInputting(displayTextSegments: ["s"], cursor: 1))
    #expect(testClientProxy.markedTexts.last == "s")
    testSession.switchState(.ofAbortion())
    #expect(testSession.state.type == .ofEmpty)
    #expect(!testSession.state.data.isProvisional)
    #expect(!testClientProxy.markedTexts.isEmpty)
    #expect(testClientProxy.markedTexts.last?.isEmpty == true)

    // ② 暫定之作廢：客體一無所獲（顯示仍為上一筆）；狀態既已正規化為空態，又帶著暫定之記。
    testSession.switchState(.ofInputting(displayTextSegments: ["s"], cursor: 1))
    let countBefore = testClientProxy.markedTexts.count
    testSession.switchState(.ofAbortion(isProvisional: true))
    #expect(testSession.state.type == .ofEmpty)
    #expect(testSession.state.data.isProvisional)
    #expect(testClientProxy.markedTexts.count == countBefore, "暫定狀態不得寫入客體之組字區顯示。")
    #expect(testClientProxy.markedTexts.last == "s")

    // ③ 同一輪內旋即落筆：客體只見到新內容，其間並無空筆。
    testSession.switchState(.ofInputting(displayTextSegments: ["9"], cursor: 1))
    #expect(testClientProxy.markedTexts.suffix(2) == ["s", "9"])

    // ④ 派送結束之結算：狀態已非暫定者，故結算為空操作、不覆寫客體已見之內容。
    testSession.settleProvisionalStateIfNeeded()
    #expect(testClientProxy.markedTexts.last == "9")

    // ⑤ 暫定而無後續落筆者：結算補寫空筆，客體方知組字已結束。
    testSession.switchState(.ofAbortion(isProvisional: true))
    #expect(testSession.state.data.isProvisional)
    testSession.settleProvisionalStateIfNeeded()
    #expect(!testSession.state.data.isProvisional)
    #expect(!testClientProxy.markedTexts.isEmpty)
    #expect(testClientProxy.markedTexts.last?.isEmpty == true)
  }

  /// 雙拼（非狂打）之待配首鍵遇非碼鍵時，其收尾切態係暫定者：該狀態必於本輪派送結束時
  /// 被結算，且客體所見之空筆只會居於末位——不復有「組字結束旋即重新開始」之閃爍。
  @Test("SS-Lifecycle-015 Dualpin retirement settles its provisional state by the end of the dispatch")
  func test_SS_Lifecycle_015() throws {
    let originalParser = testHandler.prefs.keyboardParser
    let originalParser4Dualpin = testHandler.prefs.keyboardParser4Dualpin
    let originalDualpinEnabled = testHandler.prefs.dualpinEnabledForPinyinTyping
    let originalDualpinSchema = testHandler.prefs.dualpinSchemaJSON
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.keyboardParser = originalParser
      testHandler.prefs.keyboardParser4Dualpin = originalParser4Dualpin
      testHandler.prefs.dualpinEnabledForPinyinTyping = originalDualpinEnabled
      testHandler.prefs.dualpinSchemaJSON = originalDualpinSchema
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.ensureKeyboardParser()
      testHandler.currentLM.syncPrefs()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.keyboardParser4Dualpin = KeyboardParser.ofDualpinMSPY.rawValue
    testHandler.prefs.dualpinEnabledForPinyinTyping = true
    testHandler.prefs.dualpinSchemaJSON = ""
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    InputSession.current = testSession
    testSession.resetInputHandler(forceComposerCleanup: true)
    testSession.performServerActivation()
    testClientProxy.clear()

    // 待配首鍵（微軟雙拼之 `s`）。
    press(KBEvent.KeyEventData(chars: "s"))
    #expect(!testSession.state.data.displayedText.isEmpty)

    // 非碼鍵（逗號）觸發退位作廢：本鍵交予客體去落。
    press(KBEvent.KeyEventData(chars: ","), shouldHandle: false)

    // 收尾之切態係暫定者，已於本輪派送結束時被結算（否則此記猶在）。
    #expect(testSession.state.type == .ofEmpty)
    #expect(!testSession.state.data.isProvisional, "暫定狀態須於本輪派送結束時結算。")

    // 空筆只居末位：客體不會先見「組字結束」再見「組字開始」。
    let emptyOffsets = testClientProxy.markedTexts.enumerated()
      .filter { $0.element.isEmpty }.map(\.offset)
    #expect(!emptyOffsets.isEmpty)
    #expect(emptyOffsets.allSatisfy { $0 == testClientProxy.markedTexts.count - 1 })
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
