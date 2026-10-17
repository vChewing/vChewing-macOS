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

extension LibVanguardTestsRoot.InputHandlerTests {
  /// Session 層的跨平台單元測試群。
  ///
  /// 與父 Suite（以 `MockInputHandler` + `MockSession` 直呼 `triageInput`）不同，
  /// 本 Suite 使用真正的 `InputSession` 與真正的 `InputHandler`，經由 `SessionProtocol`
  /// 的事件入口 `handleEvent(_:)` 驅動，並以 `MockClientProxy` 取代 IMK 客體；
  /// 這樣才能涵蓋 Session 層專屬的行為（啟用／停用、熱鍵放行、打字模式提示、
  /// 客體遞交內容、選字窗導覽等）。
  ///
  /// 各用例自持一份 `TestEnvironment`（辭典、宿主、偏好容器），故與兄弟 Suite 可並行；
  /// 仍宣告為 `InputHandlerTests` 的子 Suite，只是為了沿用其共用之輔助設施與命名層級。
  @Suite("SessionTests")
  final class Session {
    // MARK: Lifecycle

    init() {
      // 各用例自持一份環境（辭典、宿主、偏好容器），故不再改寫任何行程級全域（P316）。
      let env = TestEnvironment()
      self.testEnv = env
      let host = env.host
      let lx = env.lx

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
      host.ui = { [weak ui] in ui }

      let session = InputSession(preallocated: (), manuallyAssignedClientProxy: proxy, host: host)
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
      session.inputHandler?.prefs = env.prefs
      session.inputHandler?.assembler.maxSegLength = env.prefs.maxCandidateLength
      session.inputHandler?.ensureKeyboardParser()
      session.inputHandler?.errorCallback = { [weak self] message in
        self?.recordedErrors.append(message)
      }
      session.inputHandler?.filterabilityChecker = host.isStateDataFilterableForMarked
      session.inputHandler?.pomSaveCallback = {}

      // 使用者語彙寫入：單元測試以記憶體記錄取代磁碟 I/O。
      host.userDictDataURL = { _, type in
        let name = type == .theFilter ? "userdata_filter" : "userdata"
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
      }
      host.writeUserPhrasesAtOnce = { [weak self] phrase, isFiltering in
        guard let self else { return false }
        if isFiltering {
          self.recordedFilteredPhrases.append(phrase)
        } else {
          self.writtenUserPhrases.append(phrase)
        }
        return true
      }
      host.crossConvert = { $0 }
      host.kanjiConversionIfRequired = { $0 }
      host.checkIfPhrasePairExists = { _, _, _ in false }
      host.checkIfPhrasePairIsFiltered = { _, _, _ in false }
      host.updateUserPhraseWeight = { phrase, _ in phrase }
      host.bleachSpecifiedSuggestions = { _, _, _ in }
      host.validateCandidateKeys = { _, _ in nil }
      host.postEventForClosingAllPanels = {}
      host.isKeyboardJIS = { false }
    }

    deinit {
      // 僅收拾本用例自己的 Session：辭典、宿主、偏好容器皆由本用例之 `TestEnvironment`
      // 自持（P316），故 `deinit` 不得、也無需碰觸任何行程級全域。
      mainSync {
        testSession.switchState(IMEState.ofAbortion())
        testSession.inputHandler?.errorCallback = nil
        testSession.inputHandler?.session = nil
        testEnv = nil
      }
    }

    // MARK: Internal

    var testEnv: TestEnvironment?
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
