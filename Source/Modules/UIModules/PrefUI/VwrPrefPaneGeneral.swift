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
import SwiftUIBackports

@available(macOS 10.15, *)
struct VwrPrefPaneGeneral: View {
  @Binding var appleLanguageTag: String

  init() {
    _appleLanguageTag = .init(
      get: {
        let loadedValue = (UserDefaults.standard.array(forKey: UserDef.kAppleLanguages.rawValue) as? [String] ?? ["auto"]).joined()
        let plistValueNotExist = (UserDefaults.standard.object(forKey: UserDef.kAppleLanguages.rawValue) == nil)
        let targetToCheck = (plistValueNotExist || loadedValue.isEmpty) ? "auto" : loadedValue
        return Shared.arrSupportedLocales.contains(targetToCheck) ? (plistValueNotExist ? "auto" : loadedValue) : "auto"
      }, set: { newValue in
        var newValue = newValue
        if newValue.isEmpty || newValue == "auto" {
          UserDefaults.standard.removeObject(forKey: UserDef.kAppleLanguages.rawValue)
        }
        if newValue == "auto" { newValue = "" }
        guard PrefMgr.shared.appleLanguages.joined() != newValue else { return }
        if !newValue.isEmpty { PrefMgr.shared.appleLanguages = [newValue] }
        NSLog("vChewing App self-terminated due to UI language change.")
        NSApp.terminate(nil)
      }
    )
  }

  // MARK: - AppStorage Variables

  @Backport.AppStorage(wrappedValue: [], UserDef.kAppleLanguages.rawValue)
  private var appleLanguages: [String]

  @Backport.AppStorage(wrappedValue: true, UserDef.kAutoCorrectReadingCombination.rawValue)
  private var autoCorrectReadingCombination: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kKeepReadingUponCompositionError.rawValue)
  private var keepReadingUponCompositionError: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue)
  private var showHanyuPinyinInCompositionBuffer: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.rawValue)
  private var classicHaninKeyboardSymbolModeShortcutEnabled: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kUseSCPCTypingMode.rawValue)
  private var useSCPCTypingMode: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kShouldNotFartInLieuOfBeep.rawValue)
  private var shouldNotFartInLieuOfBeep: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kCheckUpdateAutomatically.rawValue)
  private var checkUpdateAutomatically: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kIsDebugModeEnabled.rawValue)
  private var isDebugModeEnabled: Bool

  // MARK: - Main View

  var body: some View {
    ScrollView {
      SSPreferences.Settings.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        SSPreferences.Settings.Section {
          Text(
            "\u{2022} "
              + NSLocalizedString(
                "Please use mouse wheel to scroll each page if needed. The CheatSheet is available in the IME menu.",
                comment: ""
              ) + "\n\u{2022} "
              + NSLocalizedString(
                "Note: The “Delete ⌫” key on Mac keyboard is named as “BackSpace ⌫” here in order to distinguish the real “Delete ⌦” key from full-sized desktop keyboards. If you want to use the real “Delete ⌦” key on a Mac keyboard with no numpad equipped, you have to press “Fn+⌫” instead.",
                comment: ""
              )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth).padding(.bottom, NSFont.systemFontSize)
        }
        SSPreferences.Settings.Section(title: "UI Language:".localized) {
          HStack {
            Picker(
              LocalizedStringKey("Follow OS settings"),
              selection: $appleLanguageTag
            ) {
              Text(LocalizedStringKey("Follow OS settings")).tag("auto")
              Text(LocalizedStringKey("Simplified Chinese")).tag("zh-Hans")
              Text(LocalizedStringKey("Traditional Chinese")).tag("zh-Hant")
              Text(LocalizedStringKey("Japanese")).tag("ja")
              Text(LocalizedStringKey("English")).tag("en")
            }
            .labelsHidden()
            .frame(width: 180.0)
            Spacer()
          }
          Text(LocalizedStringKey("Change user interface language (will reboot the IME)."))

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
        SSPreferences.Settings.Section(label: { Text(LocalizedStringKey("Typing Settings:")) }) {
          Toggle(
            LocalizedStringKey("Automatically correct reading combinations when typing"),
            isOn: $autoCorrectReadingCombination
          )
          Toggle(
            LocalizedStringKey("Show Hanyu-Pinyin in the inline composition buffer"),
            isOn: $showHanyuPinyinInCompositionBuffer
          )
          Toggle(
            LocalizedStringKey("Allow backspace-editing miscomposed readings"),
            isOn: $keepReadingUponCompositionError
          )
          Toggle(
            LocalizedStringKey("Also use “\\” or “¥” key for Hanin Keyboard Symbol Input"),
            isOn: $classicHaninKeyboardSymbolModeShortcutEnabled
          )
          Toggle(
            LocalizedStringKey("Emulating select-candidate-per-character mode"),
            isOn: $useSCPCTypingMode.onChange {
              guard useSCPCTypingMode else { return }
              LMMgr.loadUserSCPCSequencesData()
            }
          )
          Text(LocalizedStringKey("An accommodation for elder computer users."))

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          if Date.isTodayTheDate(from: 0401) {
            Toggle(
              LocalizedStringKey("Stop farting (when typed phonetic combination is invalid, etc.)"),
              isOn: $shouldNotFartInLieuOfBeep.onChange {
                let content = String(
                  format: NSLocalizedString(
                    "You are about to uncheck this fart suppressor. You are responsible for all consequences lead by letting people nearby hear the fart sound come from your computer. We strongly advise against unchecking this in any public circumstance that prohibits NSFW netas.",
                    comment: ""
                  ))
                let alert = NSAlert(error: NSLocalizedString("Warning", comment: ""))
                alert.informativeText = content
                alert.addButton(withTitle: NSLocalizedString("Uncheck", comment: ""))
                if #available(macOS 11, *) {
                  alert.buttons.forEach { button in
                    button.hasDestructiveAction = true
                  }
                }
                alert.addButton(withTitle: NSLocalizedString("Leave it checked", comment: ""))
                if let window = CtlPrefUIShared.sharedWindow, !shouldNotFartInLieuOfBeep {
                  shouldNotFartInLieuOfBeep = true
                  alert.beginSheetModal(for: window) { result in
                    switch result {
                    case .alertFirstButtonReturn:
                      shouldNotFartInLieuOfBeep = false
                    case .alertSecondButtonReturn:
                      shouldNotFartInLieuOfBeep = true
                    default: break
                    }
                    IMEApp.buzz()
                  }
                  return
                }
                IMEApp.buzz()
              }
            )
          }
        }
        SSPreferences.Settings.Section(label: { Text(LocalizedStringKey("Misc Settings:")).controlSize(.small) }) {
          Toggle(
            LocalizedStringKey("Check for updates automatically"),
            isOn: $checkUpdateAutomatically
          )
          .controlSize(.small)
          Toggle(
            LocalizedStringKey("Debug Mode"),
            isOn: $isDebugModeEnabled
          )
          .controlSize(.small)
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneGeneral_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneGeneral()
  }
}
