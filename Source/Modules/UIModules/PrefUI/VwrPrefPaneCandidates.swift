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
struct VwrPrefPaneCandidates: View {
  @State private var selCandidateUIFontSize = UserDefaults.standard.integer(
    forKey: UserDef.kCandidateListTextSize.rawValue)
  @State private var selEnableHorizontalCandidateLayout = UserDefaults.standard.bool(
    forKey: UserDef.kUseHorizontalCandidateList.rawValue)
  @State private var selCandidateWindowShowOnlyOneLine = UserDefaults.standard.bool(
    forKey: UserDef.kCandidateWindowShowOnlyOneLine.rawValue)
  @State private var selShowReverseLookupInCandidateUI = UserDefaults.standard.bool(
    forKey: UserDef.kShowReverseLookupInCandidateUI.rawValue)
  @State private var selCursorPosition =
    UserDefaults.standard.bool(
      forKey: UserDef.kUseRearCursorMode.rawValue) ? 1 : 0
  @State private var selPushCursorAfterSelection = UserDefaults.standard.bool(
    forKey: UserDef.kMoveCursorAfterSelectingCandidate.rawValue)
  @State private var selUseFixecCandidateOrderOnSelection: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kUseFixecCandidateOrderOnSelection.rawValue)
  @State private var selConsolidateContextOnCandidateSelection: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kConsolidateContextOnCandidateSelection.rawValue)
  @State private var selUseIMKCandidateWindow: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kUseIMKCandidateWindow.rawValue)
  @State private var selEnableMouseScrollingForTDKCandidatesCocoa: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.rawValue)
  @State private var selEnableSwiftUIForTDKCandidates: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kEnableSwiftUIForTDKCandidates.rawValue)

  var isMontereyOrAbove: Bool = {
    if #available(macOS 12.0, *) {
      return true
    }
    return false
  }()

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        SSPreferences.Section(title: "Selection Keys:".localized, bottomDivider: true) {
          VwrPrefPaneCandidates_SelectionKeys()
        }
        SSPreferences.Section(title: "Candidate Layout:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $selEnableHorizontalCandidateLayout.onChange {
              PrefMgr.shared.useHorizontalCandidateList = selEnableHorizontalCandidateLayout
            }
          ) {
            Text(LocalizedStringKey("Vertical")).tag(false)
            Text(LocalizedStringKey("Horizontal")).tag(true)
          }
          .labelsHidden()
          .horizontalRadioGroupLayout()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose your preferred layout of the candidate window."))
            .preferenceDescription()
          Toggle(
            LocalizedStringKey("Use only one row / column in candidate window."),
            isOn: $selCandidateWindowShowOnlyOneLine.onChange {
              PrefMgr.shared.candidateWindowShowOnlyOneLine =
                selCandidateWindowShowOnlyOneLine
            }
          )
          .controlSize(.small)
          .disabled(PrefMgr.shared.useIMKCandidateWindow)
          Text(
            "This only works with Tadokoro candidate window.".localized
              + CtlPrefUIShared.sentenceSeparator
              + "Tadokoro candidate window shows 4 rows / columns by default, providing similar experiences from Microsoft New Phonetic IME and macOS bult-in Chinese IME (since macOS 10.9). However, for some users who have presbyopia, they prefer giant candidate font sizes, resulting a concern that multiple rows / columns of candidates can make the candidate window looks too big, hence this option. Note that this option will be dismissed if the typing context is vertical, forcing the candidates to be shown in only one row / column. Only one reverse-lookup result can be made available in single row / column mode due to reduced candidate window size.".localized
          )
          .preferenceDescription()
        }
        SSPreferences.Section(title: "Candidate Size:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $selCandidateUIFontSize.onChange {
              PrefMgr.shared.candidateListTextSize = Double(selCandidateUIFontSize)
            }
          ) {
            Group {
              Text("12").tag(12)
              Text("14").tag(14)
              Text("16").tag(16)
              Text("17").tag(17)
              Text("18").tag(18)
              Text("20").tag(20)
              Text("22").tag(22)
              Text("24").tag(24)
            }
            Group {
              Text("32").tag(32)
              Text("64").tag(64)
              Text("96").tag(96)
            }
          }
          .labelsHidden()
          .frame(width: 120.0)
          Text(LocalizedStringKey("Choose candidate font size for better visual clarity."))
            .preferenceDescription()
        }
        SSPreferences.Section(title: "Cursor Selection:".localized, bottomDivider: true) {
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
        SSPreferences.Section(title: "Misc Settings:".localized, bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Show available reverse-lookup results in candidate window"),
            isOn: $selShowReverseLookupInCandidateUI.onChange {
              PrefMgr.shared.showReverseLookupInCandidateUI = selShowReverseLookupInCandidateUI
            }
          )
          .disabled(PrefMgr.shared.useIMKCandidateWindow)
          Text(
            "This only works with Tadokoro candidate window.".localized
              + CtlPrefUIShared.sentenceSeparator
              + "The lookup results are supplied by the CIN cassette module.".localized
          )
          .preferenceDescription()
          Toggle(
            LocalizedStringKey("Always use fixed listing order in candidate window"),
            isOn: $selUseFixecCandidateOrderOnSelection.onChange {
              PrefMgr.shared.useFixecCandidateOrderOnSelection = selUseFixecCandidateOrderOnSelection
            }
          )
          Text(
            LocalizedStringKey(
              "This will stop user override model from affecting how candidates get sorted."
            )
          )
          .preferenceDescription()
          Toggle(
            LocalizedStringKey("Consolidate the context on confirming candidate selection"),
            isOn: $selConsolidateContextOnCandidateSelection.onChange {
              PrefMgr.shared.consolidateContextOnCandidateSelection = selConsolidateContextOnCandidateSelection
            }
          )
          Text(
            "For example: When typing “章太炎” and you want to override the “太” with “泰”, and the raw operation index range [1,2) which bounds are cutting the current node “章太炎” in range [0,3). If having lack of the pre-consolidation process, this word will become something like “張泰言” after the candidate selection. Only if we enable this consolidation, this word will become “章泰炎” which is the expected result that the context is kept as-is.".localized
          )
          .preferenceDescription()
        }
        SSPreferences.Section(title: "Experimental:".localized) {
          Toggle(
            LocalizedStringKey("Use IMK Candidate Window instead of Tadokoro"),
            isOn: $selUseIMKCandidateWindow.onChange {
              PrefMgr.shared.useIMKCandidateWindow = selUseIMKCandidateWindow
              NSLog("vChewing App self-terminated due to enabling / disabling IMK candidate window.")
              NSApp.terminate(nil)
            }
          )
          Text(
            LocalizedStringKey("⚠︎ This will reboot the vChewing IME.")
          )
          .preferenceDescription()
          Text(
            "IMK candidate window relies on certain Apple private APIs which are force-exposed by using bridging headers. Its usability, at this moment, is only guaranteed from macOS 10.14 Mojave to macOS 13 Ventura. Further tests are required in the future in order to tell whether it is usable in newer macOS releases.".localized
          )
          .preferenceDescription()
          Toggle(
            LocalizedStringKey("Enable mouse wheel support for Tadokoro Candidate Window"),
            isOn: $selEnableMouseScrollingForTDKCandidatesCocoa.onChange {
              PrefMgr.shared.enableMouseScrollingForTDKCandidatesCocoa =
                selEnableMouseScrollingForTDKCandidatesCocoa
            }
          )
          .disabled(
            PrefMgr.shared.useIMKCandidateWindow || PrefMgr.shared.enableSwiftUIForTDKCandidates
          )
          Toggle(
            LocalizedStringKey("Enable experimental Swift UI typesetting method"),
            isOn: $selEnableSwiftUIForTDKCandidates.onChange {
              PrefMgr.shared.enableSwiftUIForTDKCandidates =
                selEnableSwiftUIForTDKCandidates
            }
          )
          .disabled(PrefMgr.shared.useIMKCandidateWindow)
          Text(
            "By checking this, Tadokoro Candidate Window will use SwiftUI. SwiftUI was being used in vChewing 3.3.8 and before. However, SwiftUI has unacceptable responsiveness & latency & efficiency problems in rendering the candidate panel UI. That's why a refactored version has been introduced since vChewing 3.3.9 using Cocoa, providing an optimized user experience with blasing-fast operation responsiveness, plus experimental mouse-wheel support.".localized
          )
          .preferenceDescription()
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneCandidates_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneCandidates()
  }
}

// MARK: - Selection Key Preferences (View)

@available(macOS 10.15, *)
private struct VwrPrefPaneCandidates_SelectionKeys: View {
  @State private var selSelectionKeysList = CandidateKey.suggestions
  @State private var selSelectionKeys =
    UserDefaults.standard.string(forKey: UserDef.kCandidateKeys.rawValue) ?? CandidateKey.defaultKeys

  var body: some View {
    ComboBox(
      items: CandidateKey.suggestions,
      text: $selSelectionKeys.onChange {
        let value = selSelectionKeys
        let keys: String = value.trimmingCharacters(in: .whitespacesAndNewlines).deduplicated
        if keys.isEmpty {
          selSelectionKeys = PrefMgr.shared.candidateKeys
          return
        }
        // Start Error Handling.
        if let errorResult = CandidateKey.validate(keys: keys) {
          IMEApp.buzz()
          if let window = CtlPrefUIShared.sharedWindow {
            let alert = NSAlert(error: NSLocalizedString("Invalid Selection Keys.", comment: ""))
            alert.informativeText = errorResult
            alert.beginSheetModal(for: window) { _ in
              selSelectionKeys = PrefMgr.shared.candidateKeys
            }
          } else {
            selSelectionKeys = PrefMgr.shared.candidateKeys
          }
        } else {
          PrefMgr.shared.candidateKeys = keys
          selSelectionKeys = PrefMgr.shared.candidateKeys
          return
        }
      }
    ).frame(width: 180).disabled(PrefMgr.shared.useIMKCandidateWindow)
    if PrefMgr.shared.useIMKCandidateWindow {
      Text(
        LocalizedStringKey(
          "⚠︎ This feature in IMK Candidate Window defects. Please consult\nApple Developer Relations with Radar ID: #FB11300759."
        )
      )
      .preferenceDescription()
    } else {
      Text(
        "Choose or hit Enter to confim your prefered keys for selecting candidates.".localized
          + "\n"
          + "This will also affect the row / column capacity of the candidate window.".localized
      )
      .preferenceDescription()
    }
  }
}
