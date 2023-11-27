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
public struct VwrSettingsPaneCandidates: View {
  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: 16, UserDef.kCandidateListTextSize.rawValue)
  private var candidateListTextSize: Double

  @AppStorage(wrappedValue: true, UserDef.kUseHorizontalCandidateList.rawValue)
  private var useHorizontalCandidateList: Bool

  @AppStorage(wrappedValue: false, UserDef.kCandidateWindowShowOnlyOneLine.rawValue)
  private var candidateWindowShowOnlyOneLine: Bool

  @AppStorage(wrappedValue: true, UserDef.kRespectClientAccentColor.rawValue)
  private var respectClientAccentColor: Bool

  @AppStorage(wrappedValue: false, UserDef.kAlwaysExpandCandidateWindow.rawValue)
  private var alwaysExpandCandidateWindow: Bool

  @AppStorage(wrappedValue: true, UserDef.kShowReverseLookupInCandidateUI.rawValue)
  private var showReverseLookupInCandidateUI: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseRearCursorMode.rawValue)
  private var useRearCursorMode: Bool

  @AppStorage(wrappedValue: true, UserDef.kMoveCursorAfterSelectingCandidate.rawValue)
  private var moveCursorAfterSelectingCandidate: Bool

  @AppStorage(wrappedValue: true, UserDef.kUseDynamicCandidateWindowOrigin.rawValue)
  private var useDynamicCandidateWindowOrigin: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseFixedCandidateOrderOnSelection.rawValue)
  private var useFixedCandidateOrderOnSelection: Bool

  @AppStorage(wrappedValue: true, UserDef.kConsolidateContextOnCandidateSelection.rawValue)
  private var consolidateContextOnCandidateSelection: Bool

  @AppStorage(wrappedValue: false, UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.rawValue)
  private var enableMouseScrollingForTDKCandidatesCocoa: Bool

  // MARK: - Main View

  public var body: some View {
    ScrollView {
      Form {
        Section {
          VStack(alignment: .leading) {
            Picker(
              "Cursor Selection:",
              selection: $useRearCursorMode
            ) {
              Text(LocalizedStringKey("in front of the phrase (like macOS built-in Zhuyin IME)")).tag(false)
              Text(LocalizedStringKey("at the rear of the phrase (like Microsoft New Phonetic)")).tag(true)
            }
            Text(LocalizedStringKey("Choose the cursor position where you want to list possible candidates."))
              .settingsDescription()
          }
          Toggle(
            LocalizedStringKey("Push the cursor in front of the phrase after selection"),
            isOn: $moveCursorAfterSelectingCandidate
          )
          if !useRearCursorMode {
            Toggle(
              LocalizedStringKey("Adjust candidate window location according to current node length"),
              isOn: $useDynamicCandidateWindowOrigin
            ).disabled(useRearCursorMode)
          }
        }
        Section {
          VStack(alignment: .leading) { VwrSettingsPaneCandidates_SelectionKeys() }
          VStack(alignment: .leading) {
            Picker(
              "Candidate Layout:",
              selection: $useHorizontalCandidateList
            ) {
              Text(LocalizedStringKey("Vertical")).tag(false)
              Text(LocalizedStringKey("Horizontal")).tag(true)
            }
            .pickerStyle(RadioGroupPickerStyle())
            Text(LocalizedStringKey("Choose your preferred layout of the candidate window."))
              .settingsDescription()
          }
          VStack(alignment: .leading) {
            Picker(
              "Candidate Size:",
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
            Text(LocalizedStringKey("Choose candidate font size for better visual clarity."))
              .settingsDescription()
          }
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Use only one row / column in candidate window"),
              isOn: $candidateWindowShowOnlyOneLine
            )
            Text(
              "Tadokoro candidate window shows 4 rows / columns by default, providing similar experiences from Microsoft New Phonetic IME and macOS bult-in Chinese IME (since macOS 10.9). However, for some users who have presbyopia, they prefer giant candidate font sizes, resulting a concern that multiple rows / columns of candidates can make the candidate window looks too big, hence this option. Note that this option will be dismissed if the typing context is vertical, forcing the candidates to be shown in only one row / column. Only one reverse-lookup result can be made available in single row / column mode due to reduced candidate window size.".localized
            )
            .settingsDescription()
          }
          if !candidateWindowShowOnlyOneLine {
            Toggle(
              LocalizedStringKey("Always expand candidate window panel"),
              isOn: $alwaysExpandCandidateWindow
            )
            .disabled(candidateWindowShowOnlyOneLine)
          }
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey(UserDef.kRespectClientAccentColor.metaData?.shortTitle ?? "[i18n]respectClientAccentColor"),
              isOn: $respectClientAccentColor
            )
            Text(
              UserDef.kRespectClientAccentColor.metaData?.description?.localized ?? "[i18n]respectClientAccentColor.description"
            )
            .settingsDescription()
          }
        }

        // MARK: (header: Text("Misc Settings:"))

        Section {
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Show available reverse-lookup results in candidate window"),
              isOn: $showReverseLookupInCandidateUI
            )
            Text(
              "The lookup results are supplied by the CIN cassette module.".localized
            )
            .settingsDescription()
          }
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Always use fixed listing order in candidate window"),
              isOn: $useFixedCandidateOrderOnSelection
            )
            Text(
              LocalizedStringKey(
                "This will stop user override model from affecting how candidates get sorted."
              )
            )
            .settingsDescription()
          }
          VStack(alignment: .leading) {
            Toggle(
              LocalizedStringKey("Consolidate the context on confirming candidate selection"),
              isOn: $consolidateContextOnCandidateSelection
            )
            Text(
              "For example: When typing “章太炎” and you want to override the “太” with “泰”, and the raw operation index range [1,2) which bounds are cutting the current node “章太炎” in range [0,3). If having lack of the pre-consolidation process, this word will become something like “張泰言” after the candidate selection. Only if we enable this consolidation, this word will become “章泰炎” which is the expected result that the context is kept as-is.".localized
            )
            .settingsDescription()
          }
        }

        // MARK: (header: Text("Experimental:"))

        let imkEOSNoticeButton = Button("Where's IMK Candidate Window?") {
          if let window = CtlSettingsUI.shared?.window {
            let title = "The End of Support for IMK Candidate Window"
            let explanation = "1) Only macOS has IMKCandidates. Since it relies on a dedicated ObjC Bridging Header to expose necessary internal APIs to work, it hinders vChewing from completely modularized for multi-platform support.\n\n2) IMKCandidates is buggy. It is not likely to be completely fixed by Apple, and its devs are not allowed to talk about it to non-Apple individuals. That's why we have had enough with IMKCandidates. It is likely the reason why Apple had never used IMKCandidates in their official InputMethodKit sample projects (as of August 2023)."
            window.callAlert(title: title.localized, text: explanation.localized)
          }
        }

        Section(footer: imkEOSNoticeButton) {
          Toggle(
            LocalizedStringKey("Enable mouse wheel support for Tadokoro Candidate Window"),
            isOn: $enableMouseScrollingForTDKCandidatesCocoa
          )
        }
      }.formStyled().frame(minWidth: CtlSettingsUI.formWidth, maxWidth: ceil(CtlSettingsUI.formWidth * 1.2))
    }
    .frame(maxHeight: CtlSettingsUI.contentMaxHeight)
  }
}

@available(macOS 13, *)
struct VwrSettingsPaneCandidates_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneCandidates()
  }
}

// MARK: - Selection Key Preferences (View)

@available(macOS 13, *)
private struct VwrSettingsPaneCandidates_SelectionKeys: View {
  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: PrefMgr.kDefaultCandidateKeys, UserDef.kCandidateKeys.rawValue)
  private var candidateKeys: String

  // MARK: - Main View

  var body: some View {
    HStack {
      Text("Selection Keys:")
      Spacer()
      ComboBox(
        items: CandidateKey.suggestions,
        text: $candidateKeys.onChange {
          let value = candidateKeys
          let keys = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().deduplicated
          // Start Error Handling.
          if let errorResult = CandidateKey.validate(keys: keys) {
            if let window = CtlSettingsUI.shared?.window, !keys.isEmpty {
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
    }
    Text(
      "Choose or hit Enter to confim your prefered keys for selecting candidates.".localized
        + "\n"
        + "This will also affect the row / column capacity of the candidate window.".localized
    )
    .settingsDescription()
  }
}

// MARK: - NSComboBox

// Ref: https://stackoverflow.com/a/71058587/4162914
// License: https://creativecommons.org/licenses/by-sa/4.0/

@available(macOS 10.15, *)
public struct ComboBox: NSViewRepresentable {
  // The items that will show up in the pop-up menu:
  public var items: [String] = []

  // The property on our parent view that gets synced to the current
  // stringValue of the NSComboBox, whether the user typed it in or
  // selected it from the list:
  @Binding public var text: String

  public func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  public func makeNSView(context: Context) -> NSComboBox {
    let comboBox = NSComboBox()
    comboBox.usesDataSource = false
    comboBox.completes = false
    comboBox.delegate = context.coordinator
    comboBox.intercellSpacing = NSSize(width: 0.0, height: 10.0)
    return comboBox
  }

  public func updateNSView(_ nsView: NSComboBox, context: Context) {
    nsView.removeAllItems()
    nsView.addItems(withObjectValues: items)

    // ComboBox doesn't automatically select the item matching its text;
    // we must do that manually. But we need the delegate to ignore that
    // selection-change or we'll get a "state modified during view update;
    // will cause undefined behavior" warning.
    context.coordinator.ignoreSelectionChanges = true
    nsView.stringValue = text
    nsView.selectItem(withObjectValue: text)
    context.coordinator.ignoreSelectionChanges = false
  }

  public class Coordinator: NSObject, NSComboBoxDelegate {
    public var parent: ComboBox
    public var ignoreSelectionChanges = false

    public init(_ parent: ComboBox) {
      self.parent = parent
    }

    public func comboBoxSelectionDidChange(_ notification: Notification) {
      if !ignoreSelectionChanges,
         let box: NSComboBox = notification.object as? NSComboBox,
         let newStringValue: String = box.objectValueOfSelectedItem as? String
      {
        parent.text = newStringValue
      }
    }

    public func controlTextDidEndEditing(_ obj: Notification) {
      if let textField = obj.object as? NSTextField {
        parent.text = textField.stringValue
      }
    }
  }
}
