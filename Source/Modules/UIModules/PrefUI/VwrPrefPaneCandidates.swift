// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import MainAssembly
import Shared
import SSPreferences
import SwiftExtension
import SwiftUI
import SwiftUIBackports

@available(macOS 10.15, *)
struct VwrPrefPaneCandidates: View {
  // MARK: - AppStorage Variables

  @Backport.AppStorage(wrappedValue: 16, UserDef.kCandidateListTextSize.rawValue)
  private var candidateListTextSize: Double

  @Backport.AppStorage(wrappedValue: true, UserDef.kUseHorizontalCandidateList.rawValue)
  private var useHorizontalCandidateList: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kCandidateWindowShowOnlyOneLine.rawValue)
  private var candidateWindowShowOnlyOneLine: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kAlwaysExpandCandidateWindow.rawValue)
  private var alwaysExpandCandidateWindow: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kShowReverseLookupInCandidateUI.rawValue)
  private var showReverseLookupInCandidateUI: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kUseRearCursorMode.rawValue)
  private var useRearCursorMode: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kMoveCursorAfterSelectingCandidate.rawValue)
  private var moveCursorAfterSelectingCandidate: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUseDynamicCandidateWindowOrigin.rawValue)
  private var useDynamicCandidateWindowOrigin: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kUseFixedCandidateOrderOnSelection.rawValue)
  private var useFixedCandidateOrderOnSelection: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kConsolidateContextOnCandidateSelection.rawValue)
  private var consolidateContextOnCandidateSelection: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kEnableSwiftUIForTDKCandidates.rawValue)
  private var enableSwiftUIForTDKCandidates: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.rawValue)
  private var enableMouseScrollingForTDKCandidatesCocoa: Bool

  // MARK: - Main View

  var body: some View {
    ScrollView {
      SSPreferences.Settings.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        SSPreferences.Settings.Section(title: "Selection Keys:".localized, bottomDivider: true) {
          VwrPrefPaneCandidates_SelectionKeys()
        }
        SSPreferences.Settings.Section(title: "Candidate Layout:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $useHorizontalCandidateList
          ) {
            Text(LocalizedStringKey("Vertical")).tag(false)
            Text(LocalizedStringKey("Horizontal")).tag(true)
          }
          .labelsHidden()
          .horizontalRadioGroupLayout()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose your preferred layout of the candidate window."))
            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          let candidateLayoutSubOptions = Group {
            Toggle(
              LocalizedStringKey("Use only one row / column in candidate window"),
              isOn: $candidateWindowShowOnlyOneLine
            )
            .controlSize(.small)
            Toggle(
              LocalizedStringKey("Always expand candidate window panel"),
              isOn: $alwaysExpandCandidateWindow
            )
            .controlSize(.small).disabled(candidateWindowShowOnlyOneLine)
          }
          if CtlPrefUIShared.isCJKInterface {
            HStack {
              candidateLayoutSubOptions
            }
          } else {
            VStack(alignment: .leading) {
              candidateLayoutSubOptions
            }
          }
          Text(
            "Tadokoro candidate window shows 4 rows / columns by default, providing similar experiences from Microsoft New Phonetic IME and macOS bult-in Chinese IME (since macOS 10.9). However, for some users who have presbyopia, they prefer giant candidate font sizes, resulting a concern that multiple rows / columns of candidates can make the candidate window looks too big, hence this option. Note that this option will be dismissed if the typing context is vertical, forcing the candidates to be shown in only one row / column. Only one reverse-lookup result can be made available in single row / column mode due to reduced candidate window size.".localized
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Candidate Size:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $candidateListTextSize.onChange {
              guard !(12 ... 196).contains(candidateListTextSize) else { return }
              candidateListTextSize = max(12, min(candidateListTextSize, 196))
            }
          ) {
            Group {
              Text("12").tag(12.0)
              Text("14").tag(14.0)
              Text("16").tag(16.0)
              Text("17").tag(17.0)
              Text("18").tag(18.0)
              Text("20").tag(20.0)
              Text("22").tag(22.0)
              Text("24").tag(24.0)
            }
            Group {
              Text("32").tag(32.0)
              Text("64").tag(64.0)
              Text("96").tag(96.0)
            }
          }
          .labelsHidden()
          .frame(width: 120.0)
          Text(LocalizedStringKey("Choose candidate font size for better visual clarity."))
            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Cursor Selection:".localized, bottomDivider: true) {
          Picker(
            "",
            selection: $useRearCursorMode
          ) {
            Text(LocalizedStringKey("in front of the phrase (like macOS built-in Zhuyin IME)")).tag(false)
            Text(LocalizedStringKey("at the rear of the phrase (like Microsoft New Phonetic)")).tag(true)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(LocalizedStringKey("Choose the cursor position where you want to list possible candidates."))
            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          Toggle(
            LocalizedStringKey("Push the cursor in front of the phrase after selection"),
            isOn: $moveCursorAfterSelectingCandidate
          ).controlSize(.small)
          Toggle(
            LocalizedStringKey("Adjust candidate window location according to current node length"),
            isOn: $useDynamicCandidateWindowOrigin
          ).controlSize(.small).disabled(useRearCursorMode)
        }
        SSPreferences.Settings.Section(title: "Misc Settings:".localized, bottomDivider: true) {
          Toggle(
            LocalizedStringKey("Show available reverse-lookup results in candidate window"),
            isOn: $showReverseLookupInCandidateUI
          )
          Text(
            "This only works with Tadokoro candidate window.".localized
              + CtlPrefUIShared.sentenceSeparator
              + "The lookup results are supplied by the CIN cassette module.".localized
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          Toggle(
            LocalizedStringKey("Always use fixed listing order in candidate window"),
            isOn: $useFixedCandidateOrderOnSelection
          )
          Text(
            LocalizedStringKey(
              "This will stop user override model from affecting how candidates get sorted."
            )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          Toggle(
            LocalizedStringKey("Consolidate the context on confirming candidate selection"),
            isOn: $consolidateContextOnCandidateSelection
          )
          Text(
            "For example: When typing “章太炎” and you want to override the “太” with “泰”, and the raw operation index range [1,2) which bounds are cutting the current node “章太炎” in range [0,3). If having lack of the pre-consolidation process, this word will become something like “張泰言” after the candidate selection. Only if we enable this consolidation, this word will become “章泰炎” which is the expected result that the context is kept as-is.".localized
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Experimental:".localized) {
          Toggle(
            LocalizedStringKey("Enable mouse wheel support for Tadokoro Candidate Window"),
            isOn: $enableMouseScrollingForTDKCandidatesCocoa
          )
          .disabled(enableSwiftUIForTDKCandidates)
          Toggle(
            LocalizedStringKey("Enable experimental Swift UI typesetting method"),
            isOn: $enableSwiftUIForTDKCandidates
          )
          Text(
            "By checking this, Tadokoro Candidate Window will use SwiftUI. SwiftUI was being used in vChewing 3.3.8 and before. However, SwiftUI has unacceptable responsiveness & latency & efficiency problems in rendering the candidate panel UI. That's why a refactored version has been introduced since vChewing 3.3.9 using Cocoa, providing an optimized user experience with blasing-fast operation responsiveness, plus experimental mouse-wheel support.".localized
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          Button("Where's IMK Candidate Window?") {
            if let window = CtlPrefUIShared.sharedWindow {
              let title = "The End of Support for IMK Candidate Window"
              let explanation = "1) Only macOS has IMKCandidates. Since it relies on a ObjC Bridging Header to expose necessary internal APIs to work, it hinders vChewing from completely modularized for multi-platform support.\n\n2) IMKCandidates is buggy. It is not likely to be completely fixed by Apple, and its devs are not allowed to talk about it to non-Apple individuals. That's why we have had enough with IMKCandidates. It is likely the reason why Apple had never used IMKCandidates in their official InputMethodKit sample projects (as of August 2023)."
              window.callAlert(title: title.localized, text: explanation.localized)
            }
          }
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
  // MARK: - AppStorage Variables

  @Backport.AppStorage(wrappedValue: PrefMgr.kDefaultCandidateKeys, UserDef.kCandidateKeys.rawValue)
  private var candidateKeys: String

  // MARK: - Main View

  var body: some View {
    ComboBox(
      items: CandidateKey.suggestions,
      text: $candidateKeys.onChange {
        let value = candidateKeys
        let keys = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().deduplicated
        // Start Error Handling.
        if let errorResult = CandidateKey.validate(keys: keys) {
          if let window = CtlPrefUIShared.sharedWindow, !keys.isEmpty {
            IMEApp.buzz()
            let alert = NSAlert(error: NSLocalizedString("Invalid Selection Keys.", comment: ""))
            alert.informativeText = errorResult
            alert.beginSheetModal(for: window) { _ in
              candidateKeys = PrefMgr.kDefaultCandidateKeys
            }
          }
        }
      }
    ).frame(width: 180)
    Text(
      "Choose or hit Enter to confim your prefered keys for selecting candidates.".localized
        + "\n"
        + "This will also affect the row / column capacity of the candidate window.".localized
    )

    .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
  }
}
