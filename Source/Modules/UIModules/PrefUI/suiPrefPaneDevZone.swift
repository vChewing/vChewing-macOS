// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

@available(macOS 10.15, *)
struct suiPrefPaneDevZone: View {
  @State private var selUseIMKCandidateWindow: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kUseIMKCandidateWindow.rawValue)
  @State private var selHandleDefaultCandidateFontsByLangIdentifier: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kHandleDefaultCandidateFontsByLangIdentifier.rawValue)
  @State private var selShouldAlwaysUseShiftKeyAccommodation: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kShouldAlwaysUseShiftKeyAccommodation.rawValue)

  private let contentMaxHeight: Double = 430
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

  var isMontereyOrAbove: Bool = {
    if #available(macOS 12.0, *) {
      return true
    }
    return false
  }()

  var body: some View {
    ScrollView {
      Preferences.Container(contentWidth: contentWidth) {
        Preferences.Section(title: "", bottomDivider: true) {
          Text(
            LocalizedStringKey(
              "Warning: This page is for testing future features. \nFeatures listed here may not work as expected.")
          )
          .fixedSize(horizontal: false, vertical: true)
          Divider()
          Toggle(
            LocalizedStringKey("Use IMK Candidate Window instead (will reboot the IME)"),
            isOn: $selUseIMKCandidateWindow.onChange {
              mgrPrefs.useIMKCandidateWindow = selUseIMKCandidateWindow
              NSLog("vChewing App self-terminated due to enabling / disabling IMK candidate window.")
              NSApplication.shared.terminate(nil)
            }
          )
          Text(LocalizedStringKey("IMK candidate window is plagued with issues and incapabilities."))
            .preferenceDescription().fixedSize(horizontal: false, vertical: true)
          Toggle(
            LocalizedStringKey("Use .langIdentifier to handle UI fonts in candidate window"),
            isOn: $selHandleDefaultCandidateFontsByLangIdentifier.onChange {
              mgrPrefs.handleDefaultCandidateFontsByLangIdentifier = selHandleDefaultCandidateFontsByLangIdentifier
            }
          )
          Text(
            LocalizedStringKey(
              "This only works since macOS 12 with non-IMK candidate window as an alternative wordaround of Apple Bug Report #FB10978412. Apple should patch that for macOS 11 and later."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
          .disabled(!isMontereyOrAbove)
          Toggle(
            LocalizedStringKey("Use Shift Key Accommodation in all cases"),
            isOn: $selShouldAlwaysUseShiftKeyAccommodation.onChange {
              mgrPrefs.shouldAlwaysUseShiftKeyAccommodation = selShouldAlwaysUseShiftKeyAccommodation
            }
          )
          .disabled(mgrPrefs.disableShiftTogglingAlphanumericalMode)
          Text(
            LocalizedStringKey(
              "Some client apps (like Chromium-cored browsers: MS Edge, Google Chrome, etc.) may duplicate Shift-key inputs due to their internal bugs, and their devs are less likely to fix their bugs of such. vChewing has its accommodation procedures enabled by default for known Chromium-cored browsers. If you want the same accommodation for other client apps, please tick this checkbox on."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
  }
}

@available(macOS 11.0, *)
struct suiPrefPaneDevZone_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneDevZone()
  }
}
