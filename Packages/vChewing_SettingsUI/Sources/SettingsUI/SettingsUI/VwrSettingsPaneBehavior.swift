// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import SwiftUI

// MARK: - VwrSettingsPaneBehavior

@available(macOS 14, *)
public struct VwrSettingsPaneBehavior: View {
  // MARK: - Main View

  public var body: some View {
    Form {
      Section {
        UserDef.kSpecifiedNotifyUIColorScheme.renderUI()
        UserDef.kShowNotificationsWhenTogglingCapsLock.renderUI()
        UserDef.kShowNotificationsWhenTogglingEisu.renderUI()
        UserDef.kShowNotificationsWhenTogglingShift.renderUI()
        UserDef.kAlwaysShowTooltipTextsHorizontally.renderUI()
          .disabled(Bundle.main.preferredLocalizations[0] == "en")
        UserDef.kShowModeDescriptionOnActivatingServer.renderUI()
        UserDef.kBeepSoundPreference.renderUI()
      }

      Section {
        UserDef.kMixedAlphanumericalEnabled.renderUI()
      }

      Section {
        UserDef.kSpaceKeyBehaviorAgainstICB.renderUI()
        UserDef.kPreferredRevolverForceLevel.renderUI()
        UserDef.kEscToCleanInputBuffer.renderUI()
        UserDef.kAlsoConfirmAssociatedCandidatesByEnter.renderUI()
        UserDef.kSpecifyShiftBackSpaceKeyBehavior.renderUI()
        UserDef.kSpecifyShiftTabKeyBehavior.renderUI()
          .pickerStyle(RadioGroupPickerStyle())
      }

      Section {
        UserDef.kSpecifyShiftSpaceKeyBehavior4CandidateWindow.renderUI()
        UserDef.kUseSpaceToCommitHighlightedCandidate4SCPC.renderUI()
      }

      Section {
        UserDef.kSpecifyCmdOptCtrlEnterBehavior.renderUI()
        VStack(alignment: .leading) {
          UserDef.kReflectBPMFVSInCompositionBuffer.renderUI()
          if let urlBPMFVS = URL(string: "https://github.com/ButTaiwan/bpmfvs") {
            Link(destination: urlBPMFVS) {
              Text(verbatim: "→ BPMFVS @ GitHub")
                .controlSize(.small)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.accentColor)
            }
          }
        }
      }

      Section {
        UserDef.kUpperCaseLetterKeyBehavior.renderUI()
        UserDef.kNumPadCharInputBehavior.renderUI()
      }

      Section {
        UserDef.kSpecifyIntonationKeyBehavior.renderUI()
        UserDef.kAcceptLeadingIntonations.renderUI()
      }

      Section {
        UserDef.kBypassNonAppleCapsLockHandling.renderUI()
        UserDef.kShareAlphanumericalModeStatusAcrossClients.renderUI()
        VStack(alignment: .leading) {
          UserDef.kTogglingAlphanumericalModeWithLShift.renderUI {
            SettingsUIHost.shared.resyncShiftKeyUpCheckerSettings()
          }
          UserDef.kTogglingAlphanumericalModeWithRShift.renderUI {
            SettingsUIHost.shared.resyncShiftKeyUpCheckerSettings()
          }
          Spacer()
          Group {
            Text(" ") +
              Text(String(format: "i18n:InfoMessage.FeatureRequiresMacOS:%@".i18n, "10.15"))
              + Text(CtlSettingsUI.sentenceSeparator)
              + Text("i18n:settings.shiftKeyASCIITogle.description".i18n)
          }.settingsDescription()
        }
        UserDef.kShiftEisuToggleOffTogetherWithCapsLock.renderUI()
      }

      Section {
        UserDef.kFuriousTypingEnabled.renderUI()
      }
    }.formStyled()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
  }
}

// MARK: - VwrSettingsPaneBehavior_Previews

@available(macOS 14, *)
struct VwrSettingsPaneBehavior_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneBehavior()
  }
}
