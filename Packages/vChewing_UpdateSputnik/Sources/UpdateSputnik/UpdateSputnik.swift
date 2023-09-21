// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

public class UpdateSputnik {
  public static let shared: UpdateSputnik = .init()
  public let kUpdateInfoPageURLKey: String = "UpdateInfoSite"
  public let kUpdateInfoPageURLGitHubKey: String = "UpdateInfoSiteGitHub"
  public let kUpdateCheckDateKeyPrevious: String = "PreviousUpdateCheckDate"
  public let kUpdateCheckDateKeyNext: String = "NextUpdateCheckDate"
  public let kUpdateCheckInterval: TimeInterval = 114_514
  public let kCheckUpdateAutomatically = "CheckUpdateAutomatically"

  public init() {}

  public func checkForUpdate(forced: Bool = false, url: URL, shouldBypass: @escaping () -> Bool) {
    let shouldBypass = shouldBypass()
    silentMode = shouldBypass
    guard !shouldBypass, !busy else { return }

    if !forced {
      if !UserDefaults.standard.bool(forKey: kCheckUpdateAutomatically) { return }
      if let nextCheckDate = nextUpdateCheckDate, Date().compare(nextCheckDate) == .orderedAscending {
        return
      }
    }
    isCurrentCheckForced = forced // 留著用來生成錯誤報告
    let request = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5
    )

    let task = URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        DispatchQueue.main.async {
          if !self.silentMode {
            self.showError(message: error.localizedDescription)
          }
          self.currentTask = nil
        }
        return
      }
      self.data = data
    }
    task.resume()
    currentTask = task
  }

  // MARK: - Private Properties

  private var silentMode = false
  private var isCurrentCheckForced = false
  var sessionConfiguration = URLSessionConfiguration.background(withIdentifier: Bundle.main.bundleIdentifier!)

  private var busy: Bool { currentTask != nil }
  private var currentTask: URLSessionDataTask?
  private var data: Data? {
    didSet {
      if let data = data {
        DispatchQueue.main.async {
          if !self.silentMode {
            self.dataDidSet(data: data)
          }
          self.currentTask = nil
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

  // MARK: - Private Functions.

  internal func dataDidSet(data: Data) {
    var plist: [AnyHashable: Any]?
    plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [AnyHashable: Any]
    nextUpdateCheckDate = .init().addingTimeInterval(kUpdateCheckInterval)
    cleanUp()

    guard let plist = plist else {
      DispatchQueue.main.async {
        self.showError(message: NSLocalizedString("Plist downloaded is nil.", comment: ""))
        self.currentTask = nil
      }
      return
    }

    NSLog("update check plist: \(plist)")

    guard let intRemoteVersion = Int(plist[kCFBundleVersionKey] as? String ?? ""),
          let strRemoteVersionShortened = plist["CFBundleShortVersionString"] as? String
    else {
      DispatchQueue.main.async {
        self.showError(message: NSLocalizedString("Plist downloaded cannot be parsed correctly.", comment: ""))
        self.currentTask = nil
      }
      return
    }

    guard let dicMainBundle = Bundle.main.infoDictionary,
          let intCurrentVersion = Int(dicMainBundle[kCFBundleVersionKey as String] as? String ?? ""),
          let strCurrentVersionShortened = dicMainBundle["CFBundleShortVersionString"] as? String
    else { return } // Shouldn't happen.
    if intRemoteVersion <= intCurrentVersion {
      guard isCurrentCheckForced else { return }
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Update Check Completed", comment: "")
      alert.informativeText = NSLocalizedString("You are already using the latest version.", comment: "")
      alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
      alert.runModal()
      NSApp.popup()
      return
    }

    let content = String(
      format: NSLocalizedString(
        "You're currently using vChewing %@ (%@), a new version %@ (%@) is now available. Do you want to visit vChewing's website to download the version?",
        comment: ""
      ),
      strCurrentVersionShortened,
      intCurrentVersion.description,
      strRemoteVersionShortened,
      intRemoteVersion.description
    )
    let alert = NSAlert()
    alert.informativeText = content
    alert.messageText = NSLocalizedString("New Version Available", comment: "")
    let strVisitWebsite = NSLocalizedString("Visit Website", comment: "")
    alert.addButton(withTitle: "\(strVisitWebsite) (Gitee)")
    alert.addButton(withTitle: "\(strVisitWebsite) (GitHub)")
    alert.addButton(withTitle: NSLocalizedString("Not Now", comment: ""))

    guard let siteInfoURLString = plist["\(kUpdateInfoPageURLKey)"] as? String,
          let siteURL = URL(string: siteInfoURLString),
          let siteInfoURLStringGitHub = plist["\(kUpdateInfoPageURLGitHubKey)"] as? String,
          let siteURLGitHub = URL(string: siteInfoURLStringGitHub)
    else {
      return
    }

    let result = alert.runModal()
    NSApp.popup()
    switch result {
    case .alertFirstButtonReturn:
      DispatchQueue.main.async {
        NSWorkspace.shared.open(siteURL)
      }
    case .alertSecondButtonReturn:
      DispatchQueue.main.async {
        NSWorkspace.shared.open(siteURLGitHub)
      }
    default: break
    }
  }

  private func cleanUp() {
    currentTask = nil
    data = nil
  }

  private func showError(message: String = "") {
    NSLog("Update check: plist error, forced check: \(isCurrentCheckForced)")
    if !isCurrentCheckForced { return }
    let alert = NSAlert()
    let content = message
    alert.messageText = NSLocalizedString("Update Check Failed", comment: "")
    alert.informativeText = content
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    alert.runModal()
    NSApp.popup()
  }
}

// MARK: - NSApp Activation Helper

// This is to deal with changes brought by macOS 14.

private extension NSApplication {
  func popup() {
    #if compiler(>=5.9) && canImport(AppKit, _version: "14.0")
      if #available(macOS 14.0, *) {
        NSApp.activate()
      } else {
        NSApp.activate(ignoringOtherApps: true)
      }
    #else
      NSApp.activate(ignoringOtherApps: true)
    #endif
  }
}
