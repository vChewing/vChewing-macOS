// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

// MARK: - § State managements.

extension KeyHandler {
  // MARK: - 構築狀態（State Building）

  var buildInputtingState: InputState.Inputting {
    // "Updating the composing buffer" means to request the client
    // to "refresh" the text input buffer with our "composing text"
    var tooltipParameterRef: [String] = ["", ""]
    var composingBuffer = ""
    var composedStringCursorIndex = 0
    var readingCursorIndex = 0
    // We must do some Unicode codepoint counting to find the actual cursor location for the client
    // i.e. we need to take UTF-16 into consideration, for which a surrogate pair takes 2 UniChars
    // locations. Since we are using Swift, we use .utf16 as the equivalent of NSString.length().
    for walkedNode in walkedAnchors {
      if let theNode = walkedNode.node {
        let strNodeValue = theNode.currentKeyValue.value
        composingBuffer += strNodeValue
        let arrSplit: [String] = Array(strNodeValue).map { String($0) }
        let codepointCount = arrSplit.count
        // This re-aligns the cursor index in the composed string
        // (the actual cursor on the screen) with the compositor's logical
        // cursor (reading) cursor; each built node has a "spanning length"
        // (e.g. two reading blocks has a spanning length of 2), and we
        // accumulate those lengths to calculate the displayed cursor
        // index.
        let spanningLength: Int = walkedNode.spanningLength
        if readingCursorIndex + spanningLength <= compositorCursorIndex {
          composedStringCursorIndex += strNodeValue.utf16.count
          readingCursorIndex += spanningLength
        } else {
          if codepointCount == spanningLength {
            var i = 0
            while i < codepointCount, readingCursorIndex < compositorCursorIndex {
              composedStringCursorIndex += arrSplit[i].utf16.count
              readingCursorIndex += 1
              i += 1
            }
          } else {
            if readingCursorIndex < compositorCursorIndex {
              composedStringCursorIndex += strNodeValue.utf16.count
              readingCursorIndex += spanningLength
              if readingCursorIndex > compositorCursorIndex {
                readingCursorIndex = compositorCursorIndex
              }
              // Now we start preparing the contents of the tooltips used
              // in cases of moving cursors across certain emojis which emoji
              // char count is inequal to the reading count.
              // Example in McBopomofo: Typing 王建民 (3 readings) gets a tree emoji.
              // Example in vChewing: Typing 義麵 (2 readings) gets a pasta emoji.
              switch compositorCursorIndex {
                case compositor.readings.count...:
                  tooltipParameterRef[0] = compositor.readings[compositor.readings.count - 1]
                case 0:
                  tooltipParameterRef[1] = compositor.readings[compositorCursorIndex]
                default:
                  do {
                    tooltipParameterRef[0] = compositor.readings[compositorCursorIndex - 1]
                    tooltipParameterRef[1] = compositor.readings[compositorCursorIndex]
                  }
              }
            }
          }
        }
      }
    }

    // Now, we gather all the intel, separate the composing buffer to two parts (head and tail),
    // and insert the reading text (the Mandarin syllable) in between them.
    // The reading text is what the user is typing.
    var arrHead = [String.UTF16View.Element]()
    var arrTail = [String.UTF16View.Element]()

    for (i, n) in composingBuffer.utf16.enumerated() {
      if i < composedStringCursorIndex {
        arrHead.append(n)
      } else {
        arrTail.append(n)
      }
    }

    let head = String(utf16CodeUnits: arrHead, count: arrHead.count)
    let reading = composer.getInlineCompositionForIMK(isHanyuPinyin: mgrPrefs.showHanyuPinyinInCompositionBuffer)
    let tail = String(utf16CodeUnits: arrTail, count: arrTail.count)
    let composedText = head + reading + tail
    let cursorIndex = composedStringCursorIndex + reading.utf16.count

    let stateResult = InputState.Inputting(composingBuffer: composedText, cursorIndex: cursorIndex)

    // Now we start weaving the contents of the tooltip.
    if tooltipParameterRef[0].isEmpty, tooltipParameterRef[1].isEmpty {
      stateResult.tooltip = ""
    } else if tooltipParameterRef[0].isEmpty {
      stateResult.tooltip = String(
        format: NSLocalizedString("Cursor is to the rear of \"%@\".", comment: ""),
        tooltipParameterRef[1]
      )
    } else if tooltipParameterRef[1].isEmpty {
      stateResult.tooltip = String(
        format: NSLocalizedString("Cursor is in front of \"%@\".", comment: ""),
        tooltipParameterRef[0]
      )
    } else {
      stateResult.tooltip = String(
        format: NSLocalizedString("Cursor is between \"%@\" and \"%@\".", comment: ""),
        tooltipParameterRef[0], tooltipParameterRef[1]
      )
    }

    if !stateResult.tooltip.isEmpty {
      ctlInputMethod.tooltipController.setColor(state: .denialOverflow)
    }

    return stateResult
  }

  // MARK: - 用以生成候選詞陣列及狀態

  func buildCandidate(
    state currentState: InputState.NotEmpty,
    isTypingVertical: Bool = false
  ) -> InputState.ChoosingCandidate {
    InputState.ChoosingCandidate(
      composingBuffer: currentState.composingBuffer,
      cursorIndex: currentState.cursorIndex,
      candidates: candidatesArray,
      isTypingVertical: isTypingVertical
    )
  }

  // MARK: - 用以接收聯想詞陣列且生成狀態

  // 這次重寫時，針對「buildAssociatePhraseStateWithKey」這個（用以生成帶有
  // 聯想詞候選清單的結果的狀態回呼的）函數進行了小幅度的重構處理，使其始終
  // 可以從 Core 部分的「buildAssociatePhraseArray」函數獲取到一個內容類型
  // 為「String」的標準 Swift 陣列。這樣一來，該聯想詞狀態回呼函數將始終能
  // 夠傳回正確的結果形態、永遠也無法傳回 nil。於是，所有在用到該函數時以
  // 回傳結果類型判斷作為合法性判斷依據的函數，全都將依據改為檢查傳回的陣列
  // 是否為空：如果陣列為空的話，直接回呼一個空狀態。
  func buildAssociatePhraseState(
    withKey key: String!,
    isTypingVertical: Bool
  ) -> InputState.AssociatedPhrases! {
    // 上一行必須要用驚嘆號，否則 Xcode 會誤導你砍掉某些實際上必需的語句。
    InputState.AssociatedPhrases(
      candidates: buildAssociatePhraseArray(withKey: key), isTypingVertical: isTypingVertical
    )
  }

  // MARK: - 用以處理就地新增自訂語彙時的行為

  func handleMarkingState(
    _ state: InputState.Marking,
    input: InputSignal,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    if input.isESC {
      stateCallback(buildInputtingState)
      return true
    }

    // Enter
    if input.isEnter {
      if let keyHandlerDelegate = delegate {
        if !keyHandlerDelegate.keyHandler(self, didRequestWriteUserPhraseWith: state) {
          IME.prtDebugIntel("5B69CC8D")
          errorCallback()
          return true
        }
      }
      stateCallback(buildInputtingState)
      return true
    }

    // Shift + Left
    if input.isCursorBackward || input.emacsKey == vChewingEmacsKey.backward, input.isShiftHold {
      var index = state.markerIndex
      if index > 0 {
        index = state.composingBuffer.utf16PreviousPosition(for: index)
        let marking = InputState.Marking(
          composingBuffer: state.composingBuffer,
          cursorIndex: state.cursorIndex,
          markerIndex: index,
          readings: state.readings
        )
        marking.tooltipForInputting = state.tooltipForInputting
        stateCallback(marking.markedRange.isEmpty ? marking.convertedToInputting : marking)
      } else {
        IME.prtDebugIntel("1149908D")
        errorCallback()
        stateCallback(state)
      }
      return true
    }

    // Shift + Right
    if input.isCursorForward || input.emacsKey == vChewingEmacsKey.forward, input.isShiftHold {
      var index = state.markerIndex
      if index < (state.composingBuffer.utf16.count) {
        index = state.composingBuffer.utf16NextPosition(for: index)
        let marking = InputState.Marking(
          composingBuffer: state.composingBuffer,
          cursorIndex: state.cursorIndex,
          markerIndex: index,
          readings: state.readings
        )
        marking.tooltipForInputting = state.tooltipForInputting
        stateCallback(marking.markedRange.isEmpty ? marking.convertedToInputting : marking)
      } else {
        IME.prtDebugIntel("9B51408D")
        errorCallback()
        stateCallback(state)
      }
      return true
    }
    return false
  }

  // MARK: - 標點輸入處理

  func handlePunctuation(
    _ customPunctuation: String,
    state: InputState,
    usingVerticalTyping isTypingVertical: Bool,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    if !ifLangModelHasUnigrams(forKey: customPunctuation) {
      return false
    }

    if composer.isEmpty {
      insertToCompositorAtCursor(reading: customPunctuation)
      let poppedText = popOverflowComposingTextAndWalk
      let inputting = buildInputtingState
      inputting.poppedText = poppedText
      stateCallback(inputting)

      if mgrPrefs.useSCPCTypingMode, composer.isEmpty {
        let candidateState = buildCandidate(
          state: inputting,
          isTypingVertical: isTypingVertical
        )
        if candidateState.candidates.count == 1 {
          clear()
          if let strPoppedText: String = candidateState.candidates.first {
            stateCallback(InputState.Committing(poppedText: strPoppedText) as InputState.Committing)
            stateCallback(InputState.Empty())
          } else {
            stateCallback(candidateState)
          }
        } else {
          stateCallback(candidateState)
        }
      }
      return true
    } else {
      // If there is still unfinished bpmf reading, ignore the punctuation
      IME.prtDebugIntel("A9B69908D")
      errorCallback()
      stateCallback(state)
      return true
    }
  }

  // MARK: - Enter 鍵處理

  func handleEnter(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback _: @escaping () -> Void
  ) -> Bool {
    guard let currentState = state as? InputState.Inputting else { return false }

    clear()
    stateCallback(InputState.Committing(poppedText: currentState.composingBuffer))
    stateCallback(InputState.Empty())
    return true
  }

  // MARK: - CMD+Enter 鍵處理（注音文）

  func handleCtrlCommandEnter(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback _: @escaping () -> Void
  ) -> Bool {
    guard state is InputState.Inputting else { return false }

    var composingBuffer = currentReadings.joined(separator: "-")
    if mgrPrefs.inlineDumpPinyinInLieuOfZhuyin {
      composingBuffer = restoreToneOneInZhuyinKey(target: composingBuffer)  // 恢復陰平標記
      composingBuffer = Tekkon.cnvPhonaToHanyuPinyin(target: composingBuffer)  // 注音轉拼音
    }

    if !IME.areWeUsingOurOwnPhraseEditor {
      composingBuffer = composingBuffer.replacingOccurrences(of: "-", with: " ")
    }

    clear()

    stateCallback(InputState.Committing(poppedText: composingBuffer))
    stateCallback(InputState.Empty())
    return true
  }

  // MARK: - CMD+Alt+Enter 鍵處理（網頁 Ruby 注音文標記）

  func handleCtrlOptionCommandEnter(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback _: @escaping () -> Void
  ) -> Bool {
    guard state is InputState.Inputting else { return false }

    var composed = ""

    for theAnchor in walkedAnchors {
      if let node = theAnchor.node {
        var key = node.currentKeyValue.key
        if mgrPrefs.inlineDumpPinyinInLieuOfZhuyin {
          key = restoreToneOneInZhuyinKey(target: key)  // 恢復陰平標記
          key = Tekkon.cnvPhonaToHanyuPinyin(target: key)  // 注音轉拼音
          key = Tekkon.cnvHanyuPinyinToTextbookStyle(target: key)  // 轉教科書式標調
          key = key.replacingOccurrences(of: "-", with: " ")
        } else {
          key = cnvZhuyinKeyToTextbookReading(target: key, newSeparator: " ")
        }

        let value = node.currentKeyValue.value
        if key.contains("_") {  // 不要給標點符號等特殊元素加注音
          composed += value
        } else {
          composed += "<ruby>\(value)<rp>(</rp><rt>\(key)</rt><rp>)</rp></ruby>"
        }
      }
    }

    clear()

    stateCallback(InputState.Committing(poppedText: composed))
    stateCallback(InputState.Empty())
    return true
  }

  // MARK: - 處理 Backspace (macOS Delete) 按鍵行為

  func handleBackspace(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard state is InputState.Inputting else { return false }

    if composer.hasToneMarker(withNothingElse: true) {
      composer.clear()
    } else if composer.isEmpty {
      if compositorCursorIndex >= 0 {
        deleteBuilderReadingInFrontOfCursor()
        walk()
      } else {
        IME.prtDebugIntel("9D69908D")
        errorCallback()
        stateCallback(state)
        return true
      }
    } else {
      composer.doBackSpace()
    }

    if composer.isEmpty, compositorLength == 0 {
      stateCallback(InputState.EmptyIgnoringPreviousState())
    } else {
      stateCallback(buildInputtingState)
    }
    return true
  }

  // MARK: - 處理 PC Delete (macOS Fn+BackSpace) 按鍵行為

  func handleDelete(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard state is InputState.Inputting else { return false }

    if composer.isEmpty {
      if compositorCursorIndex != compositorLength {
        deleteBuilderReadingToTheFrontOfCursor()
        walk()
        let inputting = buildInputtingState
        // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
        if inputting.composingBuffer.isEmpty {
          stateCallback(InputState.EmptyIgnoringPreviousState())
        } else {
          stateCallback(inputting)
        }
      } else {
        IME.prtDebugIntel("9B69938D")
        errorCallback()
        stateCallback(state)
      }
    } else {
      IME.prtDebugIntel("9C69908D")
      errorCallback()
      stateCallback(state)
    }

    return true
  }

  // MARK: - 處理與當前文字輸入排版前後方向呈 90 度的那兩個方向鍵的按鍵行為

  func handleAbsorbedArrowKey(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard state is InputState.Inputting else { return false }
    if !composer.isEmpty {
      IME.prtDebugIntel("9B6F908D")
      errorCallback()
    }
    stateCallback(state)
    return true
  }

  // MARK: - 處理 Home 鍵行為

  func handleHome(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard state is InputState.Inputting else { return false }

    if !composer.isEmpty {
      IME.prtDebugIntel("ABC44080")
      errorCallback()
      stateCallback(state)
      return true
    }

    if compositorCursorIndex != 0 {
      compositorCursorIndex = 0
      stateCallback(buildInputtingState)
    } else {
      IME.prtDebugIntel("66D97F90")
      errorCallback()
      stateCallback(state)
    }

    return true
  }

  // MARK: - 處理 End 鍵行為

  func handleEnd(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard state is InputState.Inputting else { return false }

    if !composer.isEmpty {
      IME.prtDebugIntel("9B69908D")
      errorCallback()
      stateCallback(state)
      return true
    }

    if compositorCursorIndex != compositorLength {
      compositorCursorIndex = compositorLength
      stateCallback(buildInputtingState)
    } else {
      IME.prtDebugIntel("9B69908E")
      errorCallback()
      stateCallback(state)
    }

    return true
  }

  // MARK: - 處理 Esc 鍵行為

  func handleEsc(
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback _: @escaping () -> Void
  ) -> Bool {
    guard state is InputState.Inputting else { return false }

    let escToClearInputBufferEnabled: Bool = mgrPrefs.escToCleanInputBuffer

    if escToClearInputBufferEnabled {
      // If the option is enabled, we clear everything in the buffer.
      // This includes walked nodes and the reading. Note that this convention
      // is by default in macOS 10.0-10.5 built-in Panasonic Hanin and later macOS Zhuyin.
      // Some Windows users hate this design, hence the option here to disable it.
      clear()
      stateCallback(InputState.EmptyIgnoringPreviousState())
    } else {
      // If reading is not empty, we cancel the reading.
      if !composer.isEmpty {
        composer.clear()
        if compositorLength == 0 {
          stateCallback(InputState.EmptyIgnoringPreviousState())
        } else {
          stateCallback(buildInputtingState)
        }
      }
    }
    return true
  }

  // MARK: - 處理向前方向鍵的行為

  func handleForward(
    state: InputState,
    input: InputSignal,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard let currentState = state as? InputState.Inputting else { return false }

    if !composer.isEmpty {
      IME.prtDebugIntel("B3BA5257")
      errorCallback()
      stateCallback(state)
      return true
    }

    if input.isShiftHold {
      // Shift + Right
      if currentState.cursorIndex < currentState.composingBuffer.utf16.count {
        let nextPosition = currentState.composingBuffer.utf16NextPosition(
          for: currentState.cursorIndex)
        let marking: InputState.Marking! = InputState.Marking(
          composingBuffer: currentState.composingBuffer,
          cursorIndex: currentState.cursorIndex,
          markerIndex: nextPosition,
          readings: currentReadings
        )
        marking.tooltipForInputting = currentState.tooltip
        stateCallback(marking)
      } else {
        IME.prtDebugIntel("BB7F6DB9")
        errorCallback()
        stateCallback(state)
      }
    } else {
      if compositorCursorIndex < compositorLength {
        compositorCursorIndex += 1
        stateCallback(buildInputtingState)
      } else {
        IME.prtDebugIntel("A96AAD58")
        errorCallback()
        stateCallback(state)
      }
    }

    return true
  }

  // MARK: - 處理向後方向鍵的行為

  func handleBackward(
    state: InputState,
    input: InputSignal,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard let currentState = state as? InputState.Inputting else { return false }

    if !composer.isEmpty {
      IME.prtDebugIntel("6ED95318")
      errorCallback()
      stateCallback(state)
      return true
    }

    if input.isShiftHold {
      // Shift + left
      if currentState.cursorIndex > 0 {
        let previousPosition = currentState.composingBuffer.utf16PreviousPosition(
          for: currentState.cursorIndex)
        let marking: InputState.Marking! = InputState.Marking(
          composingBuffer: currentState.composingBuffer,
          cursorIndex: currentState.cursorIndex,
          markerIndex: previousPosition,
          readings: currentReadings
        )
        marking.tooltipForInputting = currentState.tooltip
        stateCallback(marking)
      } else {
        IME.prtDebugIntel("D326DEA3")
        errorCallback()
        stateCallback(state)
      }
    } else {
      if compositorCursorIndex > 0 {
        compositorCursorIndex -= 1
        stateCallback(buildInputtingState)
      } else {
        IME.prtDebugIntel("7045E6F3")
        errorCallback()
        stateCallback(state)
      }
    }

    return true
  }

  // MARK: - 處理上下文候選字詞輪替（Tab 按鍵，或者 Shift+Space）

  func handleInlineCandidateRotation(
    state: InputState,
    reverseModifier: Bool,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard let state = state as? InputState.Inputting else {
      guard state is InputState.Empty else {
        IME.prtDebugIntel("6044F081")
        errorCallback()
        return true
      }
      // 不妨礙使用者平時輸入 Tab 的需求。
      return false
    }

    guard composer.isEmpty else {
      IME.prtDebugIntel("A2DAF7BC")
      errorCallback()
      return true
    }

    // 此處僅借用該函數生成結果內的某個物件，不用糾結「是否縱排輸入」。
    let candidates = buildCandidate(state: state).candidates
    guard !candidates.isEmpty else {
      IME.prtDebugIntel("3378A6DF")
      errorCallback()
      return true
    }

    var length = 0
    var currentAnchor = Megrez.NodeAnchor()
    let cursorIndex = min(
      actualCandidateCursorIndex + (mgrPrefs.useRearCursorMode ? 1 : 0), compositorLength
    )
    for anchor in walkedAnchors {
      length += anchor.spanningLength
      if length >= cursorIndex {
        currentAnchor = anchor
        break
      }
    }

    guard let currentNode = currentAnchor.node else {
      IME.prtDebugIntel("4F2DEC2F")
      errorCallback()
      return true
    }

    let currentValue = currentNode.currentKeyValue.value

    var currentIndex = 0
    if currentNode.score < currentNode.kSelectedCandidateScore {
      // Once the user never select a candidate for the node,
      // we start from the first candidate, so the user has a
      // chance to use the unigram with two or more characters
      // when type the tab key for the first time.
      //
      // In other words, if a user type two BPMF readings,
      // but the score of seeing them as two unigrams is higher
      // than a phrase with two characters, the user can just
      // use the longer phrase by tapping the tab key.
      if candidates[0] == currentValue {
        // If the first candidate is the value of the
        // current node, we use next one.
        if reverseModifier {
          currentIndex = candidates.count - 1
        } else {
          currentIndex = 1
        }
      }
    } else {
      for candidate in candidates {
        if candidate == currentValue {
          if reverseModifier {
            if currentIndex == 0 {
              currentIndex = candidates.count - 1
            } else {
              currentIndex -= 1
            }
          } else {
            currentIndex += 1
          }
          break
        }
        currentIndex += 1
      }
    }

    if currentIndex >= candidates.count {
      currentIndex = 0
    }

    fixNode(value: candidates[currentIndex], respectCursorPushing: false)

    stateCallback(buildInputtingState)
    return true
  }
}
