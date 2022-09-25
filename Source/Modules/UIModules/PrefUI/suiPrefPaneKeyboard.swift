// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import IMKUtils
import Preferences
import Shared
import SwiftUI

@available(macOS 10.15, *)
struct suiPrefPaneKeyboard: View {
  @State private var selSelectionKeysList = CandidateKey.suggestions
  @State private var selSelectionKeys =
    UserDefaults.standard.string(forKey: UserDef.kCandidateKeys.rawValue) ?? CandidateKey.defaultKeys
  @State private var selKeyboardParser = UserDefaults.standard.integer(forKey: UserDef.kKeyboardParser.rawValue)
  @State private var selBasicKeyboardLayout: String =
    UserDefaults.standard.string(forKey: UserDef.kBasicKeyboardLayout.rawValue) ?? PrefMgr.shared.basicKeyboardLayout
  @State private var selAlphanumericalKeyboardLayout: String =
    UserDefaults.standard.string(forKey: UserDef.kAlphanumericalKeyboardLayout.rawValue)
    ?? PrefMgr.shared.alphanumericalKeyboardLayout

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

  var body: some View {
    ScrollView {
      Preferences.Container(contentWidth: contentWidth) {
        Preferences.Section(label: { Text(LocalizedStringKey("Selection Keys:")) }) {
          ComboBox(
            items: CandidateKey.suggestions,
            text: $selSelectionKeys.onChange {
              let value = selSelectionKeys
              let keys: String = value.trimmingCharacters(in: .whitespacesAndNewlines).deduplicate
              do {
                try CandidateKey.validate(keys: keys)
                PrefMgr.shared.candidateKeys = keys
                selSelectionKeys = PrefMgr.shared.candidateKeys
              } catch CandidateKey.ErrorType.empty {
                selSelectionKeys = PrefMgr.shared.candidateKeys
              } catch {
                if let window = ctlPrefUI.shared.controller.window {
                  let alert = NSAlert(error: error)
                  alert.beginSheetModal(for: window) { _ in
                    selSelectionKeys = PrefMgr.shared.candidateKeys
                  }
                  IMEApp.buzz()
                }
              }
            }
          ).frame(width: 180).disabled(PrefMgr.shared.useIMKCandidateWindow)
          if PrefMgr.shared.useIMKCandidateWindow {
            Text(
              LocalizedStringKey(
                "⚠︎ This feature in IMK Candidate Window defects. Please consult Apple Developer Relations\nand tell them the related Radar ID: #FB11300759."
              )
            )
            .preferenceDescription()
          } else {
            Text(
              LocalizedStringKey(
                "Choose or hit Enter to confim your prefered keys for selecting candidates."
              )
            )
            .preferenceDescription()
          }
        }
        Preferences.Section(label: { Text(LocalizedStringKey("Phonetic Parser:")) }) {
          HStack {
            Picker(
              "",
              selection: $selKeyboardParser.onChange {
                let value = selKeyboardParser
                PrefMgr.shared.keyboardParser = value
                switch value {
                  case 0:
                    if !IMKHelper.arrDynamicBasicKeyLayouts.contains(PrefMgr.shared.basicKeyboardLayout) {
                      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
                      selBasicKeyboardLayout = PrefMgr.shared.basicKeyboardLayout
                    }
                  default:
                    if IMKHelper.arrDynamicBasicKeyLayouts.contains(PrefMgr.shared.basicKeyboardLayout) {
                      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ABC"
                      selBasicKeyboardLayout = PrefMgr.shared.basicKeyboardLayout
                    }
                }
              }
            ) {
              Group {
                Text(LocalizedStringKey("Dachen (Microsoft Standard / Wang / 01, etc.)")).tag(0)
                Text(LocalizedStringKey("Eten Traditional")).tag(1)
                Text(LocalizedStringKey("IBM")).tag(4)
                Text(LocalizedStringKey("MiTAC")).tag(5)
                Text(LocalizedStringKey("Seigyou")).tag(8)
                Text(LocalizedStringKey("Fake Seigyou")).tag(6)
              }
              Divider()
              Group {
                Text(LocalizedStringKey("Dachen 26 (libChewing)")).tag(7)
                Text(LocalizedStringKey("Eten 26")).tag(3)
                Text(LocalizedStringKey("Hsu")).tag(2)
                Text(LocalizedStringKey("Starlight")).tag(9)
              }
              Divider()
              Group {
                Text(LocalizedStringKey("Hanyu Pinyin with Numeral Intonation")).tag(10)
                Text(LocalizedStringKey("Secondary Pinyin with Numeral Intonation")).tag(11)
                Text(LocalizedStringKey("Yale Pinyin with Numeral Intonation")).tag(12)
                Text(LocalizedStringKey("Hualuo Pinyin with Numeral Intonation")).tag(13)
                Text(LocalizedStringKey("Universal Pinyin with Numeral Intonation")).tag(14)
              }
            }
            .labelsHidden()
            Button {
              PrefMgr.shared.keyboardParser = 0
              selKeyboardParser = PrefMgr.shared.keyboardParser
              PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
              selBasicKeyboardLayout = PrefMgr.shared.basicKeyboardLayout
            } label: {
              Text("↻ㄅ")
            }
            Button {
              PrefMgr.shared.keyboardParser = 10
              selKeyboardParser = PrefMgr.shared.keyboardParser
              PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ABC"
              selBasicKeyboardLayout = PrefMgr.shared.basicKeyboardLayout
            } label: {
              Text("↻Ａ")
            }
          }
          .frame(width: 380.0)
          HStack {
            Text(
              NSLocalizedString(
                "Choose the phonetic layout for Mandarin parser.",
                comment: ""
              ) + (PrefMgr.shared.appleLanguages[0].contains("en") ? " " : "")
                + NSLocalizedString(
                  "Apple Dynamic Bopomofo Basic Keyboard Layouts (Dachen & Eten Traditional) must match the Dachen parser in order to be functional.",
                  comment: ""
                )
            )
            .preferenceDescription().fixedSize(horizontal: false, vertical: true)
            Spacer().frame(width: 30)
          }
        }
        Preferences.Section(label: { Text(LocalizedStringKey("Basic Keyboard Layout:")) }) {
          HStack {
            Picker(
              "",
              selection: $selBasicKeyboardLayout.onChange {
                let value = selBasicKeyboardLayout
                PrefMgr.shared.basicKeyboardLayout = value
                if IMKHelper.arrDynamicBasicKeyLayouts.contains(value) {
                  PrefMgr.shared.keyboardParser = 0
                  selKeyboardParser = PrefMgr.shared.keyboardParser
                }
              }
            ) {
              ForEach(0...(IMKHelper.allowedBasicLayoutsAsTISInputSources.count - 1), id: \.self) { id in
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
          HStack {
            Text(
              NSLocalizedString(
                "Choose the macOS-level basic keyboard layout. Non-QWERTY alphanumerical keyboard layouts are for Pinyin parser only.",
                comment: ""
              )
            )
            .preferenceDescription().fixedSize(horizontal: false, vertical: true)
            Spacer().frame(width: 30)
          }
        }
        Preferences.Section(label: { Text(LocalizedStringKey("Alphanumerical Layout:")) }) {
          HStack {
            Picker(
              "",
              selection: $selAlphanumericalKeyboardLayout.onChange {
                PrefMgr.shared.alphanumericalKeyboardLayout = selAlphanumericalKeyboardLayout
              }
            ) {
              ForEach(0...(IMKHelper.allowedAlphanumericalTISInputSources.count - 1), id: \.self) { id in
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
                "Choose the macOS-level alphanumerical keyboard layout. This setting is for the alphanumerical mode toggled by Shift key.",
                comment: ""
              )
            )
            .preferenceDescription().fixedSize(horizontal: false, vertical: true)
            Spacer().frame(width: 30)
          }
        }
        Preferences.Section(label: { Text(LocalizedStringKey("Keyboard Shortcuts:")) }) {
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
            }
          }
        }
      }
    }
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
  }
}

@available(macOS 11.0, *)
struct suiPrefPaneKeyboard_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneKeyboard()
  }
}

// MARK: - NSComboBox

//  Ref: https://stackoverflow.com/a/71058587/4162914
//  License: https://creativecommons.org/licenses/by-sa/4.0/

// Ref: https://stackoverflow.com/a/71058587/4162914
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
