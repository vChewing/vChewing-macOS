// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

private let kTargetBin = "vChewing"
private let kTargetType = "app"
private let kTargetBundle = "vChewing.app"

private let urlDestinationPartial = FileManager.default.urls(
  for: .inputMethodsDirectory, in: .userDomainMask
)[0]
private let urlTargetPartial = urlDestinationPartial.appendingPathComponent(kTargetBundle)
private let urlTargetFullBinPartial = urlTargetPartial.appendingPathComponent("Contents/MacOS/")
  .appendingPathComponent(kTargetBin)

private let kDestinationPartial = urlDestinationPartial.path
private let kTargetPartialPath = urlTargetPartial.path
private let kTargetFullBinPartialPath = urlTargetFullBinPartial.path

private let kTranslocationRemovalTickInterval: TimeInterval = 0.5
private let kTranslocationRemovalDeadline: TimeInterval = 60.0

@NSApplicationMain
@objc(AppDelegate)
class AppDelegate: NSWindowController, NSApplicationDelegate {
  @IBOutlet private var installButton: NSButton!
  @IBOutlet private var cancelButton: NSButton!
  @IBOutlet private var progressSheet: NSWindow!
  @IBOutlet private var progressIndicator: NSProgressIndicator!
  @IBOutlet private var appVersionLabel: NSTextField!
  @IBOutlet private var appCopyrightLabel: NSTextField!
  @IBOutlet private var appEULAContent: NSTextView!

  private var archiveUtil: ArchiveUtil?
  private var installingVersion = ""
  private var upgrading = false
  private var translocationRemovalStartTime: Date?
  private var currentVersionNumber: Int = 0

  func runAlertPanel(title: String, message: String, buttonTitle: String) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: buttonTitle)
    alert.runModal()
  }

  func applicationDidFinishLaunching(_: Notification) {
    guard
      let installingVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String]
        as? String,
      let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    else {
      return
    }
    self.installingVersion = installingVersion
    archiveUtil = ArchiveUtil(appName: kTargetBin, targetAppBundleName: kTargetBundle)
    _ = archiveUtil?.validateIfNotarizedArchiveExists()

    cancelButton.nextKeyView = installButton
    installButton.nextKeyView = cancelButton
    if let cell = installButton.cell as? NSButtonCell {
      window?.defaultButtonCell = cell
    }

    if let copyrightLabel = Bundle.main.localizedInfoDictionary?["NSHumanReadableCopyright"]
      as? String
    {
      appCopyrightLabel.stringValue = copyrightLabel
    }
    if let eulaContent = Bundle.main.localizedInfoDictionary?["CFEULAContent"] as? String {
      appEULAContent.string = eulaContent
    }
    appVersionLabel.stringValue = String(
      format: "%@ Build %@", versionString, installingVersion
    )

    window?.title = String(
      format: NSLocalizedString("%@ (for version %@, r%@)", comment: ""), window?.title ?? "",
      versionString, installingVersion
    )
    window?.standardWindowButton(.closeButton)?.isHidden = true
    window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window?.standardWindowButton(.zoomButton)?.isHidden = true

    if FileManager.default.fileExists(
      atPath: (kTargetPartialPath as NSString).expandingTildeInPath)
    {
      let currentBundle = Bundle(path: (kTargetPartialPath as NSString).expandingTildeInPath)
      let shortVersion =
        currentBundle?.infoDictionary?["CFBundleShortVersionString"] as? String
      let currentVersion =
        currentBundle?.infoDictionary?[kCFBundleVersionKey as String] as? String
      currentVersionNumber = (currentVersion as NSString?)?.integerValue ?? 0
      if shortVersion != nil, let currentVersion = currentVersion,
        currentVersion.compare(installingVersion, options: .numeric) == .orderedAscending
      {
        upgrading = true
      }
    }

    if upgrading {
      installButton.title = NSLocalizedString("Upgrade", comment: "")
    }

    window?.center()
    window?.orderFront(self)
    NSApp.activate(ignoringOtherApps: true)
  }

  @IBAction func agreeAndInstallAction(_: AnyObject) {
    cancelButton.isEnabled = false
    installButton.isEnabled = false
    removeThenInstallInputMethod()
  }

  @objc func timerTick(_ timer: Timer) {
    let elapsed = Date().timeIntervalSince(translocationRemovalStartTime ?? Date())
    if elapsed >= kTranslocationRemovalDeadline {
      timer.invalidate()
      window?.endSheet(progressSheet, returnCode: .cancel)
    } else if isAppBundleTranslocated(atPath: kTargetPartialPath) == false {
      progressIndicator.doubleValue = 1.0
      timer.invalidate()
      window?.endSheet(progressSheet, returnCode: .continue)
    }
  }

  func removeThenInstallInputMethod() {
    if FileManager.default.fileExists(
      atPath: (kTargetPartialPath as NSString).expandingTildeInPath)
      == false
    {
      installInputMethod(
        previousExists: false, previousVersionNotFullyDeactivatedWarning: false
      )
      return
    }

    let shouldWaitForTranslocationRemoval =
      isAppBundleTranslocated(atPath: kTargetPartialPath)
      && (window?.responds(to: #selector(NSWindow.beginSheet(_:completionHandler:))) ?? false)

    // ????????????????????????????????????
    do {
      let sourceDir = (kDestinationPartial as NSString).expandingTildeInPath
      let fileManager = FileManager.default
      let fileURLString = String(format: "%@/%@", sourceDir, kTargetBundle)
      let fileURL = URL(fileURLWithPath: fileURLString)

      // ????????????????????????
      if fileManager.fileExists(atPath: fileURLString) {
        // ???????????????
        try fileManager.trashItem(at: fileURL, resultingItemURL: nil)
      } else {
        NSLog("File does not exist")
      }

    } catch let error as NSError {
      NSLog("An error took place: \(error)")
    }

    let killTask = Process()
    killTask.launchPath = "/usr/bin/killall"
    killTask.arguments = ["-9", kTargetBin]
    killTask.launch()
    killTask.waitUntilExit()

    if shouldWaitForTranslocationRemoval {
      progressIndicator.startAnimation(self)
      window?.beginSheet(progressSheet) { returnCode in
        DispatchQueue.main.async {
          if returnCode == .continue {
            self.installInputMethod(
              previousExists: true,
              previousVersionNotFullyDeactivatedWarning: false
            )
          } else {
            self.installInputMethod(
              previousExists: true,
              previousVersionNotFullyDeactivatedWarning: true
            )
          }
        }
      }

      translocationRemovalStartTime = Date()
      Timer.scheduledTimer(
        timeInterval: kTranslocationRemovalTickInterval, target: self,
        selector: #selector(timerTick(_:)), userInfo: nil, repeats: true
      )
    } else {
      installInputMethod(
        previousExists: false, previousVersionNotFullyDeactivatedWarning: false
      )
    }
  }

  func installInputMethod(
    previousExists _: Bool, previousVersionNotFullyDeactivatedWarning warning: Bool
  ) {
    guard
      let targetBundle = archiveUtil?.unzipNotarizedArchive()
        ?? Bundle.main.path(forResource: kTargetBin, ofType: kTargetType)
    else {
      return
    }
    let cpTask = Process()
    cpTask.launchPath = "/bin/cp"
    cpTask.arguments = [
      "-R", targetBundle, (kDestinationPartial as NSString).expandingTildeInPath,
    ]
    cpTask.launch()
    cpTask.waitUntilExit()

    if cpTask.terminationStatus != 0 {
      runAlertPanel(
        title: NSLocalizedString("Install Failed", comment: ""),
        message: NSLocalizedString("Cannot copy the file to the destination.", comment: ""),
        buttonTitle: NSLocalizedString("Cancel", comment: "")
      )
      endAppWithDelay()
    }

    guard let imeBundle = Bundle(path: (kTargetPartialPath as NSString).expandingTildeInPath),
      let imeIdentifier = imeBundle.bundleIdentifier
    else {
      endAppWithDelay()
      return
    }

    let imeBundleURL = imeBundle.bundleURL
    var inputSource = InputSourceHelper.inputSource(for: imeIdentifier)

    if inputSource == nil {
      NSLog("Registering input source \(imeIdentifier) at \(imeBundleURL.absoluteString).")
      let status = InputSourceHelper.registerTnputSource(at: imeBundleURL)
      if !status {
        let message = String(
          format: NSLocalizedString(
            "Cannot find input source %@ after registration.", comment: ""
          ),
          imeIdentifier
        )
        runAlertPanel(
          title: NSLocalizedString("Fatal Error", comment: ""), message: message,
          buttonTitle: NSLocalizedString("Abort", comment: "")
        )
        endAppWithDelay()
        return
      }

      inputSource = InputSourceHelper.inputSource(for: imeIdentifier)
      if inputSource == nil {
        let message = String(
          format: NSLocalizedString(
            "Cannot find input source %@ after registration.", comment: ""
          ),
          imeIdentifier
        )
        runAlertPanel(
          title: NSLocalizedString("Fatal Error", comment: ""), message: message,
          buttonTitle: NSLocalizedString("Abort", comment: "")
        )
      }
    }

    var isMacOS12OrAbove = false
    if #available(macOS 12.0, *) {
      NSLog("macOS 12 or later detected.")
      isMacOS12OrAbove = true
    } else {
      NSLog("Installer runs with the pre-macOS 12 flow.")
    }

    // If the IME is not enabled, enable it. Also, unconditionally enable it on macOS 12.0+,
    // as the kTISPropertyInputSourceIsEnabled can still be true even if the IME is *not*
    // enabled in the user's current set of IMEs (which means the IME does not show up in
    // the user's input menu).

    var mainInputSourceEnabled = InputSourceHelper.inputSourceEnabled(for: inputSource!)
    if !mainInputSourceEnabled || isMacOS12OrAbove {
      mainInputSourceEnabled = InputSourceHelper.enable(inputSource: inputSource!)
      if mainInputSourceEnabled {
        NSLog("Input method enabled: \(imeIdentifier)")
      } else {
        NSLog("Failed to enable input method: \(imeIdentifier)")
      }
    }

    // Alert Panel
    let ntfPostInstall = NSAlert()
    if warning {
      ntfPostInstall.messageText = NSLocalizedString("Attention", comment: "")
      ntfPostInstall.informativeText = NSLocalizedString(
        "vChewing is upgraded, but please log out or reboot for the new version to be fully functional.",
        comment: ""
      )
      ntfPostInstall.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    } else {
      if !mainInputSourceEnabled, !isMacOS12OrAbove {
        ntfPostInstall.messageText = NSLocalizedString("Warning", comment: "")
        ntfPostInstall.informativeText = NSLocalizedString(
          "Input method may not be fully enabled. Please enable it through System Preferences > Keyboard > Input Sources.",
          comment: ""
        )
        ntfPostInstall.addButton(withTitle: NSLocalizedString("Continue", comment: ""))
      } else {
        ntfPostInstall.messageText = NSLocalizedString(
          "Installation Successful", comment: ""
        )
        ntfPostInstall.informativeText = NSLocalizedString(
          "vChewing is ready to use.", comment: ""
        )
        ntfPostInstall.addButton(withTitle: NSLocalizedString("OK", comment: ""))
      }
    }
    ntfPostInstall.beginSheetModal(for: window!) { _ in
      self.endAppWithDelay()
    }
  }

  func endAppWithDelay() {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
      NSApp.terminate(self)
    }
  }

  @IBAction func cancelAction(_: AnyObject) {
    NSApp.terminate(self)
  }

  func windowWillClose(_: Notification) {
    NSApp.terminate(self)
  }

  // Determines if an app is translocated by Gatekeeper to a randomized path.
  // See https://weblog.rogueamoeba.com/2016/06/29/sierra-and-gatekeeper-path-randomization/
  // Originally written by Zonble Yang in Objective-C (MIT License).
  // Swiftified by: Rob Mayoff. Ref: https://forums.swift.org/t/58719/5
  func isAppBundleTranslocated(atPath bundlePath: String) -> Bool {
    var entryCount = getfsstat(nil, 0, 0)
    var entries: [statfs] = .init(repeating: .init(), count: Int(entryCount))
    let absPath = (bundlePath as NSString).expandingTildeInPath.cString(using: .utf8)
    entryCount = getfsstat(&entries, entryCount * Int32(MemoryLayout<statfs>.stride), MNT_NOWAIT)
    for entry in entries.prefix(Int(entryCount)) {
      let isMatch = withUnsafeBytes(of: entry.f_mntfromname) { mntFromName in
        strcmp(absPath, mntFromName.baseAddress) == 0
      }
      if isMatch {
        var stat = statfs()
        let rc = statfs(absPath, &stat)
        return rc == 0
      }
    }
    return false
  }
}
