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

// MARK: - § Handle Candidate State.

extension KeyHandler {
  func handleCandidate(
    state: InputState,
    input: InputSignal,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    let inputText = input.inputText
    let charCode: UniChar = input.charCode
    if let ctlCandidateCurrent = delegate!.ctlCandidate(for: self) as? ctlCandidate {
      // MARK: Cancel Candidate

      let cancelCandidateKey =
        input.isBackSpace || input.isESC || input.isDelete
        || ((input.isCursorBackward || input.isCursorForward) && input.isShiftHold)

      if cancelCandidateKey {
        if (state is InputState.AssociatedPhrases)
          || mgrPrefs.useSCPCTypingMode
          || isBuilderEmpty
        {
          // 如果此時發現當前組字緩衝區為真空的情況的話，
          // 就將當前的組字緩衝區析構處理、強制重設輸入狀態。
          // 否則，一個本不該出現的真空組字緩衝區會使前後方向鍵與 BackSpace 鍵失靈。
          // 所以這裡需要對 isBuilderEmpty 做判定。
          clear()
          stateCallback(InputState.EmptyIgnoringPreviousState())
        } else {
          stateCallback(buildInputtingState)
        }
        return true
      }

      // MARK: Enter

      if input.isEnter {
        if state is InputState.AssociatedPhrases {
          clear()
          stateCallback(InputState.EmptyIgnoringPreviousState())
          return true
        }
        delegate!.keyHandler(
          self,
          didSelectCandidateAt: Int(ctlCandidateCurrent.selectedCandidateIndex),
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

      if input.isPageDown || input.emacsKey == vChewingEmacsKey.nextPage {
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
        if ctlCandidateCurrent is ctlCandidateHorizontal {
          let updated: Bool = ctlCandidateCurrent.highlightPreviousCandidate()
          if !updated {
            IME.prtDebugIntel("1145148D")
            errorCallback()
          }
        } else {
          let updated: Bool = ctlCandidateCurrent.showPreviousPage()
          if !updated {
            IME.prtDebugIntel("1919810D")
            errorCallback()
          }
        }
        return true
      }

      // MARK: EmacsKey Backward

      if input.emacsKey == vChewingEmacsKey.backward {
        let updated: Bool = ctlCandidateCurrent.highlightPreviousCandidate()
        if !updated {
          IME.prtDebugIntel("9B89308D")
          errorCallback()
        }
        return true
      }

      // MARK: Right Arrow

      if input.isRight {
        if ctlCandidateCurrent is ctlCandidateHorizontal {
          let updated: Bool = ctlCandidateCurrent.highlightNextCandidate()
          if !updated {
            IME.prtDebugIntel("9B65138D")
            errorCallback()
          }
        } else {
          let updated: Bool = ctlCandidateCurrent.showNextPage()
          if !updated {
            IME.prtDebugIntel("9244908D")
            errorCallback()
          }
        }
        return true
      }

      // MARK: EmacsKey Forward

      if input.emacsKey == vChewingEmacsKey.forward {
        let updated: Bool = ctlCandidateCurrent.highlightNextCandidate()
        if !updated {
          IME.prtDebugIntel("9B2428D")
          errorCallback()
        }
        return true
      }

      // MARK: Up Arrow

      if input.isUp {
        if ctlCandidateCurrent is ctlCandidateHorizontal {
          let updated: Bool = ctlCandidateCurrent.showPreviousPage()
          if !updated {
            IME.prtDebugIntel("9B614524")
            errorCallback()
          }
        } else {
          let updated: Bool = ctlCandidateCurrent.highlightPreviousCandidate()
          if !updated {
            IME.prtDebugIntel("ASD9908D")
            errorCallback()
          }
        }
        return true
      }

      // MARK: Down Arrow

      if input.isDown {
        if ctlCandidateCurrent is ctlCandidateHorizontal {
          let updated: Bool = ctlCandidateCurrent.showNextPage()
          if !updated {
            IME.prtDebugIntel("92B990DD")
            errorCallback()
          }
        } else {
          let updated: Bool = ctlCandidateCurrent.highlightNextCandidate()
          if !updated {
            IME.prtDebugIntel("6B99908D")
            errorCallback()
          }
        }
        return true
      }

      // MARK: Home Key

      if input.isHome || input.emacsKey == vChewingEmacsKey.home {
        if ctlCandidateCurrent.selectedCandidateIndex == 0 {
          IME.prtDebugIntel("9B6EDE8D")
          errorCallback()
        } else {
          ctlCandidateCurrent.selectedCandidateIndex = 0
        }

        return true
      }

      // MARK: End Key

      var candidates: [String]!

      if let state = state as? InputState.ChoosingCandidate {
        candidates = state.candidates
      } else if let state = state as? InputState.AssociatedPhrases {
        candidates = state.candidates
      }

      if candidates.isEmpty {
        return false
      } else {  // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
        if input.isEnd || input.emacsKey == vChewingEmacsKey.end {
          if ctlCandidateCurrent.selectedCandidateIndex == UInt(candidates.count - 1) {
            IME.prtDebugIntel("9B69AAAD")
            errorCallback()
          } else {
            ctlCandidateCurrent.selectedCandidateIndex = UInt(candidates.count - 1)
          }
        }
      }

      // MARK: - Associated Phrases

      if state is InputState.AssociatedPhrases {
        if !input.isShiftHold { return false }
      }

      var index: Int = NSNotFound
      var match: String!
      if state is InputState.AssociatedPhrases {
        match = input.inputTextIgnoringModifiers
      } else {
        match = inputText
      }

      var j = 0
      while j < ctlCandidateCurrent.keyLabels.count {
        let label: CandidateKeyLabel = ctlCandidateCurrent.keyLabels[j]
        if match.compare(label.key, options: .caseInsensitive, range: nil, locale: .current) == .orderedSame {
          index = j
          break
        }
        j += 1
      }

      if index != NSNotFound {
        let candidateIndex: UInt = ctlCandidateCurrent.candidateIndexAtKeyLabelIndex(UInt(index))
        if candidateIndex != UInt.max {
          delegate!.keyHandler(
            self, didSelectCandidateAt: Int(candidateIndex), ctlCandidate: ctlCandidateCurrent
          )
          return true
        }
      }

      if state is InputState.AssociatedPhrases { return false }

      // MARK: SCPC Mode Processing

      if mgrPrefs.useSCPCTypingMode {
        var punctuationNamePrefix = ""

        if input.isOptionHold && !input.isControlHold {
          punctuationNamePrefix = "_alt_punctuation_"
        } else if input.isControlHold && !input.isOptionHold {
          punctuationNamePrefix = "_ctrl_punctuation_"
        } else if input.isControlHold && input.isOptionHold {
          punctuationNamePrefix = "_alt_ctrl_punctuation_"
        } else if mgrPrefs.halfWidthPunctuationEnabled {
          punctuationNamePrefix = "_half_punctuation_"
        } else {
          punctuationNamePrefix = "_punctuation_"
        }

        let parser = currentMandarinParser

        let arrCustomPunctuations: [String] = [
          punctuationNamePrefix, parser, String(format: "%c", CChar(charCode)),
        ]
        let customPunctuation: String = arrCustomPunctuations.joined(separator: "")

        let arrPunctuations: [String] = [punctuationNamePrefix, String(format: "%c", CChar(charCode))]
        let punctuation: String = arrPunctuations.joined(separator: "")

        var shouldAutoSelectCandidate: Bool =
          _composer.inputValidityCheck(key: charCode) || ifLangModelHasUnigrams(forKey: customPunctuation)
          || ifLangModelHasUnigrams(forKey: punctuation)

        if !shouldAutoSelectCandidate, input.isUpperCaseASCIILetterKey {
          let letter: String! = String(format: "%@%c", "_letter_", CChar(charCode))
          if ifLangModelHasUnigrams(forKey: letter) { shouldAutoSelectCandidate = true }
        }

        if shouldAutoSelectCandidate {
          let candidateIndex: UInt = ctlCandidateCurrent.candidateIndexAtKeyLabelIndex(0)
          if candidateIndex != UInt.max {
            delegate!.keyHandler(
              self,
              didSelectCandidateAt: Int(candidateIndex),
              ctlCandidate: ctlCandidateCurrent
            )
            clear()
            let empty = InputState.EmptyIgnoringPreviousState()
            stateCallback(empty)
            return handle(
              input: input, state: empty, stateCallback: stateCallback, errorCallback: errorCallback
            )
          }
          return true
        }
      }
    }  // END: "if let ctlCandidateCurrent"

    IME.prtDebugIntel("172A0F81")
    errorCallback()
    return true
  }
}
