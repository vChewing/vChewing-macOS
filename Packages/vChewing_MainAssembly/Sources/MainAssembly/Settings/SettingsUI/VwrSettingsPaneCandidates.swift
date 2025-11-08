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
  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: 16, UserDef.kCandidateListTextSize.rawValue)
  private var candidateListTextSize: Double

  @AppStorage(wrappedValue: true, UserDef.kUseHorizontalCandidateList.rawValue)
  private var useHorizontalCandidateList: Bool

  @AppStorage(wrappedValue: false, UserDef.kCandidateWindowShowOnlyOneLine.rawValue)
  private var candidateWindowShowOnlyOneLine: Bool

  @AppStorage(wrappedValue: true, UserDef.kRespectClientAccentColor.rawValue)
  private var respectClientAccentColor: Bool

  @AppStorage(wrappedValue: 0, UserDef.kMinCellWidthForHorizontalMatrix.rawValue)
  private var minCellWidthForHorizontalMatrix: Int

  @AppStorage(wrappedValue: false, UserDef.kAlwaysExpandCandidateWindow.rawValue)
  private var alwaysExpandCandidateWindow: Bool

  @AppStorage(wrappedValue: true, UserDef.kShowReverseLookupInCandidateUI.rawValue)
  private var showReverseLookupInCandidateUI: Bool

  @AppStorage(wrappedValue: true, UserDef.kShowCodePointInCandidateUI.rawValue)
  private var showCodePointInCandidateUI: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseRearCursorMode.rawValue)
  private var useRearCursorMode: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseHLtoMoveCompositorCursorInCandidateState.rawValue)
  private var useHLtoMoveCompositorCursorInCandidateState: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseJKtoMoveCompositorCursorInCandidateState.rawValue)
  private var useJKtoMoveCompositorCursorInCandidateState: Bool

  @AppStorage(wrappedValue: true, UserDef.kUseShiftQuestionToCallServiceMenu.rawValue)
  public var useShiftQuestionToCallServiceMenu: Bool

  @AppStorage(wrappedValue: 1, UserDef.kCursorPlacementAfterSelectingCandidate.rawValue)
  private var cursorPlacementAfterSelectingCandidate: Int

  @AppStorage(wrappedValue: true, UserDef.kUseDynamicCandidateWindowOrigin.rawValue)
  private var useDynamicCandidateWindowOrigin: Bool

  @AppStorage(wrappedValue: true, UserDef.kDodgeInvalidEdgeCandidateCursorPosition.rawValue)
  private var dodgeInvalidEdgeCandidateCursorPosition: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseFixedCandidateOrderOnSelection.rawValue)
  private var useFixedCandidateOrderOnSelection: Bool

  @AppStorage(wrappedValue: true, UserDef.kConsolidateContextOnCandidateSelection.rawValue)
  private var consolidateContextOnCandidateSelection: Bool

  @AppStorage(wrappedValue: false, UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.rawValue)
  private var enableMouseScrollingForTDKCandidatesCocoa: Bool

  @AppStorage(wrappedValue: 0, UserDef.kCandidateNarrationToggleType.rawValue)
  private var candidateNarrationToggleType: Int

  // MARK: - Main View

  public var body: some View {
    NavigationStack {
      Form {
        Section {
          UserDef.kUseRearCursorMode.bind($useRearCursorMode).render()
          UserDef.kCursorPlacementAfterSelectingCandidate
            .bind($cursorPlacementAfterSelectingCandidate)
            .render()
          if !useRearCursorMode {
            UserDef.kUseDynamicCandidateWindowOrigin.bind($useDynamicCandidateWindowOrigin).render()
              .disabled(useRearCursorMode)
          }
          UserDef.kDodgeInvalidEdgeCandidateCursorPosition
            .bind($dodgeInvalidEdgeCandidateCursorPosition).render()
          UserDef.kUseShiftQuestionToCallServiceMenu.bind(
            $useShiftQuestionToCallServiceMenu.didChange {
              // 利用該變數的 didSet 屬性自糾。
              PrefMgr.shared.candidateKeys = PrefMgr.shared.candidateKeys
            }
          ).render()
          UserDef.kUseJKtoMoveCompositorCursorInCandidateState.bind(
            $useJKtoMoveCompositorCursorInCandidateState.didChange {
              // 利用該變數的 didSet 屬性自糾。
              PrefMgr.shared.candidateKeys = PrefMgr.shared.candidateKeys
            }
          ).render()
          UserDef.kUseHLtoMoveCompositorCursorInCandidateState.bind(
            $useHLtoMoveCompositorCursorInCandidateState.didChange {
              // 利用該變數的 didSet 屬性自糾。
              PrefMgr.shared.candidateKeys = PrefMgr.shared.candidateKeys
            }
          ).render()
        }
        Section {
          VwrSettingsPaneCandidates_SelectionKeys()
          UserDef.kUseHorizontalCandidateList.bind($useHorizontalCandidateList).render()
            .pickerStyle(RadioGroupPickerStyle())
          UserDef.kCandidateListTextSize.bind(
            $candidateListTextSize.didChange {
              guard !(12 ... 196).contains(candidateListTextSize) else { return }
              candidateListTextSize = max(12, min(candidateListTextSize, 196))
            }
          ).render()
          UserDef.kCandidateWindowShowOnlyOneLine.bind($candidateWindowShowOnlyOneLine).render()
          if !candidateWindowShowOnlyOneLine {
            UserDef.kAlwaysExpandCandidateWindow.bind($alwaysExpandCandidateWindow).render()
              .disabled(candidateWindowShowOnlyOneLine)
            UserDef.kMinCellWidthForHorizontalMatrix.bind($minCellWidthForHorizontalMatrix).render()
              .disabled(candidateWindowShowOnlyOneLine)
          }
          UserDef.kRespectClientAccentColor.bind($respectClientAccentColor).render()
        }

        // MARK: (header: Text("Misc Settings:"))

        Section {
          UserDef.kShowCodePointInCandidateUI.bind($showCodePointInCandidateUI).render()
          UserDef.kShowReverseLookupInCandidateUI.bind($showReverseLookupInCandidateUI).render()
          UserDef.kUseFixedCandidateOrderOnSelection.bind($useFixedCandidateOrderOnSelection)
            .render()
          UserDef.kConsolidateContextOnCandidateSelection
            .bind($consolidateContextOnCandidateSelection).render()
          UserDef.kCandidateNarrationToggleType.bind($candidateNarrationToggleType).render()
        }

        // MARK: (header: Text("Experimental:"))

        let imkEOSNoticeButton = Button("Where's IMK Candidate Window?") {
          if let window = CtlSettingsUI.shared?.window {
            let title = "The End of Support for IMK Candidate Window"
            let explanation =
              "1) Only macOS has IMKCandidates. Since it relies on a dedicated ObjC Bridging Header to expose necessary internal APIs to work, it hinders vChewing from completely modularized for multi-platform support.\n\n2) IMKCandidates is buggy. It is not likely to be completely fixed by Apple, and its devs are not allowed to talk about it to non-Apple individuals. That's why we have had enough with IMKCandidates. It is likely the reason why Apple had never used IMKCandidates in their official InputMethodKit sample projects (as of August 2023)."
            window.callAlert(title: title.localized, text: explanation.localized)
          }
        }

        Section(footer: imkEOSNoticeButton) {
          UserDef.kEnableMouseScrollingForTDKCandidatesCocoa
            .bind($enableMouseScrollingForTDKCandidatesCocoa).render()
        }
      }.formStyled()
    }
    .frame(
      minWidth: CtlSettingsUI.formWidth,
      maxHeight: CtlSettingsUI.contentMaxHeight
    )
  }
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
    UserDef.kCandidateKeys.bind(
      $candidateKeys.didChange {
        let value = candidateKeys
        let keys = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().deduplicated
        // Start Error Handling.
        if let errorResult = PrefMgr.shared.validate(candidateKeys: keys) {
          if let window = CtlSettingsUI.shared?.window, !keys.isEmpty {
            IMEApp.buzz()
            let alert = NSAlert(error: NSLocalizedString("Invalid Selection Keys.", comment: ""))
            alert.informativeText = errorResult
            alert.beginSheetModal(for: window) { _ in
              candidateKeys = PrefMgr.kDefaultCandidateKeys
            }
          }
        }
      }
    ).render()
  }

  // MARK: Private

  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: PrefMgr.kDefaultCandidateKeys, UserDef.kCandidateKeys.rawValue)
  private var candidateKeys: String
}
