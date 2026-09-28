// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

/// 該檔案用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。

import Foundation

extension InputHandlerProtocol {
  /// 用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleComposition(input: InputSignalProtocol) -> Bool? {
    // 不處理任何包含不可列印字元的訊號。
    let hardRequirementMet = !input.text.isEmpty && input.charCode.isPrintableUniChar
    switch currentTypingMethod {
    case .codePoint where hardRequirementMet:
      return CodePointTypewriter(self).handle(input)
    case .romanNumerals where hardRequirementMet:
      return RomanNumeralTypewriter(self).handle(input)
    case .haninKeyboardSymbol where [[], .shift].contains(input.keyModifierFlags):
      return HaninSymbolTypewriter(self).handle(input)
    case .vChewingFactory where hardRequirementMet:
      // 分派依兩軸（自 P273 起明確）：
      // ① **打字模式**：磁帶優先於一切；其餘看狂打開關與注拼槽之鍵盤家族（`typingMode`）。
      // ② **注音鍵盤家族之接管者**：中英混合輸入回退啟用時，ASCII 按鍵一律由
      //    `MixedAlphanumericalTypewriter` 逐鍵接管（它本即「該批按鍵之消化器」）。
      //    此軸**先於**①，故回退與注音狂打並存時——`typingMode` 為 `.zhuyinFuriousTyping`
      //    亦然——按鍵仍走混輸；該情境之狂打只及於「讀音素材之消費」（copilot 窗、
      //    前方預覽），而**非**「按鍵之吸收」（見 `isZhuyinFuriousTypingModeEffective`
      //    與 `mixedAlnumZhuyinFuriousInEffect` 之分野）。拼音側不走此軸：回退本即
      //    注音鍵盤專屬，且 `MixedAlphanumericalTypewriter` 自身對拼音模式逕轉
      //    `BPMFFullMatchTypewriter`（見其 `handle` 之首段）。
      let isZhuyinKeyboardFamily = typingMode != .cassette && !composer.isPinyinMode
      if isZhuyinKeyboardFamily, prefs.mixedAlphanumericalEnabled {
        return MixedAlphanumericalTypewriter(self).handle(input)
      }
      switch typingMode {
      case .cassette:
        return CassetteTypewriter(self).handle(input)
      case .bopomofoKeyblock, .pinyinFuriousTyping, .pinyinKeyblock, .zhuyinFuriousTyping:
        return BPMFFullMatchTypewriter(self).handle(input)
      }
    default: return nil
    }
  }

  func handleTypewriterSCPCTasks() {
    // 僅在啟用逐字選字模式時執行，避免干擾一般組字流程。
    guard prefs.useSCPCTypingMode else { return }
    guard let session = session else { return }
    let candidateState: State = generateStateOfCandidates()
    switch candidateState.candidates.count {
    case 2...: session.switchState(candidateState)
    case 1:
      let firstCandidate = candidateState.candidates.first!
      let reading: [String] = firstCandidate.keyArray
      let text: String = firstCandidate.value
      session.switchState(State.ofCommitting(textToCommit: text))

      if prefs.associatedPhrasesEnabled {
        let associatedCandidates = generateArrayOfAssociates(
          withPairs: [.init(keyArray: reading, value: text)]
        )
        session.switchState(
          associatedCandidates.isEmpty
            ? State.ofEmpty()
            : State.ofAssociates(candidates: associatedCandidates)
        )
      }
    default: return
    }
  }
}
