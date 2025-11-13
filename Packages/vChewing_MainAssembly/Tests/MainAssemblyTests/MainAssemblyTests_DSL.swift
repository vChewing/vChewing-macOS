// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import XCTest

@testable import LangModelAssembly
@testable import MainAssembly

// MainAssembly 測試共用 DSL 輔助函式。
// 本檔提供輕量、可組合的工具，讓測試更精簡且易讀。
// - 事件輔助：壓送單鍵／多鍵，免除 asPairedEvents 樣板碼。
// - 重設輔助：統一 Session／Handler／Client 的重設流程。
// - 候選窗輔助：開啟／高亮／選取／取消等操作。
// - 卡匣資料輔助：建立卡匣路徑並以同步方式載入使用者資料。
// - 碼點模式輔助：進入碼點模式並輸入十六進位序列。
// - 常用斷言：統一常見的斷言邏輯。

extension MainAssemblyTests {
  // MARK: - 事件輔助

  /// 壓送單一按鍵（成對事件），並依 shouldHandle 針對 keyDown 斷言是否被處理。
  @discardableResult
  func press(_ key: NSEvent.KeyEventData, shouldHandle: Bool = true) -> Bool {
    handleKeyEvent(key, shouldHandle: shouldHandle)
  }

  /// 依序壓送多個按鍵（成對事件），並依 shouldHandle 針對 keyDown 斷言是否被處理。
  func press(_ keys: [NSEvent.KeyEventData], shouldHandle: Bool = true) {
    let events = keys.map(\.asPairedEvents).flatMap { $0 }
    handleEvents(events, shouldHandle: shouldHandle)
  }

  /// press(_:) 的可變參數便捷包裝。
  func pressChain(_ keys: NSEvent.KeyEventData...) {
    press(keys)
  }

  // MARK: - 重設輔助

  /// 切換至 Abortion 狀態，重設處理器，並清空客體緩衝。
  func resetToAbortionAndClear() {
    testSession.switchState(.ofAbortion())
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClient.clear()
  }

  /// 以全新處理器切換到 Empty 狀態，並清空客體緩衝。
  func resetToEmptyAndClear() {
    testSession.resetInputHandler(forceComposerCleanup: true)
    testSession.switchState(.ofEmpty())
    testClient.clear()
  }

  /// 切換逐字選字（SCPC）模式。
  func useSCPC(_ on: Bool) {
    testHandler.prefs.useSCPCTypingMode = on
  }

  /// 切換尾隨游標模式。
  func useRearCursorMode(_ on: Bool) {
    testHandler.prefs.useRearCursorMode = on
  }

  // MARK: - 候選窗輔助

  /// 依當前組字內容開啟候選窗。
  /// 可選擇在開啟前覆寫游標位置。
  /// 回傳候選窗控制器（若存在）。
  @discardableResult
  func openCandidates(cursor override: Int? = nil) -> CtlCandidateProtocol? {
    if let override {
      let limited = Swift.max(0, Swift.min(override, testHandler.assembler.length))
      testHandler.assembler.cursor = limited
      testSession.switchState(testHandler.generateStateOfInputting())
    }
    let candState = testHandler.generateStateOfCandidates()
    XCTAssertFalse(candState.candidates.isEmpty)
    testSession.switchState(candState)
    testSession.toggleCandidateUIVisibility(true)
    return testSession.candidateController()
  }

  /// 高亮下一個候選項目。
  /// 先以 Tab 推進高亮；若無變化則回退改用下箭頭。
  func highlightNextCandidate() {
    let beforeText = testSession.state.displayedText
    let beforeIndex = testSession.candidateController()?.highlightedIndex
    press(tabEvent)
    let afterText = testSession.state.displayedText
    let afterIndex = testSession.candidateController()?.highlightedIndex
    if beforeText == afterText, beforeIndex == afterIndex {
      press(nextCandidateEvent)
    }
  }

  /// 迭代移動高亮直到高亮候選等於目標字串，或達到最大步數。
  /// 此實作會確保候選窗已顯示，並解析目標索引，
  /// 接著以索引方式推進高亮以提高穩定性。
  func highlightCandidateToValue(_ value: String, maxSteps: Int = 256) {
    // Ensure candidate controller exists and the window is visible.
    if testSession.candidateController() == nil {
      testSession.toggleCandidateUIVisibility(true)
    }
    guard var controller = testSession.candidateController() else {
      XCTFail("Missing candidate controller while navigating to '\(value)'.")
      return
    }

    // Resolve the target index by value.
    let values = testSession.state.candidates.map(\.value)
    guard let targetIndex = values.firstIndex(of: value) else {
      XCTFail("Target candidate '\(value)' not found. Candidates: \(values)")
      return
    }

    // If already highlighted at target, verify and return.
    if controller.highlightedIndex == targetIndex {
      XCTAssertEqual(testSession.state.displayedText, value)
      return
    }

    // Advance highlight until the target index is reached or maxSteps exceeded.
    var steps = 0
    while steps < maxSteps {
      highlightNextCandidate()
      guard let updated = testSession.candidateController() else { break }
      controller = updated
      if controller.highlightedIndex == targetIndex { break }
      steps += 1
    }

    XCTAssertEqual(testSession.state.displayedText, value)
  }

  /// Highlight to an eligible candidate by minimal constraints on candidate value and reading key length.
  /// This mirrors common usage in tests to find a candidate with at least 2 visible chars and 2 reading key chars.
  func highlightEligibleCandidate(minValueCount: Int = 2, minKeyLength: Int = 2) {
    guard var controller = testSession.candidateController() else {
      XCTFail("Missing candidate controller while searching eligible candidate.")
      return
    }
    var highlightedIndex = controller.highlightedIndex
    guard testSession.state.candidates.indices.contains(highlightedIndex) else {
      XCTFail("Highlighted index out of candidate range.")
      return
    }
    var highlightedCandidate = testSession.state.candidates[highlightedIndex]
    var attempts = 0
    while attempts < testSession.state.candidates.count,
          highlightedCandidate.value.count < minValueCount
          || highlightedCandidate.keyArray.joined().count < minKeyLength {
      highlightNextCandidate()
      guard let updated = testSession.candidateController() else {
        XCTFail("Candidate controller unexpectedly nil during iteration.")
        return
      }
      controller = updated
      highlightedIndex = controller.highlightedIndex
      guard testSession.state.candidates.indices.contains(highlightedIndex) else { break }
      highlightedCandidate = testSession.state.candidates[highlightedIndex]
      attempts += 1
    }
    XCTAssertGreaterThanOrEqual(highlightedCandidate.value.count, minValueCount)
    XCTAssertGreaterThanOrEqual(highlightedCandidate.keyArray.joined().count, minKeyLength)
  }

  /// 依 selectionKeys 對應以索引選取候選。
  func selectCandidate(at index: Int) {
    let keys = Array(testSession.selectionKeys)
    XCTAssertGreaterThan(keys.count, index)
    let key = String(keys[index])
    press(NSEvent.KeyEventData(chars: key))
  }

  /// 以指定按鍵取消候選窗，並斷言狀態與顯示文字維持一致。
  func cancelCandidates(with keyData: NSEvent.KeyEventData) {
    let before = testSession.state.displayedText
    press(keyData)
    XCTAssertTrue(testSession.state.type == .ofInputting || testSession.state.type == .ofAbortion)
    XCTAssertEqual(testSession.state.displayedText, before)
  }

  // MARK: - 卡匣資料輔助

  /// 以同步方式載入語彙模組使用者資料來包裹執行區塊，結束後復原原設定。
  func withSynchronousLMUserData(_ body: () -> ()) {
    let original = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = original }
    body()
  }

  /// 以目前測試檔為基準，依檔名組出卡匣資料路徑。
  func cassettePath(named filename: String) -> String {
    URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // MainAssemblyTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // vChewing_MainAssembly
      .deletingLastPathComponent() // Packages
      .appendingPathComponent("vChewing_LangModelAssembly")
      .appendingPathComponent("Tests")
      .appendingPathComponent("TestCINData")
      .appendingPathComponent(filename)
      .path
  }

  // MARK: - 碼點模式輔助

  /// 進入碼點模式（預設熱鍵：Option + `）。
  func enterCodePointMode() {
    handleEvents(symbolMenuKeyEventIntlWithOpt.asPairedEvents)
    XCTAssertEqual(testHandler.currentTypingMethod, .codePoint)
  }

  /// 在碼點模式下輸入十六進位碼序列。
  func typeCodePoint(_ hex: String) {
    typeSentenceOrCandidates(hex)
  }

  // MARK: - 候選文字服務（Candidate Text Service）斷言

  /// 斷言指定索引的候選文字服務回傳值符合預期。
  func assertCandidateServiceResponse(
    services: [String],
    index: Int,
    candidate: String,
    reading: [String],
    expected: String
  ) {
    let stack = services.parseIntoCandidateTextServiceStack(candidate: candidate, reading: reading)
    XCTAssertTrue(stack.indices.contains(index), "Service index out of range.")
    let service = stack[index]
    switch service.value {
    case .url:
      XCTFail("Unexpected URL service for index \(index).")
    case .selector:
      XCTAssertEqual(service.responseFromSelector, expected)
    }
  }

  /// 啟用最終健全性檢查後，斷言服務項目數量應減少。
  func assertServiceCountReducedAfterFinalSanityCheck(
    services: [String],
    candidate: String,
    reading: [String]
  ) {
    var stack = services.parseIntoCandidateTextServiceStack(candidate: candidate, reading: reading)
    let before = stack.count
    CandidateTextService.enableFinalSanityCheck()
    stack = services.parseIntoCandidateTextServiceStack(candidate: candidate, reading: reading)
    let after = stack.count
    XCTAssertGreaterThan(before, after)
  }

  // MARK: - 常用斷言

  func assertStateIsEmptyOrCommitting() {
    XCTAssertTrue(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
  }

  func assertDisplayed(_ expected: String) {
    XCTAssertEqual(testSession.state.displayedText, expected)
  }

  func assertCursorUnchanged(_ old: Int) {
    XCTAssertEqual(testHandler.assembler.cursor, old)
  }

  func assertCandidatesContain(_ value: String) {
    XCTAssertTrue(testSession.state.candidates.map(\.value).contains(value))
  }
}
