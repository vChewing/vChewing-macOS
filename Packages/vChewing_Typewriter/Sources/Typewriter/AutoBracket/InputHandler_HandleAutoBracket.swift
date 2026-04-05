// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 自動括號配對核心邏輯。
//
// 提供三個核心方法：
// - handleAutoBracketPairing(insertedKey:)：左括號確認插入後，自動補入右括號
// - handleSmartOverwrite(for:)：輸入右括號時，若游標前方已有相同右括號則跳過
// - handleBracketBackspace()：游標位於空括號內時，Backspace 同時刪除兩側括號

extension InputHandlerProtocol {

  // MARK: - 自動括號配對（Auto Bracket Pairing）

  /// 在組字器中插入左括號後，自動在游標後補入對應右括號，游標留在兩括號之間。
  ///
  /// 此方法應在 `assembler.insertKey(leftBracketKey)` 成功之後、`assemble()` 之前呼叫。
  ///
  /// 實作細節：利用 `LMInstantiator.ephemeralUnigrams` 暫存右括號字元，使
  /// `assembler.insertKey(String(rightChar))` 可以通過 LM 檢查並建立合法節點，
  /// 完成後立即清除暫存，避免污染後續的 LM 查詢。
  ///
  /// - Parameter insertedKey: 剛插入組字器的標點鍵（如 `"_punctuation_A_9"` 對應 `（`）
  /// - Returns: 是否觸發自動配對
  @discardableResult
  func handleAutoBracketPairing(insertedKey: String) -> Bool {
    guard prefs.autoBracketPairingEnabled else { return false }

    // 查詢剛插入的 key 對應的輸出字元
    guard
      let outputChar = currentLM.unigramsFor(keyArray: [insertedKey]).first?.value.first
    else { return false }

    // 確認是全形左括號，且能找到對應右括號
    guard
      BracketPairingRules.fullWidthLeftSet.contains(outputChar),
      let rightChar = BracketPairingRules.rightOf[outputChar]
    else { return false }

    let rightKey = String(rightChar)

    // 暫存右括號字元至 LM，使 assembler.insertKey 可通過 LM 檢查
    currentLM.ephemeralUnigrams[rightKey] = .init(keyArray: [rightKey], value: rightKey)

    // 插入右括號（此時游標在右括號之後）
    let inserted = assembler.insertKey(rightKey)

    // 立即清除暫存，避免污染後續 LM 查詢
    currentLM.ephemeralUnigrams.removeAll()

    guard inserted else { return false }

    // 游標退回兩括號之間（左括號之後、右括號之前）
    assembler.cursor -= 1

    return true
  }

  // MARK: - Smart Overwrite（智慧覆蓋）

  /// 當使用者輸入右括號時，若游標右側已有由自動配對插入的相同右括號，
  /// 則不重複插入，而是讓游標向右跳過該右括號。
  ///
  /// 此方法應在 `handlePunctuation(_:)` 中、`assembler.insertKey` 之前呼叫。
  /// 若回傳 `true`，呼叫端應直接更新狀態並 `return true`（已處理完畢）。
  ///
  /// 識別方式：自動配對插入的右括號以**直接字元**（單一字元 String）為 key，
  /// 可與一般標點 key（如 `"_punctuation_A_0"`）區分。
  ///
  /// - Parameter customPunctuation: 即將輸入的標點鍵（如 `"_punctuation_A_0"`）
  /// - Returns: 是否執行了 Smart Overwrite
  @discardableResult
  func handleSmartOverwrite(for customPunctuation: String) -> Bool {
    guard prefs.autoBracketPairingEnabled else { return false }
    guard assembler.cursor < assembler.length else { return false }

    // 游標右側的 key：若為單一字元且屬於右括號，表示可能是自動配對插入的
    let keyAfterCursor = assembler.keys[assembler.cursor]
    guard
      keyAfterCursor.count == 1,
      let charAfterCursor = keyAfterCursor.first,
      BracketPairingRules.isRightBracket.contains(charAfterCursor)
    else { return false }

    // 確認即將輸入的標點鍵，其對應輸出字元與游標右側字元相符
    let outputValue = currentLM.unigramsFor(keyArray: [customPunctuation]).first?.value ?? ""
    guard outputValue == keyAfterCursor else { return false }

    // Smart Overwrite：游標向右跳過已有的右括號
    assembler.cursor += 1
    return true
  }

  // MARK: - Backspace 配對刪除（Paired Deletion）

  /// 當游標位於空括號內（左右括號之間無任何內容）時，
  /// Backspace 鍵同時刪除左右兩個括號。
  ///
  /// 此方法應在 `handleBackSpace(input:)` 中、`isComposerOrCalligrapherEmpty` 為 true
  /// 的分支最前方呼叫。若回傳 `true`，呼叫端應立即更新狀態並 `return true`。
  ///
  /// 識別條件：
  /// - 游標右側為單一字元的右括號（自動配對插入的特徵）
  /// - 游標左側的標點鍵，經 LM 查詢後對應的字元為對應左括號
  ///
  /// - Returns: 是否執行了配對刪除
  @discardableResult
  func handleBracketBackspace() -> Bool {
    guard prefs.autoBracketPairingEnabled else { return false }
    guard isComposerOrCalligrapherEmpty else { return false }
    guard assembler.cursor > 0, assembler.cursor < assembler.length else { return false }

    // 游標右側必須是單字元右括號（自動配對插入的特徵：key 為直接字元）
    let keyAfterCursor = assembler.keys[assembler.cursor]
    guard
      keyAfterCursor.count == 1,
      let charAfter = keyAfterCursor.first,
      BracketPairingRules.isRightBracket.contains(charAfter)
    else { return false }

    // 游標左側的標點鍵，確認對應字元是否為配對的左括號。
    // 若 key 本身為單一字元（ephemeral 模式直接插入），直接取用；
    // 否則查詢 LM 取得輸出字元。
    let keyBeforeCursor = assembler.keys[assembler.cursor - 1]
    let charBefore: Character?
    if keyBeforeCursor.count == 1, let ch = keyBeforeCursor.first {
      charBefore = ch
    } else {
      charBefore = currentLM.unigramsFor(keyArray: [keyBeforeCursor]).first?.value.first
    }
    guard
      let charBefore,
      BracketPairingRules.fullWidthLeftSet.contains(charBefore),
      let expectedRight = BracketPairingRules.rightOf[charBefore],
      charAfter == expectedRight
    else { return false }

    // 配對刪除：先刪左括號（使用含 KeyDropContext 回補邏輯的 InputHandler.dropKey），
    // 游標自動左移；再刪右括號（使用 assembler.dropKey 直接刪除）
    _ = dropKey(direction: .rear)
    _ = assembler.dropKey(direction: .front)
    return true
  }
}
