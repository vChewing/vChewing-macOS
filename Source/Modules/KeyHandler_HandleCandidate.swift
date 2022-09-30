// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃按鍵調度模組當中「用來規定在選字窗出現時的按鍵行為」的部分。

import CandidateWindow
import Shared

// MARK: - § 對選字狀態進行調度 (Handle Candidate State).

extension KeyHandler {
  /// 當且僅當選字窗出現時，對於經過初次篩選處理的輸入訊號的處理均藉由此函式來進行。
  /// - Parameters:
  ///   - input: 輸入訊號。
  ///   - state: 給定狀態（通常為當前狀態）。
  ///   - stateCallback: 狀態回呼，交給對應的型別內的專有函式來處理。
  ///   - errorCallback: 錯誤回呼。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleCandidate(
    state: IMEStateProtocol,
    input: InputSignalProtocol,
    stateCallback: @escaping (IMEStateProtocol) -> Void,
    errorCallback: @escaping (String) -> Void
  ) -> Bool {
    guard var ctlCandidate = delegate?.candidateController() else {
      errorCallback("06661F6E")
      return true
    }

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
        stateCallback(IMEState.ofAbortion())
      } else {
        stateCallback(buildInputtingState)
      }
      if state.type == .ofSymbolTable, let nodePrevious = state.node.previous, !nodePrevious.members.isEmpty {
        stateCallback(IMEState.ofSymbolTable(node: nodePrevious))
      }
      return true
    }

    // MARK: Enter

    if input.isEnter {
      if state.type == .ofAssociates, !prefs.alsoConfirmAssociatedCandidatesByEnter {
        stateCallback(IMEState.ofAbortion())
        return true
      }
      delegate?.candidateSelectionCalledByKeyHandler(at: ctlCandidate.selectedCandidateIndex)
      return true
    }

    // MARK: Tab

    if input.isTab {
      let updated: Bool =
        prefs.specifyShiftTabKeyBehavior
        ? (input.isShiftHold
          ? ctlCandidate.showPreviousLine()
          : ctlCandidate.showNextLine())
        : (input.isShiftHold
          ? ctlCandidate.highlightPreviousCandidate()
          : ctlCandidate.highlightNextCandidate())
      if !updated {
        errorCallback("9B691919")
      }
      return true
    }

    // MARK: Space

    if input.isSpace {
      let updated: Bool =
        prefs.specifyShiftSpaceKeyBehavior
        ? (input.isShiftHold
          ? ctlCandidate.highlightNextCandidate()
          : ctlCandidate.showNextLine())
        : (input.isShiftHold
          ? ctlCandidate.showNextLine()
          : ctlCandidate.highlightNextCandidate())
      if !updated {
        errorCallback("A11C781F")
      }
      return true
    }

    // MARK: PgDn

    if input.isPageDown {
      let updated: Bool = ctlCandidate.showNextPage()
      if !updated {
        errorCallback("9B691919")
      }
      return true
    }

    // MARK: PgUp

    if input.isPageUp {
      let updated: Bool = ctlCandidate.showPreviousPage()
      if !updated {
        errorCallback("9569955D")
      }
      return true
    }

    // MARK: Left Arrow

    if input.isLeft {
      switch ctlCandidate.currentLayout {
        case .horizontal:
          if !ctlCandidate.highlightPreviousCandidate() {
            errorCallback("1145148D")
          }
        case .vertical:
          if !ctlCandidate.showPreviousLine() {
            errorCallback("1919810D")
          }
        @unknown default:
          break
      }
      return true
    }

    // MARK: Right Arrow

    if input.isRight {
      switch ctlCandidate.currentLayout {
        case .horizontal:
          if !ctlCandidate.highlightNextCandidate() {
            errorCallback("9B65138D")
          }
        case .vertical:
          if !ctlCandidate.showNextLine() {
            errorCallback("9244908D")
          }
        @unknown default:
          break
      }
      return true
    }

    // MARK: Up Arrow

    if input.isUp {
      switch ctlCandidate.currentLayout {
        case .horizontal:
          if !ctlCandidate.showPreviousLine() {
            errorCallback("9B614524")
          }
        case .vertical:
          if !ctlCandidate.highlightPreviousCandidate() {
            errorCallback("ASD9908D")
          }
        @unknown default:
          break
      }
      return true
    }

    // MARK: Down Arrow

    if input.isDown {
      switch ctlCandidate.currentLayout {
        case .horizontal:
          if !ctlCandidate.showNextLine() {
            errorCallback("92B990DD")
            break
          }
        case .vertical:
          if !ctlCandidate.highlightNextCandidate() {
            errorCallback("6B99908D")
          }
        @unknown default:
          break
      }
      return true
    }

    // MARK: Home Key

    if input.isHome {
      if ctlCandidate.selectedCandidateIndex == 0 {
        errorCallback("9B6EDE8D")
      } else {
        ctlCandidate.selectedCandidateIndex = 0
      }

      return true
    }

    // MARK: End Key

    if state.candidates.isEmpty {
      return false
    } else {  // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
      if input.isEnd {
        if ctlCandidate.selectedCandidateIndex == state.candidates.count - 1 {
          errorCallback("9B69AAAD")
        } else {
          ctlCandidate.selectedCandidateIndex = state.candidates.count - 1
        }
        return true
      }
    }

    // MARK: 聯想詞處理 (Associated Phrases)

    if state.type == .ofAssociates {
      if !input.isShiftHold { return false }
    }

    var index: Int = NSNotFound
    let match: String =
      (state.type == .ofAssociates) ? input.inputTextIgnoringModifiers ?? "" : input.text

    for j in 0..<ctlCandidate.keyLabels.count {
      let label: CandidateCellData = ctlCandidate.keyLabels[j]
      if match.compare(label.key, options: .caseInsensitive, range: nil, locale: .current) == .orderedSame {
        index = j
        break
      }
    }

    if index != NSNotFound {
      let candidateIndex = ctlCandidate.candidateIndexAtKeyLabelIndex(index)
      if candidateIndex != Int.max {
        delegate?.candidateSelectionCalledByKeyHandler(at: candidateIndex)
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

      var shouldAutoSelectCandidate: Bool =
        composer.inputValidityCheck(key: input.charCode) || currentLM.hasUnigramsFor(key: customPunctuation)
        || currentLM.hasUnigramsFor(key: punctuation)

      if !shouldAutoSelectCandidate, input.isUpperCaseASCIILetterKey {
        let letter = "_letter_\(input.text)"
        if currentLM.hasUnigramsFor(key: letter) { shouldAutoSelectCandidate = true }
      }

      if shouldAutoSelectCandidate {
        let candidateIndex = ctlCandidate.candidateIndexAtKeyLabelIndex(0)
        if candidateIndex != Int.max {
          delegate?.candidateSelectionCalledByKeyHandler(at: candidateIndex)
          stateCallback(IMEState.ofAbortion())
          return handle(
            input: input, state: IMEState.ofEmpty(), stateCallback: stateCallback, errorCallback: errorCallback
          )
        }
        return true
      }
    }

    // MARK: - Flipping pages by using symbol menu keys (when they are not occupied).

    if input.isSymbolMenuPhysicalKey {
      var updated = true
      updated = input.isShiftHold ? ctlCandidate.showPreviousLine() : ctlCandidate.showNextLine()
      if !updated {
        errorCallback("66F3477B")
      }
      return true
    }

    errorCallback("172A0F81")
    return true
  }
}
