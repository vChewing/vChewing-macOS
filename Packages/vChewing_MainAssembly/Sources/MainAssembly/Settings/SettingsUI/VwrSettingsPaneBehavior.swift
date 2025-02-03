// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import SwiftExtension
import SwiftUI

// MARK: - VwrSettingsPaneBehavior

@available(macOS 13, *)
public struct VwrSettingsPaneBehavior: View {
  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: 2, UserDef.kBeepSoundPreference.rawValue)
  private var kBeepSoundPreference: Int

  @AppStorage(wrappedValue: true, UserDef.kChooseCandidateUsingSpace.rawValue)
  private var chooseCandidateUsingSpace: Bool

  @AppStorage(wrappedValue: true, UserDef.kEscToCleanInputBuffer.rawValue)
  private var escToCleanInputBuffer: Bool

  @AppStorage(wrappedValue: true, UserDef.kAcceptLeadingIntonations.rawValue)
  private var acceptLeadingIntonations: Bool

  @AppStorage(wrappedValue: 0, UserDef.kSpecifyIntonationKeyBehavior.rawValue)
  private var specifyIntonationKeyBehavior: Int

  @AppStorage(wrappedValue: 0, UserDef.kSpecifyShiftBackSpaceKeyBehavior.rawValue)
  private var specifyShiftBackSpaceKeyBehavior: Int

  @AppStorage(wrappedValue: false, UserDef.kSpecifyShiftTabKeyBehavior.rawValue)
  private var specifyShiftTabKeyBehavior: Bool

  @AppStorage(wrappedValue: false, UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue)
  private var specifyShiftSpaceKeyBehavior: Bool

  @AppStorage(wrappedValue: 0, UserDef.kSpecifyCmdOptCtrlEnterBehavior.rawValue)
  private var specifyCmdOptCtrlEnterBehavior: Int

  @AppStorage(wrappedValue: true, UserDef.kUseSpaceToCommitHighlightedSCPCCandidate.rawValue)
  private var useSpaceToCommitHighlightedSCPCCandidate: Bool

  @AppStorage(wrappedValue: false, UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue)
  private var alsoConfirmAssociatedCandidatesByEnter: Bool

  @AppStorage(wrappedValue: true, UserDef.kTogglingAlphanumericalModeWithLShift.rawValue)
  private var togglingAlphanumericalModeWithLShift: Bool

  @AppStorage(wrappedValue: true, UserDef.kTogglingAlphanumericalModeWithRShift.rawValue)
  private var togglingAlphanumericalModeWithRShift: Bool

  @AppStorage(wrappedValue: 0, UserDef.kUpperCaseLetterKeyBehavior.rawValue)
  private var upperCaseLetterKeyBehavior: Int

  @AppStorage(wrappedValue: 0, UserDef.kNumPadCharInputBehavior.rawValue)
  private var numPadCharInputBehavior: Int

  @AppStorage(wrappedValue: false, UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue)
  private var alwaysShowTooltipTextsHorizontally: Bool

  @AppStorage(wrappedValue: true, UserDef.kShowNotificationsWhenTogglingCapsLock.rawValue)
  private var showNotificationsWhenTogglingCapsLock: Bool

  @AppStorage(wrappedValue: false, UserDef.kShareAlphanumericalModeStatusAcrossClients.rawValue)
  private var shareAlphanumericalModeStatusAcrossClients: Bool

  @AppStorage(wrappedValue: true, UserDef.kShiftEisuToggleOffTogetherWithCapsLock.rawValue)
  public dynamic var shiftEisuToggleOffTogetherWithCapsLock: Bool

  @AppStorage(wrappedValue: false, UserDef.kBypassNonAppleCapsLockHandling.rawValue)
  public dynamic var bypassNonAppleCapsLockHandling: Bool

  // MARK: - Main View

  public var body: some View {
    ScrollView {
      Form {
        Section {
          UserDef.kShowNotificationsWhenTogglingCapsLock
            .bind($showNotificationsWhenTogglingCapsLock).render()
          UserDef.kAlwaysShowTooltipTextsHorizontally.bind($alwaysShowTooltipTextsHorizontally)
            .render()
            .disabled(Bundle.main.preferredLocalizations[0] == "en")
          UserDef.kBeepSoundPreference.bind($kBeepSoundPreference).render()
        }

        Section {
          UserDef.kChooseCandidateUsingSpace.bind($chooseCandidateUsingSpace).render()
          UserDef.kEscToCleanInputBuffer.bind($escToCleanInputBuffer).render()
          UserDef.kAlsoConfirmAssociatedCandidatesByEnter
            .bind($alsoConfirmAssociatedCandidatesByEnter).render()
          UserDef.kSpecifyShiftBackSpaceKeyBehavior.bind($specifyShiftBackSpaceKeyBehavior).render()
          UserDef.kSpecifyShiftTabKeyBehavior.bind($specifyShiftTabKeyBehavior).render()
            .pickerStyle(RadioGroupPickerStyle())
          UserDef.kSpecifyCmdOptCtrlEnterBehavior.bind($specifyCmdOptCtrlEnterBehavior).render()
          VStack(alignment: .leading) {
            UserDef.kSpecifyShiftSpaceKeyBehavior.bind($specifyShiftSpaceKeyBehavior).render()
            UserDef.kUseSpaceToCommitHighlightedSCPCCandidate
              .bind($useSpaceToCommitHighlightedSCPCCandidate).render()
          }
        }

        Section {
          UserDef.kUpperCaseLetterKeyBehavior.bind($upperCaseLetterKeyBehavior).render()
          UserDef.kNumPadCharInputBehavior.bind($numPadCharInputBehavior).render()
        }

        Section {
          UserDef.kSpecifyIntonationKeyBehavior.bind($specifyIntonationKeyBehavior).render()
          UserDef.kAcceptLeadingIntonations.bind($acceptLeadingIntonations).render()
        }

        Section {
          UserDef.kBypassNonAppleCapsLockHandling.bind($bypassNonAppleCapsLockHandling).render()
          UserDef.kShareAlphanumericalModeStatusAcrossClients
            .bind($shareAlphanumericalModeStatusAcrossClients).render()
          VStack(alignment: .leading) {
            UserDef.kTogglingAlphanumericalModeWithLShift.bind(
              $togglingAlphanumericalModeWithLShift.didChange {
                InputSession.theShiftKeyDetector
                  .toggleWithLShift = togglingAlphanumericalModeWithLShift
              }
            ).render()
            UserDef.kTogglingAlphanumericalModeWithRShift.bind(
              $togglingAlphanumericalModeWithRShift.didChange {
                InputSession.theShiftKeyDetector
                  .toggleWithRShift = togglingAlphanumericalModeWithRShift
              }
            ).render()
            Spacer()
            Group {
              Text(" ") +
                Text(LocalizedStringKey("This feature requires macOS \("10.15") and above."))
                + Text(CtlSettingsUI.sentenceSeparator)
                + Text("i18n:settings.shiftKeyASCIITogle.description".localized)
            }.settingsDescription()
          }
          UserDef.kShiftEisuToggleOffTogetherWithCapsLock
            .bind($shiftEisuToggleOffTogetherWithCapsLock).render()
        }
      }.formStyled()
    }
    .frame(
      minWidth: CtlSettingsUI.formWidth,
      maxHeight: CtlSettingsUI.contentMaxHeight
    )
  }
}

// MARK: - VwrSettingsPaneBehavior_Previews

@available(macOS 13, *)
struct VwrSettingsPaneBehavior_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneBehavior()
  }
}
