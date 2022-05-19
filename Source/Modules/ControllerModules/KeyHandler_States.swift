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

  func buildInputtingState() -> InputState.Inputting {
    // "Updating the composing buffer" means to request the client
    // to "refresh" the text input buffer with our "composing text"
    var composingBuffer = ""
    var composedStringCursorIndex = 0

    var readingCursorIndex = 0
    let builderCursorIndex = getBuilderCursorIndex()

    for theAnchor in _walkedNodes {
      guard let node = theAnchor.node else {
        continue
      }

      let valueString = node.currentKeyValue.value
      composingBuffer += valueString
      let codepointCount = valueString.count

      let spanningLength = theAnchor.spanningLength
      if readingCursorIndex + spanningLength <= builderCursorIndex {
        composedStringCursorIndex += valueString.count
        readingCursorIndex += spanningLength
      } else {
        if codepointCount == spanningLength {
          for _ in 0..<codepointCount {
            if readingCursorIndex < builderCursorIndex {
              composedStringCursorIndex += 1
              readingCursorIndex += 1
            }
          }
        } else {
          if readingCursorIndex < builderCursorIndex {
            composedStringCursorIndex += valueString.count
            readingCursorIndex += spanningLength
            if readingCursorIndex > builderCursorIndex {
              readingCursorIndex = builderCursorIndex
            }
          }
        }
      }
    }

    // Now, we gather all the intel, separate the composing buffer to two parts (head and tail),
    // and insert the reading text (the Mandarin syllable) in between them.
    // The reading text is what the user is typing.

    var rawHead = ""
    var rawEnd = ""

    for (i, n) in composingBuffer.enumerated() {
      if i < composedStringCursorIndex {
        rawHead += String(n)
      } else {
        rawEnd += String(n)
      }
    }

    let head = rawHead
    let reading = _composer.getInlineCompositionForIMK(isHanyuPinyin: mgrPrefs.showHanyuPinyinInCompositionBuffer)
    let tail = rawEnd
    let composedText = head + reading + tail
    let cursorIndex = composedStringCursorIndex + reading.count

    return InputState.Inputting(composingBuffer: composedText, cursorIndex: UInt(cursorIndex))
  }

  // MARK: - 用以生成候選詞陣列及狀態

  func buildCandidate(
    state currentState: InputState.NotEmpty,
    useVerticalMode: Bool
  ) -> InputState.ChoosingCandidate {
    InputState.ChoosingCandidate(
      composingBuffer: currentState.composingBuffer,
      cursorIndex: currentState.cursorIndex,
      candidates: getCandidatesArray(),
      useVerticalMode: useVerticalMode
    )
  }

  // MARK: - 用以接收聯想詞陣列且生成狀態

  // 這次重寫時，針對「buildAssociatePhraseStateWithKey」這個（用以生成帶有
  // 聯想詞候選清單的結果的狀態回呼的）函數進行了小幅度的重構處理，使其始終
  // 可以從 ObjC 部分的「buildAssociatePhraseArray」函數獲取到一個內容類型
  // 為「String」的標準 Swift 陣列。這樣一來，該聯想詞狀態回呼函數將始終能
  // 夠傳回正確的結果形態、永遠也無法傳回 nil。於是，所有在用到該函數時以
  // 回傳結果類型判斷作為合法性判斷依據的函數，全都將依據改為檢查傳回的陣列
  // 是否為空：如果陣列為空的話，直接回呼一個空狀態。
  func buildAssociatePhraseState(
    withKey key: String!,
    useVerticalMode: Bool
  ) -> InputState.AssociatedPhrases! {
    // 上一行必須要用驚嘆號，否則 Xcode 會誤導你砍掉某些實際上必需的語句。
    InputState.AssociatedPhrases(
      candidates: buildAssociatePhraseArray(withKey: key), useVerticalMode: useVerticalMode
    )
  }

  // MARK: - 用以處理就地新增自訂語彙時的行為

  func handleMarkingState(
    _ state: InputState.Marking,
    input: InputHandler,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    if input.isESC {
      stateCallback(buildInputtingState())
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
      stateCallback(buildInputtingState())
      return true
    }

    // Shift + Left
    if input.isCursorBackward || input.emacsKey == vChewingEmacsKey.backward, input.isShiftHold {
      var index = state.markerIndex
      if index > 0 {
        index = UInt((state.composingBuffer as NSString).previousUtf16Position(for: Int(index)))
        let marking = InputState.Marking(
          composingBuffer: state.composingBuffer,
          cursorIndex: state.cursorIndex,
          markerIndex: index,
          readings: state.readings
        )
        marking.tooltipForInputting = state.tooltipForInputting
        stateCallback(marking.markedRange.length == 0 ? marking.convertToInputting() : marking)
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
      // 這裡繼續用 NSString 是為了與 Zonble 之前引入的 NSStringUtils 相容。
      // 不然的話，這行判斷會失敗、引發「9B51408D」錯誤。
      if index < ((state.composingBuffer as NSString).length) {
        index = UInt((state.composingBuffer as NSString).nextUtf16Position(for: Int(index)))
        let marking = InputState.Marking(
          composingBuffer: state.composingBuffer,
          cursorIndex: state.cursorIndex,
          markerIndex: index,
          readings: state.readings
        )
        marking.tooltipForInputting = state.tooltipForInputting
        stateCallback(marking.markedRange.length == 0 ? marking.convertToInputting() : marking)
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
    usingVerticalMode useVerticalMode: Bool,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    if !ifLangModelHasUnigrams(forKey: customPunctuation) {
      return false
    }

    if _composer.isEmpty {
      insertReadingToBuilderAtCursor(reading: customPunctuation)
      let poppedText = popOverflowComposingTextAndWalk()
      let inputting = buildInputtingState()
      inputting.poppedText = poppedText
      stateCallback(inputting)

      if mgrPrefs.useSCPCTypingMode, _composer.isEmpty {
        let candidateState = buildCandidate(
          state: inputting,
          useVerticalMode: useVerticalMode
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

    var composingBuffer = currentReadings().joined(separator: "-")
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

    for theAnchor in _walkedNodes {
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

    if _composer.hasToneMarker(withNothingElse: true) {
      _composer.clear()
    } else if _composer.isEmpty {
      if getBuilderCursorIndex() >= 0 {
        deleteBuilderReadingInFrontOfCursor()
        walk()
      } else {
        IME.prtDebugIntel("9D69908D")
        errorCallback()
        stateCallback(state)
        return true
      }
    } else {
      _composer.doBackSpace()
    }

    if _composer.isEmpty, getBuilderLength() == 0 {
      stateCallback(InputState.EmptyIgnoringPreviousState())
    } else {
      stateCallback(buildInputtingState())
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

    if _composer.isEmpty {
      if getBuilderCursorIndex() != getBuilderLength() {
        deleteBuilderReadingToTheFrontOfCursor()
        walk()
        let inputting = buildInputtingState()
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
    if !_composer.isEmpty {
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

    if !_composer.isEmpty {
      IME.prtDebugIntel("ABC44080")
      errorCallback()
      stateCallback(state)
      return true
    }

    if getBuilderCursorIndex() != 0 {
      setBuilderCursorIndex(value: 0)
      stateCallback(buildInputtingState())
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

    if !_composer.isEmpty {
      IME.prtDebugIntel("9B69908D")
      errorCallback()
      stateCallback(state)
      return true
    }

    if getBuilderCursorIndex() != getBuilderLength() {
      setBuilderCursorIndex(value: getBuilderLength())
      stateCallback(buildInputtingState())
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
      if !_composer.isEmpty {
        _composer.clear()
        if getBuilderLength() == 0 {
          stateCallback(InputState.EmptyIgnoringPreviousState())
        } else {
          stateCallback(buildInputtingState())
        }
      }
    }
    return true
  }

  // MARK: - 處理向前方向鍵的行為

  func handleForward(
    state: InputState,
    input: InputHandler,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard let currentState = state as? InputState.Inputting else { return false }

    if !_composer.isEmpty {
      IME.prtDebugIntel("B3BA5257")
      errorCallback()
      stateCallback(state)
      return true
    }

    if input.isShiftHold {
      // Shift + Right
      if currentState.cursorIndex < (currentState.composingBuffer as NSString).length {
        let nextPosition = (currentState.composingBuffer as NSString).nextUtf16Position(
          for: Int(currentState.cursorIndex))
        let marking: InputState.Marking! = InputState.Marking(
          composingBuffer: currentState.composingBuffer,
          cursorIndex: currentState.cursorIndex,
          markerIndex: UInt(nextPosition),
          readings: currentReadings()
        )
        marking.tooltipForInputting = currentState.tooltip
        stateCallback(marking)
      } else {
        IME.prtDebugIntel("BB7F6DB9")
        errorCallback()
        stateCallback(state)
      }
    } else {
      if getBuilderCursorIndex() < getBuilderLength() {
        setBuilderCursorIndex(value: getBuilderCursorIndex() + 1)
        stateCallback(buildInputtingState())
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
    input: InputHandler,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    guard let currentState = state as? InputState.Inputting else { return false }

    if !_composer.isEmpty {
      IME.prtDebugIntel("6ED95318")
      errorCallback()
      stateCallback(state)
      return true
    }

    if input.isShiftHold {
      // Shift + left
      if currentState.cursorIndex > 0 {
        let previousPosition = (currentState.composingBuffer as NSString).previousUtf16Position(
          for: Int(currentState.cursorIndex))
        let marking: InputState.Marking! = InputState.Marking(
          composingBuffer: currentState.composingBuffer,
          cursorIndex: currentState.cursorIndex,
          markerIndex: UInt(previousPosition),
          readings: currentReadings()
        )
        marking.tooltipForInputting = currentState.tooltip
        stateCallback(marking)
      } else {
        IME.prtDebugIntel("D326DEA3")
        errorCallback()
        stateCallback(state)
      }
    } else {
      if getBuilderCursorIndex() > 0 {
        setBuilderCursorIndex(value: getBuilderCursorIndex() - 1)
        stateCallback(buildInputtingState())
      } else {
        IME.prtDebugIntel("7045E6F3")
        errorCallback()
        stateCallback(state)
      }
    }

    return true
  }
}
