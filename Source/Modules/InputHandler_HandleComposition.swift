// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。

import Shared
import Tekkon

extension InputHandler {
  /// 用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。
  /// - Parameters:
  ///   - input: 輸入訊號。
  ///   - errorCallback: 錯誤回呼。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleComposition(
    input: InputSignalProtocol,
    errorCallback: @escaping (String) -> Void
  ) -> Bool? {
    guard let delegate = delegate else { return nil }

    // MARK: 注音按鍵輸入處理 (Handle BPMF Keys)

    var keyConsumedByReading = false
    let skipPhoneticHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
      || input.isControlHold || input.isOptionHold || input.isShiftHold || input.isCommandHold

    // 這裡 inputValidityCheck() 是讓注拼槽檢查 charCode 這個 UniChar 是否是合法的注音輸入。
    // 如果是的話，就將這次傳入的這個按鍵訊號塞入注拼槽內且標記為「keyConsumedByReading」。
    // 函式 composer.receiveKey() 可以既接收 String 又接收 UniChar。
    if !skipPhoneticHandling && composer.inputValidityCheck(key: input.charCode) {
      // 引入 macOS 內建注音輸入法的行為，允許用除了陰平以外的聲調鍵覆寫前一個漢字的讀音。
      // 但如果要覆寫的內容會導致游標身後的字音沒有對應的辭典記錄的話，那就只蜂鳴警告一下。
      proc: if [0, 1].contains(prefs.specifyIntonationKeyBehavior), composer.isEmpty, !input.isSpace {
        // prevReading 的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
        guard let prevReading = previousParsableReading, isIntonationKey(input) else { break proc }
        var theComposer = composer
        prevReading.0.charComponents.forEach { theComposer.receiveKey(fromPhonabet: $0) }
        // 發現要覆寫的聲調與覆寫對象的聲調雷同的情況的話，直接跳過處理。
        let oldIntonation: Tekkon.Phonabet = theComposer.intonation
        theComposer.receiveKey(fromString: input.text)
        if theComposer.intonation == oldIntonation, prefs.specifyIntonationKeyBehavior == 1 { break proc }
        theComposer.intonation.clear()
        // 檢查新的漢字字音是否在庫。
        let temporaryReadingKey = theComposer.getComposition()
        if currentLM.hasUnigramsFor(key: theComposer.getComposition()) {
          compositor.dropKey(direction: .rear)
          walk()  // 這裡必須 Walk 一次、來更新目前被 walk 的內容。
          composer = theComposer
          // 這裡不需要回呼 generateStateOfInputting()，因為當前輸入的聲調鍵一定是合規的、會在之後回呼 generateStateOfInputting()。
        } else {
          errorCallback("4B0DD2D4：語彙庫內無「\(temporaryReadingKey)」的匹配記錄，放棄覆寫游標身後的內容。")
          return true
        }
      }

      composer.receiveKey(fromString: input.text)
      keyConsumedByReading = true

      // 沒有調號的話，只需要 setInlineDisplayWithCursor() 且終止處理（return true）即可。
      // 有調號的話，則不需要這樣，而是轉而繼續在此之後的處理。
      if !composer.hasToneMarker() {
        delegate.switchState(generateStateOfInputting())
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
        errorCallback("B49C0979：語彙庫內無「\(readingKey)」的匹配記錄。")

        if prefs.keepReadingUponCompositionError {
          composer.intonation.clear()  // 砍掉聲調。
          delegate.switchState(generateStateOfInputting())
          return true
        }

        composer.clear()
        // 根據「組字器是否為空」來判定回呼哪一種狀態。
        switch compositor.isEmpty {
          case false: delegate.switchState(generateStateOfInputting())
          case true:
            delegate.switchState(IMEState.ofAbortion())
        }
        return true  // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了。
      }

      // 將該讀音插入至組字器內的軌格當中。
      compositor.insertKey(readingKey)

      // 讓組字器反爬軌格。
      walk()

      // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
      let textToCommit = commitOverflownComposition

      // 看看半衰記憶模組是否會對目前的狀態給出自動選字建議。
      retrieveUOMSuggestions(apply: true)

      // 之後就是更新組字區了。先清空注拼槽的內容。
      composer.clear()

      // 再以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      var inputting = generateStateOfInputting()
      inputting.textToCommit = textToCommit
      delegate.switchState(inputting)

      /// 逐字選字模式的處理。
      if prefs.useSCPCTypingMode {
        let candidateState: IMEStateProtocol = generateStateOfCandidates(state: inputting)
        switch candidateState.candidates.count {
          case 2...: delegate.switchState(candidateState)
          case 1:
            let firstCandidate = candidateState.candidates.first!  // 一定會有，所以強制拆包也無妨。
            let reading: String = firstCandidate.0
            let text: String = firstCandidate.1
            delegate.switchState(IMEState.ofCommitting(textToCommit: text))

            if !prefs.associatedPhrasesEnabled {
              delegate.switchState(IMEState.ofEmpty())
            } else {
              let associatedPhrases =
                generateStateOfAssociates(
                  withPair: .init(key: reading, value: text)
                )
              delegate.switchState(associatedPhrases.candidates.isEmpty ? IMEState.ofEmpty() : associatedPhrases)
            }
          default: break
        }
      }
      // 將「這個按鍵訊號已經被輸入法攔截處理了」的結果藉由 SessionCtl 回報給 IMK。
      return true
    }

    /// 是說此時注拼槽並非為空、卻還沒組音。這種情況下只可能是「注拼槽內只有聲調」。
    if keyConsumedByReading {
      // 以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      delegate.switchState(generateStateOfInputting())
      return true
    }
    return nil
  }
}
