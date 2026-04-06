// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

// MARK: - 符號表按鍵處理

extension InputHandlerProtocol {

  // MARK: - 符號表觸發（backtick 逾時）

  /// 建立符號表並切換至 `ofSymbolTableGrid` 狀態。
  /// 由 backtick 逾時回呼觸發（數字快打功能啟用時，單按 ` 逾時即叫出符號表）。
  /// - Returns: 是否已處理（consumed）。
  @discardableResult
  public func triggerSymbolTableGrid() -> Bool {
    guard let session else { return false }
    // 確認功能已啟用
    guard prefs.symbolTableEnabled else { return false }
    // 建立符號表分類資料
    let categories = SymbolTableData.buildCategories()
    guard !categories.isEmpty else { return false }
    // 取得目前輸入狀態的顯示文字（若有組字緩衝）
    let inputtingState = generateStateOfInputting()
    let newState = State.ofSymbolTableGrid(
      categories: categories,
      selectedRow: 0,
      displayTextSegments: inputtingState.data.displayTextSegments,
      cursor: inputtingState.data.cursor
    )
    session.switchState(newState)
    return true
  }

  // MARK: - 符號表鍵盤導航

  /// 處理 `ofSymbolTableGrid` 狀態下的按鍵輸入。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 是否已處理（consumed）。
  func handleSymbolTableGridState(input: InputSignalProtocol) -> Bool {
    guard let session else { return false }
    guard session.state.type == .ofSymbolTableGrid else { return false }

    var categories = session.state.data.symbolTableCategories
    let selectedRow = session.state.data.selectedSymbolTableRow
    let displayTextSegments = session.state.data.displayTextSegments
    let cursor = session.state.data.cursor

    /// 更新選中列，重新發送狀態。
    func updateSelectedRow(_ newRow: Int) {
      let clamped = max(0, min(newRow, categories.count - 1))
      let newState = State.ofSymbolTableGrid(
        categories: categories,
        selectedRow: clamped,
        displayTextSegments: displayTextSegments,
        cursor: cursor
      )
      session.switchState(newState)
    }

    /// 取出選中列的第 n 個符號（1-indexed），提交並退出符號表。
    func selectSymbol(at oneBased: Int) {
      guard categories.indices.contains(selectedRow) else { return }
      let cat = categories[selectedRow]
      let pageStart = cat.currentPage * SymbolTableCategory.pageSize
      let zeroIndex = pageStart + (oneBased - 1)
      guard cat.symbols.indices.contains(zeroIndex) else {
        errorCallback?("SYM_OUT_OF_RANGE")
        return
      }
      let symbol = cat.symbols[zeroIndex]
      session.switchState(State.ofCommitting(textToCommit: symbol))
    }

    switch KeyCode(rawValue: input.keyCode) {
    case .kUpArrow:
      if selectedRow > 0 {
        updateSelectedRow(selectedRow - 1)
      } else {
        errorCallback?("SYM_AT_TOP")
      }
      return true

    case .kDownArrow:
      if selectedRow < categories.count - 1 {
        updateSelectedRow(selectedRow + 1)
      } else {
        errorCallback?("SYM_AT_BOTTOM")
      }
      return true

    case .kRightArrow:
      guard categories.indices.contains(selectedRow) else { return true }
      if categories[selectedRow].hasNextPage {
        categories[selectedRow].currentPage += 1
        updateSelectedRow(selectedRow)
      } else {
        errorCallback?("SYM_NO_NEXT_PAGE")
      }
      return true

    case .kLeftArrow:
      guard categories.indices.contains(selectedRow) else { return true }
      if categories[selectedRow].currentPage > 0 {
        categories[selectedRow].currentPage -= 1
        updateSelectedRow(selectedRow)
      } else {
        errorCallback?("SYM_NO_PREV_PAGE")
      }
      return true

    case .kEscape:
      // 取消：回到原本的 ofInputting 狀態（或 ofEmpty）
      let fallback = assembler.isEmpty
        ? State.ofEmpty()
        : generateStateOfInputting()
      session.switchState(fallback)
      return true

    case .kCarriageReturn, .kLineFeed, .kSpace:
      // 確認：選取選中列目前頁第一個符號
      selectSymbol(at: 1)
      return true

    default: break
    }

    // 數字鍵 1–8：直接選取選中列對應位置的符號
    if input.commonKeyModifierFlags.isEmpty,
       let numChar = input.text.first,
       let num = Int(String(numChar)), (1 ... 8).contains(num)
    {
      selectSymbol(at: num)
      return true
    }

    // 其他按鍵：攔截，避免穿透
    return true
  }
}
