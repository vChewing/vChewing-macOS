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
public struct VwrSettingsPaneDevZone: View {
  // MARK: - AppStorage Variables

  @AppStorage(
    wrappedValue: false,
    UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients.rawValue
  )
  private var disableSegmentedThickUnderlineInMarkingModeForManagedClients: Bool

  @AppStorage(
    wrappedValue: false,
    UserDef.kSecurityHardenedCompositionBuffer.rawValue
  )
  private var securityHardenedCompositionBuffer: Bool

  @AppStorage(
    wrappedValue: true,
    UserDef.kCheckAbusersOfSecureEventInputAPI.rawValue
  )
  private var checkAbusersOfSecureEventInputAPI: Bool

  // MARK: - Main View

  public var body: some View {
    ScrollView {
      Form {
        Section(header: Text(
          "Warning: This page is for testing future features. \nFeatures listed here may not work as expected."
        ), footer: Text("Some previous options are moved to other tabs.".localized).settingsDescription()) {
          VStack(alignment: .leading) {
            Toggle(
              UserDef.kSecurityHardenedCompositionBuffer.metaData?.shortTitle?.localized ?? "",
              isOn: $securityHardenedCompositionBuffer
            )
            Text(
              UserDef.kSecurityHardenedCompositionBuffer.metaData?.description?.localized ?? ""
            )
            .settingsDescription()
          }
          VStack(alignment: .leading) {
            Toggle(
              "Disable segmented thick underline in marking mode for managed clients".localized,
              isOn: $disableSegmentedThickUnderlineInMarkingModeForManagedClients
            )
            Text(
              "Some clients with web-based front UI may have issues rendering segmented thick underlines drawn by their implemented “setMarkedText()”. This option stops the input method from delivering segmented thick underlines to “client().setMarkedText()”. Note that segmented thick underlines are only used in marking mode, unless the client itself misimplements the IMKTextInput method “setMarkedText()”. This option only affects the inline composition buffer.".localized
            )
            .settingsDescription()
          }
          VStack(alignment: .leading) {
            Toggle(
              (UserDef.kCheckAbusersOfSecureEventInputAPI.metaData?.shortTitle ?? "i18n:UserDef.kCheckAbusersOfSecureEventInputAPI.shortTitle").localized,
              isOn: $checkAbusersOfSecureEventInputAPI
            )
            Text(
              (UserDef.kCheckAbusersOfSecureEventInputAPI.metaData?.description ?? "i18n:UserDef.kCheckAbusersOfSecureEventInputAPI.description").localized
            )
            .settingsDescription()
          }
        }
      }.formStyled().frame(minWidth: CtlSettingsUI.formWidth, maxWidth: ceil(CtlSettingsUI.formWidth * 1.2))
    }
    .frame(maxHeight: CtlSettingsUI.contentMaxHeight)
  }
}

@available(macOS 13, *)
struct VwrSettingsPaneDevZone_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneDevZone()
  }
}
