// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LexiconAssembly
@testable import LibVanguard
import LXAssemblyMaterials4Tests
import Shared
import SwiftExtension
import Tekkon
import Testing

// MARK: - SessionTests

extension InputHandlerTests {
  /// Session 層的跨平台單元測試群。
  ///
  /// 與父 Suite（以 `MockInputHandler` + `MockSession` 直呼 `triageInput`）不同，
  /// 本 Suite 使用真正的 `InputSession` 與真正的 `InputHandler`，經由 `SessionProtocol`
  /// 的事件入口 `handleEvent(_:)` 驅動，並以 `MockClientProxy` 取代 IMK 客體；
  /// 這樣才能涵蓋 Session 層專屬的行為（啟用／停用、熱鍵放行、打字模式提示、
  /// 客體遞交內容、選字窗導覽等）。
  ///
  /// 之所以宣告為 `InputHandlerTests` 的子 Suite，是因為兩者都會改動行程層級的全域狀態
  /// （`UserDefaults.unitTests`、`UserDef`、`LXAssembly` 的測試辭典、`SessionHost.shared`）。
  /// Swift Testing 的 `.serialized` 會由父 Suite 繼承給子 Suite，兩者因此共用同一把鎖而
  /// 不會並行執行——這正是不讓它成為頂層 Suite 的原因。
  @Suite("SessionTests", .serialized)
  final class Session {
    // MARK: Lifecycle

    init() {
      UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.LibVanguard.SessionTests")
      UserDefaults.pendingUnitTests = true
      UserDef.resetAll()

      LXAssembly.LXFacade.connectToTestFactoryDictionary(
        textMapData: LXATestsData.textMapTestCoreLXData
      )
      let lx = LXAssembly.LXFacade(isCHS: false)

      // SessionHost 為全域注入點：先還原成預設值，再補上單元測試必要的宿主行為。
      SessionHost.shared = SessionHost()
      SessionHost.shared.isCoreDBConnected = { true }
      SessionHost.shared.prefs = { PrefMgr.sharedSansDidSetOps }

      let proxy = MockClientProxy()
      let ui = MockSessionUI()
      let candidateController = MockNavigableCandidateController()
      let statusUI = MockTooltipUI()
      let pcb = MockPCB()
      let capsLockToggler = MockCapsLockToggler(isOn: false)
      ui.candidateUI = candidateController
      ui.statusUI = statusUI
      ui.pcb = pcb
      ui.capsLockToggler = capsLockToggler
      SessionHost.shared.ui = { [weak ui] in ui }

      let session = InputSession(preallocated: (), manuallyAssignedClientProxy: proxy)
      if session.inputMode == .imeModeNULL {
        session.inputMode = .imeModeCHT
      }

      self.testLX = lx
      self.testClientProxy = proxy
      self.testUI = ui
      self.testCandidateController = candidateController
      self.testStatusUI = statusUI
      self.testPCB = pcb
      self.testCapsLockToggler = capsLockToggler
      self.testSession = session
      self.writtenUserPhrases = []

      session.inputHandler?.currentLM = lx
      session.inputHandler?.prefs = PrefMgr.sharedSansDidSetOps
      session.inputHandler?.assembler.maxSegLength = PrefMgr.sharedSansDidSetOps.maxCandidateLength
      session.inputHandler?.ensureKeyboardParser()
      session.inputHandler?.errorCallback = { [weak self] message in
        self?.recordedErrors.append(message)
      }
      session.inputHandler?.filterabilityChecker = SessionHost.shared.isStateDataFilterableForMarked
      session.inputHandler?.pomSaveCallback = {}

      // 使用者語彙寫入：單元測試以記憶體記錄取代磁碟 I/O。
      SessionHost.shared.userDictDataURL = { _, type in
        let name = type == .theFilter ? "userdata_filter" : "userdata"
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
      }
      SessionHost.shared.writeUserPhrasesAtOnce = { [weak self] phrase, isFiltering in
        guard let self else { return false }
        if isFiltering {
          self.recordedFilteredPhrases.append(phrase)
        } else {
          self.writtenUserPhrases.append(phrase)
        }
        return true
      }
      SessionHost.shared.crossConvert = { $0 }
      SessionHost.shared.kanjiConversionIfRequired = { $0 }
      SessionHost.shared.checkIfPhrasePairExists = { _, _, _ in false }
      SessionHost.shared.checkIfPhrasePairIsFiltered = { _, _, _ in false }
      SessionHost.shared.updateUserPhraseWeight = { phrase, _ in phrase }
      SessionHost.shared.bleachSpecifiedSuggestions = { _, _, _ in }
      SessionHost.shared.validateCandidateKeys = { _, _ in nil }
      SessionHost.shared.postEventForClosingAllPanels = {}
      SessionHost.shared.isKeyboardJIS = { false }
    }

    deinit {
      // 僅收拾本 Suite 自己的 Session，不碰其它 Suite 共用的全域狀態。
      // 理由：Swift Testing 的 `.serialized` 只保證 Suite 內部的執行順序，
      // 不同 Suite 之間仍會並行；若在此重設 LXAssembly 共用狀態、UserDefaults 或
      // pendingUnitTests，會與並行中的 `InputHandlerTests` 互相踩踏。
      // 這些全域狀態會由每個測試自己的 `init` 重新建立，因此無需在此復原。
      mainSync {
        testSession.switchState(IMEState.ofAbortion())
        testSession.inputHandler?.errorCallback = nil
        testSession.inputHandler?.session = nil
        SessionHost.shared = SessionHost()
      }
    }

    // MARK: Internal

    let testSession: InputSession
    let testClientProxy: MockClientProxy
    let testUI: MockSessionUI
    let testCandidateController: MockNavigableCandidateController
    let testStatusUI: MockTooltipUI
    let testPCB: MockPCB
    let testCapsLockToggler: MockCapsLockToggler
    let testLX: LXAssembly.LXFacade

    var writtenUserPhrases: [UserPhraseInsertable] = []
    var recordedFilteredPhrases: [UserPhraseInsertable] = []
    var recordedErrors: [String] = []
    var recordedNotifications: [String] = []

    var testHandler: InputHandler {
      guard let handler = testSession.inputHandler else {
        fatalError("testSession.inputHandler is not initialized.")
      }
      return handler
    }

    // MARK: - 事件輔助

    /// 壓送單一按鍵（成對事件），並依 shouldHandle 針對 keyDown 斷言是否被處理。
    @discardableResult
    func press(_ key: KBEvent.KeyEventData, shouldHandle: Bool = true) -> Bool {
      handleKeyEvent(key, shouldHandle: shouldHandle)
    }

    /// 依序壓送多個按鍵（成對事件）。
    func press(_ keys: [KBEvent.KeyEventData], shouldHandle: Bool = true) {
      handleEvents(keys.map(\.asPairedEvents).flatMap { $0 }, shouldHandle: shouldHandle)
    }

    /// press(_:) 的可變參數便捷包裝。
    func pressChain(_ keys: KBEvent.KeyEventData...) {
      press(keys)
    }

    @discardableResult
    func handleKeyEvent(_ data: KBEvent.KeyEventData, shouldHandle: Bool = true) -> Bool {
      var handled = false
      data.asPairedEvents.forEach { event in
        let result = testSession.handleEvent(event)
        if event.type == .keyDown {
          if shouldHandle {
            #expect(result, "Expected keyDown to be handled for keyCode \(data.keyCode).")
          } else {
            #expect(!result, "Expected keyDown to pass through for keyCode \(data.keyCode).")
          }
          handled = result
        }
      }
      return handled
    }

    func handleEvents(_ events: [KBEvent], shouldHandle: Bool = true) {
      events.forEach { event in
        let result = testSession.handleEvent(event)
        if event.type == .keyDown {
          if shouldHandle {
            #expect(result, "Expected keyDown to be handled for keyCode \(event.keyCode).")
          } else {
            #expect(!result, "Expected keyDown to pass through for keyCode \(event.keyCode).")
          }
        }
      }
    }

    /// 輸入字串（成對事件，且逐鍵斷言被攔截）。
    func typeSentenceOrCandidates(_ sequence: String) {
      let isCandidateContainer = testSession.state.isCandidateContainer
      let stateType = testSession.state.type
      if !([.ofEmpty, .ofInputting].contains(stateType) || isCandidateContainer) { return }
      let typingSequence: [KBEvent] = sequence.compactMap { charRAW in
        KBEvent.KeyEventData(chars: charRAW.description).asPairedEvents
      }.flatMap { $0 }
      handleEvents(typingSequence)
    }

    // MARK: - 重設輔助

    func resetToAbortionAndClear() {
      testSession.switchState(.ofAbortion())
      testSession.resetInputHandler(forceComposerCleanup: true)
      testClientProxy.clear()
    }

    func resetToEmptyAndClear() {
      testSession.resetInputHandler(forceComposerCleanup: true)
      testSession.switchState(.ofEmpty())
      testClientProxy.clear()
    }

    func useSCPC(_ on: Bool) {
      testHandler.prefs.useSCPCTypingMode = on
    }

    func useRearCursorMode(_ on: Bool) {
      testHandler.prefs.useRearCursorMode = on
    }

    // MARK: - 組字輔助

    func clearTestPOM() {
      testHandler.currentLM.clearPOMData()
    }

    /// 預設測試序列是「科技蛋糕」。
    @discardableResult
    func prepareBasicComposition(sequence: String) -> String {
      testHandler.prefs.useSCPCTypingMode = false
      clearTestPOM()
      testSession.resetInputHandler(forceComposerCleanup: true)
      testClientProxy.clear()
      typeSentenceOrCandidates(sequence)
      if testSession.state.type != .ofInputting {
        testSession.switchState(testHandler.generateStateOfInputting())
      }
      return testSession.state.displayedText
    }

    // MARK: - 候選窗輔助

    /// 依當前組字內容開啟候選窗。可選擇在開啟前覆寫游標位置。
    @discardableResult
    func openCandidateWindow(cursor override: Int? = nil) -> CtlCandidateProtocol? {
      if let override {
        let limited = Swift.max(0, Swift.min(override, testHandler.assembler.length))
        testHandler.assembler.cursor = limited
        testSession.switchState(testHandler.generateStateOfInputting())
      }
      let candState = testHandler.generateStateOfCandidates()
      #expect(!(candState.candidates.isEmpty))
      testSession.switchState(candState)
      syncCandidateControllerCount()
      testSession.toggleCandidateUIVisibility(true)
      return testSession.candidateController()
    }

    /// 讓模擬選字窗控制器得知當前候選總數，供高亮導覽的邊界判定使用。
    func syncCandidateControllerCount() {
      testCandidateController.candidateCount = testSession.state.candidates.count
    }

    /// 高亮下一個候選項目：先以 Tab 推進高亮；若無變化則回退改用下箭頭。
    func highlightNextCandidate() {
      syncCandidateControllerCount()
      let beforeText = testSession.state.displayedText
      let beforeIndex = testSession.candidateController()?.highlightedIndex
      press(.tabEvent)
      let afterText = testSession.state.displayedText
      let afterIndex = testSession.candidateController()?.highlightedIndex
      if beforeText == afterText, beforeIndex == afterIndex {
        press(.nextCandidateEvent)
      }
    }

    /// 迭代移動高亮直到高亮候選等於目標字串，或達到最大步數。
    func highlightCandidateToValue(_ value: String, maxSteps: Int = 256) {
      if testSession.candidateController() == nil {
        testSession.toggleCandidateUIVisibility(true)
      }
      guard var controller = testSession.candidateController() else {
        Issue.record("Missing candidate controller while navigating to '\(value)'.")
        return
      }
      let values = testSession.state.candidates.map(\.value)
      guard let targetIndex = values.firstIndex(of: value) else {
        Issue.record("Target candidate '\(value)' not found. Candidates: \(values)")
        return
      }
      if controller.highlightedIndex == targetIndex {
        #expect(testSession.state.displayedText == value)
        return
      }
      var steps = 0
      while steps < maxSteps {
        highlightNextCandidate()
        guard let updated = testSession.candidateController() else { break }
        controller = updated
        if controller.highlightedIndex == targetIndex { break }
        steps += 1
      }
      #expect(testSession.state.displayedText == value)
    }

    /// 依 selectionKeys 對應以索引選取候選。
    func selectCandidate(at index: Int) {
      let keys = Array(testSession.selectionKeys)
      #expect(keys.count > index)
      press(KBEvent.KeyEventData(chars: String(keys[index])))
    }

    /// 以指定按鍵取消候選窗，並斷言狀態與顯示文字維持一致。
    func cancelCandidateWindowState(with keyData: KBEvent.KeyEventData) {
      let dispTextPriorToAction = testSession.state.displayedText
      press(keyData)
      #expect(testSession.state.type == .ofInputting || testSession.state.type == .ofAbortion)
      #expect(testSession.state.displayedText == dispTextPriorToAction)
    }

    // MARK: - 卡匣資料輔助

    func withSynchronousLXUserData(_ body: () -> ()) {
      let original = LXAssembly.LXFacade.asyncLoadingUserData
      LXAssembly.LXFacade.asyncLoadingUserData = false
      defer { LXAssembly.LXFacade.asyncLoadingUserData = original }
      body()
    }

    // MARK: - 碼點模式輔助

    func enterCodePointMode() {
      handleEvents(KBEvent.KeyEventData.symbolMenuKeyEventIntlWithOpt.asPairedEvents)
      #expect(testHandler.currentTypingMethod == .codePoint)
    }

    func typeCodePoint(_ hex: String) {
      typeSentenceOrCandidates(hex)
    }

    // MARK: - 常用斷言

    func assertStateIsEmptyOrCommitting() {
      #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    }

    func assertDisplayed(_ expected: String) {
      #expect(testSession.state.displayedText == expected)
    }

    func assertCursorUnchanged(_ old: Int) {
      #expect(testHandler.assembler.cursor == old)
    }

    func assertCandidatesContain(_ value: String) {
      #expect(testSession.state.candidates.map(\.value).contains(value))
    }
  }
}
