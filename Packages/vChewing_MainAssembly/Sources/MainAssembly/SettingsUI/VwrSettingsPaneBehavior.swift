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

@available(macOS 13, *)
public struct VwrSettingsPaneBehavior: View {
  // MARK: - AppStorage Variables

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

  @AppStorage(wrappedValue: false, UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue)
  private var alwaysShowTooltipTextsHorizontally: Bool

  @AppStorage(wrappedValue: true, UserDef.kShowNotificationsWhenTogglingCapsLock.rawValue)
  private var showNotificationsWhenTogglingCapsLock: Bool

  @AppStorage(wrappedValue: false, UserDef.kShareAlphanumericalModeStatusAcrossClients.rawValue)
  private var shareAlphanumericalModeStatusAcrossClients: Bool

  var macOSMontereyOrLaterDetected: Bool { true } // Always met.

  // MARK: - Main View

  public var body: some View {
    ScrollView {
      Form {
        Section {
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Enable Space key for calling candidate window"),
              isOn: $chooseCandidateUsingSpace
            )
            Text(
              LocalizedStringKey(
                "If disabled, this will insert space instead."
              )
            )
            .settingsDescription()
          }

          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Use ESC key to clear the entire input buffer"),
              isOn: $escToCleanInputBuffer
            )
            Text(
              LocalizedStringKey(
                "If unchecked, the ESC key will try cleaning the unfinished readings / strokes first, and will commit the current composition buffer if there's no unfinished readings / strokes."
              )
            )
            .settingsDescription()
          }
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Allow using Enter key to confirm associated candidate selection"),
              isOn: $alsoConfirmAssociatedCandidatesByEnter
            )
            Text(
              LocalizedStringKey(
                "Otherwise, only the candidate keys are allowed to confirm associates."
              )
            )
            .settingsDescription()
          }
          VStack(alignment: .leading) {
            Picker(
              "Shift+BackSpace:",
              selection: $specifyShiftBackSpaceKeyBehavior
            ) {
              Text(LocalizedStringKey("Disassemble the previous reading, dropping its intonation")).tag(0)
              Text(LocalizedStringKey("Clear the entire inline composition buffer like Shift+Delete")).tag(1)
              Text(LocalizedStringKey("Always drop the previous reading")).tag(2)
            }
            Text(LocalizedStringKey("Disassembling process does not work with non-phonetic reading keys."))
              .settingsDescription()
          }
          VStack(alignment: .leading) {
            Picker(
              "(Shift+)Tab:",
              selection: $specifyShiftTabKeyBehavior
            ) {
              Text(LocalizedStringKey("for revolving candidates")).tag(false)
              Text(LocalizedStringKey("for revolving pages")).tag(true)
            }
            .pickerStyle(RadioGroupPickerStyle())
            Text(LocalizedStringKey("Choose the behavior of (Shift+)Tab key in the candidate window."))
              .settingsDescription()
          }
          VStack(alignment: .leading) {
            Picker(
              "(Shift+)Space:",
              selection: $specifyShiftSpaceKeyBehavior
            ) {
              Text(LocalizedStringKey("Space to +revolve candidates, Shift+Space to +revolve pages")).tag(false)
              Text(LocalizedStringKey("Space to +revolve pages, Shift+Space to +revolve candidates")).tag(true)
            }
            Spacer()
            Text(LocalizedStringKey("Choose the behavior of (Shift+)Space key with candidates."))
              .settingsDescription()
            Toggle(
              LocalizedStringKey("Use Space to confirm highlighted candidate in Per-Char Select Mode"),
              isOn: $useSpaceToCommitHighlightedSCPCCandidate
            )
          }
        }
        Section {
          VStack(alignment: .leading) {
            Picker(
              "Shift+Letter:",
              selection: $upperCaseLetterKeyBehavior
            ) {
              Text(LocalizedStringKey("Type them into inline composition buffer")).tag(0)
              Text(LocalizedStringKey("Always directly commit lowercased letters")).tag(1)
              Text(LocalizedStringKey("Always directly commit uppercased letters")).tag(2)
              Text(LocalizedStringKey("Directly commit lowercased letters only if the compositor is empty")).tag(3)
              Text(LocalizedStringKey("Directly commit uppercased letters only if the compositor is empty")).tag(4)
            }
            Text(LocalizedStringKey("Choose the behavior of Shift+Letter key with letter inputs."))
              .settingsDescription()
          }
        }
        Section {
          VStack(alignment: .leading) {
            Picker(
              "Intonation Key:",
              selection: $specifyIntonationKeyBehavior
            ) {
              Text(LocalizedStringKey("Override the previous reading's intonation with candidate-reset")).tag(0)
              Text(LocalizedStringKey("Only override the intonation of the previous reading if different")).tag(1)
              Text(LocalizedStringKey("Always type intonations to the inline composition buffer")).tag(2)
            }
            Text(LocalizedStringKey("Specify the behavior of intonation key when syllable composer is empty."))
              .settingsDescription()
          }
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Accept leading intonations in rare cases"),
              isOn: $acceptLeadingIntonations
            )
            Spacer()
            Text(LocalizedStringKey("This feature accommodates certain typing mistakes that the intonation mark might be typed at first (which is sequentially wrong from a common sense that intonation marks are supposed to be used for confirming combinations). It won't work if the current parser is of (any) pinyin. Also, this feature won't work when an intonation override is possible (and enabled)."))
              .settingsDescription()
          }
        }
        Section {
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Share alphanumerical mode status across all clients"),
              isOn: $shareAlphanumericalModeStatusAcrossClients
            )
            Text(
              "This only works when being toggled by Shift key and JIS Eisu key.".localized
            )
            .settingsDescription()
          }
          VStack(alignment: .leading) {
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
            Spacer()
            Text(
              "This feature requires macOS 10.15 and above.".localized + CtlSettingsUI.sentenceSeparator
                + "i18n:settings.shiftKeyASCIITogle.description".localized
            )
            .settingsDescription()
          }
        }
        Section {
          VStack(alignment: .leading) {
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
            .settingsDescription()
          }
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Always show tooltip texts horizontally"),
              isOn: $alwaysShowTooltipTextsHorizontally
            ).disabled(Bundle.main.preferredLocalizations[0] == "en")
            Text(
              LocalizedStringKey(
                "Key names in tooltip will be shown as symbols when the tooltip is vertical. However, this option will be ignored since tooltip will always be horizontal if the UI language is English."
              )
            )
            .settingsDescription()
          }
        }
      }.formStyled().frame(minWidth: CtlSettingsUI.formWidth, maxWidth: ceil(CtlSettingsUI.formWidth * 1.2))
    }
    .frame(maxHeight: CtlSettingsUI.contentMaxHeight)
  }
}

@available(macOS 13, *)
struct VwrSettingsPaneBehavior_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneBehavior()
  }
}
