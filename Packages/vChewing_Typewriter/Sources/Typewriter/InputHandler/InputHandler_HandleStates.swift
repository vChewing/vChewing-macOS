// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃輸入調度模組的用以承載「根據按鍵行為來調控模式」的各種成員函式的部分。

import Foundation

// MARK: - § 根據按鍵行為來調控模式的函式 (Functions Interact With States).

extension InputHandlerProtocol {
  // MARK: - 構築狀態（State Building）

  /// 生成「正在輸入」狀態。相關的內容會被拿給狀態機械用來處理在電腦螢幕上顯示的內容。
  /// - Parameters:
  ///   - sansReading: 不顯示組音區/組筆區。
  ///   - guarded: 是否在該狀態的顯示文字為空的時候顯示替補空格，否則 InputMethodKit 無法正常攔截方向鍵事件。
  /// - Returns: 生成的「正在輸入」狀態。
  public func generateStateOfInputting(
    sansReading: Bool = false,
    guarded: Bool = false
  )
    -> State {
    if isConsideredEmptyForNow, !guarded { return State.ofAbortion() }
    restoreBackupCursor() // 只要叫了 Inputting 狀態，就盡可能還原游標備份。
    var segHighlightedAt: Int?
    let handleAsCodePointInput = currentTypingMethod == .codePoint && !sansReading
    let handleAsRomanNumeralInput = currentTypingMethod == .romanNumerals && !sansReading
    /// 「更新內文組字區 (Update the composing buffer)」是指要求客體軟體將組字緩衝區的內容
    /// 換成由此處重新生成的原始資料在 IMEStateData 當中生成的 NSAttributeString。
    var displayTextSegments: [String] = handleAsCodePointInput || handleAsRomanNumeralInput
      ? [strCodePointBuffer]
      : assembler.assembledSentence.values
    var cursor = handleAsCodePointInput || handleAsRomanNumeralInput
      ? displayTextSegments.joined().count
      : convertCursorForDisplay(assembler.cursor)
    let cursorSansReading = cursor
    // 先提出來讀音資料，減輕運算負擔。
    let noReading = sansReading || [.codePoint, .romanNumerals].contains(currentTypingMethod)
    let reading: String = noReading ? "" : readingForDisplay
    if !reading.isEmpty {
      var newDisplayTextSegments = [String]()
      var temporaryNode = ""
      var charCounter = 0
      for node in displayTextSegments {
        for char in node {
          if charCounter == cursor {
            newDisplayTextSegments.append(temporaryNode)
            temporaryNode = ""
            // 處理在組字區中間或者最後方插入游標的情形。
            segHighlightedAt = newDisplayTextSegments.count
            newDisplayTextSegments.append(reading)
          }
          temporaryNode += String(char)
          charCounter += 1
        }
        newDisplayTextSegments.append(temporaryNode)
        temporaryNode = ""
      }
      if newDisplayTextSegments == displayTextSegments {
        // 處理在組字區最前方插入游標的情形。
        segHighlightedAt = newDisplayTextSegments.count
        newDisplayTextSegments.append(reading)
      }
      displayTextSegments = newDisplayTextSegments
      cursor += reading.count
    }
    for i in 0 ..< displayTextSegments.count {
      displayTextSegments[i] = displayTextSegments[i].trimmingCharacters(in: .newlines)
    }
    /// 這裡生成準備要拿來回呼的「正在輸入」狀態。
    var result = State.ofInputting(
      displayTextSegments: displayTextSegments,
      cursor: cursor, highlightAt: segHighlightedAt
    )
    result.marker = cursorSansReading
    /// 特殊情形，否則方向鍵事件無法正常攔截。
    if guarded, result.displayTextSegments.joined().isEmpty {
      result.data.displayTextSegments = [" "]
      result.cursor = 0
      result.marker = 0
    }
    return result
  }

  /// 生成「在有單獨的前置聲調符號輸入時」的工具提示。
  var tooltipForStandaloneIntonationMark: String {
    guard !isComposerUsingPinyin else { return "" }
    guard composer.hasIntonation(withNothingElse: true) else { return "" }
    guard composer.intonation.value != " " else { return "" }
    var result = ContiguousArray<String>()
    result
      .append(
        "Intonation mark. ENTER to commit.\nSPACE to insert into composition buffer."
          .i18n
      )
    if prefs.acceptLeadingIntonations {
      result.append("\n")
      result.append("It will attempt to combine with the incoming phonabet input.".i18n)
    }
    return result.joined()
  }

  /// 將組字器內的游標位置資料轉換成可以正確顯示的游標位置資料。
  /// - Parameter rawCursor: 原始游標。
  /// - Returns: 用以顯示的游標。
  func convertCursorForDisplay(_ rawCursor: Int) -> Int {
    var composedStringCursorIndex = 0
    var readingCursorIndex = 0
    for theNode in assembler.assembledSentence {
      let strNodeValue = theNode.value
      /// 藉下述步驟重新將「可見游標位置」對齊至「組字器內的游標所在的讀音位置」。
      /// 每個節錨（NodeAnchor）都有自身的幅節長度（segLength），可以用來
      /// 累加、以此為依據，來校正「可見游標位置」。
      let segLength: Int = theNode.keyArray.count
      if readingCursorIndex + segLength <= rawCursor {
        composedStringCursorIndex += strNodeValue.count
        readingCursorIndex += segLength
        continue
      }
      if !theNode.isReadingMismatched {
        strNodeValue.forEach { _ in
          if readingCursorIndex < rawCursor {
            composedStringCursorIndex += 1
            readingCursorIndex += 1
          }
        }
        continue
      }
      guard readingCursorIndex < rawCursor else { continue }
      composedStringCursorIndex += strNodeValue.count
      readingCursorIndex += segLength
      readingCursorIndex = min(readingCursorIndex, rawCursor)
    }
    return composedStringCursorIndex
  }

  // MARK: - 用以生成候選詞陣列及狀態

  /// 拿著給定的候選字詞陣列資料內容，切換至選字狀態。
  /// - Returns: 回呼一個新的選詞狀態，來就給定的候選字詞陣列資料內容顯示選字窗。
  public func generateStateOfCandidates(dodge: Bool = true) -> State {
    guard let session = session else { return State.ofAbortion() }
    let cursorPriorToCandidateSelection = assembler.cursor
    if dodge, session.state.type == .ofInputting {
      dodgeInvalidEdgeCursorForCandidateState()
    }
    if restoreCursorAfterSelectingCandidate, backupCursor == nil {
      backupCursor = cursorPriorToCandidateSelection
    }
    var result = State.ofCandidates(
      candidates: generateArrayOfCandidates(fixOrder: prefs.useFixedCandidateOrderOnSelection),
      displayTextSegments: assembler.assembledSentence.values,
      cursor: assembler.cursor
    )
    if !prefs.useRearCursorMode {
      let markerBackup = assembler.marker
      assembler.jumpCursorBySegment(to: .rear, isMarker: true)
      result.marker = assembler.marker
      assembler.marker = markerBackup
    }
    return result
  }

  // MARK: - 用以接收關聯詞語陣列且生成狀態

  /// 拿著給定的關聯詞語陣列資料內容，切換至關聯詞語狀態。
  ///
  /// 這次重寫時，針對「generateStateOfAssociates」這個（用以生成帶有
  /// 關聯詞語候選清單的結果的狀態回呼的）函式進行了小幅度的重構處理，使其始終
  /// 可以從 Core 部分的「generateArrayOfAssociates」函式獲取到一個內容類型
  /// 為「String」的標準 Swift 陣列。這樣一來，該關聯詞語狀態回呼函式將始終能
  /// 夠傳回正確的結果形態、永遠也無法傳回 nil。於是，所有在用到該函式時以
  /// 回傳結果類型判斷作為合法性判斷依據的函式，全都將依據改為檢查傳回的陣列
  /// 是否為空：如果陣列為空的話，直接回呼一個空狀態。
  ///
  /// 該函式僅用於 SessionCtl，因為 InputHandler 內部可以直接存取 generateArrayOfAssociates().
  /// - Parameters:
  ///   - key: 給定的索引鍵（也就是給定的關聯詞語的開頭字）。
  /// - Returns: 回呼一個新的關聯詞語狀態，來就給定的關聯詞語陣列資料內容顯示選字窗。
  public func generateStateOfAssociates(withPair pair: KeyValuePaired) -> State {
    State.ofAssociates(candidates: generateArrayOfAssociates(withPair: pair))
  }

  // MARK: - 用以處理就地新增自訂語彙時的行為

  /// 用以處理就地新增自訂語彙時的行為。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleMarkingState(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    let state = session.state

    if input.isEsc {
      session.switchState(generateStateOfInputting())
      return true
    }

    // 阻止用於行內注音輸出的熱鍵。
    if input.isControlHold, input.isCommandHold, input.isEnter {
      errorCallback?("1198E3E5")
      return true
    }

    // Enter
    if input.isEnter {
      var tooltipMessage = "+ Succeeded in adding / boosting a user phrase."
      var tooltipColorState: TooltipColorState = .normal
      // 先判斷是否是在摁了降權組合鍵的時候目標不在庫。
      if input.isShiftHold, input.isCommandHold {
        tooltipMessage = "- Succeeded in nerfing a user phrase."
        tooltipColorState = .succeeded
      }
      if !state.isMarkedLengthValid {
        errorCallback?("9AAFAC00")
        return true
      }
      let areWeUnfiltering = state.markedTargetIsCurrentlyFiltered
      if !session.performUserPhraseOperation(addToFilter: false) {
        errorCallback?("5B69CC8D")
        return true
      }
      if areWeUnfiltering {
        tooltipMessage = "- Succeeded in unfiltering a phrase."
        tooltipColorState = .succeeded
      }
      var newState = generateStateOfInputting()
      newState.tooltip = tooltipMessage.i18n
      newState.data.tooltipColorState = tooltipColorState
      newState.tooltipDuration = 1.85
      session.switchState(newState)
      return true
    }

    // BackSpace & Delete
    if input.isBackSpace || input.isDelete {
      let tooltipMessage = "! Succeeded in filtering a user phrase."
      guard let filterabilityChecker else {
        errorCallback?("FF333223")
        return true
      }
      let isMarkingFilterable = filterabilityChecker(state.data)
      if !isMarkingFilterable {
        errorCallback?("1F88B191")
        return true
      }
      if !session.performUserPhraseOperation(addToFilter: true) {
        errorCallback?("68D3C6C8")
        return true
      }
      var newState = generateStateOfInputting()
      newState.tooltip = tooltipMessage.i18n
      newState.data.tooltipColorState = .warning
      newState.tooltipDuration = 1.85
      session.switchState(newState)
      return true
    }

    // Shift + Left
    if input.isCursorBackward, input.isShiftHold {
      let moved: Bool = {
        if input.isCommandHold || input.isOptionHold {
          assembler.jumpCursorBySegment(to: .rear, isMarker: true)
        } else {
          assembler.moveCursorStepwise(to: .rear, isMarker: true)
        }
      }()
      guard moved else {
        errorCallback?("D326DEA3")
        return true
      }
      var marking = State.ofMarking(
        displayTextSegments: state.displayTextSegments,
        markedReadings: Array(assembler.keys[currentMarkedRange()]),
        cursor: convertCursorForDisplay(assembler.cursor),
        marker: convertCursorForDisplay(assembler.marker)
      )
      marking.tooltipBackupForInputting = state.tooltipBackupForInputting
      session.switchState(marking.markedRange.isEmpty ? marking.convertedToInputting : marking)
      return true
    }

    // Shift + Right
    if input.isCursorForward, input.isShiftHold {
      let moved: Bool = {
        if input.isCommandHold || input.isOptionHold {
          assembler.jumpCursorBySegment(to: .front, isMarker: true)
        } else {
          assembler.moveCursorStepwise(to: .front, isMarker: true)
        }
      }()
      guard moved else {
        errorCallback?("9B51408D")
        return true
      }
      var marking = State.ofMarking(
        displayTextSegments: state.displayTextSegments,
        markedReadings: Array(assembler.keys[currentMarkedRange()]),
        cursor: convertCursorForDisplay(assembler.cursor),
        marker: convertCursorForDisplay(assembler.marker)
      )
      marking.tooltipBackupForInputting = state.tooltipBackupForInputting
      session.switchState(marking.markedRange.isEmpty ? marking.convertedToInputting : marking)
      return true
    }
    return false
  }

  // MARK: - 標點輸入的處理

  /// 標點輸入的處理。
  /// - Parameters:
  ///   - customPunctuation: 自訂標點索引鍵頭。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handlePunctuation(_ customPunctuation: String) -> Bool {
    guard let session = session else { return false }

    if !currentLM.hasUnigramsFor(keyArray: [customPunctuation]) {
      return false
    }

    guard isComposerOrCalligrapherEmpty else {
      // 注音沒敲完的情況下，無視標點輸入。
      errorCallback?("A9B69908D")
      return true
    }

    guard assembler.insertKey(customPunctuation) else {
      errorCallback?("C0793A6D: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
      return true
    }

    assemble()
    // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
    let textToCommit = commitOverflownComposition
    var inputting = generateStateOfInputting()
    inputting.textToCommit = textToCommit
    session.switchState(inputting)

    // 從這一行之後開始，就是針對逐字選字模式的單獨處理。
    guard prefs.useSCPCTypingMode, isComposerOrCalligrapherEmpty else { return true }

    let candidateState = generateStateOfCandidates()
    switch candidateState.candidates.count {
    case 2...: session.switchState(candidateState)
    case 1:
      clear() // 這句不要砍，因為下文可能會回呼 candidateState。
      if let strToCommit = candidateState.candidates.first?.value, !strToCommit.isEmpty {
        session.switchState(State.ofCommitting(textToCommit: strToCommit))
      } else {
        session.switchState(candidateState)
      }
    default: errorCallback?("8DA4096E")
    }
    return true
  }

  // MARK: - Enter 鍵的處理，包括對其他修飾鍵的應對。

  /// Enter 鍵的處理。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  ///   - readingOnly: 是否僅遞交讀音。
  ///   - associatesData: 給定的關聯詞語資料陣列。
  ///   該部分僅對 .ofInputting() 狀態有效、且不能是漢音符號模式與內碼輸入模式。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  @discardableResult
  func handleEnter(
    input: InputSignalProtocol, readingOnly: Bool = false,
    associatesData: @escaping () -> ([CandidateInState]) = { [] }
  )
    -> Bool {
    guard let session = session else { return false }
    let state = session.state

    // Special handling for roman numerals mode with buffer content
    if currentTypingMethod == .romanNumerals, !strCodePointBuffer.isEmpty {
      return commitRomanNumeral(session: session)
    }

    guard currentTypingMethod == .vChewingFactory else {
      return revolveTypingMethod(to: .vChewingFactory)
    }

    guard state.type == .ofInputting else { return false }

    var displayedText = state.displayedText

    if input.commonKeyModifierFlags == [.option, .shift] {
      displayedText = displayedText.map(\.description).joined(separator: " ")
    } else if readingOnly {
      displayedText = commissionByCtrlCommandEnter()
    } else if input.isCommandHold, input.isControlHold {
      displayedText = input.isOptionHold
        ? commissionByCtrlOptionCommandEnter(isShiftPressed: input.isShiftHold)
        : commissionByCtrlCommandEnter(isShiftPressed: input.isShiftHold)
    }

    session.switchState(State.ofCommitting(textToCommit: displayedText))

    associatedPhrases: if !prefs.useSCPCTypingMode, prefs.associatedPhrasesEnabled {
      guard input.commonKeyModifierFlags == .shift else { break associatedPhrases }
      guard isComposerOrCalligrapherEmpty else { break associatedPhrases }
      let associatedCandidates = associatesData()
      guard !associatedCandidates.isEmpty else { break associatedPhrases }
      session.switchState(State.ofAssociates(candidates: associatedCandidates))
    }

    return true
  }

  // MARK: - 處理 BackSpace (macOS Delete) 按鍵行為

  /// 處理 BackSpace (macOS Delete) 按鍵行為。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleBackSpace(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    let state = session.state
    guard state.type == .ofInputting else {
      currentTypingMethod = .vChewingFactory
      return false
    }

    if currentTypingMethod == .codePoint {
      if !strCodePointBuffer.isEmpty {
        func refreshState() {
          var updatedState = generateStateOfInputting(guarded: true)
          updatedState.tooltipDuration = 0
          updatedState.tooltip = session.state.tooltip
          session.switchState(updatedState)
        }
        strCodePointBuffer = strCodePointBuffer.dropLast(1).description
        if input.commonKeyModifierFlags == .option {
          return revolveTypingMethod(to: .codePoint)
        }
        if !strCodePointBuffer.isEmpty {
          refreshState()
          return true
        }
      }
      return revolveTypingMethod(to: .vChewingFactory)
    }

    if currentTypingMethod == .romanNumerals {
      if !strCodePointBuffer.isEmpty {
        func refreshState() {
          var updatedState = generateStateOfInputting(guarded: true)
          updatedState.tooltipDuration = 0
          updatedState.tooltip = session.state.tooltip
          session.switchState(updatedState)
        }
        strCodePointBuffer = strCodePointBuffer.dropLast(1).description
        if input.commonKeyModifierFlags == .option {
          return revolveTypingMethod(to: .romanNumerals)
        }
        if !strCodePointBuffer.isEmpty {
          refreshState()
          return true
        }
      }
      return revolveTypingMethod(to: .vChewingFactory)
    }

    // 引入 macOS 內建注音輸入法的行為，允許用 Shift+BackSpace 解構前一個漢字的讀音。
    shiftBksp: if input.commonKeyModifierFlags == .shift {
      switch prefs.specifyShiftBackSpaceKeyBehavior {
      case 0:
        if prefs.cassetteEnabled {
          guard input.isShiftHold, calligrapher.isEmpty else { break shiftBksp }
          guard let prevReading = previousParsableCalligraph else { break shiftBksp }
          // 此處刻意使用 Assembler 的 API（assembler.dropKey）以避免呼叫
          // InputHandler 的 dropKey 中所包含的 KeyDropContext 回補邏輯。
          assembler.dropKey(direction: .rear)
          assemble() // 這裡必須 Walk 一次、來更新目前被 walk 的內容。
          calligrapher = prevReading
        } else {
          guard input.isShiftHold, isComposerOrCalligrapherEmpty else { break shiftBksp }
          guard let prevReading = previousParsableReading else { break shiftBksp }
          // prevReading 的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
          // 此處刻意使用 Assembler 的 API（assembler.dropKey）以避免呼叫
          // InputHandler 的 dropKey 中所包含的 KeyDropContext 回補邏輯。
          assembler.dropKey(direction: .rear)
          assemble() // 這裡必須 Walk 一次、來更新目前被 walk 的內容。
          prevReading.1.map(\.description).forEach {
            composer.receiveKey(fromPhonabet: $0.unicodeScalars.first)
          }
        }
        session.switchState(generateStateOfInputting())
        return true
      case 1:
        session.switchState(State.ofAbortion())
        return true
      default: break
      }
    }

    let steps = getStepsToNearbyNodeBorder(direction: .rear)
    var actualSteps = 1

    switch input.commonKeyModifierFlags {
    case .shift:
      session.switchState(State.ofAbortion())
      return true
    case .option:
      actualSteps = steps
    default: break
    }

    if isComposerOrCalligrapherEmpty {
      if assembler.cursor <= 0 || actualSteps <= 0 {
        errorCallback?("9D69908D")
        return true
      }
      var isConsolidated = false
      for _ in 0 ..< actualSteps {
        if !isConsolidated {
          dropKey(direction: .rear)
          isConsolidated = true
        } else {
          assembler.dropKey(direction: .rear)
        }
      }
      assemble()
    } else {
      _ = input.commonKeyModifierFlags == .option
        ? clearComposerAndCalligrapher()
        : letComposerAndCalligrapherDoBackSpace()
    }

    switch isConsideredEmptyForNow {
    case false:
      var result = generateStateOfInputting()
      if prefs.cassetteEnabled,
         let fetched = currentLM.cassetteQuickSetsFor(key: calligrapher)?.split(separator: "\t") {
        result.candidates = fetched.enumerated().map {
          (keyArray: [($0.offset + 1).description], value: $0.element.description)
        }
      }
      session.switchState(result)
    case true: session.switchState(State.ofAbortion())
    }
    return true
  }

  // MARK: - 處理 PC Delete (macOS Fn+BackSpace) 按鍵行為

  /// 處理 PC Delete (macOS Fn+BackSpace) 按鍵行為。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleDelete(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    let state = session.state

    guard currentTypingMethod == .vChewingFactory else {
      return revolveTypingMethod(to: .vChewingFactory)
    }

    guard state.type == .ofInputting else { return false }

    let steps = getStepsToNearbyNodeBorder(direction: .front)
    var actualSteps = 1

    // macOS 認為 PC Delete 鍵訊號是必然有 .function 這個修飾鍵在起作用的。
    // 總之處理起來非常機車就是了。
    switch input.commonKeyModifierFlags {
    case .shift:
      session.switchState(State.ofAbortion())
      return true
    case .option:
      actualSteps = steps
    default: break
    }

    if isComposerOrCalligrapherEmpty {
      if assembler.cursor >= assembler.length || actualSteps <= 0 {
        errorCallback?("9B69938D")
        return true
      }
      var isConsolidated = false
      for _ in 0 ..< actualSteps {
        if !isConsolidated {
          dropKey(direction: .front)
          isConsolidated = true
        } else {
          assembler.dropKey(direction: .front)
        }
      }
      assemble()
    } else {
      clearComposerAndCalligrapher()
    }

    let inputting = generateStateOfInputting()
    // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
    switch inputting.displayedText.isEmpty {
    case false: session.switchState(inputting)
    case true: session.switchState(State.ofAbortion())
    }
    return true
  }

  // MARK: - 處理與當前文字輸入排版前後方向呈 90 度的那兩個方向鍵的按鍵行為

  /// 處理與當前文字輸入排版前後方向呈 90 度的那兩個方向鍵的按鍵行為。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleClockKey() -> Bool {
    guard let session = session else { return false }
    let state = session.state
    guard state.type == .ofInputting else { return false }
    if !isComposerOrCalligrapherEmpty { errorCallback?("9B6F908D") }
    return true
  }

  // MARK: - 處理 Home 鍵的行為

  /// 處理 Home 鍵的行為。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleHome() -> Bool {
    guard let session = session else { return false }
    let state = session.state
    guard state.type == .ofInputting else { return false }

    if !isComposerOrCalligrapherEmpty {
      errorCallback?("ABC44080")
      return true
    }

    if assembler.cursor != 0 {
      assembler.cursor = 0
      session.switchState(generateStateOfInputting())
    } else {
      errorCallback?("66D97F90")
    }

    return true
  }

  // MARK: - 處理 End 鍵的行為

  /// 處理 End 鍵的行為。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleEnd() -> Bool {
    guard let session = session else { return false }
    let state = session.state
    guard state.type == .ofInputting else { return false }

    if !isComposerOrCalligrapherEmpty {
      errorCallback?("9B69908D")
      return true
    }

    if assembler.cursor != assembler.length {
      assembler.cursor = assembler.length
      session.switchState(generateStateOfInputting())
    } else {
      errorCallback?("9B69908E")
    }

    return true
  }

  // MARK: - 處理 Esc 鍵的行為

  /// 處理 Esc 鍵的行為。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleEsc() -> Bool {
    guard let session = session else { return false }
    let state = session.state

    guard currentTypingMethod == .vChewingFactory else {
      return revolveTypingMethod(to: .vChewingFactory)
    }

    guard state.type == .ofInputting else { return false }

    if prefs.escToCleanInputBuffer {
      /// 若啟用了該選項，則清空組字器的內容與注拼槽的內容。
      /// 此乃 macOS 內建注音輸入法預設之行為，但不太受 Windows 使用者群體之待見。
      session.switchState(State.ofAbortion())
    } else {
      if isComposerOrCalligrapherEmpty {
        let commitText = generateStateOfInputting(sansReading: true).displayedText
        session.switchState(State.ofCommitting(textToCommit: commitText))
        return true
      }
      /// 如果注拼槽或組筆區不是空的話，則清空之。
      clearComposerAndCalligrapher()
      switch assembler.isEmpty {
      case false: session.switchState(generateStateOfInputting())
      case true: session.switchState(State.ofAbortion())
      }
    }
    return true
  }

  // MARK: - 處理向前方向鍵的行為

  /// 處理向前方向鍵的行為。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleForward(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    let state = session.state
    guard state.type == .ofInputting else { return false }

    if !isComposerOrCalligrapherEmpty {
      errorCallback?("B3BA5257")
      return true
    }

    if input.isShiftHold {
      // Shift + Right
      if assembler.cursor < assembler.length {
        assembler.marker = assembler.cursor
        if input.isCommandHold || input.isOptionHold {
          assembler.jumpCursorBySegment(to: .front, isMarker: true)
        } else {
          assembler.marker += 1
          if isCursorCuttingChar(isMarker: true) {
            assembler.jumpCursorBySegment(to: .front, isMarker: true)
          }
        }
        var marking = State.ofMarking(
          displayTextSegments: assembler.assembledSentence.values,
          markedReadings: Array(assembler.keys[currentMarkedRange()]),
          cursor: convertCursorForDisplay(assembler.cursor),
          marker: convertCursorForDisplay(assembler.marker)
        )
        marking.tooltipBackupForInputting = state.tooltip
        session.switchState(marking)
      } else {
        errorCallback?("BB7F6DB9")
      }
    } else if input.isOptionHold, !input.isShiftHold {
      if input.isControlHold {
        return handleEnd()
      }
      // 游標跳轉動作無論怎樣都會執行，但如果出了執行失敗的結果的話則觸發報錯流程。
      if !assembler.jumpCursorBySegment(to: .front) {
        errorCallback?("33C3B580")
        return true
      }
      session.switchState(generateStateOfInputting())
    } else {
      if assembler.moveCursorStepwise(to: .front) {
        session.switchState(generateStateOfInputting())
      } else {
        errorCallback?("A96AAD58")
      }
    }

    return true
  }

  // MARK: - 處理向後方向鍵的行為

  /// 處理向後方向鍵的行為。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleBackward(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    let state = session.state
    guard state.type == .ofInputting else { return false }

    if !isComposerOrCalligrapherEmpty {
      errorCallback?("6ED95318")
      return true
    }

    if input.isShiftHold {
      // Shift + left
      if assembler.cursor > 0 {
        assembler.marker = assembler.cursor
        let moved: Bool = {
          if input.isCommandHold || input.isOptionHold {
            assembler.jumpCursorBySegment(to: .rear, isMarker: true)
          } else {
            assembler.moveCursorStepwise(to: .rear, isMarker: true)
          }
        }()
        guard moved else {
          errorCallback?("D326DEA3")
          return true
        }
        var marking = State.ofMarking(
          displayTextSegments: assembler.assembledSentence.values,
          markedReadings: Array(assembler.keys[currentMarkedRange()]),
          cursor: convertCursorForDisplay(assembler.cursor),
          marker: convertCursorForDisplay(assembler.marker)
        )
        marking.tooltipBackupForInputting = state.tooltip
        session.switchState(marking)
      } else {
        errorCallback?("D326DEA3")
      }
    } else if input.isOptionHold, !input.isShiftHold {
      if input.isControlHold { return handleHome() }
      // 游標跳轉動作無論怎樣都會執行，但如果出了執行失敗的結果的話則觸發報錯流程。
      if !assembler.jumpCursorBySegment(to: .rear) {
        errorCallback?("8D50DD9E")
        return true
      }
      session.switchState(generateStateOfInputting())
    } else {
      if assembler.moveCursorStepwise(to: .rear) {
        session.switchState(generateStateOfInputting())
      } else {
        errorCallback?("7045E6F3")
      }
    }

    return true
  }

  // MARK: - 處理上下文候選字詞輪替（Tab 按鍵，或者 Shift+Space）

  /// 以給定之參數來處理上下文候選字詞之輪替。
  /// - Parameters:
  ///   - reverseOrder: 是否有控制輪替方向的修飾鍵輸入。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func revolveCandidate(reverseOrder: Bool) -> Bool {
    guard let session = session else { return false }
    let state = session.state
    if isComposerOrCalligrapherEmpty,
       assembler.isEmpty || assembler.assembledSentence.isEmpty { return false }
    guard state.type == .ofInputting else {
      guard state.type == .ofEmpty else {
        errorCallback?("6044F081")
        return true
      }
      // 不妨礙使用者平時輸入 Tab 的需求。
      return false
    }

    guard isComposerOrCalligrapherEmpty else {
      errorCallback?("A2DAF7BC")
      return true
    }

    let candidates = generateArrayOfCandidates(fixOrder: prefs.useFixedCandidateOrderOnSelection)
    guard !candidates.isEmpty else {
      errorCallback?("3378A6DF")
      return true
    }

    guard let region = assembler.assembledSentence.cursorRegionMap[actualNodeCursorPosition],
          assembler.assembledSentence.count > region
    else {
      errorCallback?("1CE6FFBD")
      return true
    }

    let currentNode = assembler.assembledSentence[region]

    let currentPaired = (currentNode.keyArray, currentNode.value)

    // 改成一次性計算，省得每次讀取時都被重複計算。
    let newIndex: Int = {
      if candidates.count == 1 { return 0 }
      var result = 0
      theLoop: for candidate in candidates {
        if !currentNode.isExplicit {
          if candidates[0] == currentPaired { result = reverseOrder ? candidates.count - 1 : 1 }
          break theLoop
        }
        result.revolveAsIndex(
          with: candidates,
          clockwise: !(candidate == currentPaired && reverseOrder)
        )
        if candidate == currentPaired { break }
      }
      return (0 ..< candidates.count).contains(result) ? result : 0
    }()

    if candidates.count > 1 {
      let previousSentence = assembler.assembledSentence
      vCLog(
        "revolveCandidate: attempting to consolidate candidate \(newIndex): \(candidates[newIndex].value)"
      )

      // 重試機制：如果 consolidateNode 沒有改變組字器狀態，則重試最多 20 次
      var retryCount = 0
      let maxRetries = 20
      var consolidationSucceeded = false

      while retryCount < maxRetries {
        consolidateNode(
          candidate: candidates[newIndex], respectCursorPushing: false,
          preConsolidate: retryCount > 0, skipObservation: true,
          explicitlyChosen: true
        )

        let currentSentence = assembler.assembledSentence
        if previousSentence.map(\.value) != currentSentence.map(\.value) {
          vCLog("revolveCandidate: consolidateNode succeeded after \(retryCount + 1) attempts")
          consolidationSucceeded = true
          break
        }

        retryCount += 1
        if retryCount < maxRetries {
          vCLog("revolveCandidate: consolidateNode failed, retrying (\(retryCount)/\(maxRetries))")
          // 第一次使用 preConsolidate，後續重試不使用，以避免重複相同的失敗原因
        }
      }

      if !consolidationSucceeded {
        vCLog("revolveCandidate: consolidateNode failed after \(maxRetries) attempts")
        vCLog("revolveCandidate: previous: \(previousSentence.map(\.value))")
        vCLog("revolveCandidate: current: \(assembler.assembledSentence.map(\.value))")
        vCLog("revolveCandidate: candidate that failed: \(candidates[newIndex])")
        vCLog("revolveCandidate: currentNode.isExplicit: \(currentNode.isExplicit)")
        vCLog("revolveCandidate: actualNodeCursorPosition: \(actualNodeCursorPosition)")
        errorCallback?("040CDB2A")
        // 即使失敗也繼續顯示狀態，而不是直接返回
      }
    } else {
      errorCallback?("F6644C24")
      // 只有一個候選字的情況下，沒有輪替的必要，直接返回
      return true
    }

    // 該動態函式僅用於此場合。
    func isContextVertical() -> Bool {
      session.updateVerticalTypingStatus()
      return session.isVerticalTyping
    }

    var newState = generateStateOfInputting()
    let locID = Bundle.main.preferredLocalizations[0]
    var newTooltip = ContiguousArray<String>()
    newTooltip.insert("　" + candidates[newIndex].value, at: 0)
    if #available(macOS 10.13, *), isContextVertical(), locID != "en" {
      newTooltip.insert(
        (newIndex + 1).i18n(loc: locID) + "・" + candidates.count.i18n(loc: locID),
        at: 0
      )
    } else {
      newTooltip.insert((newIndex + 1).description + " / " + candidates.count.description, at: 0)
    }
    newState.tooltip = newTooltip.joined()
    vCLog(newState.tooltip)
    newState.tooltipDuration = 0
    session.switchState(newState)
    return true
  }

  // MARK: - 處理符號選單（Symbol Menu Input）

  /// 處理符號選單。
  /// - Parameters:
  ///   - alternative: 使用另一個模式。
  ///   - JIS: 是否為 JIS 鍵盤。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handlePunctuationList(alternative: Bool, isJIS: Bool = false) -> Bool {
    guard let session = session, session.state.type != .ofDeactivated else { return false }
    if alternative {
      if currentLM.hasUnigramsFor(keyArray: ["_punctuation_list"]) {
        if isComposerOrCalligrapherEmpty, assembler.insertKey("_punctuation_list") {
          assemble()
          // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
          let textToCommit = commitOverflownComposition
          var inputting = generateStateOfInputting()
          inputting.textToCommit = textToCommit
          session.switchState(inputting)
          // 開始決定是否切換至選字狀態。
          let newState = generateStateOfCandidates(dodge: false)
          _ = newState.candidates.isEmpty ? errorCallback?("B5127D8A") : session
            .switchState(newState)
        } else { // 不要在注音沒敲完整的情況下叫出統合符號選單。
          errorCallback?("17446655")
        }
        return true
      } else {
        let errorMessage =
          "Please manually implement the symbols of this menu \nin the user phrase file with “_punctuation_list” key."
            .i18n
        vCLog("8EB3FB1A: " + errorMessage)
        let textToCommit = generateStateOfInputting(sansReading: true).displayedText
        session.switchState(State.ofCommitting(textToCommit: textToCommit))
        session.switchState(State.ofCommitting(textToCommit: isJIS ? "_" : "`"))
        return true
      }
    } else {
      // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
      let textToCommit = generateStateOfInputting(sansReading: true).displayedText
      session.switchState(State.ofCommitting(textToCommit: textToCommit))
      session.switchState(State.ofSymbolTable(node: CandidateNode.root))
      return true
    }
  }

  // MARK: - 處理選字窗服務選單 (Service Menu)

  func handleServiceMenuInitiation(candidateText: String, reading: [String]) -> Bool {
    guard let session = session, session.state.type != .ofDeactivated else { return false }
    guard !candidateText.isEmpty else { return false }
    let rootNode = CandidateTextService.getCurrentServiceMenu(
      candidate: candidateText,
      reading: reading
    )
    guard let rootNode = rootNode else { return false }
    // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
    let textToCommit = generateStateOfInputting(sansReading: true).displayedText
    session.switchState(State.ofCommitting(textToCommit: textToCommit))
    session.switchState(State.ofSymbolTable(node: rootNode))
    return true
  }

  // MARK: - 處理 Caps Lock 與英數輸入模式（Caps Lock and Alphanumerical mode）

  /// 處理 CapsLock 與英數輸入模式。
  /// - Remark: 若 Caps Lock 被啟用的話，則暫停對注音輸入的處理。
  /// 這裡的處理仍舊有用，不然 Caps Lock 英文模式無法直接鍵入小寫字母。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleCapsLockAndAlphanumericalMode(input: InputSignalProtocol) -> Bool? {
    guard let session = session else { return nil }
    let handleCapsLock = !prefs.bypassNonAppleCapsLockHandling && input.isCapsLockOn
    guard handleCapsLock || session.isASCIIMode else { return nil }

    // 低於 macOS 12 的系統無法偵測 CapsLock 的啟用狀態，
    // 所以這裡一律強制重置狀態為 .ofEmpty()。
    session.switchState(State.ofEmpty())

    // 字母鍵摁 Shift 的話，無須額外處理，因為直接就會敲出大寫字母。
    var shiftCapsLockHandling = input.isUpperCaseASCIILetterKey && session.isASCIIMode
    shiftCapsLockHandling = shiftCapsLockHandling || handleCapsLock && input.isShiftHold
    guard !shiftCapsLockHandling else { return false }

    // 不再讓唯音處理由 Shift 切換到的英文模式的按鍵輸入。
    if session.isASCIIMode, !handleCapsLock { return false }

    /// 如果是 ASCII 當中的不可列印的字元的話，
    /// 不使用「insertText:replacementRange:」。
    /// 某些應用無法正常處理非 ASCII 字符的輸入。
    if input.isASCII, !input.charCode.isPrintableASCII { return false }

    // 將整個組字區的內容遞交給客體應用。
    session.switchState(State.ofCommitting(textToCommit: input.text.lowercased()))

    return true
  }

  // MARK: - 呼叫選字窗（Intentionally Call Candidate Window）

  /// 手動呼叫選字窗。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func callCandidateState(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    var state: State { session.state }
    // 用上下左右鍵呼叫選字窗。
    // 僅憑藉 state.hasComposition 的話，並不能真實把握組字器的狀況。
    // 另外，這裡不要用「!input.isFunctionKeyHold」，
    // 否則會導致對上下左右鍵與翻頁鍵的判斷失效。
    let notEmpty = state.hasComposition && !assembler.isEmpty && isComposerOrCalligrapherEmpty
    let bannedModifiers: KBEvent.ModifierFlags = [.option, .shift, .command, .control]
    let noBannedModifiers = bannedModifiers.intersection(input.keyModifierFlags).isEmpty
    var triggered = input.isCursorClockLeft || input.isCursorClockRight
    triggered = triggered || (input.isSpace && prefs.chooseCandidateUsingSpace)
    triggered = triggered || input.isPageDown || input.isPageUp
    triggered = triggered || (input.isTab && prefs.specifyShiftTabKeyBehavior)
    guard notEmpty, noBannedModifiers, triggered else { return false }
    // 開始決定是否切換至選字狀態。
    let candidateState: State = generateStateOfCandidates()
    _ = candidateState.candidates.isEmpty ? errorCallback?("3572F238") : session
      .switchState(candidateState)
    return true
  }

  // MARK: - 處理全形/半形阿拉伯數字輸入（FW/HW Arabic Numerals）

  /// 處理全形/半形阿拉伯數字輸入。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleArabicNumeralInputs(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    guard session.state.type == .ofEmpty, input.isMainAreaNumKey else { return false }
    guard input.isOptionHold, !input.isCommandHold, !input.isControlHold else { return false }
    guard let strRAW = input.mainAreaNumKeyChar else { return false }
    let newString: String = {
      if input.isShiftHold {
        return strRAW.applyingTransformFW2HW(reverse: !prefs.halfWidthPunctuationEnabled)
      }
      return strRAW.applyingTransformFW2HW(reverse: false)
    }()
    session.switchState(State.ofCommitting(textToCommit: newString))
    return true
  }

  // MARK: - 處理「摁住 SHIFT 敲字母鍵」的輸入行為（Shift + Letter keys）

  /// 處理「摁住 SHIFT 敲字母鍵」的輸入行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleLettersWithShiftHold(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    let inputText = input.text
    if input.isUpperCaseASCIILetterKey, !input.isCommandHold, !input.isControlHold {
      if input.isShiftHold { // 這裡先不要判斷 isOptionHold。
        switch prefs.upperCaseLetterKeyBehavior {
        case 1, 3:
          if prefs.upperCaseLetterKeyBehavior == 3, !isConsideredEmptyForNow { break }
          let commitText = generateStateOfInputting(sansReading: true).displayedText
          session
            .switchState(State.ofCommitting(textToCommit: commitText + inputText.lowercased()))
          return true
        case 2, 4:
          if prefs.upperCaseLetterKeyBehavior == 4, !isConsideredEmptyForNow { break }
          let commitText = generateStateOfInputting(sansReading: true).displayedText
          session
            .switchState(State.ofCommitting(textToCommit: commitText + inputText.uppercased()))
          return true
        default: // 包括 case 0。
          break
        }
        // 直接塞給組字區。
        let letter = "_letter_\(inputText)"
        if handlePunctuation(letter) {
          return true
        }
      }
    }
    return false
  }

  // MARK: - 處理羅馬數字提交（Roman Numeral Commit）

  /// 轉換並提交緩衝區內的羅馬數字
  func commitRomanNumeral(session: Session) -> Bool {
    let inputStr = strCodePointBuffer

    func handleErrorState(msg: String) {
      var newErrorState = State.ofAbortion()
      if !msg.isEmpty {
        newErrorState.tooltip = msg
        newErrorState.tooltipDuration = 2
        newErrorState.data.tooltipColorState = .redAlert
        session.switchState(newErrorState)
      }
    }

    // 將輸入解析為整數
    guard let number = parseRomanNumeralInput(inputStr) else {
      handleErrorState(msg: "typingMethod.romanNumerals.error.invalidInput".i18n)
      errorCallback?("A3D5B7F9")
      return true
    }

    // 從偏好設定取得輸出格式
    let formatValue = prefs.romanNumeralOutputFormat
    let format = RomanNumeralOutputFormat(rawValue: formatValue) ?? .uppercaseASCII

    // 轉換為羅馬數字
    guard let romanNumeral = RomanNumeralConverter.convert(number, format: format) else {
      handleErrorState(msg: "typingMethod.romanNumerals.error.valueOutOfRange".i18n)
      errorCallback?("2E8C4D61")
      return true
    }

    // 提交結果
    session.switchState(State.ofCommitting(textToCommit: romanNumeral))
    // 羅馬數字提交後切換到 Empty 狀態，因為羅馬數字不是連續輸入的內容。
    // 這些步驟已由 State Machine 自動完成。
    // session.switchState(State.ofEmpty())
    // currentTypingMethod = .vChewingFactory
    return true
  }

  /// 將輸入字串解析為整數
  private func parseRomanNumeralInput(_ input: String) -> Int? {
    // 解析為整數（羅馬數字不支援零）
    Int(input)
  }

  // MARK: - 處理數字小鍵盤的文字輸入行為（NumPad）

  /// 處理數字小鍵盤的文字輸入行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleNumPadKeyInput(input: InputSignalProtocol) -> Bool {
    guard let session = session, input.isNumericPadKey else { return false }
    let inputText = input.text
    guard inputText.count == 1, input.isASCII else { return false }
    guard KeyCode(rawValue: input.keyCode) == nil else { return false } // 排除功能鍵。
    let behaviorValue = prefs.numPadCharInputBehavior
    let fullWidthResult = behaviorValue % 2 != 0 // 能被二整除的都是半形。
    triagePrefs: switch (behaviorValue, isConsideredEmptyForNow) {
    case (2, _), (3, _), (4, false), (5, false):
      currentLM.setOptions { config in
        config.numPadFWHWStatus = fullWidthResult
      }
      if handlePunctuation("_NumPad_\(inputText)") { return true }
    default: break triagePrefs // 包括 case 0 & 1。
    }
    currentLM.setOptions { config in
      config.numPadFWHWStatus = nil
    }
    session.switchState(State.ofEmpty())
    let charToCommit = inputText.applyingTransformFW2HW(reverse: fullWidthResult)
    session.switchState(State.ofCommitting(textToCommit: charToCommit))
    return true
  }

  // MARK: - 處理磁帶模式的符號選單輸入

  func handleCassetteSymbolTable(input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    guard prefs.cassetteEnabled else { return false }
    let inputText = input.text
    guard !inputText.isEmpty else { return false }
    let queryString = calligrapher + inputText
    let maybeResult = currentLM.cassetteSymbolDataFor(key: queryString)
    guard let result = maybeResult else { return false }
    let root = CandidateNode(name: queryString, symbols: result)
    // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
    let textToCommit = generateStateOfInputting(sansReading: true).displayedText
    session.switchState(State.ofCommitting(textToCommit: textToCommit))
    session.switchState(State.ofSymbolTable(node: root))
    return true
  }
}
