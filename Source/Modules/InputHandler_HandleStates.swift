// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃輸入調度模組的用以承載「根據按鍵行為來調控模式」的各種成員函式的部分。

import Megrez
import Shared
import Tekkon

// MARK: - § 根據按鍵行為來調控模式的函式 (Functions Interact With States).

extension InputHandler {
  // MARK: - 構築狀態（State Building）

  /// 生成「正在輸入」狀態。相關的內容會被拿給狀態機械用來處理在電腦螢幕上顯示的內容。
  public func generateStateOfInputting(sansReading: Bool = false) -> IMEStateProtocol {
    if isConsideredEmptyForNow { return IMEState.ofAbortion() }
    var segHighlightedAt: Int?
    let cpInput = isCodePointInputMode && !sansReading
    /// 「更新內文組字區 (Update the composing buffer)」是指要求客體軟體將組字緩衝區的內容
    /// 換成由此處重新生成的原始資料在 IMEStateData 當中生成的 NSAttributeString。
    var displayTextSegments: [String] = cpInput
      ? [strCodePointBuffer]
      : compositor.walkedNodes.values
    var cursor = cpInput
      ? displayTextSegments.joined().count
      : convertCursorForDisplay(compositor.cursor)
    let reading: String = (sansReading || isCodePointInputMode) ? "" : readingForDisplay // 先提出來，減輕運算負擔。
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
    var result = IMEState.ofInputting(
      displayTextSegments: displayTextSegments,
      cursor: cursor, highlightAt: segHighlightedAt
    )
    result.marker = compositor.cursor
    return result
  }

  /// 生成「在有單獨的前置聲調符號輸入時」的工具提示。
  var tooltipForStandaloneIntonationMark: String {
    guard !isComposerUsingPinyin else { return "" }
    guard composer.hasIntonation(withNothingElse: true) else { return "" }
    guard composer.intonation.value != " " else { return "" }
    let result = NSMutableString()
    result.append("Intonation mark. ENTER to commit.\nSPACE to insert into composition buffer.".localized)
    if prefs.acceptLeadingIntonations {
      result.append("\n")
      result.append("It will attempt to combine with the incoming phonabet input.".localized)
    }
    return result.description
  }

  /// 將組字器內的游標位置資料轉換成可以正確顯示的游標位置資料。
  /// - Parameter rawCursor: 原始游標。
  /// - Returns: 用以顯示的游標。
  func convertCursorForDisplay(_ rawCursor: Int) -> Int {
    var composedStringCursorIndex = 0
    var readingCursorIndex = 0
    for theNode in compositor.walkedNodes {
      let strNodeValue = theNode.value
      /// 藉下述步驟重新將「可見游標位置」對齊至「組字器內的游標所在的讀音位置」。
      /// 每個節錨（NodeAnchor）都有自身的幅位長度（spanningLength），可以用來
      /// 累加、以此為依據，來校正「可見游標位置」。
      let spanningLength: Int = theNode.keyArray.count
      if readingCursorIndex + spanningLength <= rawCursor {
        composedStringCursorIndex += strNodeValue.count
        readingCursorIndex += spanningLength
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
      readingCursorIndex += spanningLength
      readingCursorIndex = min(readingCursorIndex, rawCursor)
    }
    return composedStringCursorIndex
  }

  // MARK: - 用以生成候選詞陣列及狀態

  /// 拿著給定的候選字詞陣列資料內容，切換至選字狀態。
  /// - Returns: 回呼一個新的選詞狀態，來就給定的候選字詞陣列資料內容顯示選字窗。
  public func generateStateOfCandidates() -> IMEStateProtocol {
    IMEState.ofCandidates(
      candidates: generateArrayOfCandidates(fixOrder: prefs.useFixecCandidateOrderOnSelection),
      displayTextSegments: compositor.walkedNodes.values,
      cursor: delegate?.state.cursor ?? generateStateOfInputting().cursor
    )
  }

  // MARK: - 用以接收聯想詞陣列且生成狀態

  /// 拿著給定的聯想詞陣列資料內容，切換至聯想詞狀態。
  ///
  /// 這次重寫時，針對「generateStateOfAssociates」這個（用以生成帶有
  /// 聯想詞候選清單的結果的狀態回呼的）函式進行了小幅度的重構處理，使其始終
  /// 可以從 Core 部分的「generateArrayOfAssociates」函式獲取到一個內容類型
  /// 為「String」的標準 Swift 陣列。這樣一來，該聯想詞狀態回呼函式將始終能
  /// 夠傳回正確的結果形態、永遠也無法傳回 nil。於是，所有在用到該函式時以
  /// 回傳結果類型判斷作為合法性判斷依據的函式，全都將依據改為檢查傳回的陣列
  /// 是否為空：如果陣列為空的話，直接回呼一個空狀態。
  /// - Parameters:
  ///   - key: 給定的索引鍵（也就是給定的聯想詞的開頭字）。
  /// - Returns: 回呼一個新的聯想詞狀態，來就給定的聯想詞陣列資料內容顯示選字窗。
  public func generateStateOfAssociates(withPair pair: Megrez.KeyValuePaired) -> IMEStateProtocol {
    IMEState.ofAssociates(
      candidates: generateArrayOfAssociates(withPair: pair))
  }

  // MARK: - 用以處理就地新增自訂語彙時的行為

  /// 用以處理就地新增自訂語彙時的行為。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleMarkingState(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate else { return false }
    let state = delegate.state

    if input.isEsc {
      delegate.switchState(generateStateOfInputting())
      return true
    }

    // 阻止用於行內注音輸出的熱鍵。
    if input.isControlHold, input.isCommandHold, input.isEnter {
      delegate.callError("1198E3E5")
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
        delegate.callError("9AAFAC00")
        return true
      }
      if !delegate.performUserPhraseOperation(addToFilter: false) {
        delegate.callError("5B69CC8D")
        return true
      }
      var newState = generateStateOfInputting()
      newState.tooltip = NSLocalizedString(tooltipMessage, comment: "")
      newState.data.tooltipColorState = tooltipColorState
      newState.tooltipDuration = 1.85
      delegate.switchState(newState)
      return true
    }

    // BackSpace & Delete
    if input.isBackSpace || input.isDelete {
      let tooltipMessage = "! Succeeded in filtering a user phrase."
      if !state.isFilterable {
        delegate.callError("1F88B191")
        return true
      }
      if !delegate.performUserPhraseOperation(addToFilter: true) {
        delegate.callError("68D3C6C8")
        return true
      }
      var newState = generateStateOfInputting()
      newState.tooltip = NSLocalizedString(tooltipMessage, comment: "")
      newState.data.tooltipColorState = .warning
      newState.tooltipDuration = 1.85
      delegate.switchState(newState)
      return true
    }

    // Shift + Left
    if input.isCursorBackward, input.isShiftHold {
      if compositor.marker > 0 {
        if input.isCommandHold || input.isOptionHold {
          compositor.jumpCursorBySpan(to: .rear, isMarker: true)
        } else {
          compositor.marker -= 1
          if isCursorCuttingChar(isMarker: true) {
            compositor.jumpCursorBySpan(to: .rear, isMarker: true)
          }
        }
        var marking = IMEState.ofMarking(
          displayTextSegments: state.displayTextSegments,
          markedReadings: Array(compositor.keys[currentMarkedRange()]),
          cursor: convertCursorForDisplay(compositor.cursor),
          marker: convertCursorForDisplay(compositor.marker)
        )
        marking.tooltipBackupForInputting = state.tooltipBackupForInputting
        delegate.switchState(marking.markedRange.isEmpty ? marking.convertedToInputting : marking)
      } else {
        delegate.callError("1149908D")
      }
      return true
    }

    // Shift + Right
    if input.isCursorForward, input.isShiftHold {
      if compositor.marker < compositor.length {
        if input.isCommandHold || input.isOptionHold {
          compositor.jumpCursorBySpan(to: .front, isMarker: true)
        } else {
          compositor.marker += 1
          if isCursorCuttingChar(isMarker: true) {
            compositor.jumpCursorBySpan(to: .front, isMarker: true)
          }
        }
        var marking = IMEState.ofMarking(
          displayTextSegments: state.displayTextSegments,
          markedReadings: Array(compositor.keys[currentMarkedRange()]),
          cursor: convertCursorForDisplay(compositor.cursor),
          marker: convertCursorForDisplay(compositor.marker)
        )
        marking.tooltipBackupForInputting = state.tooltipBackupForInputting
        delegate.switchState(marking.markedRange.isEmpty ? marking.convertedToInputting : marking)
      } else {
        delegate.callError("9B51408D")
      }
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
    guard let delegate = delegate else { return false }

    if !currentLM.hasUnigramsFor(keyArray: [customPunctuation]) {
      return false
    }

    guard isComposerOrCalligrapherEmpty else {
      // 注音沒敲完的情況下，無視標點輸入。
      delegate.callError("A9B69908D")
      return true
    }

    guard compositor.insertKey(customPunctuation) else {
      delegate.callError("C0793A6D: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
      return true
    }

    walk()
    // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
    let textToCommit = commitOverflownComposition
    var inputting = generateStateOfInputting()
    inputting.textToCommit = textToCommit
    delegate.switchState(inputting)

    // 從這一行之後開始，就是針對逐字選字模式的單獨處理。
    guard prefs.useSCPCTypingMode, isComposerOrCalligrapherEmpty else { return true }

    let candidateState = generateStateOfCandidates()
    switch candidateState.candidates.count {
    case 2...: delegate.switchState(candidateState)
    case 1:
      clear() // 這句不要砍，因為下文可能會回呼 candidateState。
      if let strToCommit = candidateState.candidates.first?.value, !strToCommit.isEmpty {
        delegate.switchState(IMEState.ofCommitting(textToCommit: strToCommit))
      } else {
        delegate.switchState(candidateState)
      }
    default: delegate.callError("8DA4096E")
    }
    return true
  }

  // MARK: - Enter 鍵的處理，包括對其他修飾鍵的應對。

  /// Enter 鍵的處理。
  /// - Parameter input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  @discardableResult func handleEnter(input: InputSignalProtocol, readingOnly: Bool = false) -> Bool {
    guard let delegate = delegate else { return false }
    let state = delegate.state

    if isHaninKeyboardSymbolMode { return handleHaninKeyboardSymbolModeToggle() }
    if isCodePointInputMode { return handleCodePointInputToggle() }

    guard state.type == .ofInputting else { return false }

    var displayedText = state.displayedText

    if input.modifierFlags == [.option, .shift] {
      displayedText = displayedText.map(\.description).joined(separator: " ")
    } else if readingOnly {
      displayedText = commissionByCtrlCommandEnter()
    } else if input.isCommandHold, input.isControlHold {
      displayedText =
        input.isOptionHold
          ? commissionByCtrlOptionCommandEnter(isShiftPressed: input.isShiftHold)
          : commissionByCtrlCommandEnter(isShiftPressed: input.isShiftHold)
    }

    delegate.switchState(IMEState.ofCommitting(textToCommit: displayedText))
    return true
  }

  // MARK: - Command+Enter 鍵的處理（注音文）

  /// Command+Enter 鍵的處理（注音文）。
  /// - Parameter isShiftPressed: 有沒有同時摁著 Shift 鍵。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  private func commissionByCtrlCommandEnter(isShiftPressed: Bool = false) -> String {
    var displayedText = compositor.keys.joined(separator: "\t")
    if compositor.isEmpty {
      displayedText = readingForDisplay
    }
    if !prefs.cassetteEnabled {
      if prefs.inlineDumpPinyinInLieuOfZhuyin {
        if !compositor.isEmpty {
          var arrDisplayedTextElements = [String]()
          compositor.keys.forEach { key in
            arrDisplayedTextElements.append(Tekkon.restoreToneOneInPhona(target: key)) // 恢復陰平標記
          }
          displayedText = arrDisplayedTextElements.joined(separator: "\t")
        }
        displayedText = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: displayedText) // 注音轉拼音
      }
      if prefs.showHanyuPinyinInCompositionBuffer {
        if compositor.isEmpty {
          displayedText = displayedText.replacingOccurrences(of: "1", with: "")
        }
      }
    }

    displayedText = displayedText.replacingOccurrences(of: "\t", with: isShiftPressed ? "-" : " ")
    return displayedText
  }

  // MARK: - Command+Option+Enter 鍵的處理（網頁 Ruby 注音文標記）

  /// Command+Option+Enter 鍵的處理（網頁 Ruby 注音文標記）。
  /// - Parameter isShiftPressed: 有沒有同時摁著 Shift 鍵。摁了的話則只遞交讀音字串。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  private func commissionByCtrlOptionCommandEnter(isShiftPressed: Bool = false) -> String {
    var composed = ""

    compositor.walkedNodes.smashedPairs.forEach { key, value in
      var key = key
      if !prefs.cassetteEnabled {
        key =
          prefs.inlineDumpPinyinInLieuOfZhuyin
            ? Tekkon.restoreToneOneInPhona(target: key) // 恢復陰平標記
            : Tekkon.cnvPhonaToTextbookReading(target: key) // 恢復陰平標記

        if prefs.inlineDumpPinyinInLieuOfZhuyin {
          key = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: key) // 注音轉拼音
          key = Tekkon.cnvHanyuPinyinToTextbookStyle(targetJoined: key) // 轉教科書式標調
        }
      }

      key = key.replacingOccurrences(of: "\t", with: " ")

      if isShiftPressed {
        if !composed.isEmpty { composed += " " }
        composed += key.contains("_") ? "??" : key
        return
      }

      // 不要給標點符號等特殊元素加注音
      composed += key.contains("_") ? value : "<ruby>\(value)<rp>(</rp><rt>\(key)</rt><rp>)</rp></ruby>"
    }

    return composed
  }

  // MARK: - 處理 BackSpace (macOS Delete) 按鍵行為

  /// 處理 BackSpace (macOS Delete) 按鍵行為。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleBackSpace(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate else { return false }
    let state = delegate.state
    guard state.type == .ofInputting else {
      isCodePointInputMode = false
      return false
    }

    if isCodePointInputMode {
      if !strCodePointBuffer.isEmpty {
        func refreshState() {
          var updatedState = generateStateOfInputting()
          updatedState.tooltipDuration = 0
          updatedState.tooltip = tooltipCodePointInputMode
          delegate.switchState(updatedState)
        }
        strCodePointBuffer = strCodePointBuffer.dropLast(1).description
        if input.modifierFlags == .option {
          strCodePointBuffer.removeAll()
          refreshState()
          isCodePointInputMode = true
          return true
        }
        if !strCodePointBuffer.isEmpty {
          refreshState()
          return true
        }
      }
      return handleCodePointInputToggle()
    }

    // 引入 macOS 內建注音輸入法的行為，允許用 Shift+BackSpace 解構前一個漢字的讀音。
    shiftBksp: switch prefs.specifyShiftBackSpaceKeyBehavior {
    case 0:
      if prefs.cassetteEnabled {
        guard input.isShiftHold, calligrapher.isEmpty else { break shiftBksp }
        guard let prevReading = previousParsableCalligraph else { break shiftBksp }
        compositor.dropKey(direction: .rear)
        walk() // 這裡必須 Walk 一次、來更新目前被 walk 的內容。
        calligrapher = prevReading
      } else {
        guard input.isShiftHold, isComposerOrCalligrapherEmpty else { break shiftBksp }
        guard let prevReading = previousParsableReading else { break shiftBksp }
        // prevReading 的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
        compositor.dropKey(direction: .rear)
        walk() // 這裡必須 Walk 一次、來更新目前被 walk 的內容。
        prevReading.1.map(\.description).forEach { composer.receiveKey(fromPhonabet: $0) }
      }
      delegate.switchState(generateStateOfInputting())
      return true
    case 1:
      delegate.switchState(IMEState.ofAbortion())
      return true
    default: break
    }

    let steps = getStepsToNearbyNodeBorder(direction: .rear)
    var actualSteps = 1

    switch input.modifierFlags {
    case .shift:
      delegate.switchState(IMEState.ofAbortion())
      return true
    case .option:
      actualSteps = steps
    default: break
    }

    if isComposerOrCalligrapherEmpty {
      if compositor.cursor <= 0 || actualSteps <= 0 {
        delegate.callError("9D69908D")
        return true
      }
      for _ in 0 ..< actualSteps {
        compositor.dropKey(direction: .rear)
      }
      walk()
    } else {
      _ = input.modifierFlags == .option
        ? clearComposerAndCalligrapher()
        : letComposerAndCalligrapherDoBackSpace()
    }

    switch isConsideredEmptyForNow {
    case false:
      var result = generateStateOfInputting()
      if prefs.cassetteEnabled, var fetched = currentLM.cassetteQuickSetsFor(key: calligrapher)?.split(separator: "\t") {
        if prefs.useIMKCandidateWindow {
          fetched = fetched.deduplicated.filter { $0.description != currentLM.nullCandidateInCassette }
        }
        result.candidates = fetched.enumerated().map {
          (keyArray: [($0.offset + 1).description], value: $0.element.description)
        }
      }
      delegate.switchState(result)
    case true: delegate.switchState(IMEState.ofAbortion())
    }
    return true
  }

  // MARK: - 處理 PC Delete (macOS Fn+BackSpace) 按鍵行為

  /// 處理 PC Delete (macOS Fn+BackSpace) 按鍵行為。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleDelete(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate else { return false }
    let state = delegate.state

    if isHaninKeyboardSymbolMode { return handleHaninKeyboardSymbolModeToggle() }
    if isCodePointInputMode { return handleCodePointInputToggle() }

    guard state.type == .ofInputting else { return false }

    let steps = getStepsToNearbyNodeBorder(direction: .front)
    var actualSteps = 1

    // macOS 認為 PC Delete 鍵訊號是必然有 .function 這個修飾鍵在起作用的。
    // 總之處理起來非常機車就是了。
    switch input.modifierFlags {
    case _ where input.isShiftHold && !input.isOptionHold && !input.isControlHold:
      delegate.switchState(IMEState.ofAbortion())
      return true
    case _ where !input.isShiftHold && input.isOptionHold && !input.isControlHold:
      actualSteps = steps
    default: break
    }

    if isComposerOrCalligrapherEmpty {
      if compositor.cursor >= compositor.length || actualSteps <= 0 {
        delegate.callError("9B69938D")
        return true
      }
      for _ in 0 ..< actualSteps {
        compositor.dropKey(direction: .front)
      }
      walk()
    } else {
      clearComposerAndCalligrapher()
    }

    let inputting = generateStateOfInputting()
    // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
    switch inputting.displayedText.isEmpty {
    case false: delegate.switchState(inputting)
    case true: delegate.switchState(IMEState.ofAbortion())
    }
    return true
  }

  // MARK: - 處理與當前文字輸入排版前後方向呈 90 度的那兩個方向鍵的按鍵行為

  /// 處理與當前文字輸入排版前後方向呈 90 度的那兩個方向鍵的按鍵行為。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleClockKey() -> Bool {
    guard let delegate = delegate else { return false }
    let state = delegate.state
    guard state.type == .ofInputting else { return false }
    if !isComposerOrCalligrapherEmpty { delegate.callError("9B6F908D") }
    return true
  }

  // MARK: - 處理 Home 鍵的行為

  /// 處理 Home 鍵的行為。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleHome() -> Bool {
    guard let delegate = delegate else { return false }
    let state = delegate.state
    guard state.type == .ofInputting else { return false }

    if !isComposerOrCalligrapherEmpty {
      delegate.callError("ABC44080")
      return true
    }

    if compositor.cursor != 0 {
      compositor.cursor = 0
      delegate.switchState(generateStateOfInputting())
    } else {
      delegate.callError("66D97F90")
    }

    return true
  }

  // MARK: - 處理 End 鍵的行為

  /// 處理 End 鍵的行為。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleEnd() -> Bool {
    guard let delegate = delegate else { return false }
    let state = delegate.state
    guard state.type == .ofInputting else { return false }

    if !isComposerOrCalligrapherEmpty {
      delegate.callError("9B69908D")
      return true
    }

    if compositor.cursor != compositor.length {
      compositor.cursor = compositor.length
      delegate.switchState(generateStateOfInputting())
    } else {
      delegate.callError("9B69908E")
    }

    return true
  }

  // MARK: - 處理 Esc 鍵的行為

  /// 處理 Esc 鍵的行為。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleEsc() -> Bool {
    guard let delegate = delegate else { return false }
    let state = delegate.state

    if isHaninKeyboardSymbolMode { return handleHaninKeyboardSymbolModeToggle() }
    if isCodePointInputMode { return handleCodePointInputToggle() }

    guard state.type == .ofInputting else { return false }

    if prefs.escToCleanInputBuffer {
      /// 若啟用了該選項，則清空組字器的內容與注拼槽的內容。
      /// 此乃 macOS 內建注音輸入法預設之行為，但不太受 Windows 使用者群體之待見。
      delegate.switchState(IMEState.ofAbortion())
    } else {
      if isComposerOrCalligrapherEmpty {
        let commitText = generateStateOfInputting(sansReading: true).displayedText
        delegate.switchState(IMEState.ofCommitting(textToCommit: commitText))
        return true
      }
      /// 如果注拼槽或組筆區不是空的話，則清空之。
      clearComposerAndCalligrapher()
      switch compositor.isEmpty {
      case false: delegate.switchState(generateStateOfInputting())
      case true: delegate.switchState(IMEState.ofAbortion())
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
    guard let delegate = delegate else { return false }
    let state = delegate.state
    guard state.type == .ofInputting else { return false }

    if !isComposerOrCalligrapherEmpty {
      delegate.callError("B3BA5257")
      return true
    }

    if input.isShiftHold {
      // Shift + Right
      if compositor.cursor < compositor.length {
        compositor.marker = compositor.cursor
        if input.isCommandHold || input.isOptionHold {
          compositor.jumpCursorBySpan(to: .front, isMarker: true)
        } else {
          compositor.marker += 1
          if isCursorCuttingChar(isMarker: true) {
            compositor.jumpCursorBySpan(to: .front, isMarker: true)
          }
        }
        var marking = IMEState.ofMarking(
          displayTextSegments: compositor.walkedNodes.values,
          markedReadings: Array(compositor.keys[currentMarkedRange()]),
          cursor: convertCursorForDisplay(compositor.cursor),
          marker: convertCursorForDisplay(compositor.marker)
        )
        marking.tooltipBackupForInputting = state.tooltip
        delegate.switchState(marking)
      } else {
        delegate.callError("BB7F6DB9")
      }
    } else if input.isOptionHold, !input.isShiftHold {
      if input.isControlHold {
        return handleEnd()
      }
      // 游標跳轉動作無論怎樣都會執行，但如果出了執行失敗的結果的話則觸發報錯流程。
      if !compositor.jumpCursorBySpan(to: .front) {
        delegate.callError("33C3B580")
        return true
      }
      delegate.switchState(generateStateOfInputting())
    } else {
      if compositor.cursor < compositor.length {
        compositor.cursor += 1
        if isCursorCuttingChar() {
          compositor.jumpCursorBySpan(to: .front)
        }
        delegate.switchState(generateStateOfInputting())
      } else {
        delegate.callError("A96AAD58")
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
    guard let delegate = delegate else { return false }
    let state = delegate.state
    guard state.type == .ofInputting else { return false }

    if !isComposerOrCalligrapherEmpty {
      delegate.callError("6ED95318")
      return true
    }

    if input.isShiftHold {
      // Shift + left
      if compositor.cursor > 0 {
        compositor.marker = compositor.cursor
        if input.isCommandHold || input.isOptionHold {
          compositor.jumpCursorBySpan(to: .rear, isMarker: true)
        } else {
          compositor.marker -= 1
          if isCursorCuttingChar(isMarker: true) {
            compositor.jumpCursorBySpan(to: .rear, isMarker: true)
          }
        }
        var marking = IMEState.ofMarking(
          displayTextSegments: compositor.walkedNodes.values,
          markedReadings: Array(compositor.keys[currentMarkedRange()]),
          cursor: convertCursorForDisplay(compositor.cursor),
          marker: convertCursorForDisplay(compositor.marker)
        )
        marking.tooltipBackupForInputting = state.tooltip
        delegate.switchState(marking)
      } else {
        delegate.callError("D326DEA3")
      }
    } else if input.isOptionHold, !input.isShiftHold {
      if input.isControlHold { return handleHome() }
      // 游標跳轉動作無論怎樣都會執行，但如果出了執行失敗的結果的話則觸發報錯流程。
      if !compositor.jumpCursorBySpan(to: .rear) {
        delegate.callError("8D50DD9E")
        return true
      }
      delegate.switchState(generateStateOfInputting())
    } else {
      if compositor.cursor > 0 {
        compositor.cursor -= 1
        if isCursorCuttingChar() {
          compositor.jumpCursorBySpan(to: .rear)
        }
        delegate.switchState(generateStateOfInputting())
      } else {
        delegate.callError("7045E6F3")
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
    guard let delegate = delegate else { return false }
    let state = delegate.state
    if isComposerOrCalligrapherEmpty, compositor.isEmpty || compositor.walkedNodes.isEmpty { return false }
    guard state.type == .ofInputting else {
      guard state.type == .ofEmpty else {
        delegate.callError("6044F081")
        return true
      }
      // 不妨礙使用者平時輸入 Tab 的需求。
      return false
    }

    guard isComposerOrCalligrapherEmpty else {
      delegate.callError("A2DAF7BC")
      return true
    }

    let candidates = generateArrayOfCandidates(fixOrder: true)
    guard !candidates.isEmpty else {
      delegate.callError("3378A6DF")
      return true
    }

    guard let region = compositor.walkedNodes.cursorRegionMap[actualNodeCursorPosition],
          compositor.walkedNodes.count > region
    else {
      delegate.callError("1CE6FFBD")
      return true
    }

    let currentNode = compositor.walkedNodes[region]

    let currentPaired = (currentNode.keyArray, currentNode.value)

    // 改成一次性計算，省得每次讀取時都被重複計算。
    let newIndex: Int = {
      if candidates.count == 1 { return 0 }
      var result = 0
      theLoop: for candidate in candidates {
        if !currentNode.isOverridden {
          if candidates[0] == currentPaired { result = reverseOrder ? candidates.count - 1 : 1 }
          break theLoop
        }
        result.revolveAsIndex(with: candidates, clockwise: !(candidate == currentPaired && reverseOrder))
        if candidate == currentPaired { break }
      }
      return (0 ..< candidates.count).contains(result) ? result : 0
    }()

    if candidates.count > 1 {
      consolidateNode(
        candidate: candidates[newIndex], respectCursorPushing: false,
        preConsolidate: false, skipObservation: true
      )
    }

    // 該動態函式僅用於此場合。
    func isContextVertical() -> Bool {
      delegate.updateVerticalTypingStatus()
      return delegate.isVerticalTyping
    }

    var newState = generateStateOfInputting()
    let locID = Bundle.main.preferredLocalizations[0]
    let newTooltip = NSMutableString()
    newTooltip.insert("　" + candidates[newIndex].value, at: 0)
    if #available(macOS 10.13, *), isContextVertical(), locID != "en" {
      newTooltip.insert((newIndex + 1).i18n(loc: locID) + "・" + candidates.count.i18n(loc: locID), at: 0)
    } else {
      newTooltip.insert((newIndex + 1).description + " / " + candidates.count.description, at: 0)
    }
    newState.tooltip = newTooltip.description
    vCLog(newState.tooltip)
    newState.tooltipDuration = 0
    delegate.switchState(newState)
    return true
  }

  // MARK: - 處理區位輸入狀態的啟動過程（CodePoint Input Toggle）

  @discardableResult func handleCodePointInputToggle() -> Bool {
    guard let delegate = delegate, delegate.state.type != .ofDeactivated else { return false }
    if isCodePointInputMode {
      isCodePointInputMode = false
      delegate.switchState(IMEState.ofAbortion())
      return true
    }
    var updatedState = generateStateOfInputting(sansReading: true)
    delegate.switchState(IMEState.ofCommitting(textToCommit: updatedState.displayedText))
    updatedState = IMEState.ofEmpty()
    updatedState.tooltipDuration = 0
    updatedState.tooltip = tooltipCodePointInputMode
    delegate.switchState(updatedState)
    isCodePointInputMode = true
    return true
  }

  // MARK: - 處理漢音鍵盤符號輸入狀態的啟動過程（Hanin Pallete）

  @discardableResult func handleHaninKeyboardSymbolModeToggle() -> Bool {
    guard let delegate = delegate, delegate.state.type != .ofDeactivated else { return false }
    if isCodePointInputMode { isCodePointInputMode = false }
    if isHaninKeyboardSymbolMode {
      isHaninKeyboardSymbolMode = false
      delegate.switchState(IMEState.ofAbortion())
      return true
    }
    var updatedState = generateStateOfInputting(sansReading: true)
    delegate.switchState(IMEState.ofCommitting(textToCommit: updatedState.displayedText))
    updatedState = IMEState.ofEmpty()
    updatedState.tooltipDuration = 0
    updatedState.tooltip = Self.tooltipHaninKeyboardSymbolMode
    delegate.switchState(updatedState)
    isHaninKeyboardSymbolMode = true
    return true
  }

  /// 處理漢音鍵盤符號輸入。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handleHaninKeyboardSymbolModeInput(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate, delegate.state.type != .ofDeactivated else { return false }
    let charText = input.text.lowercased().applyingTransformFW2HW(reverse: false)
    guard CandidateNode.mapHaninKeyboardSymbols.keys.contains(charText) else {
      return handleHaninKeyboardSymbolModeToggle()
    }
    guard
      charText.count == 1, let symbols = CandidateNode.queryHaninKeyboardSymbols(char: charText)
    else {
      delegate.callError("C1A760C7")
      return true
    }
    // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
    let textToCommit = generateStateOfInputting(sansReading: true).displayedText
    delegate.switchState(IMEState.ofCommitting(textToCommit: textToCommit))
    if symbols.members.count == 1 {
      delegate.switchState(IMEState.ofCommitting(textToCommit: symbols.members.map(\.name).joined()))
    } else {
      delegate.switchState(IMEState.ofSymbolTable(node: symbols))
    }
    isHaninKeyboardSymbolMode = false // 用完就關掉，但保持選字窗開啟，所以這裡不用呼叫 toggle 函式。
    return true
  }

  // MARK: - 處理符號選單（Symbol Menu Input）

  /// 處理符號選單。
  /// - Parameters:
  ///   - alternative: 使用另一個模式。
  ///   - JIS: 是否為 JIS 鍵盤。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func handlePunctuationList(alternative: Bool, isJIS: Bool = false) -> Bool {
    guard let delegate = delegate, delegate.state.type != .ofDeactivated else { return false }
    if alternative {
      if currentLM.hasUnigramsFor(keyArray: ["_punctuation_list"]) {
        if isComposerOrCalligrapherEmpty, compositor.insertKey("_punctuation_list") {
          walk()
          // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
          let textToCommit = commitOverflownComposition
          var inputting = generateStateOfInputting()
          inputting.textToCommit = textToCommit
          delegate.switchState(inputting)
          // 開始決定是否切換至選字狀態。
          let newState = generateStateOfCandidates()
          _ = newState.candidates.isEmpty ? delegate.callError("B5127D8A") : delegate.switchState(newState)
        } else { // 不要在注音沒敲完整的情況下叫出統合符號選單。
          delegate.callError("17446655")
        }
        return true
      } else {
        let errorMessage =
          NSLocalizedString(
            "Please manually implement the symbols of this menu \nin the user phrase file with “_punctuation_list” key.",
            comment: ""
          )
        vCLog("8EB3FB1A: " + errorMessage)
        let textToCommit = generateStateOfInputting(sansReading: true).displayedText
        delegate.switchState(IMEState.ofCommitting(textToCommit: textToCommit))
        delegate.switchState(IMEState.ofCommitting(textToCommit: isJIS ? "_" : "`"))
        return true
      }
    } else {
      // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
      let textToCommit = generateStateOfInputting(sansReading: true).displayedText
      delegate.switchState(IMEState.ofCommitting(textToCommit: textToCommit))
      delegate.switchState(IMEState.ofSymbolTable(node: CandidateNode.root))
      return true
    }
  }

  // MARK: - 處理 Caps Lock 與英數輸入模式（Caps Lock and Alphanumerical mode）

  /// 處理 CapsLock 與英數輸入模式。
  /// - Remark: 若 Caps Lock 被啟用的話，則暫停對注音輸入的處理。
  /// 這裡的處理仍舊有用，不然 Caps Lock 英文模式無法直接鍵入小寫字母。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleCapsLockAndAlphanumericalMode(input: InputSignalProtocol) -> Bool? {
    guard let delegate = delegate else { return nil }
    guard input.isCapsLockOn || delegate.isASCIIMode else { return nil }

    // 低於 macOS 12 的系統無法偵測 CapsLock 的啟用狀態，
    // 所以這裡一律強制重置狀態為 .ofEmpty()。
    delegate.switchState(IMEState.ofEmpty())

    // 字母鍵摁 Shift 的話，無須額外處理，因為直接就會敲出大寫字母。
    if (input.isUpperCaseASCIILetterKey && delegate.isASCIIMode)
      || (input.isCapsLockOn && input.isShiftHold)
    {
      return false
    }

    /// 如果是 ASCII 當中的不可列印的字元的話，
    /// 不使用「insertText:replacementRange:」。
    /// 某些應用無法正常處理非 ASCII 字符的輸入。
    if input.isASCII, !input.charCode.isPrintableASCII { return false }

    // 將整個組字區的內容遞交給客體應用。
    delegate.switchState(IMEState.ofCommitting(textToCommit: input.text.lowercased()))

    return true
  }

  // MARK: - 呼叫選字窗（Intentionally Call Candidate Window）

  /// 手動呼叫選字窗。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func callCandidateState(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate else { return false }
    var state: IMEStateProtocol { delegate.state }
    // 用上下左右鍵呼叫選字窗。
    // 僅憑藉 state.hasComposition 的話，並不能真實把握組字器的狀況。
    // 另外，這裡不要用「!input.isFunctionKeyHold」，
    // 否則會導致對上下左右鍵與翻頁鍵的判斷失效。
    let notEmpty = state.hasComposition && !compositor.isEmpty && isComposerOrCalligrapherEmpty
    let bannedModifiers: NSEvent.ModifierFlags = [.option, .shift, .command, .control]
    let noBannedModifiers = bannedModifiers.intersection(input.modifierFlags).isEmpty
    var triggered = input.isCursorClockLeft || input.isCursorClockRight
    triggered = triggered || (input.isSpace && prefs.chooseCandidateUsingSpace)
    triggered = triggered || input.isPageDown || input.isPageUp
    triggered = triggered || (input.isTab && prefs.specifyShiftTabKeyBehavior)
    guard notEmpty, noBannedModifiers, triggered else { return false }
    // 開始決定是否切換至選字狀態。
    let candidateState: IMEStateProtocol = generateStateOfCandidates()
    _ = candidateState.candidates.isEmpty ? delegate.callError("3572F238") : delegate.switchState(candidateState)
    return true
  }

  // MARK: - 處理全形/半形阿拉伯數字輸入（FW/HW Arabic Numerals）

  /// 處理全形/半形阿拉伯數字輸入。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleArabicNumeralInputs(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate else { return false }
    guard delegate.state.type == .ofEmpty, input.isMainAreaNumKey else { return false }
    guard input.isOptionHold, !input.isCommandHold, !input.isControlHold else { return false }
    guard let strRAW = input.mainAreaNumKeyChar else { return false }
    let newString: String = {
      if input.isShiftHold {
        return strRAW.applyingTransformFW2HW(reverse: !prefs.halfWidthPunctuationEnabled)
      }
      return strRAW.applyingTransformFW2HW(reverse: false)
    }()
    delegate.switchState(IMEState.ofCommitting(textToCommit: newString))
    return true
  }

  // MARK: - 處理「摁住 SHIFT 敲字母鍵」的輸入行為（Shift + Letter keys）

  /// 處理「摁住 SHIFT 敲字母鍵」的輸入行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleLettersWithShiftHold(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate else { return false }
    let inputText = input.text
    if input.isUpperCaseASCIILetterKey, !input.isCommandHold, !input.isControlHold {
      if input.isShiftHold { // 這裡先不要判斷 isOptionHold。
        switch prefs.upperCaseLetterKeyBehavior {
        case 1, 3:
          if prefs.upperCaseLetterKeyBehavior == 3, !isConsideredEmptyForNow { break }
          let commitText = generateStateOfInputting(sansReading: true).displayedText
          delegate.switchState(IMEState.ofCommitting(textToCommit: commitText + inputText.lowercased()))
          return true
        case 2, 4:
          if prefs.upperCaseLetterKeyBehavior == 4, !isConsideredEmptyForNow { break }
          let commitText = generateStateOfInputting(sansReading: true).displayedText
          delegate.switchState(IMEState.ofCommitting(textToCommit: commitText + inputText.uppercased()))
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

  // MARK: - 處理磁帶模式的符號選單輸入

  func handleCassetteSymbolTable(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate else { return false }
    guard prefs.cassetteEnabled else { return false }
    let inputText = input.text
    guard !inputText.isEmpty else { return false }
    let queryString = calligrapher + inputText
    let maybeResult = currentLM.cassetteSymbolDataFor(key: queryString)
    guard let result = maybeResult else { return false }
    let root = CandidateNode(name: queryString, symbols: result)
    // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
    let textToCommit = generateStateOfInputting(sansReading: true).displayedText
    delegate.switchState(IMEState.ofCommitting(textToCommit: textToCommit))
    delegate.switchState(IMEState.ofSymbolTable(node: root))
    return true
  }
}
