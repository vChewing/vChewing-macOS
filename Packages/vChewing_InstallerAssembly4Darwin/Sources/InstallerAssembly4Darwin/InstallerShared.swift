// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import IMKUtils
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

/// 從安裝器內嵌的 IME App Bundle 取得 InputMethodConnectionName。
/// 若 plist 中沒有該 key，則 fallback 到 CFBundleIdentifier。
var installingIMEConnectionName: String? {
  Bundle.main.path(forResource: kTargetBin, ofType: kTargetType)
    .flatMap { Bundle(path: $0) }
    .flatMap { $0.infoDictionary?["InputMethodConnectionName"] as? String ?? $0.bundleIdentifier }
}

/// 安裝失敗後，兩次嘗試之間的等待間隔（秒）。
let kInstallRetryInterval: TimeInterval = 0.5
/// 放棄自動重試、改提示使用者重新登入前的等待上限（秒）。
let kInstallRetryTimeout: Int = 60

/// 於指定目錄內產生一個不會與既有項目碰撞的暫存 URL。
///
/// 之所以要求在**同一目錄**內：就位時用的是同卷宗的 `moveItem`，必須是原子搬移。
/// 名稱以 `.` 起頭（隱藏），故 `findAppBundlesWithSameConnectionName`（帶 `skipsHiddenFiles`）
/// 不會把殘留的暫存物誤認為已安裝的 bundle。
func makeStagingURL(
  inDirectory directory: URL,
  fileManager: FileManager = .default
)
  -> URL {
  var candidate = directory.appendingPathComponent(".vChewingInstallStaging-\(UUID().uuidString).app")
  while fileManager.fileExists(atPath: candidate.path) {
    candidate = directory.appendingPathComponent(".vChewingInstallStaging-\(UUID().uuidString).app")
  }
  return candidate
}

let installingVersion = Bundle.main
  .infoDictionary?[kCFBundleVersionKey as String] as? String ?? "BAD_INSTALLING_VER"
let versionString = Bundle.main
  .infoDictionary?["CFBundleShortVersionString"] as? String ?? "BAD_VER_STR"
let copyrightLabel = Bundle.main
  .localizedInfoDictionary?["NSHumanReadableCopyright"] as? String ?? "BAD_COPYRIGHT_LABEL"
let eulaContent = Bundle.main
  .localizedInfoDictionary?["CFEULAContent"] as? String ?? "BAD_EULA_CONTENT"
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
  var isCancelButtonEnabled: Bool = true
  var isAgreeButtonEnabled: Bool = true
  var isPreviousVersionNotFullyDeactivated: Bool = false
  var isUpgrading: Bool = false
  var timeRemaining: Int = kInstallRetryTimeout
  /// 首次安裝失敗時記下的重試截止時刻；`nil` 表示尚未失敗過。
  var retryDeadline: Date?
  var adminRenameFailureAlertPaths: [String] = []
  /// 安裝結果面板所顯示的 AlertType（Cocoa / AppKit 前端仍使用此標記觸發 alert）。
  var currentAlertContent: AlertType = .nothing

  /// 當前應該顯示的警示面板內容（SwiftUI 使用）。
  /// 因 SwiftUI 不允許在同一個 view 上串接多個 `.alert()`，
  /// 所以統一由單一 `alert(item:)` 驅動。
  var alertItem: InstallerAlertItem?

  /// 距離重試截止時刻的剩餘秒數（無條件進位）；尚未失敗過時回傳逾時上限。
  var retrySecondsRemaining: Int {
    guard let retryDeadline else { return kInstallRetryTimeout }
    return max(0, Int(retryDeadline.timeIntervalSinceNow.rounded(.up)))
  }
}

// MARK: - InstallerAlertItem

struct InstallerAlertItem: Identifiable, Hashable {
  // MARK: Lifecycle

  init(title: String, message: String, buttonTitle: String) {
    self.title = title
    self.message = message
    self.buttonTitle = buttonTitle
  }

  // MARK: Internal

  let id = UUID()
  let title: String
  let message: String
  let buttonTitle: String

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

// MARK: - InstallerUIConfig.AlertType

extension InstallerUIConfig {
  public enum AlertType: String, Identifiable, Hashable, Sendable {
    case nothing, installationFailed, missingAfterRegistration, oldVersionStillInUse,
         postInstallWarning, postInstallOK, adminRenameFailure

    // MARK: Public

    public var id: String { rawValue }

    // MARK: Internal

    var titleLocalized: String {
      switch self {
      case .nothing: return ""
      case .installationFailed: return "i18n:Installer.InstallFailed".i18n
      case .missingAfterRegistration: return "i18n:Installer.FatalError".i18n
      case .oldVersionStillInUse: return "i18n:Installer.Attention".i18n
      case .postInstallWarning: return "i18n:Common.Warning".i18n
      case .postInstallOK: return "i18n:Installer.InstallationSuccessful".i18n
      case .adminRenameFailure: return "i18n:Installer.Attention".i18n
      }
    }

    var message: String {
      switch self {
      case .nothing: return ""
      case .installationFailed:
        return "i18n:Installer.CannotCopyFileToDestination".i18n
      case .missingAfterRegistration:
        return String(
          format: "i18n:Installer.CannotFindInputSourceAfterRegistration:%@".i18n,
          kTISInputSourceID
        )
      case .oldVersionStillInUse:
        return "i18n:Installer.OldVersionStillInUse".i18n
      case .postInstallWarning:
        return "i18n:Installer.InputMethodMayNotBeFullyEnabled".i18n
      case .postInstallOK:
        return "i18n:Installer.ReadyToUse".i18n
      case .adminRenameFailure:
        return "i18n:Installer.AdminRenameFailureNotice".i18n
      }
    }

    func alertContent(paths: [String] = []) -> (title: String, message: String, buttonTitle: String) {
      let title = titleLocalized
      let msg: String
      switch self {
      case .adminRenameFailure:
        msg = message + "\n\n" + paths.joined(separator: "\n")
      default:
        msg = message
      }
      let button: String
      switch self {
      case .installationFailed: button = "Cancel"
      case .missingAfterRegistration: button = "Abort"
      case .postInstallWarning: button = "Continue"
      default: button = "OK"
      }
      return (title, msg, button)
    }

    func makeAlertItem(paths: [String] = []) -> InstallerAlertItem {
      let content = alertContent(paths: paths)
      return InstallerAlertItem(title: content.title, message: content.message, buttonTitle: content.buttonTitle)
    }

    /// 若 AlertType 不是 `.nothing`，則產生對應的 `InstallerAlertItem`，供 Cocoa 前端顯示。
    func makeAlertItemIfNeeded(paths: [String] = []) -> InstallerAlertItem? {
      guard self != .nothing else { return nil }
      return makeAlertItem(paths: paths)
    }
  }
}
