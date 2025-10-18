// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

extension PrefMgr {
  public static let shared: PrefMgr = {
    var result = PrefMgr(
      didAskForSyncingLMPrefs: {
        if PrefMgr.shared.phraseReplacementEnabled {
          LMMgr.loadUserPhraseReplacement()
        }
        if PrefMgr.shared.associatedPhrasesEnabled {
          LMMgr.loadUserAssociatesData()
        }
        LMMgr.syncLMPrefs()
      },
      didAskForRefreshingSpeechSputnik: SpeechSputnik.shared.refreshStatus,
      didAskForSyncingShiftKeyDetectorPrefs: {
        InputSession.theShiftKeyDetector.toggleWithLShift =
          PrefMgr.shared
            .togglingAlphanumericalModeWithLShift
        InputSession.theShiftKeyDetector.toggleWithRShift =
          PrefMgr.shared
            .togglingAlphanumericalModeWithRShift
      }
    )
    result.candidateKeyValidator = { candidateKeys in
      result.validate(candidateKeys: candidateKeys)
    }
    return result
  }()
}

// MARK: Guarded Method for Validating Candidate Keys.

extension PrefMgr {
  public func validate(candidateKeys: String) -> String? {
    var excluded = ""
    if useJKtoMoveCompositorCursorInCandidateState { excluded.append("jk") }
    if useHLtoMoveCompositorCursorInCandidateState { excluded.append("hl") }
    if useShiftQuestionToCallServiceMenu { excluded.append("?") }
    excluded.append(IMEApp.isKeyboardJIS ? "_" : "`~")
    return CandidateKey.validate(keys: candidateKeys, excluding: excluded)
  }
}
