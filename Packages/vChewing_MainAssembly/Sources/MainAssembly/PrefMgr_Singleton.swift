// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

extension PrefMgr {
  public static let shared: PrefMgr = {
    let result = PrefMgr()
    result.assignDidSetActions()
    return result
  }()

  private func assignDidSetActions() {
    didAskForSyncingLMPrefs = {
      if PrefMgr.shared.phraseReplacementEnabled {
        LMMgr.loadUserPhraseReplacement()
      }
      if PrefMgr.shared.associatedPhrasesEnabled {
        LMMgr.loadUserAssociatesData()
      }
      LMMgr.syncLMPrefs()
    }
    didAskForRefreshingSpeechSputnik = {
      SpeechSputnik.shared.refreshStatus()
    }
    didAskForSyncingShiftKeyDetectorPrefs = {
      InputSession.theShiftKeyDetector.toggleWithLShift = PrefMgr.shared
        .togglingAlphanumericalModeWithLShift
      InputSession.theShiftKeyDetector.toggleWithRShift = PrefMgr.shared
        .togglingAlphanumericalModeWithRShift
    }
  }
}
