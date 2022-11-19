// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import IMKUtils
import InputMethodKit

public let kTargetBin = "vChewing"
public let kTargetBinPhraseEditor = "vChewingPhraseEditor"
public let kTargetType = "app"
public let kTargetBundle = "vChewing.app"
public let kTargetBundleWithComponents = "Library/Input%20Methods/vChewing.app"

public let realHomeDir = URL(
  fileURLWithFileSystemRepresentation: getpwuid(getuid()).pointee.pw_dir, isDirectory: true, relativeTo: nil
)
public let urlDestinationPartial = realHomeDir.appendingPathComponent("Library/Input Methods")
public let urlTargetPartial = realHomeDir.appendingPathComponent(kTargetBundleWithComponents)
public let urlTargetFullBinPartial = urlTargetPartial.appendingPathComponent("Contents/MacOS")
  .appendingPathComponent(kTargetBin)

public let kDestinationPartial = urlDestinationPartial.path
public let kTargetPartialPath = urlTargetPartial.path
public let kTargetFullBinPartialPath = urlTargetFullBinPartial.path

public let kTranslocationRemovalTickInterval: TimeInterval = 0.5
public let kTranslocationRemovalDeadline: TimeInterval = 60.0

@NSApplicationMain
@objc(AppDelegate)
class AppDelegate: NSWindowController, NSApplicationDelegate {
  @IBOutlet var installButton: NSButton!
  @IBOutlet var cancelButton: NSButton!
  @IBOutlet var progressSheet: NSWindow!
  @IBOutlet var progressIndicator: NSProgressIndicator!
  @IBOutlet var appVersionLabel: NSTextField!
  @IBOutlet var appCopyrightLabel: NSTextField!
  @IBOutlet var appEULAContent: NSTextView!

  var installingVersion = ""
  var translocationRemovalStartTime: Date?
  var currentVersionNumber: Int = 0

  let imeURLInstalled = realHomeDir.appendingPathComponent("Library/Input Methods/vChewing.app")

  var allRegisteredInstancesOfThisInputMethod: [TISInputSource] {
    guard let components = Bundle(url: imeURLInstalled)?.infoDictionary?["ComponentInputModeDict"] as? [String: Any],
      let tsInputModeListKey = components["tsInputModeListKey"] as? [String: Any]
    else {
      return []
    }
    return tsInputModeListKey.keys.compactMap { TISInputSource.generate(from: $0) }
  }

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
      let window = window,
      let cell = installButton.cell as? NSButtonCell,
      let installingVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String,
      let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
      let copyrightLabel = Bundle.main.localizedInfoDictionary?["NSHumanReadableCopyright"] as? String,
      let eulaContent = Bundle.main.localizedInfoDictionary?["CFEULAContent"] as? String,
      let eulaContentUpstream = Bundle.main.infoDictionary?["CFUpstreamEULAContent"] as? String
    else {
      NSSound.beep()
      NSLog("The vChewing App Installer failed its initial guard-let process on appDidFinishLaunching().")
      return
    }
    self.installingVersion = installingVersion
    cancelButton.nextKeyView = installButton
    installButton.nextKeyView = cancelButton
    window.defaultButtonCell = cell
    appCopyrightLabel.stringValue = copyrightLabel
    appEULAContent.string = eulaContent + "\n" + eulaContentUpstream
    appVersionLabel.stringValue = "\(versionString) Build \(installingVersion)"
    window.title = "\(window.title) (v\(versionString), Build \(installingVersion))"
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.titlebarAppearsTransparent = true

    if FileManager.default.fileExists(atPath: kTargetPartialPath) {
      let currentBundle = Bundle(path: kTargetPartialPath)
      let shortVersion = currentBundle?.infoDictionary?["CFBundleShortVersionString"] as? String
      let currentVersion = currentBundle?.infoDictionary?[kCFBundleVersionKey as String] as? String
      currentVersionNumber = (currentVersion as NSString?)?.integerValue ?? 0
      if shortVersion != nil, let currentVersion = currentVersion,
        currentVersion.compare(installingVersion, options: .numeric) == .orderedAscending
      {
        // Upgrading confirmed.
        installButton.title = NSLocalizedString("Upgrade", comment: "")
      }
    }

    window.center()
    window.orderFront(self)
    NSApp.activate(ignoringOtherApps: true)
  }

  @IBAction func agreeAndInstallAction(_: AnyObject) {
    cancelButton.isEnabled = false
    installButton.isEnabled = false
    removeThenInstallInputMethod()
  }

  @objc func timerTick(_ timer: Timer) {
    guard let window = window else { return }
    let elapsed = Date().timeIntervalSince(translocationRemovalStartTime ?? Date())
    if elapsed >= kTranslocationRemovalDeadline {
      timer.invalidate()
      window.endSheet(progressSheet, returnCode: .cancel)
    } else if Reloc.isAppBundleTranslocated(atPath: kTargetPartialPath) == false {
      progressIndicator.doubleValue = 1.0
      timer.invalidate()
      window.endSheet(progressSheet, returnCode: .continue)
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

  func shell(_ command: String) throws -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    if #available(macOS 10.13, *) {
      task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    } else {
      task.launchPath = "/bin/zsh"
    }
    task.standardInput = nil

    if #available(macOS 10.13, *) {
      try task.run()
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
  }
}
