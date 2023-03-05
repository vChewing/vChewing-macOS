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
import SwiftUIBackports

@available(macOS 10.15, *)
struct VwrPrefPaneBehavior: View {
  // MARK: - AppStorage Variables

  @Backport.AppStorage(wrappedValue: true, UserDef.kChooseCandidateUsingSpace.rawValue)
  private var chooseCandidateUsingSpace: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kEscToCleanInputBuffer.rawValue)
  private var escToCleanInputBuffer: Bool

  @Backport.AppStorage(wrappedValue: 0, UserDef.kSpecifyIntonationKeyBehavior.rawValue)
  private var specifyIntonationKeyBehavior: Int

  @Backport.AppStorage(wrappedValue: 0, UserDef.kSpecifyShiftBackSpaceKeyBehavior.rawValue)
  private var specifyShiftBackSpaceKeyBehavior: Int

  @Backport.AppStorage(wrappedValue: false, UserDef.kSpecifyShiftTabKeyBehavior.rawValue)
  private var specifyShiftTabKeyBehavior: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue)
  private var specifyShiftSpaceKeyBehavior: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue)
  private var alsoConfirmAssociatedCandidatesByEnter: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kTogglingAlphanumericalModeWithLShift.rawValue)
  private var togglingAlphanumericalModeWithLShift: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kTogglingAlphanumericalModeWithRShift.rawValue)
  private var togglingAlphanumericalModeWithRShift: Bool

  @Backport.AppStorage(wrappedValue: 0, UserDef.kUpperCaseLetterKeyBehavior.rawValue)
  private var upperCaseLetterKeyBehavior: Int

  @Backport.AppStorage(wrappedValue: false, UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue)
  private var alwaysShowTooltipTextsHorizontally: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kShowNotificationsWhenTogglingCapsLock.rawValue)
  private var showNotificationsWhenTogglingCapsLock: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kShareAlphanumericalModeStatusAcrossClients.rawValue)
  private var shareAlphanumericalModeStatusAcrossClients: Bool

  var macOSMontereyOrLaterDetected: Bool {
    if #available(macOS 12, *) {
      return true
    }
    return false
  }

  // MARK: - Main View

  var body: some View {
    ScrollView {
      SSPreferences.Settings.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        SSPreferences.Settings.Section(title: "Space:".localized, bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Enable Space key for calling candidate window"),
            isOn: $chooseCandidateUsingSpace
          )
          Text(
            LocalizedStringKey(
              "If disabled, this will insert space instead."
            )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "ESC:".localized, bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Use ESC key to clear the entire input buffer"),
            isOn: $escToCleanInputBuffer
          )
          Text(
            LocalizedStringKey(
              "If unchecked, the ESC key will try cleaning the unfinished readings / strokes first, and will commit the current composition buffer if there's no unfinished readings / strkes."
            )
          )

          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Enter:".localized, bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Allow using Enter key to confirm associated candidate selection"),
            isOn: $alsoConfirmAssociatedCandidatesByEnter
          )
          Text(
            LocalizedStringKey(
              "Otherwise, only the candidate keys are allowed to confirm associates."
            )
          )

          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Shift+BackSpace:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $specifyShiftBackSpaceKeyBehavior
          ) {
            Text(LocalizedStringKey("Disassemble the previous reading, dropping its intonation")).tag(0)
            Text(LocalizedStringKey("Clear the entire inline composition buffer like Shift+Delete")).tag(1)
            Text(LocalizedStringKey("Always drop the previous reading")).tag(2)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Disassembling process does not work with non-phonetic reading keys."))

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "(Shift+)Tab:", bottomDivider: true) {
          Picker(
            "",
            selection: $specifyShiftTabKeyBehavior
          ) {
            Text(LocalizedStringKey("for revolving candidates")).tag(false)
            Text(LocalizedStringKey("for revolving pages")).tag(true)
          }
          .labelsHidden()
          .horizontalRadioGroupLayout()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the behavior of (Shift+)Tab key in the candidate window."))

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "(Shift+)Space:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $specifyShiftSpaceKeyBehavior
          ) {
            Text(LocalizedStringKey("Space to +revolve candidates, Shift+Space to +revolve pages")).tag(false)
            Text(LocalizedStringKey("Space to +revolve pages, Shift+Space to +revolve candidates")).tag(true)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the behavior of (Shift+)Space key with candidates."))

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Shift+Letter:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $upperCaseLetterKeyBehavior
          ) {
            Text(LocalizedStringKey("Type them into inline composition buffer")).tag(0)
            Text(LocalizedStringKey("Directly commit lowercased letters")).tag(1)
            Text(LocalizedStringKey("Directly commit uppercased letters")).tag(2)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the behavior of Shift+Letter key with letter inputs."))

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Intonation Key:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $specifyIntonationKeyBehavior
          ) {
            Text(LocalizedStringKey("Override the previous reading's intonation with candidate-reset")).tag(0)
            Text(LocalizedStringKey("Only override the intonation of the previous reading if different")).tag(1)
            Text(LocalizedStringKey("Always type intonations to the inline composition buffer")).tag(2)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Specify the behavior of intonation key when syllable composer is empty."))

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Shift:", bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Toggle alphanumerical mode with Left-Shift"),
            isOn: $togglingAlphanumericalModeWithLShift.onChange {
              SessionCtl.theShiftKeyDetector.toggleWithLShift = togglingAlphanumericalModeWithLShift
            }
          )
          Toggle(
            LocalizedStringKey("Toggle alphanumerical mode with Right-Shift"),
            isOn: $togglingAlphanumericalModeWithRShift.onChange {
              SessionCtl.theShiftKeyDetector.toggleWithRShift = togglingAlphanumericalModeWithRShift
            }
          )
          Toggle(
            LocalizedStringKey("Share alphanumerical mode status across all clients"),
            isOn: $shareAlphanumericalModeStatusAcrossClients
          ).disabled(
            !togglingAlphanumericalModeWithRShift && !togglingAlphanumericalModeWithLShift
          )
          Text(
            "This feature requires macOS 10.15 and above.".localized + CtlPrefUIShared.sentenceSeparator
              + "It only needs to parse consecutive NSEvents passed by macOS built-in InputMethodKit framework, hence no necessity of asking end-users for extra privileges of monitoring global keyboard inputs. You are free to investigate our codebase or reverse-engineer this input method to see whether the above statement is trustable.".localized
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Caps Lock:", bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Show notifications when toggling Caps Lock"),
            isOn: $showNotificationsWhenTogglingCapsLock.onChange {
              if !macOSMontereyOrLaterDetected, showNotificationsWhenTogglingCapsLock {
                showNotificationsWhenTogglingCapsLock.toggle()
              }
            }
          ).disabled(!macOSMontereyOrLaterDetected)
          Text(
            "This feature requires macOS 12 and above.".localized
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Misc Settings:".localized) {
          Toggle(
            LocalizedStringKey("Always show tooltip texts horizontally"),
            isOn: $alwaysShowTooltipTextsHorizontally
          ).disabled(Bundle.main.preferredLocalizations[0] == "en")
          Text(
            LocalizedStringKey(
              "Key names in tooltip will be shown as symbols when the tooltip is vertical. However, this option will be ignored since tooltip will always be horizontal if the UI language is English."
            )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneBehavior_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneBehavior()
  }
}
