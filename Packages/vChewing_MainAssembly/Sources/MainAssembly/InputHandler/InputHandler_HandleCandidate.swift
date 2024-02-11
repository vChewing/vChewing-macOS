// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃輸入調度模組當中「用來規定在選字窗出現時的按鍵行為」的部分。

import CandidateWindow
import CocoaExtension
import InputMethodKit
import Megrez
import Shared

// MARK: - § 對選字狀態進行調度 (Handle Candidate State).

extension InputHandler {
  /// 當且僅當選字窗出現時，對於經過初次篩選處理的輸入訊號的處理均藉由此函式來進行。
  /// - Parameters:
  ///   - input: 輸入訊號。
  ///   - ignoringModifiers: 是否需要忽視修飾鍵。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleCandidate(input: InputSignalProtocol, ignoringModifiers: Bool = false) -> Bool {
    guard let delegate = delegate else { return false }
    guard var ctlCandidate = delegate.candidateController() else { return false }
    let state = delegate.state
    guard state.isCandidateContainer else { return false } // 會自動判斷「isEmpty」。
    guard ctlCandidate.visible else { return false }
    let inputText = ignoringModifiers ? (input.inputTextIgnoringModifiers ?? input.text) : input.text

    // MARK: 選字窗內使用熱鍵升權、降權、刪詞。

    manipulator: if (delegate as? CtlCandidateDelegate)?.isCandidateContextMenuEnabled ?? false {
      let candidates = state.candidates
      let highlightedIndex = ctlCandidate.highlightedIndex
      if !(0 ..< candidates.count).contains(ctlCandidate.highlightedIndex) { break manipulator }
      if candidates[highlightedIndex].keyArray.count < 2 || candidates[highlightedIndex].value.count < 2 {
        break manipulator
      }
      switch input.commonKeyModifierFlags {
      case [.option, .command] where input.keyCode == 27: // 減號鍵
        ctlCandidate.delegate?.candidatePairRightClicked(at: highlightedIndex, action: .toNerf)
        return true
      case [.option, .command] where input.keyCode == 24: // 英數鍵盤的等號加號鍵；JIS 鍵盤的 ^ 號鍵。
        ctlCandidate.delegate?.candidatePairRightClicked(at: highlightedIndex, action: .toBoost)
        return true
      case _ where input.isOptionHold && input.isCommandHold && input.isDelete:
        ctlCandidate.delegate?.candidatePairRightClicked(at: highlightedIndex, action: .toFilter)
        return true
      default: break
      }
    }

    // MARK: 簡碼候選時對 BackSpace 的特殊處理

    if input.isBackSpace, prefs.cassetteEnabled, state.type == .ofInputting {
      return handleBackSpace(input: input)
    }

    // MARK: 取消選字 (Cancel Candidate)

    let dismissingCandidateWindow =
      input.isBackSpace || input.isEsc || input.isDelete
        || ((input.isCursorBackward || input.isCursorForward) && input.commonKeyModifierFlags == .shift)

    if dismissingCandidateWindow {
      if state.type == .ofAssociates
        || prefs.useSCPCTypingMode
        || compositor.isEmpty
      {
        // 如果此時發現當前組字緩衝區為真空的情況的話，
        // 就將當前的組字緩衝區析構處理、強制重設輸入狀態。
        // 否則，一個本不該出現的真空組字緩衝區會使前後方向鍵與 BackSpace 鍵失靈。
        // 所以這裡需要對 compositor.isEmpty 做判定。
        delegate.switchState(IMEState.ofAbortion())
      } else {
        delegate.switchState(generateStateOfInputting())
        if input.isCursorBackward || input.isCursorForward, input.commonKeyModifierFlags == .shift {
          return triageInput(event: input)
        }
      }
      if state.type == .ofSymbolTable, let nodePrevious = state.node.previous, !nodePrevious.members.isEmpty {
        delegate.switchState(IMEState.ofSymbolTable(node: nodePrevious))
      }
      return true
    }

    // MARK: 批次集中處理某些常用功能鍵

    func confirmHighlightedCandidate() {
      delegate.candidateSelectionConfirmedByInputHandler(at: ctlCandidate.highlightedIndex)
    }

    if let keyCodeType = KeyCode(rawValue: input.keyCode) {
      switch keyCodeType {
      case .kLineFeed, .kCarriageReturn:
        if state.type == .ofAssociates, !(input.isShiftHold || prefs.alsoConfirmAssociatedCandidatesByEnter) {
          delegate.switchState(IMEState.ofAbortion())
          return true
        }
        let highlightedCandidate = state.candidates[ctlCandidate.highlightedIndex] // 關聯詞語功能專用。
        var handleAssociates = !prefs.useSCPCTypingMode && prefs.associatedPhrasesEnabled // 關聯詞語功能專用。
        handleAssociates = handleAssociates && compositor.cursor == compositor.length // 關聯詞語功能專用。
        confirmHighlightedCandidate()
        // 關聯詞語。
        associatedPhrases: if handleAssociates {
          guard handleAssociates else { break associatedPhrases }
          guard input.commonKeyModifierFlags == .shift else { break associatedPhrases }
          let pair = Megrez.KeyValuePaired(
            keyArray: highlightedCandidate.keyArray, value: highlightedCandidate.value
          )
          let associatedCandidates = generateArrayOfAssociates(withPair: pair)
          guard !associatedCandidates.isEmpty else { break associatedPhrases }
          delegate.switchState(IMEState.ofCommitting(textToCommit: state.displayedText))
          delegate.switchState(IMEState.ofAssociates(candidates: associatedCandidates))
        }
        return true
      case .kTab:
        let updated: Bool =
          prefs.specifyShiftTabKeyBehavior
            ? (input.isShiftHold
              ? ctlCandidate.showPreviousLine()
              : ctlCandidate.showNextLine())
            : (input.isShiftHold
              ? ctlCandidate.highlightPreviousCandidate()
              : ctlCandidate.highlightNextCandidate())
        _ = updated ? {}() : delegate.callError("9B691919")
        return true
      case .kSpace where state.type != .ofInputting:
        guard !(prefs.useSpaceToCommitHighlightedSCPCCandidate && prefs.useSCPCTypingMode) else {
          confirmHighlightedCandidate()
          return true
        }
        let updated: Bool =
          prefs.specifyShiftSpaceKeyBehavior
            ? (input.isShiftHold
              ? ctlCandidate.highlightNextCandidate()
              : ctlCandidate.showNextLine())
            : (input.isShiftHold
              ? ctlCandidate.showNextLine()
              : ctlCandidate.highlightNextCandidate())
        _ = updated ? {}() : delegate.callError("A11C781F")
        return true
      case .kPageDown:
        _ = ctlCandidate.showNextPage() ? {}() : delegate.callError("9B691919")
        return true
      case .kPageUp:
        _ = ctlCandidate.showPreviousPage() ? {}() : delegate.callError("9569955D")
        return true
      case .kUpArrow, .kDownArrow, .kLeftArrow, .kRightArrow:
        switch input.commonKeyModifierFlags {
        case [.option, .shift] where input.isCursorForward:
          if compositor.cursor < compositor.length {
            compositor.cursor += 1
            if isCursorCuttingChar() { compositor.jumpCursorBySpan(to: .front) }
            delegate.switchState(generateStateOfCandidates())
          } else {
            delegate.callError("D3006C85")
          }
          return true
        case [.option, .shift] where input.isCursorBackward:
          if compositor.cursor > 0 {
            compositor.cursor -= 1
            if isCursorCuttingChar() { compositor.jumpCursorBySpan(to: .rear) }
            delegate.switchState(generateStateOfCandidates())
          } else {
            delegate.callError("DE9DAF0D")
          }
          return true
        case .option where input.isCursorForward:
          if compositor.cursor < compositor.length {
            compositor.jumpCursorBySpan(to: .front)
            delegate.switchState(generateStateOfCandidates())
          } else {
            delegate.callError("5D9F4819")
          }
          return true
        case .option where input.isCursorBackward:
          if compositor.cursor > 0 {
            compositor.jumpCursorBySpan(to: .rear)
            delegate.switchState(generateStateOfCandidates())
          } else {
            delegate.callError("34B6322D")
          }
          return true
        default:
          handleArrowKey: switch (keyCodeType, ctlCandidate.currentLayout) {
          case (.kLeftArrow, .horizontal), (.kUpArrow, .vertical): // Previous Candidate
            _ = ctlCandidate.highlightPreviousCandidate()
          case (.kRightArrow, .horizontal), (.kDownArrow, .vertical): // Next Candidate
            _ = ctlCandidate.highlightNextCandidate()
          case (.kUpArrow, .horizontal), (.kLeftArrow, .vertical): // Previous Line
            _ = ctlCandidate.showPreviousLine()
          case (.kDownArrow, .horizontal), (.kRightArrow, .vertical): // Next Line
            _ = ctlCandidate.showNextLine()
          default: break handleArrowKey
          }
          return true
        }
      case .kHome:
        _ =
          (ctlCandidate.highlightedIndex == 0)
            ? delegate.callError("9B6EDE8D") : (ctlCandidate.highlightedIndex = 0)
        return true
      case .kEnd:
        let maxIndex = state.candidates.count - 1
        _ =
          (ctlCandidate.highlightedIndex == maxIndex)
            ? delegate.callError("9B69AAAD") : (ctlCandidate.highlightedIndex = maxIndex)
        return true
      default: break
      }
    }

    // MARK: 關聯詞語處理 (Associated Phrases) 以及標準選字處理

    if state.type == .ofAssociates, !input.isShiftHold { return false }

    var index: Int?
    var shaltShiftHold = [.ofAssociates].contains(state.type)
    if [.ofInputting].contains(state.type) {
      let cassetteShift = currentLM.areCassetteCandidateKeysShiftHeld
      shaltShiftHold = shaltShiftHold || cassetteShift
    }
    let matched: String = shaltShiftHold ? input.inputTextIgnoringModifiers ?? "" : inputText
    checkSelectionKey: for keyPair in delegate.selectionKeys.enumerated() {
      guard matched.lowercased() == keyPair.element.lowercased() else { continue }
      index = Int(keyPair.offset)
      break checkSelectionKey
    }

    // 標準選字處理
    if let index = index, let candidateIndex = ctlCandidate.candidateIndexAtKeyLabelIndex(index) {
      delegate.candidateSelectionConfirmedByInputHandler(at: candidateIndex)
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
          ? currentLM.isThisCassetteKeyAllowed(key: inputText) : composer.inputValidityCheck(key: input.charCode)

      var shouldAutoSelectCandidate: Bool =
        isInputValid || currentLM.hasUnigramsFor(keyArray: [customPunctuation])
          || currentLM.hasUnigramsFor(keyArray: [punctuation])

      if !shouldAutoSelectCandidate, input.isUpperCaseASCIILetterKey {
        let letter = "_letter_\(inputText)"
        if currentLM.hasUnigramsFor(keyArray: [letter]) { shouldAutoSelectCandidate = true }
      }

      if shouldAutoSelectCandidate {
        confirmHighlightedCandidate() // 此時的高亮候選字是第一個候選字。
        delegate.switchState(IMEState.ofAbortion())
        return triageInput(event: input)
      }
    }

    // MARK: - Flipping pages by using modified bracket keys (when they are not occupied).

    // Shift+Command+[] 被 Chrome 系瀏覽器佔用，所以改用 Ctrl。
    let ctrlCMD: Bool = input.commonKeyModifierFlags == [.control, .command]
    let ctrlShiftCMD: Bool = input.commonKeyModifierFlags == [.control, .command, .shift]
    if ctrlShiftCMD || ctrlCMD {
      // 此處 JIS 鍵盤判定無法用於螢幕鍵盤。所以，螢幕鍵盤的場合，系統會依照 US 鍵盤的判定方案。
      switch (input.keyCode, IMEApp.isKeyboardJIS) {
      case (30, true), (33, false):
        _ = ctlCandidate.highlightPreviousCandidate() ? {}() : delegate.callError("8B144DCD")
        return true
      case (42, true), (30, false):
        _ = ctlCandidate.highlightNextCandidate() ? {}() : delegate.callError("D2ABB507")
        return true
      default: break
      }
    }

    // MARK: - Flipping pages by using symbol menu keys (when they are not occupied).

    if input.isSymbolMenuPhysicalKey {
      switch input.commonKeyModifierFlags {
      case .shift, [],
           .option where state.type != .ofSymbolTable:
        var updated = true
        let reverseTrigger = input.isShiftHold || input.isOptionHold
        updated = reverseTrigger ? ctlCandidate.showPreviousLine() : ctlCandidate.showNextLine()
        if !updated { delegate.callError("66F3477B") }
        return true
      case .option where state.type == .ofSymbolTable:
        // 繞過內碼輸入模式，直接進入漢音鍵盤符號模式。
        return revolveTypingMethod(to: .haninKeyboardSymbol)
      default: break
      }
    }

    if state.type == .ofInputting { return false } // `%quick`

    delegate.callError("172A0F81")
    return true
  }
}
