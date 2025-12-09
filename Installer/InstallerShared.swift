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
import SwiftUI

public let kTargetBin = "vChewing"
public let kTargetBinPhraseEditor = "vChewingPhraseEditor"
public let kTargetType = "app"
public let kTargetBundle = "vChewing.app"
public let kTargetBundleWithComponents = "Library/Input%20Methods/vChewing.app"
public let kTISInputSourceID = "org.atelierInmu.inputmethod.vChewing"

let imeURLInstalled = realHomeDir.appendingPathComponent("Library/Input Methods/vChewing.app")

public let realHomeDir: URL = {
  // Use 10.9-safe URL initializer (no relativeTo: parameter).
  let url = URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir))
  return url.standardizedFileURL
}()

public let urlDestinationPartial = realHomeDir.appendingPathComponent("Library/Input Methods")
public let urlTargetPartial = realHomeDir.appendingPathComponent(kTargetBundleWithComponents)
public let urlTargetFullBinPartial = urlTargetPartial.appendingPathComponent("Contents/MacOS")
  .appendingPathComponent(kTargetBin)

public let kDestinationPartial = urlDestinationPartial.path
public let kTargetPartialPath = urlTargetPartial.path
public let kTargetFullBinPartialPath = urlTargetFullBinPartial.path

public let kTranslocationRemovalTickInterval: TimeInterval = 0.5
public let kTranslocationRemovalDeadline: TimeInterval = 60.0

public let installingVersion = Bundle.main
  .infoDictionary?[kCFBundleVersionKey as String] as? String ?? "BAD_INSTALLING_VER"
public let versionString = Bundle.main
  .infoDictionary?["CFBundleShortVersionString"] as? String ?? "BAD_VER_STR"
public let copyrightLabel = Bundle.main
  .localizedInfoDictionary?["NSHumanReadableCopyright"] as? String ?? "BAD_COPYRIGHT_LABEL"
public let eulaContent = Bundle.main
  .localizedInfoDictionary?["CFEULAContent"] as? String ?? "BAD_EULA_CONTENT"
public let eulaContentUpstream = Bundle.main
  .infoDictionary?["CFUpstreamEULAContent"] as? String ?? "BAD_EULA_UPSTREAM"

public var mainWindowTitle: String {
  "i18n:installer.INSTALLER_APP_TITLE_FULL"
    .i18n + " (v\(versionString), Build \(installingVersion))"
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

// MARK: - NSApp Activation Helper

// This is to deal with changes brought by macOS 14.

extension NSApplication {
  public func popup() {
    #if compiler(>=5.9) && canImport(AppKit, _version: 14.0)
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

// MARK: - KeyWindow Finder

extension NSApplication {
  public var keyWindows: [NSWindow] {
    NSApp.windows.filter(\.isKeyWindow)
  }
}

// MARK: - NSApp End With Delay

extension NSApplication {
  public func terminateWithDelay() {
    asyncOnMain(after: 0.1) { [weak self] in
      if let this = self {
        this.terminate(this)
      }
    }
  }
}

// MARK: - AlertIntel

public struct AlertIntel {}

// MARK: - AlertType

public enum AlertType: String, Identifiable {
  case nothing, installationFailed, missingAfterRegistration, postInstallAttention,
       postInstallWarning, postInstallOK

  // MARK: Public

  public var id: String { rawValue }

  // MARK: Internal

  var title: LocalizedStringKey {
    switch self {
    case .nothing: return ""
    case .installationFailed: return "Install Failed"
    case .missingAfterRegistration: return "Fatal Error"
    case .postInstallAttention: return "Attention"
    case .postInstallWarning: return "Warning"
    case .postInstallOK: return "Installation Successful"
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

extension StringLiteralType {
  fileprivate var i18n: String { NSLocalizedString(description, comment: "") }
}

// MARK: - Shell

extension NSApplication {
  /// 以安全的方式執行可執行檔與參數，避免將使用者輸入插入到 shell 的 -c 字串中，降低命令注入風險。
  /// - Parameters:
  ///   - executable: 可執行檔完整路徑，例如 "/usr/bin/xattr"。
  ///   - args: 參數陣列，會被直接傳給 `Process.arguments` 使用。
  /// - Returns: 回傳執行結果 stdout 的字串表示。
  public func exec(_ executable: String, args: [String]) throws -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = args
    if #available(macOS 10.13, *) {
      task.executableURL = URL(fileURLWithPath: executable)
    } else {
      task.launchPath = executable
    }
    task.standardInput = nil

    if #available(macOS 10.13, *) {
      try task.run()
    } else {
      task.launch()
    }

    var output = ""
    do {
      let data = try pipe.fileHandleForReading.readDataToEnd()
      if let data = data, let str = String(data: data, encoding: .utf8) {
        output.append(str)
      }
    } catch { return "" }
    return output
  }
}
