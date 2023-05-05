// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import IMKUtils
import Shared
import SSPreferences
import SwiftExtension
import SwiftUI
import SwiftUIBackports

@available(macOS 10.15, *)
struct VwrPrefPaneKeyboard: View {
  // MARK: - AppStorage Variables

  @Backport.AppStorage(wrappedValue: 0, UserDef.kKeyboardParser.rawValue)
  private var keyboardParser: Int

  @Backport.AppStorage(
    wrappedValue: PrefMgr.kDefaultBasicKeyboardLayout,
    UserDef.kBasicKeyboardLayout.rawValue
  )
  private var basicKeyboardLayout: String

  @Backport.AppStorage(
    wrappedValue: PrefMgr.kDefaultAlphanumericalKeyboardLayout,
    UserDef.kAlphanumericalKeyboardLayout.rawValue
  )
  private var alphanumericalKeyboardLayout: String

  // MARK: - Main View

  var body: some View {
    ScrollView {
      SSPreferences.Settings.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        SSPreferences.Settings.Section(title: "Quick Setup:".localized) {
          HStack(alignment: .top) {
            Button {
              keyboardParser = 0
              basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
            } label: {
              Text("↻ㄅ" + " " + NSLocalizedString("Dachen Trad.", comment: ""))
            }
            Button {
              keyboardParser = 1
              basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
            } label: {
              Text("↻ㄅ" + " " + NSLocalizedString("Eten Trad.", comment: ""))
            }
            Button {
              keyboardParser = 10
              basicKeyboardLayout = "com.apple.keylayout.ABC"
            } label: {
              Text("↻Ａ")
            }
          }.controlSize(.small)
        }
        SSPreferences.Settings.Section(title: "Phonetic Parser:".localized) {
          HStack {
            Picker(
              "",
              selection: $keyboardParser
            ) {
              ForEach(KeyboardParser.allCases, id: \.self) { item in
                if [7, 10].contains(item.rawValue) { Divider() }
                Text(item.localizedMenuName).tag(item.rawValue)
              }.id(UUID())
            }
            .fixedSize()
            .labelsHidden()
            Spacer(minLength: NSFont.systemFontSize)
          }
          Text(NSLocalizedString("Choose the phonetic layout for Mandarin parser.", comment: ""))

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Basic Keyboard Layout:".localized) {
          HStack {
            Picker(
              "",
              selection: $basicKeyboardLayout
            ) {
              ForEach(0 ... (IMKHelper.allowedBasicLayoutsAsTISInputSources.count - 1), id: \.self) { id in
                let theEntry = IMKHelper.allowedBasicLayoutsAsTISInputSources[id]
                if let theEntry = theEntry {
                  Text(theEntry.vChewingLocalizedName).tag(theEntry.identifier)
                } else {
                  Divider()
                }
              }.id(UUID())
            }
            .labelsHidden().frame(width: 290)
            Spacer(minLength: NSFont.systemFontSize)
          }
          Text(
            NSLocalizedString(
              "Choose the macOS-level basic keyboard layout. Non-QWERTY alphanumerical keyboard layouts are for Pinyin parser only. This option will only affect the appearance of the on-screen-keyboard if the current Mandarin parser is neither (any) pinyin nor dynamically reparsable with different western keyboard layouts (like Eten 26, Hsu, etc.).",
              comment: ""
            )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Alphanumerical Layout:".localized) {
          HStack {
            Picker(
              "",
              selection: $alphanumericalKeyboardLayout
            ) {
              ForEach(0 ... (IMKHelper.allowedAlphanumericalTISInputSources.count - 1), id: \.self) { id in
                if let theEntry = IMKHelper.allowedAlphanumericalTISInputSources[id] {
                  Text(theEntry.vChewingLocalizedName).tag(theEntry.identifier)
                }
              }.id(UUID())
            }
            .labelsHidden().frame(width: 290)
            Spacer(minLength: NSFont.systemFontSize)
          }
          Text(
            NSLocalizedString(
              "Choose the macOS-level alphanumerical keyboard layout. This setting is for Shift-toggled alphanumerical mode only.",
              comment: ""
            )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(title: "Keyboard Shortcuts:".localized) {
          VwrPrefPaneKeyboard_KeyboardShortcuts()
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight)
  }
}

@available(macOS 10.15, *)
private struct VwrPrefPaneKeyboard_KeyboardShortcuts: View {
  // MARK: - AppStorage Variables

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeySCPC.rawValue)
  private var usingHotKeySCPC: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyAssociates.rawValue)
  private var usingHotKeyAssociates: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCNS.rawValue)
  private var usingHotKeyCNS: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyKangXi.rawValue)
  private var usingHotKeyKangXi: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyJIS.rawValue)
  private var usingHotKeyJIS: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyHalfWidthASCII.rawValue)
  private var usingHotKeyHalfWidthASCII: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCurrencyNumerals.rawValue)
  private var usingHotKeyCurrencyNumerals: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCassette.rawValue)
  private var usingHotKeyCassette: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyRevLookup.rawValue)
  private var usingHotKeyRevLookup: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kUsingHotKeyInputMode.rawValue)
  private var usingHotKeyInputMode: Bool

  // MARK: - Main View

  var body: some View {
    HStack(alignment: .top, spacing: NSFont.systemFontSize) {
      VStack(alignment: .leading) {
        Toggle(
          LocalizedStringKey("Per-Char Select Mode"),
          isOn: $usingHotKeySCPC
        )
        Toggle(
          LocalizedStringKey("Per-Char Associated Phrases"),
          isOn: $usingHotKeyAssociates
        )
        Toggle(
          LocalizedStringKey("CNS11643 Mode"),
          isOn: $usingHotKeyCNS
        )
        Toggle(
          LocalizedStringKey("Force KangXi Writing"),
          isOn: $usingHotKeyKangXi
        )
        Toggle(
          LocalizedStringKey("Reverse Lookup (Phonabets)"),
          isOn: $usingHotKeyRevLookup
        )
      }
      VStack(alignment: .leading) {
        Toggle(
          LocalizedStringKey("JIS Shinjitai Output"),
          isOn: $usingHotKeyJIS
        )
        Toggle(
          LocalizedStringKey("Half-Width Punctuation Mode"),
          isOn: $usingHotKeyHalfWidthASCII
        )
        Toggle(
          LocalizedStringKey("Currency Numeral Output"),
          isOn: $usingHotKeyCurrencyNumerals
        )
        Toggle(
          LocalizedStringKey("CIN Cassette Mode"),
          isOn: $usingHotKeyCassette
        )
        Toggle(
          LocalizedStringKey("CHS / CHT Input Mode Switch"),
          isOn: $usingHotKeyInputMode
        )
      }
    }
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneKeyboard_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneKeyboard()
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
