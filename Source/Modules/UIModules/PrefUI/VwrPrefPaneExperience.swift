// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SSPreferences
import Shared
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPaneExperience: View {
  @State private var selCursorPosition =
    UserDefaults.standard.bool(
      forKey: UserDef.kUseRearCursorMode.rawValue) ? 1 : 0
  @State private var selPushCursorAfterSelection = UserDefaults.standard.bool(
    forKey: UserDef.kMoveCursorAfterSelectingCandidate.rawValue)
  @State private var selKeyBehaviorShiftTab =
    UserDefaults.standard.bool(forKey: UserDef.kSpecifyShiftTabKeyBehavior.rawValue) ? 1 : 0
  @State private var selKeyBehaviorShiftSpace =
    UserDefaults.standard.bool(
      forKey: UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue) ? 1 : 0
  @State private var selKeyBehaviorSpaceForCallingCandidate = UserDefaults.standard.bool(
    forKey: UserDef.kChooseCandidateUsingSpace.rawValue)
  @State private var selKeyBehaviorESCForClearingTheBuffer = UserDefaults.standard.bool(
    forKey: UserDef.kEscToCleanInputBuffer.rawValue)
  @State private var selEnableSCPCTypingMode = UserDefaults.standard.bool(forKey: UserDef.kUseSCPCTypingMode.rawValue)
  @State private var selAutoCorrectReadingCombination = UserDefaults.standard.bool(
    forKey: UserDef.kAutoCorrectReadingCombination.rawValue)
  @State private var selAlsoConfirmAssociatedCandidatesByEnter = UserDefaults.standard.bool(
    forKey: UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue)
  @State private var selKeepReadingUponCompositionError = UserDefaults.standard.bool(
    forKey: UserDef.kKeepReadingUponCompositionError.rawValue)
  @State private var selTogglingAlphanumericalModeWithLShift = UserDefaults.standard.bool(
    forKey: UserDef.kTogglingAlphanumericalModeWithLShift.rawValue)
  @State private var selUpperCaseLetterKeyBehavior = UserDefaults.standard.integer(
    forKey: UserDef.kUpperCaseLetterKeyBehavior.rawValue)
  @State private var selDisableShiftTogglingAlphanumericalMode: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kDisableShiftTogglingAlphanumericalMode.rawValue)
  @State private var selSpecifyIntonationKeyBehavior = UserDefaults.standard.integer(
    forKey: UserDef.kSpecifyIntonationKeyBehavior.rawValue)
  @State private var selSpecifyShiftBackSpaceKeyBehavior = UserDefaults.standard.integer(
    forKey: UserDef.kSpecifyShiftBackSpaceKeyBehavior.rawValue)
  @State private var selTrimUnfinishedReadingsOnCommit = UserDefaults.standard.bool(
    forKey: UserDef.kTrimUnfinishedReadingsOnCommit.rawValue)
  @State private var selAlwaysShowTooltipTextsHorizontally = UserDefaults.standard.bool(
    forKey: UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue)
  @State private var selShowNotificationsWhenTogglingCapsLock = UserDefaults.standard.bool(
    forKey: UserDef.kShowNotificationsWhenTogglingCapsLock.rawValue)
  @State private var selShareAlphanumericalModeStatusAcrossClients = UserDefaults.standard.bool(
    forKey: UserDef.kShareAlphanumericalModeStatusAcrossClients.rawValue)

  private let contentMaxHeight: Double = 440
  private let contentWidth: Double = {
    switch PrefMgr.shared.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 580
        }
    }
  }()

  var macOSMontereyOrLaterDetected: Bool {
    if #available(macOS 12, *) {
      return true
    }
    return false
  }

  var body: some View {
    ScrollView {
      VStack {
        _VSpacer(minHeight: 24)
        Text(
          "\u{2022} "
            + NSLocalizedString(
              "Please use mouse wheel to scroll this page. The CheatSheet is available in the IME menu.",
              comment: ""
            ) + "\n\u{2022} "
            + NSLocalizedString(
              "Note: The “Delete ⌫” key on Mac keyboard is named as “BackSpace ⌫” here in order to distinguish the real “Delete ⌦” key from full-sized desktop keyboards. If you want to use the real “Delete ⌦” key on a Mac keyboard with no numpad equipped, you have to press “Fn+⌫” instead.",
              comment: ""
            )
        )
        .preferenceDescription()
        .fixedSize(horizontal: false, vertical: true)
      }.frame(maxWidth: contentWidth)
      SSPreferences.Container(contentWidth: contentWidth) {
        SSPreferences.Section(label: { Text(LocalizedStringKey("Cursor Selection:")) }) {
          Picker(
            "",
            selection: $selCursorPosition.onChange {
              PrefMgr.shared.useRearCursorMode = (selCursorPosition == 1) ? true : false
            }
          ) {
            Text(LocalizedStringKey("in front of the phrase (like macOS built-in Zhuyin IME)")).tag(0)
            Text(LocalizedStringKey("at the rear of the phrase (like Microsoft New Phonetic)")).tag(1)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the cursor position where you want to list possible candidates."))
            .preferenceDescription()
          Toggle(
            LocalizedStringKey("Push the cursor in front of the phrase after selection"),
            isOn: $selPushCursorAfterSelection.onChange {
              PrefMgr.shared.moveCursorAfterSelectingCandidate = selPushCursorAfterSelection
            }
          ).controlSize(.small)
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Shift+BackSpace:")) }) {
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
        SSPreferences.Section(title: "(Shift+)Tab:") {
          Picker(
            "",
            selection: $selKeyBehaviorShiftTab.onChange {
              PrefMgr.shared.specifyShiftTabKeyBehavior = (selKeyBehaviorShiftTab == 1) ? true : false
            }
          ) {
            Text(LocalizedStringKey("for cycling candidates")).tag(0)
            Text(LocalizedStringKey("for cycling pages")).tag(1)
          }
          .labelsHidden()
          .horizontalRadioGroupLayout()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the behavior of (Shift+)Tab key in the candidate window."))
            .preferenceDescription()
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("(Shift+)Space:")) }) {
          Picker(
            "",
            selection: $selKeyBehaviorShiftSpace.onChange {
              PrefMgr.shared.specifyShiftSpaceKeyBehavior = (selKeyBehaviorShiftSpace == 1) ? true : false
            }
          ) {
            Text(LocalizedStringKey("Space to +cycle candidates, Shift+Space to +cycle pages")).tag(0)
            Text(LocalizedStringKey("Space to +cycle pages, Shift+Space to +cycle candidates")).tag(1)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the behavior of (Shift+)Space key with candidates."))
            .preferenceDescription()
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Shift+Letter:")) }) {
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
        SSPreferences.Section(label: { Text(LocalizedStringKey("Intonation Key:")) }) {
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
        SSPreferences.Section(title: "Shift:") {
          Toggle(
            LocalizedStringKey("Completely disable using Shift key to toggle alphanumerical mode"),
            isOn: $selDisableShiftTogglingAlphanumericalMode.onChange {
              PrefMgr.shared.disableShiftTogglingAlphanumericalMode = selDisableShiftTogglingAlphanumericalMode
            }
          )
          Toggle(
            LocalizedStringKey("Also toggle alphanumerical mode with Left-Shift"),
            isOn: $selTogglingAlphanumericalModeWithLShift.onChange {
              PrefMgr.shared.togglingAlphanumericalModeWithLShift = selTogglingAlphanumericalModeWithLShift
            }
          ).disabled(PrefMgr.shared.disableShiftTogglingAlphanumericalMode == true)
          Toggle(
            LocalizedStringKey("Share alphanumerical mode status across all clients"),
            isOn: $selShareAlphanumericalModeStatusAcrossClients.onChange {
              PrefMgr.shared.shareAlphanumericalModeStatusAcrossClients = selShareAlphanumericalModeStatusAcrossClients
            }
          ).disabled(PrefMgr.shared.disableShiftTogglingAlphanumericalMode == true)
        }
        SSPreferences.Section(title: "Caps Lock:") {
          Toggle(
            LocalizedStringKey("Show notifications when toggling Caps Lock"),
            isOn: $selShowNotificationsWhenTogglingCapsLock.onChange {
              PrefMgr.shared.showNotificationsWhenTogglingCapsLock = selShowNotificationsWhenTogglingCapsLock
            }
          ).disabled(!macOSMontereyOrLaterDetected)
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Misc Settings:")) }) {
          Toggle(
            LocalizedStringKey("Enable Space key for calling candidate window"),
            isOn: $selKeyBehaviorSpaceForCallingCandidate.onChange {
              PrefMgr.shared.chooseCandidateUsingSpace = selKeyBehaviorSpaceForCallingCandidate
            }
          )
          Toggle(
            LocalizedStringKey("Use ESC key to clear the entire input buffer"),
            isOn: $selKeyBehaviorESCForClearingTheBuffer.onChange {
              PrefMgr.shared.escToCleanInputBuffer = selKeyBehaviorESCForClearingTheBuffer
            }
          )
          Toggle(
            LocalizedStringKey("Automatically correct reading combinations when typing"),
            isOn: $selAutoCorrectReadingCombination.onChange {
              PrefMgr.shared.autoCorrectReadingCombination = selAutoCorrectReadingCombination
            }
          )
          Toggle(
            LocalizedStringKey("Allow using Enter key to confirm associated candidate selection"),
            isOn: $selAlsoConfirmAssociatedCandidatesByEnter.onChange {
              PrefMgr.shared.alsoConfirmAssociatedCandidatesByEnter = selAlsoConfirmAssociatedCandidatesByEnter
            }
          )
          Toggle(
            LocalizedStringKey("Allow backspace-editing miscomposed readings"),
            isOn: $selKeepReadingUponCompositionError.onChange {
              PrefMgr.shared.keepReadingUponCompositionError = selKeepReadingUponCompositionError
            }
          )
          Toggle(
            LocalizedStringKey("Trim unfinished readings / strokes on commit"),
            isOn: $selTrimUnfinishedReadingsOnCommit.onChange {
              PrefMgr.shared.trimUnfinishedReadingsOnCommit = selTrimUnfinishedReadingsOnCommit
            }
          )
          Toggle(
            LocalizedStringKey("Emulating select-candidate-per-character mode"),
            isOn: $selEnableSCPCTypingMode.onChange {
              PrefMgr.shared.useSCPCTypingMode = selEnableSCPCTypingMode
            }
          )
          Text(LocalizedStringKey("An accommodation for elder computer users."))
            .preferenceDescription()
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
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneExperience_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneExperience()
  }
}
