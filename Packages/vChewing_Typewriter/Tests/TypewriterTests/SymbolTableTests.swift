// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import Testing
@testable import Typewriter

// MARK: - SymbolTableCategoryTests

@Suite("SymbolTableCategory")
struct SymbolTableCategoryTests {

  // MARK: - pageSize

  @Test("pageSize 為 8")
  func testPageSize() {
    #expect(SymbolTableCategory.pageSize == 8)
  }

  // MARK: - totalPages

  @Test("totalPages: 空 symbols → 1 頁")
  func testTotalPagesEmpty() {
    let cat = SymbolTableCategory(name: "空", symbols: [])
    #expect(cat.totalPages == 1)
  }

  @Test("totalPages: 8 個 symbols → 1 頁")
  func testTotalPagesExactlyOnePage() {
    let cat = SymbolTableCategory(name: "一頁", symbols: Array(repeating: "★", count: 8))
    #expect(cat.totalPages == 1)
  }

  @Test("totalPages: 9 個 symbols → 2 頁")
  func testTotalPagesTwoPages() {
    let cat = SymbolTableCategory(name: "兩頁", symbols: Array(repeating: "★", count: 9))
    #expect(cat.totalPages == 2)
  }

  @Test("totalPages: 16 個 symbols → 2 頁")
  func testTotalPagesExactlyTwoPages() {
    let cat = SymbolTableCategory(name: "兩頁整", symbols: Array(repeating: "★", count: 16))
    #expect(cat.totalPages == 2)
  }

  // MARK: - symbolsOnCurrentPage

  @Test("symbolsOnCurrentPage: 第 0 頁，共 10 個 → 前 8 個")
  func testSymbolsOnCurrentPageFirstPage() {
    let symbols = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
    var cat = SymbolTableCategory(name: "test", symbols: symbols)
    let page = cat.symbolsOnCurrentPage
    #expect(page == ["A", "B", "C", "D", "E", "F", "G", "H"])
    #expect(page.count == 8)
    cat.currentPage = 1
    let page2 = cat.symbolsOnCurrentPage
    #expect(page2 == ["I", "J"])
  }

  // MARK: - hasNextPage

  @Test("hasNextPage: 第 0 頁，共 9 個 → true")
  func testHasNextPageTrue() {
    var cat = SymbolTableCategory(name: "test", symbols: Array(repeating: "★", count: 9))
    #expect(cat.hasNextPage == true)
    cat.currentPage = 1
    #expect(cat.hasNextPage == false)
  }

  @Test("hasNextPage: 第 0 頁，共 8 個 → false")
  func testHasNextPageFalseExactPage() {
    let cat = SymbolTableCategory(name: "test", symbols: Array(repeating: "★", count: 8))
    #expect(cat.hasNextPage == false)
  }
}

// MARK: - SymbolTableGridStateTests

import LangModelAssembly

@Suite("SymbolTableGrid State", .serialized)
@MainActor
struct SymbolTableGridStateTests {

  private func makeHandlerAndSession() -> (MockInputHandler, MockSession) {
    let lm = LMAssembly.LMInstantiator(isCHS: false)
    let pref = MockPrefMgr()
    let handler = MockInputHandler(lm: lm, pref: pref)
    let session = MockSession()
    handler.session = session
    session.inputHandler = handler
    return (handler, session)
  }

  /// 建立 Ctrl+` 的 KBEvent（keyCode 50）。
  private func ctrlBacktickEvent() -> KBEvent {
    KBEvent.keyEventSimple(
      type: .keyDown,
      flags: .control,
      chars: "`",
      charsSansModifiers: "`",
      keyCode: 50
    )
  }

  /// 建立方向鍵事件。
  private func arrowEvent(_ keyCode: KeyCode) -> KBEvent {
    let specialKey: KBEvent.SpecialKey
    switch keyCode {
    case .kUpArrow: specialKey = .upArrow
    case .kLeftArrow: specialKey = .leftArrow
    case .kRightArrow: specialKey = .rightArrow
    default: specialKey = .downArrow
    }
    return KBEvent.keyEventSimple(
      type: .keyDown,
      flags: [],
      chars: specialKey.unicodeScalar.description,
      keyCode: keyCode.rawValue
    )
  }

  /// 建立 Esc 事件（KeyCode 53，char "\u{1B}"）。
  private func escEvent() -> KBEvent {
    KBEvent.keyEventSimple(
      type: .keyDown,
      flags: [],
      chars: "\u{1B}",
      keyCode: KeyCode.kEscape.rawValue
    )
  }

  /// 建立數字鍵事件（chars 為 "1"–"8"）。
  private func numberKeyEvent(_ digit: Int) -> KBEvent {
    let char = "\(digit)"
    let keyCode = mapKeyCodesANSIForTests[char] ?? 65_535
    return KBEvent.keyEventSimple(
      type: .keyDown,
      flags: [],
      chars: char,
      keyCode: keyCode
    )
  }

  // MARK: - 符號表觸發（backtick 逾時）

  @Test("backtick 逾時觸發符號表狀態（功能啟用時）")
  func testTriggerSymbolTableGrid() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()

    let consumed = handler.triggerSymbolTableGrid()
    #expect(consumed == true)
    #expect(session.state.type == .ofSymbolTableGrid)
    #expect(!session.state.data.symbolTableCategories.isEmpty)
    #expect(session.state.data.selectedSymbolTableRow == 0)
  }

  @Test("backtick 逾時觸發符號表：功能停用時不觸發")
  func testTriggerSymbolTableGridDisabled() async throws {
    let (handler, session) = makeHandlerAndSession()
    (handler.prefs as! MockPrefMgr).symbolTableEnabled = false

    let consumed = handler.triggerSymbolTableGrid()
    #expect(consumed == false)
    #expect(session.state.type == .ofEmpty)
  }

  // MARK: - 上下鍵導航

  @Test("↓ 鍵：選中列往下移動")
  func testDownArrowNavigation() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()

    _ = handler.triggerSymbolTableGrid()
    #expect(session.state.type == .ofSymbolTableGrid)
    #expect(session.state.data.selectedSymbolTableRow == 0)

    _ = handler.handleSymbolTableGridState(input: arrowEvent(.kDownArrow))
    #expect(session.state.data.selectedSymbolTableRow == 1)
  }

  @Test("↑ 鍵：在最頂列時觸發 errorCallback")
  func testUpArrowAtTop() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()
    var errorMsg: String?
    handler.errorCallback = { errorMsg = $0 }
    _ = session // suppress unused warning

    _ = handler.triggerSymbolTableGrid()

    _ = handler.handleSymbolTableGridState(input: arrowEvent(.kUpArrow))
    #expect(errorMsg == "SYM_AT_TOP")
  }

  // MARK: - Esc 取消

  @Test("Esc 取消：回到 ofEmpty 狀態（空組字器）")
  func testEscapeReturnsToEmpty() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()

    _ = handler.triggerSymbolTableGrid()
    #expect(session.state.type == .ofSymbolTableGrid)

    _ = handler.handleSymbolTableGridState(input: escEvent())
    #expect(session.state.type == .ofEmpty)
  }

  // MARK: - 數字鍵選取

  @Test("數字鍵 1：選取選中列第一個符號，提交並退出")
  func testNumberKeySelectsSymbol() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()

    _ = handler.triggerSymbolTableGrid()
    #expect(session.state.type == .ofSymbolTableGrid)

    let cat = session.state.data.symbolTableCategories[0]
    let expectedSymbol = cat.symbols[0]

    _ = handler.handleSymbolTableGridState(input: numberKeyEvent(1))
    // 按下數字鍵後，state 變成 ofCommitting 或已提交
    let committed = session.state.type == .ofCommitting || !session.recentCommissions.isEmpty
    #expect(committed)
    if !session.recentCommissions.isEmpty {
      #expect(session.recentCommissions.last == expectedSymbol)
    }
  }

  // MARK: - 邊界導航測試

  @Test("↓ 鍵：在最底列時觸發 errorCallback（SYM_AT_BOTTOM）")
  func testDownArrowAtBottom() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()
    var errorMsg: String?
    handler.errorCallback = { errorMsg = $0 }

    _ = handler.triggerSymbolTableGrid()
    let totalRows = session.state.data.symbolTableCategories.count
    // 移到最後一列
    for _ in 0 ..< totalRows - 1 {
      _ = handler.handleSymbolTableGridState(input: arrowEvent(.kDownArrow))
    }
    #expect(session.state.data.selectedSymbolTableRow == totalRows - 1)

    _ = handler.handleSymbolTableGridState(input: arrowEvent(.kDownArrow))
    #expect(errorMsg == "SYM_AT_BOTTOM")
  }

  @Test("→ 鍵：翻至下一頁")
  func testRightArrowNextPage() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()

    _ = handler.triggerSymbolTableGrid()
    // 找到有多頁的分類列
    let cats = session.state.data.symbolTableCategories
    guard let multiPageIdx = cats.indices.first(where: { cats[$0].totalPages > 1 }) else { return }

    // 移到多頁列
    for _ in 0 ..< multiPageIdx {
      _ = handler.handleSymbolTableGridState(input: arrowEvent(.kDownArrow))
    }
    #expect(session.state.data.selectedSymbolTableRow == multiPageIdx)
    #expect(session.state.data.symbolTableCategories[multiPageIdx].currentPage == 0)

    _ = handler.handleSymbolTableGridState(input: arrowEvent(.kRightArrow))
    #expect(session.state.data.symbolTableCategories[multiPageIdx].currentPage == 1)
  }

  @Test("← 鍵：翻回上一頁")
  func testLeftArrowPrevPage() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()

    _ = handler.triggerSymbolTableGrid()
    let cats = session.state.data.symbolTableCategories
    guard let multiPageIdx = cats.indices.first(where: { cats[$0].totalPages > 1 }) else { return }

    for _ in 0 ..< multiPageIdx {
      _ = handler.handleSymbolTableGridState(input: arrowEvent(.kDownArrow))
    }
    // 先翻到第 1 頁
    _ = handler.handleSymbolTableGridState(input: arrowEvent(.kRightArrow))
    #expect(session.state.data.symbolTableCategories[multiPageIdx].currentPage == 1)

    // 再翻回第 0 頁
    _ = handler.handleSymbolTableGridState(input: arrowEvent(.kLeftArrow))
    #expect(session.state.data.symbolTableCategories[multiPageIdx].currentPage == 0)
  }

  @Test("← 鍵：在第一頁時觸發 errorCallback（SYM_NO_PREV_PAGE）")
  func testLeftArrowAtFirstPage() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()
    var errorMsg: String?
    handler.errorCallback = { errorMsg = $0 }
    _ = session // 防止 ARC 提早釋放

    _ = handler.triggerSymbolTableGrid()
    _ = handler.handleSymbolTableGridState(input: arrowEvent(.kLeftArrow))
    #expect(errorMsg == "SYM_NO_PREV_PAGE")
  }

  @Test("Enter 鍵：確認選中列第一個符號並提交")
  func testEnterConfirmsFirstSymbol() async throws {
    CandidateNode.load()
    let (handler, session) = makeHandlerAndSession()

    _ = handler.triggerSymbolTableGrid()
    #expect(session.state.type == .ofSymbolTableGrid)

    let cat = session.state.data.symbolTableCategories[0]
    let expectedSymbol = cat.symbols[0]

    let enterEvent = KBEvent.keyEventSimple(
      type: .keyDown,
      flags: [],
      chars: "\r",
      keyCode: KeyCode.kCarriageReturn.rawValue
    )
    _ = handler.handleSymbolTableGridState(input: enterEvent)
    let committed = session.state.type == .ofCommitting || !session.recentCommissions.isEmpty
    #expect(committed)
    if !session.recentCommissions.isEmpty {
      #expect(session.recentCommissions.last == expectedSymbol)
    }
  }
}
