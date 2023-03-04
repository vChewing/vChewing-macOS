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
struct VwrPrefPaneGeneral: View {
  @State private var selUILanguage: [String] =
    Shared.arrSupportedLocales.contains(
      ((UserDefaults.standard.object(forKey: UserDef.kAppleLanguages.rawValue) == nil)
        ? ["auto"] : UserDefaults.standard.array(forKey: UserDef.kAppleLanguages.rawValue) as? [String] ?? ["auto"])[0])
    ? ((UserDefaults.standard.object(forKey: UserDef.kAppleLanguages.rawValue) == nil)
      ? ["auto"] : UserDefaults.standard.array(forKey: UserDef.kAppleLanguages.rawValue) as? [String] ?? ["auto"])
    : ["auto"]
  @State private var selAutoCorrectReadingCombination = UserDefaults.standard.bool(
    forKey: UserDef.kAutoCorrectReadingCombination.rawValue)
  @State private var selShowHanyuPinyinInCompositionBuffer = UserDefaults.standard.bool(
    forKey: UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue)
  @State private var selKeepReadingUponCompositionError = UserDefaults.standard.bool(
    forKey: UserDef.kKeepReadingUponCompositionError.rawValue)
  @State private var selClassicHaninKeyboardSymbolModeShortcutEnabled = UserDefaults.standard.bool(
    forKey: UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.rawValue)
  @State private var selEnableSCPCTypingMode = UserDefaults.standard.bool(forKey: UserDef.kUseSCPCTypingMode.rawValue)
  @State private var selEnableFartSuppressor = UserDefaults.standard.bool(
    forKey: UserDef.kShouldNotFartInLieuOfBeep.rawValue)
  @State private var selEnableAutoUpdateCheck = UserDefaults.standard.bool(
    forKey: UserDef.kCheckUpdateAutomatically.rawValue)
  @State private var selEnableDebugMode = UserDefaults.standard.bool(forKey: UserDef.kIsDebugModeEnabled.rawValue)

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        SSPreferences.Section {
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
          .preferenceDescription().padding(.bottom, NSFont.systemFontSize)
        }
        SSPreferences.Section(title: "UI Language:".localized) {
          HStack {
            Picker(
              LocalizedStringKey("Follow OS settings"),
              selection: $selUILanguage.onChange {
                vCLog(selUILanguage[0])
                if selUILanguage == PrefMgr.shared.appleLanguages
                  || (selUILanguage[0] == "auto"
                    && UserDefaults.standard.object(forKey: UserDef.kAppleLanguages.rawValue) == nil)
                {
                  return
                }
                if selUILanguage[0] != "auto" {
                  PrefMgr.shared.appleLanguages = selUILanguage
                } else {
                  UserDefaults.standard.removeObject(forKey: UserDef.kAppleLanguages.rawValue)
                }
                NSLog("vChewing App self-terminated due to UI language change.")
                NSApp.terminate(nil)
              }
            ) {
              Text(LocalizedStringKey("Follow OS settings")).tag(["auto"])
              Text(LocalizedStringKey("Simplified Chinese")).tag(["zh-Hans"])
              Text(LocalizedStringKey("Traditional Chinese")).tag(["zh-Hant"])
              Text(LocalizedStringKey("Japanese")).tag(["ja"])
              Text(LocalizedStringKey("English")).tag(["en"])
            }
            .labelsHidden()
            .frame(width: 180.0)
            Spacer()
          }
          Text(LocalizedStringKey("Change user interface language (will reboot the IME)."))
            .preferenceDescription()
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Typing Settings:")) }) {
          Toggle(
            LocalizedStringKey("Automatically correct reading combinations when typing"),
            isOn: $selAutoCorrectReadingCombination.onChange {
              PrefMgr.shared.autoCorrectReadingCombination = selAutoCorrectReadingCombination
            }
          )
          Toggle(
            LocalizedStringKey("Show Hanyu-Pinyin in the inline composition buffer"),
            isOn: $selShowHanyuPinyinInCompositionBuffer.onChange {
              PrefMgr.shared.showHanyuPinyinInCompositionBuffer = selShowHanyuPinyinInCompositionBuffer
            }
          )
          Toggle(
            LocalizedStringKey("Allow backspace-editing miscomposed readings"),
            isOn: $selKeepReadingUponCompositionError.onChange {
              PrefMgr.shared.keepReadingUponCompositionError = selKeepReadingUponCompositionError
            }
          )
          Toggle(
            LocalizedStringKey("Also use “\\” or “¥” key for Hanin Keyboard Symbol Input"),
            isOn: $selClassicHaninKeyboardSymbolModeShortcutEnabled.onChange {
              PrefMgr.shared.classicHaninKeyboardSymbolModeShortcutEnabled
                = selClassicHaninKeyboardSymbolModeShortcutEnabled
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
          if Date.isTodayTheDate(from: 0401) {
            Toggle(
              LocalizedStringKey("Stop farting (when typed phonetic combination is invalid, etc.)"),
              isOn: $selEnableFartSuppressor.onChange {
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
                if let window = CtlPrefUIShared.sharedWindow, !selEnableFartSuppressor {
                  PrefMgr.shared.shouldNotFartInLieuOfBeep = true
                  alert.beginSheetModal(for: window) { result in
                    switch result {
                    case .alertFirstButtonReturn:
                      PrefMgr.shared.shouldNotFartInLieuOfBeep = false
                    case .alertSecondButtonReturn:
                      PrefMgr.shared.shouldNotFartInLieuOfBeep = true
                    default: break
                    }
                    selEnableFartSuppressor = PrefMgr.shared.shouldNotFartInLieuOfBeep
                    IMEApp.buzz()
                  }
                  return
                }
                PrefMgr.shared.shouldNotFartInLieuOfBeep = selEnableFartSuppressor
                IMEApp.buzz()
              }
            )
          }
        }
        SSPreferences.Section(label: { Text(LocalizedStringKey("Misc Settings:")).controlSize(.small) }) {
          Toggle(
            LocalizedStringKey("Check for updates automatically"),
            isOn: $selEnableAutoUpdateCheck.onChange {
              PrefMgr.shared.checkUpdateAutomatically = selEnableAutoUpdateCheck
            }
          )
          .controlSize(.small)
          Toggle(
            LocalizedStringKey("Debug Mode"),
            isOn: $selEnableDebugMode.onChange {
              PrefMgr.shared.isDebugModeEnabled = selEnableDebugMode
            }
          )
          .controlSize(.small)
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneGeneral_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneGeneral()
  }
}
