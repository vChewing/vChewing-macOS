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
struct VwrPrefPaneDevZone: View {
  // MARK: - AppStorage Variables

  @Backport.AppStorage(
    wrappedValue: false,
    UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients.rawValue
  )
  private var disableSegmentedThickUnderlineInMarkingModeForManagedClients: Bool

  @Backport.AppStorage(
    wrappedValue: false,
    UserDef.kSecurityHardenedCompositionBuffer.rawValue
  )
  private var securityHardenedCompositionBuffer: Bool

  // MARK: - Main View

  var body: some View {
    ScrollView {
      SSPreferences.Settings.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        SSPreferences.Settings.Section(bottomDivider: true) {
          Text(
            LocalizedStringKey(
              "Warning: This page is for testing future features. \nFeatures listed here may not work as expected.")
          )
          .fixedSize(horizontal: false, vertical: true)
          Divider()
          HStack {
            Text("Some previous options are moved to other tabs.".localized)

              .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          }
          Toggle(
            UserDef.kSecurityHardenedCompositionBuffer.metaData?.shortTitle?.localized ?? "",
            isOn: $securityHardenedCompositionBuffer
          )
          Text(
            UserDef.kSecurityHardenedCompositionBuffer.metaData?.description?.localized ?? ""
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          Toggle(
            "Disable segmented thick underline in marking mode for managed clients".localized,
            isOn: $disableSegmentedThickUnderlineInMarkingModeForManagedClients
          )
          Text(
            "Some clients with web-based front UI may have issues rendering segmented thick underlines drawn by their implemented “setMarkedText()”. This option stops the input method from delivering segmented thick underlines to “client().setMarkedText()”. Note that segmented thick underlines are only used in marking mode, unless the client itself misimplements the IMKTextInput method “setMarkedText()”. This option only affects the inline composition buffer.".localized
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneDevZone_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneDevZone()
  }
}
