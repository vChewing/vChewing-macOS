// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - VwrSettingsPaneCandidates

@available(macOS 14, *)
public struct VwrSettingsPaneCandidates: View {
  // MARK: Public

  // MARK: - Main View

  public var body: some View {
    Form {
      Section {
        UserDef.kUseRearCursorMode.renderUI()
        UserDef.kCursorPlacementAfterSelectingCandidate.renderUI()
        if !useRearCursorMode {
          UserDef.kUseDynamicCandidateWindowOrigin.renderUI()
            .disabled(useRearCursorMode)
        }
        UserDef.kDodgeInvalidEdgeCandidateCursorPosition.renderUI()
        UserDef.kCandidateStateJKHLBehavior.renderUI {
          // 利用該變數的 didSet 屬性自糾。
          PrefMgr.shared.candidateKeys = PrefMgr.shared.candidateKeys
        }
        UserDef.kUseShiftQuestionToCallServiceMenu.renderUI {
          // 利用該變數的 didSet 屬性自糾。
          PrefMgr.shared.candidateKeys = PrefMgr.shared.candidateKeys
        }
      }
      Section {
        VwrSettingsPaneCandidates_SelectionKeys()
        UserDef.kUseHorizontalCandidateList.renderUI()
          .pickerStyle(RadioGroupPickerStyle())
        UserDef.kCandidateListTextSize.renderUI {
          let val = PrefMgr.shared.candidateListTextSize
          guard !(12 ... 196).contains(val) else { return }
          PrefMgr.shared.candidateListTextSize = max(12, min(val, 196))
        }
        UserDef.kCandidateWindowShowOnlyOneLine.renderUI()
        UserDef.kEnableCandidateWindowAnimation.renderUI()
        if !candidateWindowShowOnlyOneLine {
          UserDef.kAlwaysExpandCandidateWindow.renderUI()
            .disabled(candidateWindowShowOnlyOneLine)
          UserDef.kMinCellWidthForHorizontalMatrix.renderUI()
            .disabled(candidateWindowShowOnlyOneLine)
        }
        UserDef.kRespectClientAccentColor.renderUI()
      }

      // MARK: (header: Text("Misc Settings:"))

      Section {
        UserDef.kShowCodePointInCandidateUI.renderUI()
        UserDef.kShowReverseLookupInCandidateUI.renderUI()
        UserDef.kUseFixedCandidateOrderOnSelection.renderUI()
        UserDef.kConsolidateContextOnCandidateSelection.renderUI()
        UserDef.kCandidateNarrationToggleType.renderUI()
      }

      // MARK: (header: Text("Experimental:"))

      let imkEOSNoticeButton = Button("Where's IMK Candidate Window?") {
        isShowingIMKEOSNotice = true
      }

      Section(footer: imkEOSNoticeButton) {
        UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.renderUI()
      }
    }.formStyled()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
      .alert(
        "The End of Support for IMK Candidate Window".i18n,
        isPresented: $isShowingIMKEOSNotice
      ) {
        Button("OK".i18n, role: .cancel) {}
      } message: {
        Text(
          "1) Only macOS has IMKCandidates. Since it relies on a dedicated ObjC Bridging Header to expose necessary internal APIs to work, it hinders vChewing from completely modularized for multi-platform support.\n\n2) IMKCandidates is buggy. It is not likely to be completely fixed by Apple, and its devs are not allowed to talk about it to non-Apple individuals. That\u{2019}s why we have had enough with IMKCandidates. It is likely the reason why Apple had never used IMKCandidates in their official InputMethodKit sample projects (as of August 2023)."
            .i18n
        )
      }
  }

  // MARK: Private

  @State
  private var isShowingIMKEOSNotice = false

  // MARK: - AppStorage Variables（僅保留需在 View 條件中讀取的屬性）

  @AppStorage(wrappedValue: false, UserDef.kUseRearCursorMode.rawValue)
  private var useRearCursorMode: Bool

  @AppStorage(wrappedValue: false, UserDef.kCandidateWindowShowOnlyOneLine.rawValue)
  private var candidateWindowShowOnlyOneLine: Bool
}

// MARK: - VwrSettingsPaneCandidates_Previews

@available(macOS 14, *)
struct VwrSettingsPaneCandidates_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneCandidates()
  }
}

// MARK: - VwrSettingsPaneCandidates_SelectionKeys

@available(macOS 14, *)
/// 出於與效能有關的隱憂，該部件單獨以一個 View Struct 實現。
private struct VwrSettingsPaneCandidates_SelectionKeys: View {
  // MARK: Internal

  // MARK: - Main View

  var body: some View {
    UserDef.kCandidateKeys.renderUI {
      let value = candidateKeys
      let keys = value.trimmingCharacters(
        in: .whitespacesAndNewlines
      ).lowercased().deduplicated
      // Start Error Handling.
      if let errorResult = PrefMgr.shared.validate(candidateKeys: keys) {
        if !keys.isEmpty {
          IMEApp.buzz()
          selectionKeyErrorMessage = errorResult
          isShowingSelectionKeyError = true
        }
      }
    }
    .alert(
      "Invalid Selection Keys.".i18n,
      isPresented: $isShowingSelectionKeyError
    ) {
      Button("OK".i18n, role: .cancel) {
        candidateKeys = UserDef.kCandidateKeys.stringDefaultValue
      }
    } message: {
      if let msg = selectionKeyErrorMessage {
        Text(msg)
      }
    }
  }

  // MARK: Private

  @State
  private var isShowingSelectionKeyError = false
  @State
  private var selectionKeyErrorMessage: String?

  // MARK: - AppStorage Variables

  @AppStorage(
    wrappedValue: UserDef.kCandidateKeys.stringDefaultValue,
    UserDef.kCandidateKeys.rawValue
  )
  private var candidateKeys: String
}
