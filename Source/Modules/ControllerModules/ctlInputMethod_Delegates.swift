// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

// MARK: - KeyHandler Delegate

extension ctlInputMethod: KeyHandlerDelegate {
  func ctlCandidate() -> ctlCandidateProtocol { ctlInputMethod.ctlCandidateCurrent }

  func keyHandler(
    _: KeyHandler, didSelectCandidateAt index: Int,
    ctlCandidate controller: ctlCandidateProtocol
  ) {
    ctlCandidate(controller, didSelectCandidateAtIndex: index)
  }

  func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputStateProtocol, addToFilter: Bool)
    -> Bool
  {
    guard let state = state as? InputState.Marking else { return false }
    let refInputModeReversed: InputMode =
      (keyHandler.inputMode == InputMode.imeModeCHT)
      ? InputMode.imeModeCHS : InputMode.imeModeCHT
    if !mgrLangModel.writeUserPhrase(
      state.userPhrase, inputMode: keyHandler.inputMode,
      areWeDuplicating: state.chkIfUserPhraseExists,
      areWeDeleting: addToFilter
    )
      || !mgrLangModel.writeUserPhrase(
        state.userPhraseConverted, inputMode: refInputModeReversed,
        areWeDuplicating: false,
        areWeDeleting: addToFilter
      )
    {
      return false
    }
    return true
  }
}

// MARK: - Candidate Controller Delegate

extension ctlInputMethod: ctlCandidateDelegate {
  func handleDelegateEvent(_ event: NSEvent!) -> Bool {
    // 用 Shift 開關半形英數模式，僅對 macOS 10.15 及之後的 macOS 有效。
    if #available(macOS 10.15, *) {
      if ShiftKeyUpChecker.check(event) {
        if !rencentKeyHandledByKeyHandler {
          NotifierController.notify(
            message: String(
              format: "%@%@%@", NSLocalizedString("Alphanumerical Mode", comment: ""), "\n",
              toggleASCIIMode()
                ? NSLocalizedString("NotificationSwitchON", comment: "")
                : NSLocalizedString("NotificationSwitchOFF", comment: "")
            )
          )
        }
        rencentKeyHandledByKeyHandler = false
        return false
      }
    }

    /// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 KeyHandler 內修復。
    /// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    /// 同時注意：必須在 event.type == .flagsChanged 結尾插入 return false，
    /// 否則，每次處理這種判斷時都會觸發 NSInternalInconsistencyException。
    if event.type == .flagsChanged { return false }

    // 準備修飾鍵，用來判定要新增的詞彙是否需要賦以非常低的權重。
    ctlInputMethod.areWeNerfing = event.modifierFlags.contains([.shift, .command])

    var textFrame = NSRect.zero

    let attributes: [AnyHashable: Any]? = client().attributes(
      forCharacterIndex: 0, lineHeightRectangle: &textFrame
    )

    let isTypingVertical =
      (attributes?["IMKTextOrientation"] as? NSNumber)?.intValue == 0 || false

    if client().bundleIdentifier()
      == "org.atelierInmu.vChewing.vChewingPhraseEditor"
    {
      IME.areWeUsingOurOwnPhraseEditor = true
    } else {
      IME.areWeUsingOurOwnPhraseEditor = false
    }

    var input = InputSignal(event: event, isVerticalTyping: isTypingVertical)
    input.isASCIIModeInput = isASCIIMode

    // 無法列印的訊號輸入，一概不作處理。
    // 這個過程不能放在 KeyHandler 內，否則不會起作用。
    if !input.charCode.isPrintable {
      return false
    }

    /// 將按鍵行為與當前輸入法狀態結合起來、交給按鍵調度模組來處理。
    /// 再根據返回的 result bool 數值來告知 IMK「這個按鍵事件是被處理了還是被放行了」。
    let result = keyHandler.handleCandidate(state: state, input: input) { newState in
      self.handle(state: newState)
    } errorCallback: {
      clsSFX.beep()
    }
    rencentKeyHandledByKeyHandler = result
    return result
  }

  func candidateCountForController(_ controller: ctlCandidateProtocol) -> Int {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates.count
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates.count
    }
    return 0
  }

  /// 直接給出全部的候選字詞的字音配對陣列
  /// - Parameter controller: 對應的控制器。因為有唯一解，所以填錯了也不會有影響。
  /// - Returns: 候選字詞陣列（字音配對）。
  func candidatesForController(_ controller: ctlCandidateProtocol) -> [(String, String)] {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates
    }
    return .init()
  }

  func ctlCandidate(_ controller: ctlCandidateProtocol, candidateAtIndex index: Int)
    -> (String, String)
  {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates[index]
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates[index]
    }
    return ("", "")
  }

  func ctlCandidate(_ controller: ctlCandidateProtocol, didSelectCandidateAtIndex index: Int) {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。

    if let state = state as? InputState.SymbolTable,
      let node = state.node.children?[index]
    {
      if let children = node.children, !children.isEmpty {
        handle(state: InputState.Empty())  // 防止縱橫排選字窗同時出現
        handle(
          state: InputState.SymbolTable(node: node, previous: state.node, isTypingVertical: state.isTypingVertical)
        )
      } else {
        handle(state: InputState.Committing(textToCommit: node.title))
        handle(state: InputState.Empty())
      }
      return
    }

    if let state = state as? InputState.ChoosingCandidate {
      let selectedValue = state.candidates[index]
      keyHandler.fixNode(candidate: selectedValue, respectCursorPushing: true)

      let inputting = keyHandler.buildInputtingState

      if mgrPrefs.useSCPCTypingMode {
        handle(state: InputState.Committing(textToCommit: inputting.composingBuffer))
        // 此時是逐字選字模式，所以「selectedValue.1」是單個字、不用追加處理。
        if mgrPrefs.associatedPhrasesEnabled,
          let associatePhrases = keyHandler.buildAssociatePhraseState(
            withPair: .init(key: selectedValue.0, value: selectedValue.1),
            isTypingVertical: state.isTypingVertical
          ), !associatePhrases.candidates.isEmpty
        {
          handle(state: associatePhrases)
        } else {
          handle(state: InputState.Empty())
        }
      } else {
        handle(state: inputting)
      }
      return
    }

    if let state = state as? InputState.AssociatedPhrases {
      let selectedValue = state.candidates[index]
      handle(state: InputState.Committing(textToCommit: selectedValue.1))
      // 此時是聯想詞選字模式，所以「selectedValue.1」必須只保留最後一個字。
      // 不然的話，一旦你選中了由多個字組成的聯想候選詞，則連續聯想會被打斷。
      guard let valueKept = selectedValue.1.last else {
        handle(state: InputState.Empty())
        return
      }
      if mgrPrefs.associatedPhrasesEnabled,
        let associatePhrases = keyHandler.buildAssociatePhraseState(
          withPair: .init(key: selectedValue.0, value: String(valueKept)),
          isTypingVertical: state.isTypingVertical
        ), !associatePhrases.candidates.isEmpty
      {
        handle(state: associatePhrases)
        return
      }
      handle(state: InputState.Empty())
    }
  }
}
