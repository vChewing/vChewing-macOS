// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

// MARK: - 近音表按鍵處理

extension InputHandlerProtocol {

  // MARK: - 近音表觸發（↑ 鍵）

  /// 偵測 ↑ 鍵，若條件符合則建立近音表並切換至 `ofSimilarPhonetic` 狀態。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 是否已處理（consumed）。
  func triggerSimilarPhonetic(input: InputSignalProtocol) -> Bool {
    guard let session else { return false }
    // 只在水平模式的 ↑ 鍵觸發
    guard KeyCode(rawValue: input.keyCode) == .kUpArrow else { return false }
    guard !session.isVerticalTyping else { return false }
    // 無修飾鍵
    guard input.commonKeyModifierFlags.isEmpty else { return false }
    // 組字器非空，且注音槽/筆根槽為空（代表已有組好的字）
    guard !assembler.isEmpty, isComposerOrCalligrapherEmpty else { return false }
    // 取得游標前一字的注音讀音
    guard let (phonetic, _, _) = previousParsableReading else { return false }
    // 建立近音表
    let rows = SimilarPhoneticHandler.buildRows(for: phonetic, lm: currentLM)
    guard !rows.isEmpty else { return false }
    // 建立顯示用的 ofInputting 基底
    let inputtingState = generateStateOfInputting()
    let newState = State.ofSimilarPhonetic(
      rows: rows,
      selectedRow: 0,
      displayTextSegments: inputtingState.data.displayTextSegments,
      cursor: inputtingState.data.cursor
    )
    session.switchState(newState)
    return true
  }

  // MARK: - 近音表鍵盤導航

  /// 處理 `ofSimilarPhonetic` 狀態下的按鍵輸入。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 是否已處理（consumed）。
  func handleSimilarPhoneticState(input: InputSignalProtocol) -> Bool {
    guard let session else { return false }
    guard session.state.type == .ofSimilarPhonetic else { return false }

    var rows = session.state.data.similarPhoneticRows
    let selectedRow = session.state.data.selectedSimilarPhoneticRow
    let displayTextSegments = session.state.data.displayTextSegments
    let cursor = session.state.data.cursor

    /// 更新選中列，重新發送狀態（使用當前 rows 快照）。
    func updateSelectedRow(_ newRow: Int) {
      let clamped = max(0, min(newRow, rows.count - 1))
      let newState = State.ofSimilarPhonetic(
        rows: rows,
        selectedRow: clamped,
        displayTextSegments: displayTextSegments,
        cursor: cursor
      )
      session.switchState(newState)
    }

    /// 取出選中列的第 n 個候選字（1-indexed），套用取代。
    func selectCandidate(at oneBased: Int) {
      guard rows.indices.contains(selectedRow) else { return }
      let row = rows[selectedRow]
      let pageStart = row.currentPage * SimilarPhoneticRow.pageSize
      let zeroIndex = pageStart + (oneBased - 1)
      guard row.candidates.indices.contains(zeroIndex) else {
        errorCallback?("SPC_OUT_OF_RANGE")
        return
      }
      let value = row.candidates[zeroIndex]
      applyNearPhoneticReplacement(newPhonetic: row.phonetic, value: value)
    }

    switch KeyCode(rawValue: input.keyCode) {
    case .kUpArrow:
      if selectedRow > 0 {
        updateSelectedRow(selectedRow - 1)
      } else {
        errorCallback?("SPC_AT_TOP")
      }
      return true

    case .kDownArrow:
      if selectedRow < rows.count - 1 {
        updateSelectedRow(selectedRow + 1)
      } else {
        errorCallback?("SPC_AT_BOTTOM")
      }
      return true

    case .kRightArrow:
      // 選中列往下一頁（若有更多候選字）
      guard rows.indices.contains(selectedRow) else { return true }
      if rows[selectedRow].hasNextPage {
        rows[selectedRow].currentPage += 1
        updateSelectedRow(selectedRow)
      } else {
        errorCallback?("SPC_NO_NEXT_PAGE")
      }
      return true

    case .kLeftArrow:
      // 選中列回到上一頁
      guard rows.indices.contains(selectedRow) else { return true }
      if rows[selectedRow].currentPage > 0 {
        rows[selectedRow].currentPage -= 1
        updateSelectedRow(selectedRow)
      } else {
        errorCallback?("SPC_NO_PREV_PAGE")
      }
      return true

    case .kEscape:
      // 取消：回到原本的 ofInputting 狀態
      session.switchState(generateStateOfInputting())
      return true

    case .kCarriageReturn, .kLineFeed, .kSpace:
      // 確認：選取選中列的第一個候選字
      selectCandidate(at: 1)
      return true

    default: break
    }

    // 數字鍵 1–8：直接選取選中列對應位置的候選字
    if input.commonKeyModifierFlags.isEmpty,
       let numChar = input.text.first,
       let num = Int(String(numChar)), (1 ... 8).contains(num)
    {
      selectCandidate(at: num)
      return true
    }

    // 其他按鍵：不處理（攔截，避免穿透）
    return true
  }

  // MARK: - 近音字取代

  /// 將組字器中游標前一字取代為指定注音讀音與字值。
  ///
  /// 流程：
  /// 1. `dropKey(direction: .rear)` — 移除游標前一字的讀音鍵
  /// 2. `assembler.insertKey(newPhonetic)` — 插入新讀音鍵
  /// 3. `assemble()` — 重新組字
  /// 4. `assembler.overrideCandidate(...)` — 強制指定節點值
  /// 5. `assemble()` — 再次組字
  /// 6. 切換回 `ofInputting` 狀態
  ///
  /// - Parameters:
  ///   - newPhonetic: 新讀音（如 "ㄗㄢˊ"）。
  ///   - value: 選取的字（如 "參"）。
  func applyNearPhoneticReplacement(newPhonetic: String, value: String) {
    guard let session else { return }
    guard !assembler.isEmpty, assembler.cursor > 0 else { return }
    // Step 1: 移除游標前一字的讀音鍵（透過包裝版 dropKey）
    guard dropKey(direction: .rear) else { return }
    // Step 2: 插入新讀音
    guard assembler.insertKey(newPhonetic) else {
      // 回退：重組現有狀態
      assemble()
      session.switchState(generateStateOfInputting())
      return
    }
    // Step 3 & 4: 組字後強制指定節點
    assemble()
    assembler.overrideCandidate(
      .init(keyArray: [newPhonetic], value: value),
      at: actualNodeCursorPosition,
      overrideType: .withSpecified,
      isExplicitlyOverridden: true,
      enforceRetokenization: false
    )
    // Step 5: 再次組字
    assemble()
    // Step 6: 回到輸入狀態
    session.switchState(generateStateOfInputting())
  }
}
