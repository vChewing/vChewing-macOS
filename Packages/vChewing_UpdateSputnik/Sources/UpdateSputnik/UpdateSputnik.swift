// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import SwiftExtension

// MARK: - UpdateSputnik

public final class UpdateSputnik {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  /// 由 `MainSputnik4IME.runNSApp(isLegacyDistro:)` 於啟動階段填入；勿再以 bundle ID 之類的線索猜測發行版。
  /// 讀取端落於 URLSession 的回呼，故以 `nonisolated(unsafe)` 標明「啟動時寫入一次、其後唯讀」。
  nonisolated(unsafe) public static var isMainStreamRelease = true
  public static let shared: UpdateSputnik = .init()

  public let kUpdateInfoPageURLKey: String = {
    if #available(macOS 13, *) {
      return "UpdateInfoSite"
    }
    return "UpdateInfoSiteLegacy"
  }()

  public let kUpdateInfoPageURLGitHubKey: String = {
    if #available(macOS 13, *) {
      return "UpdateInfoSiteGitHub"
    }
    return "UpdateInfoSiteLegacyGitHub"
  }()

  public let kUpdateCheckDateKeyPrevious: String = "PreviousUpdateCheckDate"
  public let kUpdateCheckDateKeyNext: String = "NextUpdateCheckDate"
  public let kUpdateCheckInterval: TimeInterval = 114_514
  public let kCheckUpdateAutomatically = "CheckUpdateAutomatically"
  public let kSkippedUpdateVersionBuildKey = "SkippedUpdateVersionBuild"

  public func checkForUpdate(forced: Bool = false, url: URL, shouldBypass: @escaping () -> Bool) {
    let shouldBypass = shouldBypass()
    silentMode = shouldBypass
    guard !shouldBypass, !busy else { return }

    if !forced {
      if !UserDefaults.standard.bool(forKey: kCheckUpdateAutomatically) { return }
      if let nextCheckDate = nextUpdateCheckDate,
         Date().compare(nextCheckDate) == .orderedAscending {
        return
      }
    }
    isCurrentCheckForced = forced // 留著用來生成錯誤報告
    let request = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5
    )

    let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
      guard let this = self else { return }
      if let error = error {
        asyncOnMain { [weak self] in
          guard let this = self else { return }
          mainSync {
            if !this.silentMode {
              this.showError(message: error.localizedDescription)
            }
            this.currentTask = nil
          }
        }
        return
      }
      mainSync {
        this.data = data
      }
    }
    task.resume()
    currentTask = task
  }

  // MARK: Internal

  var sessionConfiguration: URLSessionConfiguration = {
    if #available(macOS 10.10, *) {
      return URLSessionConfiguration.background(withIdentifier: Bundle.main.bundleIdentifier!)
    } else {
      return URLSessionConfiguration.backgroundSessionConfiguration(Bundle.main.bundleIdentifier!)
    }
  }()

  // MARK: - Private Functions.

  internal func dataDidSet(data: Data) {
    var plist: [AnyHashable: Any]?
    plist = try? PropertyListSerialization
      .propertyList(from: data, options: [], format: nil) as? [AnyHashable: Any]
    nextUpdateCheckDate = .init().addingTimeInterval(kUpdateCheckInterval)
    cleanUp()

    guard let plist = plist else {
      asyncOnMain { [weak self] in
        guard let this = self else { return }
        this.showError(message: "i18n:ErrorMessage.PlistNil".i18n)
        this.currentTask = nil
      }
      return
    }

    Process.consoleLog("update check plist: \(plist)")

    guard let intRemoteVersion = Int(plist[kCFBundleVersionKey] as? String ?? ""),
          let strRemoteVersionShortened = plist["CFBundleShortVersionString"] as? String
    else {
      asyncOnMain { [weak self] in
        guard let this = self else { return }
        this.showError(message: "i18n:ErrorMessage.PlistParseError".i18n)
        this.currentTask = nil
      }
      return
    }

    guard let dicMainBundle = Bundle.main.infoDictionary,
          let intCurrentVersion =
          Int(dicMainBundle[kCFBundleVersionKey as String] as? String ?? ""),
          let strCurrentVersionShortened = dicMainBundle["CFBundleShortVersionString"] as? String
    else { return } // Shouldn't happen.
    /// 註：此處 isRemoteMainStreamDistro 在 Aqua 紀念版內應該設為 false；主流版則為 true。
    let isRemoteMainStreamDistro: Bool = plist["IsMainStreamDistro"] as? Bool ?? true
    let crossDistroNotification = Self.isMainStreamRelease != isRemoteMainStreamDistro
    versionCheck: if intRemoteVersion <= intCurrentVersion {
      guard isCurrentCheckForced else { return }
      if intRemoteVersion == intCurrentVersion, crossDistroNotification { break versionCheck }
      let alert = NSAlert()
      alert.messageText = "i18n:UpdateNotification.UpdateCheckCompleted".i18n
      alert.informativeText = "i18n:InfoMessage.AlreadyLatestVersion".i18n
      alert.addButton(withTitle: "i18n:Common.OK".i18n)
      alert.runModal()
      NSApp.popup()
      return
    }

    // 「略過該版本」：若該遠端建置編號曾被使用者略過，則僅在手動強制檢查時才再次提醒。
    if !isCurrentCheckForced,
       UserDefaults.standard.integer(forKey: kSkippedUpdateVersionBuildKey) == intRemoteVersion {
      return
    }

    var content = String(
      format: "i18n:InfoMessage.NewVersionAvailableDetail:%@%@@%@@%@".i18n,
      strCurrentVersionShortened,
      intCurrentVersion.description,
      strRemoteVersionShortened,
      intRemoteVersion.description
    )
    if crossDistroNotification {
      content.append("\n\n")
      content
        .append(
          "i18n:InfoMessage.UpdateToMainstreamRelease".i18n
        )
    }
    let alert = NSAlert()
    alert.informativeText = content
    alert.messageText = "i18n:UpdateNotification.NewVersionAvailable".i18n
    let strVisitWebsite = "i18n:Menu.VisitWebsite".i18n
    alert.addButton(withTitle: "\(strVisitWebsite) (Gitee)")
    alert.addButton(withTitle: "\(strVisitWebsite) (GitHub)")
    alert.addButton(withTitle: "i18n:Common.NotNow".i18n)
    alert.addButton(withTitle: "i18n:UpdateNotification.SkipThisVersion".i18n)

    guard let siteInfoURLString = plist["\(kUpdateInfoPageURLKey)"] as? String,
          let siteURL = URL(string: siteInfoURLString),
          let siteInfoURLStringGitHub = plist["\(kUpdateInfoPageURLGitHubKey)"] as? String,
          let siteURLGitHub = URL(string: siteInfoURLStringGitHub)
    else {
      return
    }

    // NSAlert 僅為前三個按鈕提供具名 ModalResponse，第四個按鈕需以 rawValue 推算。
    let skipThisVersionResponse = NSApplication.ModalResponse(
      rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + 3
    )
    let result = alert.runModal()
    NSApp.popup()
    switch result {
    case .alertFirstButtonReturn:
      asyncOnMain {
        NSWorkspace.shared.open(siteURL)
      }
    case .alertSecondButtonReturn:
      asyncOnMain {
        NSWorkspace.shared.open(siteURLGitHub)
      }
    case skipThisVersionResponse:
      UserDefaults.standard.set(intRemoteVersion, forKey: kSkippedUpdateVersionBuildKey)
    default: break
    }
  }

  // MARK: Private

  // MARK: - Private Properties

  private var silentMode = false
  private var isCurrentCheckForced = false
  private var currentTask: URLSessionDataTask?

  private var busy: Bool { currentTask != nil }
  private var data: Data? {
    didSet {
      if let data = data {
        asyncOnMain { [weak self] in
          guard let this = self else { return }
          if !this.silentMode {
            this.dataDidSet(data: data)
          }
          this.currentTask = nil
        }
      }
    }
  }

  private var nextUpdateCheckDate: Date? {
    get {
      UserDefaults.standard.object(forKey: kUpdateCheckDateKeyNext) as? Date
    }
    set {
      UserDefaults.standard.set(newValue, forKey: kUpdateCheckDateKeyNext)
    }
  }

  private func cleanUp() {
    currentTask = nil
    data = nil
  }

  private func showError(message: String = "") {
    Process.consoleLog("Update check: plist error, forced check: \(isCurrentCheckForced)")
    if !isCurrentCheckForced { return }
    let alert = NSAlert()
    let content = message
    alert.messageText = "i18n:UpdateNotification.UpdateCheckFailed".i18n
    alert.informativeText = content
    alert.addButton(withTitle: "i18n:Common.OK".i18n)
    alert.runModal()
    NSApp.popup()
  }
}

// MARK: - NSApp Activation Helper

// This is to deal with changes brought by macOS 14.

extension NSApplication {
  fileprivate func popup() {
    // 此處使用與 macOS 13 SDK 相容的方法來呼叫 macOS 14+ 的 API。
    let sel = NSSelectorFromString("activate")
    if let method = class_getInstanceMethod(Self.self, sel) {
      typealias Fn = @convention(c) (AnyObject, Selector) -> ()
      let imp = method_getImplementation(method)
      unsafeBitCast(imp, to: Fn.self)(self, sel)
    } else {
      activate(ignoringOtherApps: true)
    }
  }
}
