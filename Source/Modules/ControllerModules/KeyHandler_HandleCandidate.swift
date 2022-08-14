// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃按鍵調度模組當中「用來規定在選字窗出現時的按鍵行為」的部分。

import Cocoa

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
    state: InputStateProtocol,
    input: InputSignal,
    stateCallback: @escaping (InputStateProtocol) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    let inputText = input.inputText
    let charCode: UniChar = input.charCode
    guard var ctlCandidateCurrent = delegate?.ctlCandidate() else {
      IME.prtDebugIntel("06661F6E")
      errorCallback()
      return true
    }

    // MARK: 取消選字 (Cancel Candidate)

    let cancelCandidateKey =
      input.isBackSpace || input.isEsc || input.isDelete
      || ((input.isCursorBackward || input.isCursorForward) && input.isShiftHold)

    if cancelCandidateKey {
      if state is InputState.AssociatedPhrases
        || mgrPrefs.useSCPCTypingMode
        || compositor.isEmpty
      {
        // 如果此時發現當前組字緩衝區為真空的情況的話，
        // 就將當前的組字緩衝區析構處理、強制重設輸入狀態。
        // 否則，一個本不該出現的真空組字緩衝區會使前後方向鍵與 BackSpace 鍵失靈。
        // 所以這裡需要對 compositor.isEmpty 做判定。
        stateCallback(InputState.EmptyIgnoringPreviousState())
        stateCallback(InputState.Empty())
      } else {
        stateCallback(buildInputtingState)
      }
      if let state = state as? InputState.SymbolTable, let nodePrevious = state.node.previous {
        stateCallback(InputState.SymbolTable(node: nodePrevious, isTypingVertical: state.isTypingVertical))
      }
      return true
    }

    // MARK: Enter

    if input.isEnter {
      if state is InputState.AssociatedPhrases, !mgrPrefs.alsoConfirmAssociatedCandidatesByEnter {
        stateCallback(InputState.EmptyIgnoringPreviousState())
        stateCallback(InputState.Empty())
        return true
      }
      delegate?.keyHandler(
        self,
        didSelectCandidateAt: ctlCandidateCurrent.selectedCandidateIndex,
        ctlCandidate: ctlCandidateCurrent
      )
      return true
    }

    // MARK: Tab

    if input.isTab {
      let updated: Bool =
        mgrPrefs.specifyShiftTabKeyBehavior
        ? (input.isShiftHold
          ? ctlCandidateCurrent.showPreviousPage()
          : ctlCandidateCurrent.showNextPage())
        : (input.isShiftHold
          ? ctlCandidateCurrent.highlightPreviousCandidate()
          : ctlCandidateCurrent.highlightNextCandidate())
      if !updated {
        IME.prtDebugIntel("9B691919")
        errorCallback()
      }
      return true
    }

    // MARK: Space

    if input.isSpace {
      let updated: Bool =
        mgrPrefs.specifyShiftSpaceKeyBehavior
        ? (input.isShiftHold
          ? ctlCandidateCurrent.highlightNextCandidate()
          : ctlCandidateCurrent.showNextPage())
        : (input.isShiftHold
          ? ctlCandidateCurrent.showNextPage()
          : ctlCandidateCurrent.highlightNextCandidate())
      if !updated {
        IME.prtDebugIntel("A11C781F")
        errorCallback()
      }
      return true
    }

    // MARK: PgDn

    if input.isPageDown || input.emacsKey == EmacsKey.nextPage {
      let updated: Bool = ctlCandidateCurrent.showNextPage()
      if !updated {
        IME.prtDebugIntel("9B691919")
        errorCallback()
      }
      return true
    }

    // MARK: PgUp

    if input.isPageUp {
      let updated: Bool = ctlCandidateCurrent.showPreviousPage()
      if !updated {
        IME.prtDebugIntel("9569955D")
        errorCallback()
      }
      return true
    }

    // MARK: Left Arrow

    if input.isLeft {
      switch ctlCandidateCurrent.currentLayout {
        case .horizontal:
          if !ctlCandidateCurrent.highlightPreviousCandidate() {
            IME.prtDebugIntel("1145148D")
            errorCallback()
          }
        case .vertical:
          if !ctlCandidateCurrent.showPreviousPage() {
            IME.prtDebugIntel("1919810D")
            errorCallback()
          }
      }
      return true
    }

    // MARK: EmacsKey Backward

    if input.emacsKey == EmacsKey.backward {
      let updated: Bool = ctlCandidateCurrent.highlightPreviousCandidate()
      if !updated {
        IME.prtDebugIntel("9B89308D")
        errorCallback()
      }
      return true
    }

    // MARK: Right Arrow

    if input.isRight {
      switch ctlCandidateCurrent.currentLayout {
        case .horizontal:
          if !ctlCandidateCurrent.highlightNextCandidate() {
            IME.prtDebugIntel("9B65138D")
            errorCallback()
          }
        case .vertical:
          if !ctlCandidateCurrent.showNextPage() {
            IME.prtDebugIntel("9244908D")
            errorCallback()
          }
      }
      return true
    }

    // MARK: EmacsKey Forward

    if input.emacsKey == EmacsKey.forward {
      let updated: Bool = ctlCandidateCurrent.highlightNextCandidate()
      if !updated {
        IME.prtDebugIntel("9B2428D")
        errorCallback()
      }
      return true
    }

    // MARK: Up Arrow

    if input.isUp {
      switch ctlCandidateCurrent.currentLayout {
        case .horizontal:
          if !ctlCandidateCurrent.showPreviousPage() {
            IME.prtDebugIntel("9B614524")
            errorCallback()
          }
        case .vertical:
          if !ctlCandidateCurrent.highlightPreviousCandidate() {
            IME.prtDebugIntel("ASD9908D")
            errorCallback()
          }
      }
      return true
    }

    // MARK: Down Arrow

    if input.isDown {
      switch ctlCandidateCurrent.currentLayout {
        case .horizontal:
          if !ctlCandidateCurrent.showNextPage() {
            IME.prtDebugIntel("92B990DD")
            errorCallback()
          }
        case .vertical:
          if !ctlCandidateCurrent.highlightNextCandidate() {
            IME.prtDebugIntel("6B99908D")
            errorCallback()
          }
      }
      return true
    }

    // MARK: Home Key

    if input.isHome || input.emacsKey == EmacsKey.home {
      if ctlCandidateCurrent.selectedCandidateIndex == 0 {
        IME.prtDebugIntel("9B6EDE8D")
        errorCallback()
      } else {
        ctlCandidateCurrent.selectedCandidateIndex = 0
      }

      return true
    }

    // MARK: End Key

    var candidates: [(String, String)]!

    if let state = state as? InputState.ChoosingCandidate {
      candidates = state.candidates
    } else if let state = state as? InputState.AssociatedPhrases {
      candidates = state.candidates
    }

    if candidates.isEmpty {
      return false
    } else {  // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
      if input.isEnd || input.emacsKey == EmacsKey.end {
        if ctlCandidateCurrent.selectedCandidateIndex == candidates.count - 1 {
          IME.prtDebugIntel("9B69AAAD")
          errorCallback()
        } else {
          ctlCandidateCurrent.selectedCandidateIndex = candidates.count - 1
        }
        return true
      }
    }

    // MARK: 聯想詞處理 (Associated Phrases)

    if state is InputState.AssociatedPhrases {
      if !input.isShiftHold { return false }
    }

    var index: Int = NSNotFound
    let match: String =
      (state is InputState.AssociatedPhrases) ? input.inputTextIgnoringModifiers ?? "" : inputText

    for j in 0..<ctlCandidateCurrent.keyLabels.count {
      let label: CandidateKeyLabel = ctlCandidateCurrent.keyLabels[j]
      if match.compare(label.key, options: .caseInsensitive, range: nil, locale: .current) == .orderedSame {
        index = j
        break
      }
    }

    if index != NSNotFound {
      let candidateIndex = ctlCandidateCurrent.candidateIndexAtKeyLabelIndex(index)
      if candidateIndex != Int.max {
        delegate?.keyHandler(
          self, didSelectCandidateAt: candidateIndex, ctlCandidate: ctlCandidateCurrent
        )
        return true
      }
    }

    if state is InputState.AssociatedPhrases { return false }

    // MARK: 逐字選字模式的處理 (SCPC Mode Processing)

    if mgrPrefs.useSCPCTypingMode {
      /// 檢查：
      /// - 是否是針對當前注音排列/拼音輸入種類專門提供的標點符號。
      /// - 是否是需要摁修飾鍵才可以輸入的那種標點符號。

      let punctuationNamePrefix: String = generatePunctuationNamePrefix(withKeyCondition: input)
      let parser = currentMandarinParser
      let arrCustomPunctuations: [String] = [
        punctuationNamePrefix, parser, String(format: "%c", charCode.isPrintableASCII ? CChar(charCode) : inputText),
      ]
      let customPunctuation: String = arrCustomPunctuations.joined(separator: "")

      /// 看看這個輸入是否是不需要修飾鍵的那種標點鍵輸入。

      let arrPunctuations: [String] = [
        punctuationNamePrefix, String(format: "%c", charCode.isPrintableASCII ? CChar(charCode) : inputText),
      ]
      let punctuation: String = arrPunctuations.joined(separator: "")

      var shouldAutoSelectCandidate: Bool =
        composer.inputValidityCheck(key: charCode) || currentLM.hasUnigramsFor(key: customPunctuation)
        || currentLM.hasUnigramsFor(key: punctuation)

      if !shouldAutoSelectCandidate, input.isUpperCaseASCIILetterKey {
        let letter: String! = String(
          format: "%@%c", "_letter_", charCode.isPrintableASCII ? CChar(charCode) : inputText
        )
        if currentLM.hasUnigramsFor(key: letter) { shouldAutoSelectCandidate = true }
      }

      if shouldAutoSelectCandidate {
        let candidateIndex = ctlCandidateCurrent.candidateIndexAtKeyLabelIndex(0)
        if candidateIndex != Int.max {
          delegate?.keyHandler(
            self,
            didSelectCandidateAt: candidateIndex,
            ctlCandidate: ctlCandidateCurrent
          )
          stateCallback(InputState.EmptyIgnoringPreviousState())
          stateCallback(InputState.Empty())
          return handle(
            input: input, state: InputState.Empty(), stateCallback: stateCallback, errorCallback: errorCallback
          )
        }
        return true
      }
    }

    // MARK: - Flipping pages by using symbol menu keys (when they are not occupied).

    if input.isSymbolMenuPhysicalKey {
      let updated: Bool =
        input.isShiftHold ? ctlCandidateCurrent.showPreviousPage() : ctlCandidateCurrent.showNextPage()
      if !updated {
        IME.prtDebugIntel("66F3477B")
        errorCallback()
      }
      return true
    }

    IME.prtDebugIntel("172A0F81")
    errorCallback()
    return true
  }
}
