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
import Shared

// MARK: - § 對選字狀態進行調度 (Handle Candidate State).

extension InputHandler {
  /// 當且僅當選字窗出現時，對於經過初次篩選處理的輸入訊號的處理均藉由此函式來進行。
  /// - Parameters:
  ///   - input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleCandidate(input: InputSignalProtocol) -> Bool {
    guard let delegate = delegate else { return false }
    guard var ctlCandidate = delegate.candidateController() else { return false }
    let state = delegate.state
    guard !state.candidates.isEmpty else { return false }

    // MARK: 取消選字 (Cancel Candidate)

    let cancelCandidateKey =
      input.isBackSpace || input.isEsc || input.isDelete
      || ((input.isCursorBackward || input.isCursorForward) && input.isShiftHold)

    if cancelCandidateKey {
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
      }
      if state.type == .ofSymbolTable, let nodePrevious = state.node.previous, !nodePrevious.members.isEmpty {
        delegate.switchState(IMEState.ofSymbolTable(node: nodePrevious))
      }
      return true
    }

    // MARK: 批次集中處理某些常用功能鍵

    if let keyCodeType = KeyCode(rawValue: input.keyCode) {
      switch keyCodeType {
        case .kLineFeed, .kCarriageReturn:
          if state.type == .ofAssociates, !prefs.alsoConfirmAssociatedCandidatesByEnter {
            delegate.switchState(IMEState.ofAbortion())
            return true
          }
          delegate.candidateSelectionCalledByInputHandler(at: ctlCandidate.highlightedIndex)
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
        case .kSpace:
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
          handleArrowKey: switch (keyCodeType, ctlCandidate.currentLayout) {
            case (.kLeftArrow, .horizontal), (.kUpArrow, .vertical):  // Previous Candidate
              _ = ctlCandidate.highlightPreviousCandidate() ? {}() : delegate.callError("5548FD14")
            case (.kRightArrow, .horizontal), (.kDownArrow, .vertical):  // Next Candidate
              _ = ctlCandidate.highlightNextCandidate() ? {}() : delegate.callError("3CEFB82E")
            case (.kUpArrow, .horizontal), (.kLeftArrow, .vertical):  // Previous Line
              _ = ctlCandidate.showPreviousLine() ? {}() : delegate.callError("827BBD79")
            case (.kDownArrow, .horizontal), (.kRightArrow, .vertical):  // Next Line
              _ = ctlCandidate.showNextLine() ? {}() : delegate.callError("7A0C7FBD")
            default: break handleArrowKey
          }
          return true
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

    // MARK: 聯想詞處理 (Associated Phrases) 以及標準選字處理

    if state.type == .ofAssociates {
      if !input.isShiftHold { return false }
    }

    var index: Int = NSNotFound
    let match: String =
      (state.type == .ofAssociates) ? input.inputTextIgnoringModifiers ?? "" : input.text

    let selectionKeys = delegate.selectionKeys

    for j in 0..<selectionKeys.count {
      let label = selectionKeys.charComponents[j]
      if match.compare(label, options: .caseInsensitive, range: nil, locale: .current) == .orderedSame {
        index = j
        break
      }
    }

    if index != NSNotFound {
      let candidateIndex = ctlCandidate.candidateIndexAtKeyLabelIndex(index)
      if candidateIndex != -114_514 {
        delegate.candidateSelectionCalledByInputHandler(at: candidateIndex)
        return true
      }
    }

    if state.type == .ofAssociates { return false }

    // MARK: 逐字選字模式的處理 (SCPC Mode Processing)

    if prefs.useSCPCTypingMode {
      /// 檢查：
      /// - 是否是針對當前注音排列/拼音輸入種類專門提供的標點符號。
      /// - 是否是需要摁修飾鍵才可以輸入的那種標點符號。

      let punctuationNamePrefix: String = generatePunctuationNamePrefix(withKeyCondition: input)
      let parser = currentKeyboardParser
      let arrCustomPunctuations: [String] = [
        punctuationNamePrefix, parser, input.text,
      ]
      let customPunctuation: String = arrCustomPunctuations.joined()

      /// 看看這個輸入是否是不需要修飾鍵的那種標點鍵輸入。

      let arrPunctuations: [String] = [
        punctuationNamePrefix, input.text,
      ]
      let punctuation: String = arrPunctuations.joined()

      let isInputValid: Bool =
        prefs.cassetteEnabled
        ? currentLM.isThisCassetteKeyAllowed(key: input.text) : composer.inputValidityCheck(key: input.charCode)

      var shouldAutoSelectCandidate: Bool =
        isInputValid || currentLM.hasUnigramsFor(key: customPunctuation)
        || currentLM.hasUnigramsFor(key: punctuation)

      if !shouldAutoSelectCandidate, input.isUpperCaseASCIILetterKey {
        let letter = "_letter_\(input.text)"
        if currentLM.hasUnigramsFor(key: letter) { shouldAutoSelectCandidate = true }
      }

      if shouldAutoSelectCandidate {
        let candidateIndex = ctlCandidate.candidateIndexAtKeyLabelIndex(0)
        if candidateIndex != -114_514 {
          delegate.candidateSelectionCalledByInputHandler(at: candidateIndex)
          delegate.switchState(IMEState.ofAbortion())
          return handleInput(event: input)
        }
        return true
      }
    }

    // MARK: - Flipping pages by using symbol menu keys (when they are not occupied).

    if input.isSymbolMenuPhysicalKey {
      var updated = true
      let reverseTrigger = input.isShiftHold || input.isOptionHold
      updated = reverseTrigger ? ctlCandidate.showPreviousLine() : ctlCandidate.showNextLine()
      if !updated { delegate.callError("66F3477B") }
      return true
    }

    delegate.callError("172A0F81")
    return true
  }
}
