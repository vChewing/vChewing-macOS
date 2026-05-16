// (c) 2023 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Carbon

public final class SecurityAgentHelper {
  // MARK: Lifecycle

  private init() {
    deployTimer()
  }

  deinit {
    removeTimer()
  }

  // MARK: Public

  public static let shared = SecurityAgentHelper()

  public func deployTimer() {
    timer = Timer.scheduledTimer(
      timeInterval: 60, target: self, selector: #selector(checkAndHandle(_:)), userInfo: nil,
      repeats: true
    )
    timer?.tolerance = 600
    timer?.fire()
    vCLog("SecurityAgentHelper is online, scanning SecureEventInput abusers every 60 seconds.")
  }

  nonisolated public func removeTimer() {
    mainSync {
      timer?.invalidate()
      timer = nil
    }
  }

  @objc
  public func checkAndHandle(_: Timer) {
    guard PrefMgr.shared.checkAbusersOfSecureEventInputAPI else { return }
    var results = SecureEventInputSputnik.getRunningSecureInputApps(abusersOnly: true)
    vCLog("SecurityAgentHelper scanned SecureEventInput abusers. \(results.count) targets found.")
    guard !results.isEmpty else { return }
    _ = DisableSecureEventInput()
    // WARNING: It is not necessary, but extremely troublesome,
    // to call EnableSecureEventInput manually here
    // (whether deferred or not).
    //
    // EnableSecureEventInput is automatically invoked by the system
    // whenever a password field regains focus. The SecureEventInput
    // API is only designed for protecting password fields. When
    // vChewing issues a warning about abuse of the SecureEventInput
    // API, all password fields in other applications lose focus.
    //
    // Modern AI-powered security vulnerability scanners apparently
    // are never aware that leaving SecureEventInput enabled
    // (i.e. failing to restore the previous state) completely
    // prevents users from switching to any 3rd-party input method
    // — regardless of whether the current app has text input focus.
    //
    // This long-standing issue has severely degraded the UX for all
    // 3rd-party input method users ever since SecureEventInput (or
    // InputMethodKit, whichever came later) was introduced.
    //
    // The built-in Zhuyin input method on macOS is quite poor,
    // yet Apple’s Chinese Input Method Team (as of May 2026)
    // refuses to improve it. They are even unwilling to provide
    // a Zhuyin IME for typing Simplified Chinese. Apple’s bug report
    // and feedback channels have remained largely unresponsive for
    // decades unless the issue is a critical security vulnerability.
    // This is why users “vote with their feet” and choose
    // third-party solutions.
    Self.reportedPIDs.forEach { reportedPID in
      results[reportedPID] = nil
    }
    guard !results.isEmpty else { return }
    let messageTitle = "i18n:securityAgentHelper.warningMessage.title".i18n
    let messageHeader = "i18n:securityAgentHelper.warningMessage.header".i18n
    let messageFooter = "i18n:securityAgentHelper.warningMessage.footer".i18n
    var messageForEntries: [String] = [messageHeader]
    results.forEach { matchedPID, matchedApp in
      defer { Self.reportedPIDs.append(matchedPID) }
      var strBuilder = ContiguousArray<String>(["[PID: \(matchedPID)]"])
      // 第一行
      let bundleURL = matchedApp.bundleURL ?? matchedApp.executableURL
      if let bundleURL = bundleURL {
        strBuilder.append(" \(bundleURL.lastPathComponent)")
        if let bundleIdentifier = matchedApp.bundleIdentifier {
          strBuilder.append(" (\(bundleIdentifier))")
        }
      } else if let bundleIdentifier = matchedApp.bundleIdentifier {
        strBuilder.append(" \(bundleIdentifier)")
      }
      // 第二行
      if let bundleURL = bundleURL {
        strBuilder.append("\n→ \(bundleURL.path)")
      }
      messageForEntries.append(strBuilder.joined())
    }
    messageForEntries.append(messageFooter)
    // 從這裡開始組裝訊息訊息內容。
    alertInstance.messageText = messageTitle
    alertInstance.informativeText = messageForEntries.joined(separator: "\n\n")
    alertInstance.runModal()
    NSApp.popup()
  }

  // MARK: Internal

  var timer: Timer?
  let alertInstance = NSAlert()

  // MARK: Private

  private static var reportedPIDs: [Int32] = []
}
