// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃輸入調度模組當中「用來規定在選字窗出現時的按鍵行為」的部分。

// MARK: - § 對選字狀態進行調度 (Handle Candidate State).

extension InputHandlerProtocol {
  /// 當且僅當選字窗出現時，對於經過初次篩選處理的輸入訊號的處理均藉由此函式來進行。
  /// - Parameters:
  ///   - input: 輸入訊號。
  ///   - ignoringModifiers: 是否需要忽視修飾鍵。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleCandidate(input: InputSignalProtocol, ignoringModifiers: Bool = false) -> Bool {
    guard let session = session else { return false }
    guard var ctlCandidate = session.candidateController() else {
      return false
    }
    let state = session.state
    guard state.isCandidateContainer else { return false } // 會自動判斷「isEmpty」。
    guard ctlCandidate.visible else { return false }
    let inputText = ignoringModifiers ? (input.inputTextIgnoringModifiers ?? input.text) : input
      .text
    let allowMovingCompositorCursor = state.type == .ofCandidates && !prefs.useSCPCTypingMode
    let highlightedCandidate = state.candidates[ctlCandidate.highlightedIndex]

    // MARK: 選字窗服務選單（Shift+?）。

    var candidateTextServiceMenuRunning: Bool {
      state.node.containsCandidateServices && state.type == .ofSymbolTable
    }

    serviceMenu: if prefs.useShiftQuestionToCallServiceMenu, input.commonKeyModifierFlags == .shift,
                    input.text == "?" {
      if candidateTextServiceMenuRunning { break serviceMenu }
      let handled = handleServiceMenuInitiation(
        candidateText: highlightedCandidate.value,
        reading: highlightedCandidate.keyArray
      )
      if handled { return true }
    }

    // MARK: 波浪符號鍵（選字窗服務選單 / 輔助翻頁 / 其他功能）。

    if input.isSymbolMenuPhysicalKey {
      switch input.commonKeyModifierFlags {
      case .shift, [],
           .option where !candidateTextServiceMenuRunning:
        if !candidateTextServiceMenuRunning {
          let handled = handleServiceMenuInitiation(
            candidateText: highlightedCandidate.value,
            reading: highlightedCandidate.keyArray
          )
          if handled { return true }
        }
        var updated = true
        let reverseTrigger = input.isShiftHold || input.isOptionHold
        updated = reverseTrigger ? ctlCandidate.showPreviousLine() : ctlCandidate.showNextLine()
        if !updated { errorCallback?("66F3477B") }
        return true
      case .option where state.type == .ofSymbolTable:
        // 繞過內碼輸入模式，直接進入漢音鍵盤符號模式。
        return revolveTypingMethod(to: .haninKeyboardSymbol)
      default: break
      }
    }

    // MARK: 選字窗內使用熱鍵升權、降權、刪詞。

    manipulator: if state.type == .ofCandidates {
      let candidates = state.candidates
      let highlightedIndex = ctlCandidate.highlightedIndex
      let isFilter = input.isDelete || input.isBackSpace
      if !(0 ..< candidates.count).contains(ctlCandidate.highlightedIndex) { break manipulator }
      if !prefs.allowBoostingSingleKanjiAsUserPhrase || isFilter {
        if candidates[highlightedIndex].keyArray.count < 2 || candidates[highlightedIndex].value
          .count < 2 {
          break manipulator
        }
      }
      let action: CandidateContextMenuAction? = switch input.commonKeyModifierFlags {
      case [.option, .command] where input.keyCode == 27: .toNerf // 減號鍵
      case [.option, .command] where input.keyCode == 24: .toBoost // 英數鍵盤的等號加號鍵；JIS 鍵盤的 ^ 號鍵。
      case _ where input.isOptionHold && input.isCommandHold && input.isDelete: .toFilter
      case _ where input.isOptionHold && input.isCommandHold && input.isBackSpace: .toFilter
      default: nil
      }
      guard let action else { break manipulator }
      session.candidatePairManipulated(at: highlightedIndex, action: action)
      return true
    }

    // MARK: 簡碼候選時對 BackSpace 的特殊處理

    if input.isBackSpace, prefs.cassetteEnabled, state.type == .ofInputting {
      return handleBackSpace(input: input)
    }

    // MARK: 取消選字 (Cancel Candidate)

    let dismissingCandidateWindow =
      input.isBackSpace || input.isEsc || input.isDelete
        ||
        (
          (input.isCursorBackward || input.isCursorForward) && input
            .commonKeyModifierFlags == .shift
        )

    if dismissingCandidateWindow {
      if state.type == .ofAssociates
        || prefs.useSCPCTypingMode
        || assembler.isEmpty {
        // 如果此時發現當前組字緩衝區為真空的情況的話，
        // 就將當前的組字緩衝區析構處理、強制重設輸入狀態。
        // 否則，一個本不該出現的真空組字緩衝區會使前後方向鍵與 BackSpace 鍵失靈。
        // 所以這裡需要對 compositor.isEmpty 做判定。
        session.switchState(State.ofAbortion())
      } else {
        session.switchState(generateStateOfInputting())
        if input.isCursorBackward || input.isCursorForward, input.commonKeyModifierFlags == .shift {
          return triageInput(event: input)
        }
      }
      if state.type == .ofSymbolTable, let nodePrevious = state.node.previous,
         !nodePrevious.members.isEmpty {
        session.switchState(State.ofSymbolTable(node: nodePrevious))
      }
      return true
    }

    // MARK: 批次集中處理某些常用功能鍵

    func confirmHighlightedCandidate() {
      session.candidatePairSelectionConfirmed(at: ctlCandidate.highlightedIndex)
    }

    if let keyCodeType = KeyCode(rawValue: input.keyCode) {
      switch keyCodeType {
      case .kCarriageReturn, .kLineFeed:
        if state.type == .ofAssociates,
           !(input.isShiftHold || prefs.alsoConfirmAssociatedCandidatesByEnter) {
          session.switchState(State.ofAbortion())
          return true
        }
        var handleAssociates = !prefs.useSCPCTypingMode && prefs
          .associatedPhrasesEnabled // 關聯詞語功能專用。
        handleAssociates = handleAssociates && assembler.cursor == assembler.length // 關聯詞語功能專用。
        confirmHighlightedCandidate()
        // 關聯詞語。
        associatedPhrases: if handleAssociates {
          guard handleAssociates else { break associatedPhrases }
          guard input.commonKeyModifierFlags == .shift else { break associatedPhrases }
          let pair = KeyValuePaired(
            keyArray: highlightedCandidate.keyArray, value: highlightedCandidate.value
          )
          let associatedCandidates = generateArrayOfAssociates(withPair: pair)
          guard !associatedCandidates.isEmpty else { break associatedPhrases }
          session.switchState(State.ofCommitting(textToCommit: state.displayedText))
          session.switchState(State.ofAssociates(candidates: associatedCandidates))
        }
        return true
      case .kTab:
        let updated: Bool =
          prefs.specifyShiftTabKeyBehavior
            ? (
              input.isShiftHold
                ? ctlCandidate.showPreviousLine()
                : ctlCandidate.showNextLine()
            )
            : (
              input.isShiftHold
                ? ctlCandidate.highlightPreviousCandidate()
                : ctlCandidate.highlightNextCandidate()
            )
        _ = updated ? {}() : errorCallback?("9B691919")
        return true
      case .kSpace where state.type != .ofInputting:
        guard !(prefs.useSpaceToCommitHighlightedSCPCCandidate && prefs.useSCPCTypingMode) else {
          confirmHighlightedCandidate()
          return true
        }
        let updated: Bool =
          prefs.specifyShiftSpaceKeyBehavior
            ? (
              input.isShiftHold
                ? ctlCandidate.highlightNextCandidate()
                : ctlCandidate.showNextLine()
            )
            : (
              input.isShiftHold
                ? ctlCandidate.showNextLine()
                : ctlCandidate.highlightNextCandidate()
            )
        _ = updated ? {}() : errorCallback?("A11C781F")
        return true
      case .kPageDown:
        _ = ctlCandidate.showNextPage() ? {}() : errorCallback?("9B691919")
        return true
      case .kPageUp:
        _ = ctlCandidate.showPreviousPage() ? {}() : errorCallback?("9569955D")
        return true
      case .kDownArrow, .kLeftArrow, .kRightArrow, .kUpArrow:
        switch input.commonKeyModifierFlags {
        case [.option, .shift] where allowMovingCompositorCursor && input.isCursorForward:
          if assembler.moveCursorStepwise(to: .front) {
            session.switchState(generateStateOfCandidates())
          } else {
            errorCallback?("D3006C85")
          }
          return true
        case [.option, .shift] where allowMovingCompositorCursor && input.isCursorBackward:
          if assembler.moveCursorStepwise(to: .rear) {
            session.switchState(generateStateOfCandidates())
          } else {
            errorCallback?("DE9DAF0D")
          }
          return true
        case .option where input.isCursorForward:
          if assembler.cursor < assembler.length {
            assembler.jumpCursorBySegment(to: .front)
            session.switchState(generateStateOfCandidates())
          } else {
            errorCallback?("5D9F4819")
          }
          return true
        case .option where input.isCursorBackward:
          if assembler.cursor > 0 {
            assembler.jumpCursorBySegment(to: .rear)
            session.switchState(generateStateOfCandidates())
          } else {
            errorCallback?("34B6322D")
          }
          return true
        default:
          #if canImport(AppKit)
            handleArrowKey: switch (keyCodeType, ctlCandidate.currentLayout) {
            case (.kLeftArrow, .horizontal), (.kUpArrow, .vertical): // Previous Candidate
              _ = ctlCandidate.highlightPreviousCandidate()
            case (.kDownArrow, .vertical), // Next Candidate
                 (.kRightArrow, .horizontal): // Next Candidate
              _ = ctlCandidate.highlightNextCandidate()
            case (.kLeftArrow, .vertical), // Previous Line
                 (.kUpArrow, .horizontal): // Previous Line
              _ = ctlCandidate.showPreviousLine()
            case (.kDownArrow, .horizontal), (.kRightArrow, .vertical): // Next Line
              _ = ctlCandidate.showNextLine()
            default: break handleArrowKey
            }
          #else
            // 非 macOS 平台暫時僅支援橫書模式。
            switch keyCodeType {
            case .kLeftArrow, .kUpArrow:
              _ = ctlCandidate.highlightPreviousCandidate()
            case .kDownArrow, .kRightArrow:
              _ = ctlCandidate.highlightNextCandidate()
            default: break
            }
          #endif
          return true
        }
      case .kHome:
        _ =
          (ctlCandidate.highlightedIndex == 0)
            ? errorCallback?("9B6EDE8D") : (ctlCandidate.highlightedIndex = 0)
        return true
      case .kEnd:
        let maxIndex = state.candidates.count - 1
        _ =
          (ctlCandidate.highlightedIndex == maxIndex)
            ? errorCallback?("9B69AAAD") : (ctlCandidate.highlightedIndex = maxIndex)
        return true
      default: break
      }
    }

    // MARK: J / K / H / L 鍵組字區的游標移動行為處理

    let allowMovinCursorByJK = allowMovingCompositorCursor && prefs
      .useJKtoMoveCompositorCursorInCandidateState
    let allowMovingCursorByHL = allowMovingCompositorCursor && prefs
      .useHLtoMoveCompositorCursorInCandidateState

    checkMovingCompositorCursorByJKHL: if allowMovinCursorByJK || allowMovingCursorByHL {
      guard input.keyModifierFlags.isEmpty else { break checkMovingCompositorCursorByJKHL }
      // keycode: 38 = J, 40 = K, 4 = H, 37 = L.
      switch input.keyCode {
      case 38 where allowMovinCursorByJK, 4 where allowMovingCursorByHL:
        if assembler.moveCursorStepwise(to: .rear) {
          session.switchState(generateStateOfCandidates())
        } else {
          errorCallback?("6F389AE9")
        }
        return true
      case 40 where allowMovinCursorByJK, 37 where allowMovingCursorByHL:
        if assembler.moveCursorStepwise(to: .front) {
          session.switchState(generateStateOfCandidates())
        } else {
          errorCallback?("EDBD27F2")
        }
        return true
      default: break checkMovingCompositorCursorByJKHL
      }
    }

    // MARK: 關聯詞語處理 (Associated Phrases) 以及標準選字處理

    if state.type == .ofAssociates, !input.isShiftHold { return false }

    var index: Int?
    var shaltShiftHold = [.ofAssociates].contains(state.type)
    if state.type == .ofInputting {
      let cassetteShift = currentLM.areCassetteCandidateKeysShiftHeld
      shaltShiftHold = shaltShiftHold || cassetteShift
    }
    let matched: String = (shaltShiftHold ? input.inputTextIgnoringModifiers ?? "" : inputText)
      .lowercased()
    // 如果允許 J / K 鍵前後移動組字區游標的話，則不再將 J / K 鍵盤視為選字鍵。
    if !(prefs.useJKtoMoveCompositorCursorInCandidateState && "jk".contains(matched)) {
      checkSelectionKey: for keyPair in session.selectionKeys.enumerated() {
        guard matched == keyPair.element.lowercased() else { continue }
        index = Int(keyPair.offset)
        break checkSelectionKey
      }
    }
    // 如果允許 H / L 鍵前後移動組字區游標的話，則不再將 H / L 鍵盤視為選字鍵。
    if !(prefs.useHLtoMoveCompositorCursorInCandidateState && "hl".contains(matched)) {
      checkSelectionKey: for keyPair in session.selectionKeys.enumerated() {
        guard matched == keyPair.element.lowercased() else { continue }
        index = Int(keyPair.offset)
        break checkSelectionKey
      }
    }

    // 標準選字處理
    if let index = index, let candidateIndex = ctlCandidate.candidateIndexAtKeyLabelIndex(index) {
      session.candidatePairSelectionConfirmed(at: candidateIndex)
      return true
    }

    if state.type == .ofAssociates { return false }

    // MARK: 逐字選字模式的處理 (SCPC Mode Processing)

    // 這裡得排除掉 .ofInputting 模式，否則會在有 `%quick` 結果的情況下無法正常鍵入一個完整的漢字讀音/字根。
    if prefs.useSCPCTypingMode, state.type != .ofInputting {
      /// 檢查：
      /// - 是否是針對當前注音排列/拼音輸入種類專門提供的標點符號。
      /// - 是否是需要摁修飾鍵才可以輸入的那種標點符號。

      let punctuationNamePrefix: String = generatePunctuationNamePrefix(withKeyCondition: input)
      let parser = currentKeyboardParser
      let arrCustomPunctuations: [String] = [
        punctuationNamePrefix, parser, inputText,
      ]
      let customPunctuation: String = arrCustomPunctuations.joined()

      /// 看看這個輸入是否是不需要修飾鍵的那種標點鍵輸入。

      let arrPunctuations: [String] = [
        punctuationNamePrefix, inputText,
      ]
      let punctuation: String = arrPunctuations.joined()

      let isInputValid: Bool =
        prefs.cassetteEnabled
          ? currentLM.isThisCassetteKeyAllowed(key: inputText) : composer
          .inputValidityCheck(key: input.charCode)

      var shouldAutoSelectCandidate: Bool =
        isInputValid || currentLM.hasUnigramsFor(keyArray: [customPunctuation])
          || currentLM.hasUnigramsFor(keyArray: [punctuation])

      if !shouldAutoSelectCandidate, input.isUpperCaseASCIILetterKey {
        let letter = "_letter_\(inputText)"
        if currentLM.hasUnigramsFor(keyArray: [letter]) { shouldAutoSelectCandidate = true }
      }

      if shouldAutoSelectCandidate {
        confirmHighlightedCandidate() // 此时的高亮候選字是第一個候選字。
        session.switchState(State.ofAbortion())
        return triageInput(event: input)
      }
    }

    // MARK: Flipping pages by using modified bracket keys (when they are not occupied).

    // Shift+Command+[] 被 Chrome 系瀏覽器佔用，所以改用 Ctrl。
    let ctrlCMD: Bool = input.commonKeyModifierFlags == [.control, .command]
    let ctrlShiftCMD: Bool = input.commonKeyModifierFlags == [.control, .command, .shift]
    if ctrlShiftCMD || ctrlCMD {
      // 此處 JIS 鍵盤判定無法用於螢幕鍵盤。所以，螢幕鍵盤的場合，系統會依照 US 鍵盤的判定方案。
      switch (input.keyCode, isJISKeyboard?() ?? false) {
      case (30, true), (33, false):
        _ = ctlCandidate.highlightPreviousCandidate() ? {}() : errorCallback?("8B144DCD")
        return true
      case (30, false), (42, true):
        _ = ctlCandidate.highlightNextCandidate() ? {}() : errorCallback?("D2ABB507")
        return true
      default: break
      }
    }

    if state.type == .ofInputting { return false } // `%quick`

    errorCallback?("172A0F81")
    return true
  }
}
