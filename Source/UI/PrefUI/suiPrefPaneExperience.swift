// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import SwiftUI

@available(macOS 11.0, *)
struct suiPrefPaneExperience: View {
  @State private var selSelectionKeysList = mgrPrefs.suggestedCandidateKeys
  @State private var selSelectionKeys =
    (UserDefaults.standard.string(forKey: UserDef.kCandidateKeys.rawValue) ?? mgrPrefs.defaultCandidateKeys) as String
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
  @State private var selComposingBufferSize = UserDefaults.standard.integer(
    forKey: UserDef.kComposingBufferSize.rawValue)
  @State private var selAutoCorrectReadingCombination = UserDefaults.standard.bool(
    forKey: UserDef.kAutoCorrectReadingCombination.rawValue)
  @State private var selAlsoConfirmAssociatedCandidatesByEnter = UserDefaults.standard.bool(
    forKey: UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue)
  @State private var selKeepReadingUponCompositionError = UserDefaults.standard.bool(
    forKey: UserDef.kKeepReadingUponCompositionError.rawValue)
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
    Preferences.Container(contentWidth: contentWidth) {
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Selection Keys:")) }) {
        ComboBox(items: mgrPrefs.suggestedCandidateKeys, text: $selSelectionKeys).frame(width: 180).onChange(
          of: selSelectionKeys
        ) { value in
          let keys: String = value.trimmingCharacters(in: .whitespacesAndNewlines).deduplicate
          do {
            try mgrPrefs.validate(candidateKeys: keys)
            mgrPrefs.candidateKeys = keys
            selSelectionKeys = mgrPrefs.candidateKeys
          } catch mgrPrefs.CandidateKeyError.empty {
            selSelectionKeys = mgrPrefs.candidateKeys
          } catch {
            if let window = ctlPrefUI.shared.controller.window {
              let alert = NSAlert(error: error)
              alert.beginSheetModal(for: window) { _ in
                selSelectionKeys = mgrPrefs.candidateKeys
              }
              clsSFX.beep()
            }
          }
        }
        Text(
          LocalizedStringKey(
            "Choose or hit Enter to confim your prefered keys for selecting candidates."
          )
        )
        .preferenceDescription()
      }
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Buffer Limit:")) }) {
        Picker("", selection: $selComposingBufferSize) {
          Text("10").tag(10)
          Text("15").tag(15)
          Text("20").tag(20)
          Text("25").tag(25)
          Text("30").tag(30)
          Text("35").tag(35)
          Text("40").tag(40)
        }.onChange(of: selComposingBufferSize) { value in
          mgrPrefs.composingBufferSize = value
        }
        .labelsHidden()
        .horizontalRadioGroupLayout()
        .pickerStyle(RadioGroupPickerStyle())
        Text(LocalizedStringKey("Specify the maximum characters allowed in the composition buffer."))
          .preferenceDescription()
      }
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Cursor Selection:")) }) {
        Picker("", selection: $selCursorPosition) {
          Text(LocalizedStringKey("in front of the phrase (like macOS built-in Zhuyin IME)")).tag(0)
          Text(LocalizedStringKey("at the rear of the phrase (like Microsoft New Phonetic)")).tag(1)
        }.onChange(of: selCursorPosition) { value in
          mgrPrefs.useRearCursorMode = (value == 1) ? true : false
        }
        .labelsHidden()
        .pickerStyle(RadioGroupPickerStyle())
        Text(LocalizedStringKey("Choose the cursor position where you want to list possible candidates."))
          .preferenceDescription()
        Toggle(
          LocalizedStringKey("Push the cursor in front of the phrase after selection"),
          isOn: $selPushCursorAfterSelection
        ).onChange(of: selPushCursorAfterSelection) { value in
          mgrPrefs.moveCursorAfterSelectingCandidate = value
        }.controlSize(.small)
      }
      Preferences.Section(title: "(Shift+)Tab:", bottomDivider: true) {
        Picker("", selection: $selKeyBehaviorShiftTab) {
          Text(LocalizedStringKey("for cycling candidates")).tag(0)
          Text(LocalizedStringKey("for cycling pages")).tag(1)
        }.onChange(of: selKeyBehaviorShiftTab) { value in
          mgrPrefs.specifyShiftTabKeyBehavior = (value == 1) ? true : false
        }
        .labelsHidden()
        .horizontalRadioGroupLayout()
        .pickerStyle(RadioGroupPickerStyle())
        Text(LocalizedStringKey("Choose the behavior of (Shift+)Tab key in the candidate window."))
          .preferenceDescription()
      }
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("(Shift+)Space:")) }) {
        Picker("", selection: $selKeyBehaviorShiftSpace) {
          Text(LocalizedStringKey("Space to +cycle candidates, Shift+Space to +cycle pages")).tag(0)
          Text(LocalizedStringKey("Space to +cycle pages, Shift+Space to +cycle candidates")).tag(1)
        }.onChange(of: selKeyBehaviorShiftSpace) { value in
          mgrPrefs.specifyShiftSpaceKeyBehavior = (value == 1) ? true : false
        }
        .labelsHidden()
        .pickerStyle(RadioGroupPickerStyle())
        Text(LocalizedStringKey("Choose the behavior of (Shift+)Space key with candidates."))
          .preferenceDescription()
      }
      Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Space & ESC Key:")) }) {
        Toggle(
          LocalizedStringKey("Enable Space key for calling candidate window"),
          isOn: $selKeyBehaviorSpaceForCallingCandidate
        ).onChange(of: selKeyBehaviorSpaceForCallingCandidate) { value in
          mgrPrefs.chooseCandidateUsingSpace = value
        }
        Toggle(
          LocalizedStringKey("Use ESC key to clear the entire input buffer"),
          isOn: $selKeyBehaviorESCForClearingTheBuffer
        ).onChange(of: selKeyBehaviorESCForClearingTheBuffer) { value in
          mgrPrefs.escToCleanInputBuffer = value
        }
      }
      Preferences.Section(label: { Text(LocalizedStringKey("Typing Style:")) }) {
        Toggle(
          LocalizedStringKey("Automatically correct reading combinations when typing"),
          isOn: $selAutoCorrectReadingCombination
        ).onChange(of: selAutoCorrectReadingCombination) { value in
          mgrPrefs.autoCorrectReadingCombination = value
        }
        Toggle(
          LocalizedStringKey("Emulating select-candidate-per-character mode"), isOn: $selEnableSCPCTypingMode
        ).onChange(of: selEnableSCPCTypingMode) { value in
          mgrPrefs.useSCPCTypingMode = value
        }
        Text(LocalizedStringKey("An accomodation for elder computer users."))
          .preferenceDescription()
        Toggle(
          LocalizedStringKey("Allow using Enter key to confirm associated candidate selection"),
          isOn: $selAlsoConfirmAssociatedCandidatesByEnter
        ).onChange(of: selAlsoConfirmAssociatedCandidatesByEnter) { value in
          mgrPrefs.alsoConfirmAssociatedCandidatesByEnter = value
        }
        Toggle(
          LocalizedStringKey("Allow backspace-editing miscomposed readings"),
          isOn: $selKeepReadingUponCompositionError
        ).onChange(of: selKeepReadingUponCompositionError) { value in
          mgrPrefs.keepReadingUponCompositionError = value
        }
      }
    }
  }
}

@available(macOS 11.0, *)
struct suiPrefPaneExperience_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneExperience()
  }
}
