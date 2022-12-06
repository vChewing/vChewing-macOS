// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SSPreferences
import Shared
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPaneDevZone: View {
  @State private var selUseIMKCandidateWindow: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kUseIMKCandidateWindow.rawValue)
  @State private var selHandleDefaultCandidateFontsByLangIdentifier: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kHandleDefaultCandidateFontsByLangIdentifier.rawValue)
  @State private var selShiftKeyAccommodationBehavior: Int = UserDefaults.standard.integer(
    forKey: UserDef.kShiftKeyAccommodationBehavior.rawValue)
  @State private var selPhraseReplacementEnabled: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kPhraseReplacementEnabled.rawValue
  )

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

  var isMontereyOrAbove: Bool = {
    if #available(macOS 12.0, *) {
      return true
    }
    return false
  }()

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: contentWidth) {
        SSPreferences.Section(title: "", bottomDivider: true) {
          Text(
            LocalizedStringKey(
              "Warning: This page is for testing future features. \nFeatures listed here may not work as expected.")
          )
          .fixedSize(horizontal: false, vertical: true)
          Divider()
          Toggle(
            LocalizedStringKey("Use IMK Candidate Window instead of Tadokoro (will reboot the IME)"),
            isOn: $selUseIMKCandidateWindow.onChange {
              PrefMgr.shared.useIMKCandidateWindow = selUseIMKCandidateWindow
              NSLog("vChewing App self-terminated due to enabling / disabling IMK candidate window.")
              NSApp.terminate(nil)
            }
          )
          Text(
            LocalizedStringKey(
              "IMK candidate window relies on certain Apple private APIs which are force-exposed by using bridging headers. Its usability, at this moment, is only guaranteed from macOS 10.14 Mojave to macOS 13 Ventura. Further tests are required in the future in order to tell whether it is usable in newer macOS releases. However, this mode is recommended at this moment since Tadokoro candidate window still needs possible improvements."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
          Toggle(
            LocalizedStringKey("Use .langIdentifier to handle UI fonts in candidate window"),
            isOn: $selHandleDefaultCandidateFontsByLangIdentifier.onChange {
              PrefMgr.shared.handleDefaultCandidateFontsByLangIdentifier =
                selHandleDefaultCandidateFontsByLangIdentifier
            }
          )
          .disabled(!isMontereyOrAbove)
          Text(
            LocalizedStringKey(
              "This only works with Tadokoro candidate window."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
          Picker(
            "",
            selection: $selShiftKeyAccommodationBehavior.onChange {
              PrefMgr.shared.shiftKeyAccommodationBehavior = selShiftKeyAccommodationBehavior
            }
          ) {
            Text(LocalizedStringKey("Disable Shift key accomodation in all cases")).tag(0)
            Text(LocalizedStringKey("Only use this with known Chromium-based browsers")).tag(1)
            Text(LocalizedStringKey("Use Shift key accommodation in all cases")).tag(2)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(
            LocalizedStringKey(
              "Some client apps (like Chromium-cored browsers: MS Edge, Google Chrome, etc.) may duplicate Shift-key inputs due to their internal bugs, and their devs are less likely to fix their bugs of such. vChewing has its accommodation procedures enabled by default for known Chromium-cored browsers. Here you can customize how the accommodation should work."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
          HStack {
            Toggle(
              LocalizedStringKey("Enable phrase replacement table"),
              isOn: $selPhraseReplacementEnabled.onChange {
                PrefMgr.shared.phraseReplacementEnabled = selPhraseReplacementEnabled
              }
            )
          }
          Text(
            LocalizedStringKey(
              "This will batch-replace specified candidates."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneDevZone_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneDevZone()
  }
}
