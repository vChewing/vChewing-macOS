// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - VwrSettingsPaneDevZone

@available(macOS 14, *)
public struct VwrSettingsPaneDevZone: View {
  // MARK: Public

  // MARK: - Main View

  public var body: some View {
    NavigationStack {
      Form {
        Section {
          UserDef.kSecurityHardenedCompositionBuffer
            .bind($securityHardenedCompositionBuffer)
            .render()
          UserDef.kAlwaysUsePCBWithElectronBasedClients
            .bind($alwaysUsePCBWithElectronBasedClients)
            .render()
          UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients
            .bind($disableSegmentedThickUnderlineInMarkingModeForManagedClients)
            .render()
        } header: {
          Text(
            "Warning: This page is for testing future features. \nFeatures listed here may not work as expected."
          )
        }
        Section {
          UserDef.kCheckAbusersOfSecureEventInputAPI
            .bind($checkAbusersOfSecureEventInputAPI)
            .render()
          UserDef.kUserPhrasesDatabaseBypassed
            .bind($bypassNonAppleCapsLockHandling)
            .render()
          UserDef.kAllowRescoringSingleKanjiCandidates.bind($allowRescoringSingleKanjiCandidates)
            .render()
        } footer: {
          Text("Some previous options are moved to other tabs.".i18n)
            .settingsDescription()
        }
      }.formStyled()
    }
    .frame(
      minWidth: CtlSettingsUI.formWidth,
      maxHeight: CtlSettingsUI.contentMaxHeight
    )
  }

  // MARK: Private

  // MARK: - AppStorage Variables

  @AppStorage(
    wrappedValue: false,
    UserDef.kAllowRescoringSingleKanjiCandidates.rawValue
  )
  private var allowRescoringSingleKanjiCandidates: Bool

  @AppStorage(
    wrappedValue: false,
    UserDef.kBypassNonAppleCapsLockHandling.rawValue
  )
  private var bypassNonAppleCapsLockHandling: Bool

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
    UserDef.kAlwaysUsePCBWithElectronBasedClients.rawValue
  )
  private var alwaysUsePCBWithElectronBasedClients: Bool

  @AppStorage(
    wrappedValue: true,
    UserDef.kCheckAbusersOfSecureEventInputAPI.rawValue
  )
  private var checkAbusersOfSecureEventInputAPI: Bool
}

// MARK: - VwrSettingsPaneDevZone_Previews

@available(macOS 14, *)
struct VwrSettingsPaneDevZone_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneDevZone()
  }
}
