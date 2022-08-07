// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案用來處理 KeyHandler.HandleInput() 當中的與組字有關的行為。

extension KeyHandler {
  /// 用來處理 KeyHandler.HandleInput() 當中的與組字有關的行為。
  /// - Parameters:
  ///   - input: 輸入訊號。
  ///   - stateCallback: 狀態回呼，交給對應的型別內的專有函式來處理。
  ///   - errorCallback: 錯誤回呼。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleComposition(
    input: InputSignal,
    stateCallback: @escaping (InputStateProtocol) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool? {
    // MARK: 注音按鍵輸入處理 (Handle BPMF Keys)

    var keyConsumedByReading = false
    let skipPhoneticHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
      || input.isControlHold || input.isOptionHold || input.isShiftHold || input.isCommandHold

    // 這裡 inputValidityCheck() 是讓注拼槽檢查 charCode 這個 UniChar 是否是合法的注音輸入。
    // 如果是的話，就將這次傳入的這個按鍵訊號塞入注拼槽內且標記為「keyConsumedByReading」。
    // 函式 composer.receiveKey() 可以既接收 String 又接收 UniChar。
    if !skipPhoneticHandling && composer.inputValidityCheck(key: input.charCode) {
      composer.receiveKey(fromCharCode: input.charCode)
      keyConsumedByReading = true

      // 沒有調號的話，只需要 updateClientComposingBuffer() 且終止處理（return true）即可。
      // 有調號的話，則不需要這樣，而是轉而繼續在此之後的處理。
      if !composer.hasToneMarker() {
        stateCallback(buildInputtingState)
        return true
      }
    }

    var composeReading = composer.hasToneMarker() && composer.inputValidityCheck(key: input.charCode)  // 這裡不需要做排他性判斷。

    // 如果當前的按鍵是 Enter 或 Space 的話，這時就可以取出 _composer 內的注音來做檢查了。
    // 來看看詞庫內到底有沒有對應的讀音索引。這裡用了類似「|=」的判斷處理方式。
    composeReading = composeReading || (!composer.isEmpty && (input.isSpace || input.isEnter))
    if composeReading {
      if input.isSpace, !composer.hasToneMarker() {
        // 補上空格，否則倚天忘形與許氏排列某些音無法響應不了陰平聲調。
        // 小麥注音因為使用 OVMandarin，所以不需要這樣補。但鐵恨引擎對所有聲調一視同仁。
        composer.receiveKey(fromString: " ")
      }
      let readingKey = composer.getComposition()  // 拿取用來進行索引檢索用的注音。
      // 如果輸入法的辭典索引是漢語拼音的話，要注意上一行拿到的內容得是漢語拼音。

      // 向語言模型詢問是否有對應的記錄。
      if !currentLM.hasUnigramsFor(key: readingKey) {
        IME.prtDebugIntel("B49C0979：語彙庫內無「\(readingKey)」的匹配記錄。")
        errorCallback()

        if mgrPrefs.keepReadingUponCompositionError {
          composer.intonation.clear()  // 砍掉聲調。
          stateCallback(buildInputtingState)
          return true
        }

        composer.clear()
        // 根據「組字器是否為空」來判定回呼哪一種狀態。
        switch compositor.isEmpty {
          case false: stateCallback(buildInputtingState)
          case true:
            stateCallback(InputState.EmptyIgnoringPreviousState())
            stateCallback(InputState.Empty())
        }
        return true  // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了。
      }

      // 將該讀音插入至組字器內的軌格當中。
      compositor.insertKey(readingKey)

      // 讓組字器反爬軌格。
      walk()

      // 看看半衰記憶模組是否會對目前的狀態給出自動選字建議。
      fetchAndApplySuggestionsFromUserOverrideModel()

      // 之後就是更新組字區了。先清空注拼槽的內容。
      composer.clear()

      // 再以回呼組字狀態的方式來執行 updateClientComposingBuffer()。
      let inputting = buildInputtingState
      stateCallback(inputting)

      /// 逐字選字模式的處理。
      if mgrPrefs.useSCPCTypingMode {
        let choosingCandidates: InputState.ChoosingCandidate = buildCandidate(
          state: inputting,
          isTypingVertical: input.isTypingVertical
        )
        if choosingCandidates.candidates.count == 1, let firstCandidate = choosingCandidates.candidates.first {
          let reading: String = firstCandidate.0
          let text: String = firstCandidate.1
          stateCallback(InputState.Committing(textToCommit: text))

          if !mgrPrefs.associatedPhrasesEnabled {
            stateCallback(InputState.Empty())
          } else {
            if let associatedPhrases =
              buildAssociatePhraseState(
                withPair: .init(key: reading, value: text),
                isTypingVertical: input.isTypingVertical
              ), !associatedPhrases.candidates.isEmpty
            {
              stateCallback(associatedPhrases)
            } else {
              stateCallback(InputState.Empty())
            }
          }
        } else {
          stateCallback(choosingCandidates)
        }
      }
      // 將「這個按鍵訊號已經被輸入法攔截處理了」的結果藉由 ctlInputMethod 回報給 IMK。
      return true
    }

    /// 是說此時注拼槽並非為空、卻還沒組音。這種情況下只可能是「注拼槽內只有聲調」。
    if keyConsumedByReading {
      // 以回呼組字狀態的方式來執行 updateClientComposingBuffer()。
      stateCallback(buildInputtingState)
      return true
    }
    return nil
  }
}
