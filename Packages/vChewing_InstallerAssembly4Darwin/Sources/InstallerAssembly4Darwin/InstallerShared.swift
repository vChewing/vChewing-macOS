// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import InputMethodKit
import SwiftExtension

let kTargetBin = "vChewing"
let kTargetBinPhraseEditor = "vChewingPhraseEditor"
let kTargetType = "app"
let kTargetBundle = "vChewing.app"
let kTargetBundleWithComponents = "Library/Input%20Methods/vChewing.app"
let kTISInputSourceID = "org.atelierInmu.inputmethod.vChewing"

let imeURLInstalled = realHomeDir.appendingPathComponent("Library/Input Methods/vChewing.app")

let realHomeDir: URL = {
  // Use 10.9-safe URL initializer (no relativeTo: parameter).
  let url = URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir))
  return url.standardizedFileURL
}()

let urlDestinationPartial = realHomeDir.appendingPathComponent("Library/Input Methods")
let urlTargetPartial = realHomeDir.appendingPathComponent(kTargetBundleWithComponents)
let urlTargetFullBinPartial = urlTargetPartial.appendingPathComponent("Contents/MacOS")
  .appendingPathComponent(kTargetBin)

let kDestinationPartial = urlDestinationPartial.path
let kTargetPartialPath = urlTargetPartial.path
let kTargetFullBinPartialPath = urlTargetFullBinPartial.path

let kTranslocationRemovalTickInterval: TimeInterval = 0.5
let kTranslocationRemovalDeadline: TimeInterval = 60.0

let installingVersion = Bundle.main
  .infoDictionary?[kCFBundleVersionKey as String] as? String ?? "BAD_INSTALLING_VER"
let versionString = Bundle.main
  .infoDictionary?["CFBundleShortVersionString"] as? String ?? "BAD_VER_STR"
let copyrightLabel = Bundle.main
  .localizedInfoDictionary?["NSHumanReadableCopyright"] as? String ?? "BAD_COPYRIGHT_LABEL"
let eulaContent = Bundle.main
  .localizedInfoDictionary?["CFEULAContent"] as? String ?? "BAD_EULA_CONTENT"
let eulaContentUpstream = Bundle.main
  .infoDictionary?["CFUpstreamEULAContent"] as? String ?? "BAD_EULA_UPSTREAM"
let lsMinOSVerStr = Bundle.main
  .infoDictionary?["LSMinimumSystemVersion"] as? String

var minimumOSSupportedDescriptionString: String? {
  guard let lsMinOSVerStr else { return nil }
  let formattedString = String(
    format: "i18n:installer.SUPPORTING_OS:%@".i18n,
    lsMinOSVerStr
  )
  return " " + formattedString
}

var mainWindowTitle: String {
  let result = "i18n:installer.INSTALLER_APP_TITLE_FULL"
    .i18n + " (v\(versionString), Build \(installingVersion))"
  if AppInstallerDelegate.shared.isLegacyDistro {
    return "\(result) (Aqua Special)"
  }
  return result
}

var allRegisteredInstancesOfThisInputMethod: [TISInputSource] {
  guard let components = Bundle(url: imeURLInstalled)?
    .infoDictionary?["ComponentInputModeDict"] as? [String: Any],
    let tsInputModeListKey = components["tsInputModeListKey"] as? [String: Any]
  else {
    return []
  }
  return TISInputSource.match(modeIDs: tsInputModeListKey.keys.map(\.description))
}

// MARK: - KeyWindow Finder

extension NSApplication {
  var keyWindows: [NSWindow] {
    NSApp.windows.filter(\.isKeyWindow)
  }
}

// MARK: - NSApp End With Delay

extension NSApplication {
  func terminateWithDelay() {
    asyncOnMain(after: 0.1) { [weak self] in
      if let this = self {
        this.terminate(this)
      }
    }
  }
}

// MARK: - InstallerUIConfig

struct InstallerUIConfig: Hashable {
  var pendingSheetPresenting: Bool = false
  var isLegacyPackageNoticeEverShown: Bool = false
  var isShowingAlertForFailedInstallation: Bool = false
  var isShowingAlertForMissingPostInstall: Bool = false
  var isShowingPostInstallNotification: Bool = false
  var currentAlertContent: AlertType = .nothing
  var isCancelButtonEnabled: Bool = true
  var isAgreeButtonEnabled: Bool = true
  var isPreviousVersionNotFullyDeactivated: Bool = false
  var isTranslocationFinished: Bool?
  var isUpgrading: Bool = false
  var timeRemaining: Int = .init(kTranslocationRemovalDeadline)
}

// MARK: InstallerUIConfig.AlertType

extension InstallerUIConfig {
  public enum AlertType: String, Identifiable, Hashable, Sendable {
    case nothing, installationFailed, missingAfterRegistration, postInstallAttention,
         postInstallWarning, postInstallOK

    // MARK: Public

    public var id: String { rawValue }

    // MARK: Internal

    var titleLocalized: String {
      switch self {
      case .nothing: return ""
      case .installationFailed: return "Install Failed".i18n
      case .missingAfterRegistration: return "Fatal Error".i18n
      case .postInstallAttention: return "Attention".i18n
      case .postInstallWarning: return "Warning".i18n
      case .postInstallOK: return "Installation Successful".i18n
      }
    }

    var message: String {
      switch self {
      case .nothing: return ""
      case .installationFailed:
        return "Cannot copy the file to the destination.".i18n
      case .missingAfterRegistration:
        return String(
          format: "Cannot find input source %@ after registration.".i18n,
          kTISInputSourceID
        )
      case .postInstallAttention:
        return "vChewing is upgraded, but please log out or reboot for the new version to be fully functional."
          .i18n
      case .postInstallWarning:
        return "Input method may not be fully enabled. Please enable it through System Preferences > Keyboard > Input Sources."
          .i18n
      case .postInstallOK:
        return "vChewing is ready to use. \n\nPlease relogin if this is the first time you install it in this user account."
          .i18n
      }
    }
  }
}
