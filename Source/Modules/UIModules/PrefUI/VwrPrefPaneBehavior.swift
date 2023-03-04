// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import SSPreferences
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPaneBehavior: View {
  @State private var selChooseCandidateUsingSpace = UserDefaults.standard.bool(
    forKey: UserDef.kChooseCandidateUsingSpace.rawValue)
  @State private var selKeyBehaviorShiftTab =
    UserDefaults.standard.bool(forKey: UserDef.kSpecifyShiftTabKeyBehavior.rawValue) ? 1 : 0
  @State private var selKeyBehaviorShiftSpace =
    UserDefaults.standard.bool(
      forKey: UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue) ? 1 : 0
  @State private var selKeyBehaviorESCForClearingTheBuffer = UserDefaults.standard.bool(
    forKey: UserDef.kEscToCleanInputBuffer.rawValue)
  @State private var selAlsoConfirmAssociatedCandidatesByEnter = UserDefaults.standard.bool(
    forKey: UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue)
  @State private var selTogglingAlphanumericalModeWithLShift = UserDefaults.standard.bool(
    forKey: UserDef.kTogglingAlphanumericalModeWithLShift.rawValue)
  @State private var selTogglingAlphanumericalModeWithRShift = UserDefaults.standard.bool(
    forKey: UserDef.kTogglingAlphanumericalModeWithRShift.rawValue)
  @State private var selUpperCaseLetterKeyBehavior = UserDefaults.standard.integer(
    forKey: UserDef.kUpperCaseLetterKeyBehavior.rawValue)
  @State private var selSpecifyIntonationKeyBehavior = UserDefaults.standard.integer(
    forKey: UserDef.kSpecifyIntonationKeyBehavior.rawValue)
  @State private var selSpecifyShiftBackSpaceKeyBehavior = UserDefaults.standard.integer(
    forKey: UserDef.kSpecifyShiftBackSpaceKeyBehavior.rawValue)
  @State private var selAlwaysShowTooltipTextsHorizontally = UserDefaults.standard.bool(
    forKey: UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue)
  @State private var selShowNotificationsWhenTogglingCapsLock = UserDefaults.standard.bool(
    forKey: UserDef.kShowNotificationsWhenTogglingCapsLock.rawValue)
  @State private var selShareAlphanumericalModeStatusAcrossClients = UserDefaults.standard.bool(
    forKey: UserDef.kShareAlphanumericalModeStatusAcrossClients.rawValue)

  var macOSMontereyOrLaterDetected: Bool {
    if #available(macOS 12, *) {
      return true
    }
    return false
  }

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        SSPreferences.Section(title: "Space:".localized, bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Enable Space key for calling candidate window"),
            isOn: $selChooseCandidateUsingSpace.onChange {
              PrefMgr.shared.chooseCandidateUsingSpace = selChooseCandidateUsingSpace
            }
          )
          Text(
            LocalizedStringKey(
              "If disabled, this will insert space instead."
            )
          )
          .preferenceDescription()
        }
        SSPreferences.Section(title: "ESC:".localized, bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Use ESC key to clear the entire input buffer"),
            isOn: $selKeyBehaviorESCForClearingTheBuffer.onChange {
              PrefMgr.shared.escToCleanInputBuffer = selKeyBehaviorESCForClearingTheBuffer
            }
          )
          Text(
            LocalizedStringKey(
              "If unchecked, the ESC key will try cleaning the unfinished readings / strokes first, and will commit the current composition buffer if there's no unfinished readings / strkes."
            )
          )
          .preferenceDescription()
        }
        SSPreferences.Section(title: "Enter:".localized, bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Allow using Enter key to confirm associated candidate selection"),
            isOn: $selAlsoConfirmAssociatedCandidatesByEnter.onChange {
              PrefMgr.shared.alsoConfirmAssociatedCandidatesByEnter = selAlsoConfirmAssociatedCandidatesByEnter
            }
          )
          Text(
            LocalizedStringKey(
              "Otherwise, only the candidate keys are allowed to confirm associates."
            )
          )
          .preferenceDescription()
        }
        SSPreferences.Section(title: "Shift+BackSpace:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $selSpecifyShiftBackSpaceKeyBehavior.onChange {
              PrefMgr.shared.specifyShiftBackSpaceKeyBehavior = selSpecifyShiftBackSpaceKeyBehavior
            }
          ) {
            Text(LocalizedStringKey("Disassemble the previous reading, dropping its intonation")).tag(0)
            Text(LocalizedStringKey("Clear the entire inline composition buffer like Shift+Delete")).tag(1)
            Text(LocalizedStringKey("Always drop the previous reading")).tag(2)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Disassembling process does not work with non-phonetic reading keys."))
            .preferenceDescription()
        }
        SSPreferences.Section(title: "(Shift+)Tab:", bottomDivider: true) {
          Picker(
            "",
            selection: $selKeyBehaviorShiftTab.onChange {
              PrefMgr.shared.specifyShiftTabKeyBehavior = (selKeyBehaviorShiftTab == 1) ? true : false
            }
          ) {
            Text(LocalizedStringKey("for revolving candidates")).tag(0)
            Text(LocalizedStringKey("for revolving pages")).tag(1)
          }
          .labelsHidden()
          .horizontalRadioGroupLayout()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the behavior of (Shift+)Tab key in the candidate window."))
            .preferenceDescription()
        }
        SSPreferences.Section(title: "(Shift+)Space:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $selKeyBehaviorShiftSpace.onChange {
              PrefMgr.shared.specifyShiftSpaceKeyBehavior = (selKeyBehaviorShiftSpace == 1) ? true : false
            }
          ) {
            Text(LocalizedStringKey("Space to +revolve candidates, Shift+Space to +revolve pages")).tag(0)
            Text(LocalizedStringKey("Space to +revolve pages, Shift+Space to +revolve candidates")).tag(1)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the behavior of (Shift+)Space key with candidates."))
            .preferenceDescription()
        }
        SSPreferences.Section(title: "Shift+Letter:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $selUpperCaseLetterKeyBehavior.onChange {
              PrefMgr.shared.upperCaseLetterKeyBehavior = selUpperCaseLetterKeyBehavior
            }
          ) {
            Text(LocalizedStringKey("Type them into inline composition buffer")).tag(0)
            Text(LocalizedStringKey("Directly commit lowercased letters")).tag(1)
            Text(LocalizedStringKey("Directly commit uppercased letters")).tag(2)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the behavior of Shift+Letter key with letter inputs."))
            .preferenceDescription()
        }
        SSPreferences.Section(title: "Intonation Key:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $selSpecifyIntonationKeyBehavior.onChange {
              PrefMgr.shared.specifyIntonationKeyBehavior = selSpecifyIntonationKeyBehavior
            }
          ) {
            Text(LocalizedStringKey("Override the previous reading's intonation with candidate-reset")).tag(0)
            Text(LocalizedStringKey("Only override the intonation of the previous reading if different")).tag(1)
            Text(LocalizedStringKey("Always type intonations to the inline composition buffer")).tag(2)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Specify the behavior of intonation key when syllable composer is empty."))
            .preferenceDescription()
        }
        SSPreferences.Section(title: "Shift:", bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Toggle alphanumerical mode with Left-Shift"),
            isOn: $selTogglingAlphanumericalModeWithLShift.onChange {
              PrefMgr.shared.togglingAlphanumericalModeWithLShift = selTogglingAlphanumericalModeWithLShift
            }
          )
          Toggle(
            LocalizedStringKey("Toggle alphanumerical mode with Right-Shift"),
            isOn: $selTogglingAlphanumericalModeWithRShift.onChange {
              PrefMgr.shared.togglingAlphanumericalModeWithRShift = selTogglingAlphanumericalModeWithRShift
            }
          )
          Toggle(
            LocalizedStringKey("Share alphanumerical mode status across all clients"),
            isOn: $selShareAlphanumericalModeStatusAcrossClients.onChange {
              PrefMgr.shared.shareAlphanumericalModeStatusAcrossClients = selShareAlphanumericalModeStatusAcrossClients
            }
          ).disabled(
            !PrefMgr.shared.togglingAlphanumericalModeWithRShift && !PrefMgr.shared.togglingAlphanumericalModeWithLShift
          )
          Text(
            "This feature requires macOS 10.15 and above.".localized + CtlPrefUIShared.sentenceSeparator
              + "It only needs to parse consecutive NSEvents passed by macOS built-in InputMethodKit framework, hence no necessity of asking end-users for extra privileges of monitoring global keyboard inputs. You are free to investigate our codebase or reverse-engineer this input method to see whether the above statement is trustable.".localized
          ).preferenceDescription()
        }
        SSPreferences.Section(title: "Caps Lock:", bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Show notifications when toggling Caps Lock"),
            isOn: $selShowNotificationsWhenTogglingCapsLock.onChange {
              PrefMgr.shared.showNotificationsWhenTogglingCapsLock = selShowNotificationsWhenTogglingCapsLock
            }
          ).disabled(!macOSMontereyOrLaterDetected)
          Text(
            "This feature requires macOS 10.15 and above.".localized
          ).preferenceDescription()
        }
        SSPreferences.Section(title: "Misc Settings:".localized) {
          Toggle(
            LocalizedStringKey("Always show tooltip texts horizontally"),
            isOn: $selAlwaysShowTooltipTextsHorizontally.onChange {
              PrefMgr.shared.alwaysShowTooltipTextsHorizontally = selAlwaysShowTooltipTextsHorizontally
            }
          ).disabled(Bundle.main.preferredLocalizations[0] == "en")
          Text(
            LocalizedStringKey(
              "Key names in tooltip will be shown as symbols when the tooltip is vertical. However, this option will be ignored since tooltip will always be horizontal if the UI language is English."
            )
          ).preferenceDescription()
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneBehavior_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneBehavior()
  }
}
