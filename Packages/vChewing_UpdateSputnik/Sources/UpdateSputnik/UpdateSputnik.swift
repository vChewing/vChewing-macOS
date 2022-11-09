// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public class UpdateSputnik {
  public static var shared: UpdateSputnik = .init()
  public var varkUpdateInfoPageURLKey: String = "UpdateInfoSite"
  public var varkUpdateCheckDateKeyPrevious: String = "PreviousUpdateCheckDate"
  public var varkUpdateCheckDateKeyNext: String = "NextUpdateCheckDate"
  public var varkUpdateCheckInterval: TimeInterval = 114_514
  public var varCheckUpdateAutomatically = "CheckUpdateAutomatically"

  public init() {}

  public func checkForUpdate(forced: Bool = false, url: URL) {
    guard !busy else { return }

    if !forced {
      if !UserDefaults.standard.bool(forKey: varCheckUpdateAutomatically) { return }
      if let nextCheckDate = nextUpdateCheckDate, Date().compare(nextCheckDate) == .orderedAscending {
        return
      }
    }
    isCurrentCheckForced = forced  // 留著用來生成錯誤報告
    let request = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5
    )

    let task = URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        DispatchQueue.main.async {
          self.showError(message: error.localizedDescription)
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

  private var isCurrentCheckForced = false
  var sessionConfiguration = URLSessionConfiguration.background(withIdentifier: Bundle.main.bundleIdentifier!)

  private var busy: Bool { currentTask != nil }
  private var currentTask: URLSessionDataTask?
  private var data: Data? {
    didSet {
      if let data = data {
        DispatchQueue.main.async {
          self.dataDidSet(data: data)
          self.currentTask = nil
        }
      }
    }
  }

  private var nextUpdateCheckDate: Date? {
    get {
      UserDefaults.standard.object(forKey: varkUpdateCheckDateKeyNext) as? Date
    }
    set {
      UserDefaults.standard.set(newValue, forKey: varkUpdateCheckDateKeyNext)
    }
  }

  // MARK: - Private Functions.

  internal func dataDidSet(data: Data) {
    var plist: [AnyHashable: Any]?
    plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [AnyHashable: Any]
    nextUpdateCheckDate = .init().addingTimeInterval(varkUpdateCheckInterval)
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
    else { return }  // Shouldn't happen.
    if intRemoteVersion <= intCurrentVersion {
      guard isCurrentCheckForced else { return }
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Update Check Completed", comment: "")
      alert.informativeText = NSLocalizedString("You are already using the latest version.", comment: "")
      alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
      alert.runModal()
      NSApp.setActivationPolicy(.accessory)
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
    alert.messageText = NSLocalizedString("New Version Available", comment: "")
    alert.informativeText = content
    alert.addButton(withTitle: NSLocalizedString("Visit Website", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("Not Now", comment: ""))
    NSApp.setActivationPolicy(.accessory)
    let result = alert.runModal()
    if result == NSApplication.ModalResponse.alertFirstButtonReturn {
      if let siteInfoURLString = plist[varkUpdateInfoPageURLKey] as? String,
        let siteURL = URL(string: siteInfoURLString)
      {
        DispatchQueue.main.async {
          NSWorkspace.shared.open(siteURL)
        }
      }
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
    NSApp.setActivationPolicy(.accessory)
  }
}
