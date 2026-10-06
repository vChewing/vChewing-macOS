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
