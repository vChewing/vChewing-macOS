// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import SwiftUI

@available(macOS 10.15, *)
struct suiPrefPaneExperience: View {
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

  private let contentMaxHeight: Double = 430
  private let contentWidth: Double = {
    switch mgrPrefs.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if mgrPrefs.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 550
        }
    }
  }()

  var body: some View {
    ScrollView {
      Preferences.Container(contentWidth: contentWidth) {
        Preferences.Section(label: { Text(LocalizedStringKey("Cursor Selection:")) }) {
          Picker(
            "",
            selection: $selCursorPosition.onChange {
              mgrPrefs.useRearCursorMode = (selCursorPosition == 1) ? true : false
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
              mgrPrefs.moveCursorAfterSelectingCandidate = selPushCursorAfterSelection
            }
          ).controlSize(.small)
        }
        Preferences.Section(title: "(Shift+)Tab:") {
          Picker(
            "",
            selection: $selKeyBehaviorShiftTab.onChange {
              mgrPrefs.specifyShiftTabKeyBehavior = (selKeyBehaviorShiftTab == 1) ? true : false
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
        Preferences.Section(label: { Text(LocalizedStringKey("(Shift+)Space:")) }) {
          Picker(
            "",
            selection: $selKeyBehaviorShiftSpace.onChange {
              mgrPrefs.specifyShiftSpaceKeyBehavior = (selKeyBehaviorShiftSpace == 1) ? true : false
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
        Preferences.Section(label: { Text(LocalizedStringKey("Shift+Letter:")) }) {
          Picker(
            "",
            selection: $selUpperCaseLetterKeyBehavior.onChange {
              mgrPrefs.upperCaseLetterKeyBehavior = selUpperCaseLetterKeyBehavior
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
        Preferences.Section(label: { Text(LocalizedStringKey("Misc Settings:")) }) {
          Toggle(
            LocalizedStringKey("Enable Space key for calling candidate window"),
            isOn: $selKeyBehaviorSpaceForCallingCandidate.onChange {
              mgrPrefs.chooseCandidateUsingSpace = selKeyBehaviorSpaceForCallingCandidate
            }
          )
          Toggle(
            LocalizedStringKey("Use ESC key to clear the entire input buffer"),
            isOn: $selKeyBehaviorESCForClearingTheBuffer.onChange {
              mgrPrefs.escToCleanInputBuffer = selKeyBehaviorESCForClearingTheBuffer
            }
          )
          Toggle(
            LocalizedStringKey("Automatically correct reading combinations when typing"),
            isOn: $selAutoCorrectReadingCombination.onChange {
              mgrPrefs.autoCorrectReadingCombination = selAutoCorrectReadingCombination
            }
          )
          Toggle(
            LocalizedStringKey("Allow using Enter key to confirm associated candidate selection"),
            isOn: $selAlsoConfirmAssociatedCandidatesByEnter.onChange {
              mgrPrefs.alsoConfirmAssociatedCandidatesByEnter = selAlsoConfirmAssociatedCandidatesByEnter
            }
          )
          Toggle(
            LocalizedStringKey("Also toggle alphanumerical mode with Left-Shift"),
            isOn: $selTogglingAlphanumericalModeWithLShift.onChange {
              mgrPrefs.togglingAlphanumericalModeWithLShift = selTogglingAlphanumericalModeWithLShift
            }
          ).disabled(mgrPrefs.disableShiftTogglingAlphanumericalMode == true)
          Toggle(
            LocalizedStringKey("Completely disable using Shift key to toggling alphanumerical mode"),
            isOn: $selDisableShiftTogglingAlphanumericalMode.onChange {
              mgrPrefs.disableShiftTogglingAlphanumericalMode = selDisableShiftTogglingAlphanumericalMode
            }
          )
          Toggle(
            LocalizedStringKey("Allow backspace-editing miscomposed readings"),
            isOn: $selKeepReadingUponCompositionError.onChange {
              mgrPrefs.keepReadingUponCompositionError = selKeepReadingUponCompositionError
            }
          )
          Toggle(
            LocalizedStringKey("Emulating select-candidate-per-character mode"),
            isOn: $selEnableSCPCTypingMode.onChange {
              mgrPrefs.useSCPCTypingMode = selEnableSCPCTypingMode
            }
          )
          Text(LocalizedStringKey("An accommodation for elder computer users."))
            .preferenceDescription()
        }
      }
    }.frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 11.0, *)
struct suiPrefPaneExperience_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneExperience()
  }
}
