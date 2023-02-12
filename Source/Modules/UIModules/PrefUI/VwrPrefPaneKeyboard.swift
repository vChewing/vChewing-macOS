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

@available(macOS 10.15, *)
struct VwrPrefPaneKeyboard: View {
  @State private var selKeyboardParser = UserDefaults.standard.integer(forKey: UserDef.kKeyboardParser.rawValue)
  @State private var selBasicKeyboardLayout: String =
    UserDefaults.standard.string(forKey: UserDef.kBasicKeyboardLayout.rawValue) ?? PrefMgr.shared.basicKeyboardLayout
  @State private var selAlphanumericalKeyboardLayout: String =
    UserDefaults.standard.string(forKey: UserDef.kAlphanumericalKeyboardLayout.rawValue)
      ?? PrefMgr.shared.alphanumericalKeyboardLayout

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: CtlPrefUI.contentWidth) {
        SSPreferences.Section(title: "Quick Setup:".localized) {
          HStack(alignment: .top) {
            Button {
              PrefMgr.shared.keyboardParser = 0
              selKeyboardParser = PrefMgr.shared.keyboardParser
              PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
              selBasicKeyboardLayout = PrefMgr.shared.basicKeyboardLayout
            } label: {
              Text("↻ㄅ" + " " + NSLocalizedString("Dachen Trad.", comment: ""))
            }
            Button {
              PrefMgr.shared.keyboardParser = 1
              selKeyboardParser = PrefMgr.shared.keyboardParser
              PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
              selBasicKeyboardLayout = PrefMgr.shared.basicKeyboardLayout
            } label: {
              Text("↻ㄅ" + " " + NSLocalizedString("Eten Trad.", comment: ""))
            }
            Button {
              PrefMgr.shared.keyboardParser = 10
              selKeyboardParser = PrefMgr.shared.keyboardParser
              PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ABC"
              selBasicKeyboardLayout = PrefMgr.shared.basicKeyboardLayout
            } label: {
              Text("↻Ａ")
            }
          }.controlSize(.small)
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Phonetic Parser:")) }) {
          HStack {
            Picker(
              "",
              selection: $selKeyboardParser.onChange {
                let value = selKeyboardParser
                PrefMgr.shared.keyboardParser = value
              }
            ) {
              ForEach(KeyboardParser.allCases, id: \.self) { item in
                if [7, 10].contains(item.rawValue) { Divider() }
                Text(item.localizedMenuName).tag(item.rawValue)
              }.id(UUID())
            }
            .fixedSize()
            .labelsHidden()
            Spacer()
          }
          .frame(width: 380.0)
          Text(NSLocalizedString("Choose the phonetic layout for Mandarin parser.", comment: ""))
            .preferenceDescription()
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Basic Keyboard Layout:")) }) {
          HStack {
            Picker(
              "",
              selection: $selBasicKeyboardLayout.onChange {
                let value = selBasicKeyboardLayout
                PrefMgr.shared.basicKeyboardLayout = value
              }
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
            .labelsHidden()
            .frame(width: 240.0)
          }
          Text(
            NSLocalizedString(
              "Choose the macOS-level basic keyboard layout. Non-QWERTY alphanumerical keyboard layouts are for Pinyin parser only. This option will only affect the appearance of the on-screen-keyboard if the current Mandarin parser is not (any) pinyin.",
              comment: ""
            )
          )
          .preferenceDescription()
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Alphanumerical Layout:")) }) {
          HStack {
            Picker(
              "",
              selection: $selAlphanumericalKeyboardLayout.onChange {
                PrefMgr.shared.alphanumericalKeyboardLayout = selAlphanumericalKeyboardLayout
              }
            ) {
              ForEach(0 ... (IMKHelper.allowedAlphanumericalTISInputSources.count - 1), id: \.self) { id in
                if let theEntry = IMKHelper.allowedAlphanumericalTISInputSources[id] {
                  Text(theEntry.vChewingLocalizedName).tag(theEntry.identifier)
                }
              }.id(UUID())
            }
            .labelsHidden()
            .frame(width: 240.0)
          }
          HStack {
            Text(
              NSLocalizedString(
                "Choose the macOS-level alphanumerical keyboard layout. This setting is for Shift-toggled alphanumerical mode only.",
                comment: ""
              )
            )
            .preferenceDescription().fixedSize(horizontal: false, vertical: true)
            Spacer().frame(width: 30)
          }
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Keyboard Shortcuts:")) }) {
          VwrPrefPaneKeyboard_KeyboardShortcuts()
        }
      }
    }
    .frame(maxHeight: CtlPrefUI.contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 10.15, *)
private struct VwrPrefPaneKeyboard_KeyboardShortcuts: View {
  @State private var selUsingHotKeySCPC = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeySCPC.rawValue)
  @State private var selUsingHotKeyAssociates = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyAssociates.rawValue)
  @State private var selUsingHotKeyCNS = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyCNS.rawValue)
  @State private var selUsingHotKeyKangXi = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyKangXi.rawValue)
  @State private var selUsingHotKeyJIS = UserDefaults.standard.bool(forKey: UserDef.kUsingHotKeyJIS.rawValue)
  @State private var selUsingHotKeyHalfWidthASCII = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyHalfWidthASCII.rawValue)
  @State private var selUsingHotKeyCurrencyNumerals = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyCurrencyNumerals.rawValue)
  @State private var selUsingHotKeyCassette = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyCassette.rawValue)
  @State private var selUsingHotKeyRevLookup = UserDefaults.standard.bool(
    forKey: UserDef.kUsingHotKeyRevLookup.rawValue)

  var body: some View {
    HStack(alignment: .top, spacing: NSFont.systemFontSize) {
      VStack(alignment: .leading) {
        Toggle(
          LocalizedStringKey("Per-Char Select Mode"),
          isOn: $selUsingHotKeySCPC.onChange {
            PrefMgr.shared.usingHotKeySCPC = selUsingHotKeySCPC
          }
        )
        Toggle(
          LocalizedStringKey("Per-Char Associated Phrases"),
          isOn: $selUsingHotKeyAssociates.onChange {
            PrefMgr.shared.usingHotKeyAssociates = selUsingHotKeyAssociates
          }
        )
        Toggle(
          LocalizedStringKey("CNS11643 Mode"),
          isOn: $selUsingHotKeyCNS.onChange {
            PrefMgr.shared.usingHotKeyCNS = selUsingHotKeyCNS
          }
        )
        Toggle(
          LocalizedStringKey("Force KangXi Writing"),
          isOn: $selUsingHotKeyKangXi.onChange {
            PrefMgr.shared.usingHotKeyKangXi = selUsingHotKeyKangXi
          }
        )
        Toggle(
          LocalizedStringKey("Reverse Lookup (Phonabets)"),
          isOn: $selUsingHotKeyRevLookup.onChange {
            PrefMgr.shared.usingHotKeyRevLookup = selUsingHotKeyRevLookup
          }
        )
      }
      VStack(alignment: .leading) {
        Toggle(
          LocalizedStringKey("JIS Shinjitai Output"),
          isOn: $selUsingHotKeyJIS.onChange {
            PrefMgr.shared.usingHotKeyJIS = selUsingHotKeyJIS
          }
        )
        Toggle(
          LocalizedStringKey("Half-Width Punctuation Mode"),
          isOn: $selUsingHotKeyHalfWidthASCII.onChange {
            PrefMgr.shared.usingHotKeyHalfWidthASCII = selUsingHotKeyHalfWidthASCII
          }
        )
        Toggle(
          LocalizedStringKey("Currency Numeral Output"),
          isOn: $selUsingHotKeyCurrencyNumerals.onChange {
            PrefMgr.shared.usingHotKeyCurrencyNumerals = selUsingHotKeyCurrencyNumerals
          }
        )
        Toggle(
          LocalizedStringKey("CIN Cassette Mode"),
          isOn: $selUsingHotKeyCassette.onChange {
            PrefMgr.shared.usingHotKeyCassette = selUsingHotKeyCassette
          }
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
