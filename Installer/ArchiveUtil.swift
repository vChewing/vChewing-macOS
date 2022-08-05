// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

struct ArchiveUtil {
  var appName: String
  var targetAppBundleName: String

  init(appName: String, targetAppBundleName: String) {
    self.appName = appName
    self.targetAppBundleName = targetAppBundleName
  }

  // Returns YES if (1) a zip file under
  // Resources/NotarizedArchives/$_appName-$bundleVersion.zip exists, and (2) if
  // Resources/$_invalidAppBundleName does not exist.
  func validateIfNotarizedArchiveExists() -> Bool {
    guard let resourePath = Bundle.main.resourcePath,
      let notarizedArchivesPath = notarizedArchivesPath,
      let notarizedArchive = notarizedArchive,
      let notarizedArchivesContent: [String] = try? FileManager.default.subpathsOfDirectory(
        atPath: notarizedArchivesPath)
    else {
      return false
    }

    let devModeAppBundlePath = (resourePath as NSString).appendingPathComponent(targetAppBundleName)
    let count = notarizedArchivesContent.count
    let notarizedArchiveExists = FileManager.default.fileExists(atPath: notarizedArchive)
    let devModeAppBundleExists = FileManager.default.fileExists(atPath: devModeAppBundlePath)

    if !notarizedArchivesContent.isEmpty {
      // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
      if count != 1 || !notarizedArchiveExists || devModeAppBundleExists {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Internal Error"
        alert.informativeText =
          "devMode installer, expected archive name: \(notarizedArchive), "
          + "archive exists: \(notarizedArchiveExists), devMode app bundle exists: \(devModeAppBundleExists)"
        alert.addButton(withTitle: "Terminate")
        alert.runModal()
        NSApp.terminate(nil)
      } else {
        return true
      }
    }

    if !devModeAppBundleExists {
      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = "Internal Error"
      alert.informativeText = "Dev target bundle does not exist: \(devModeAppBundlePath)"
      alert.addButton(withTitle: "Terminate")
      alert.runModal()
      NSApp.terminate(nil)
    }

    return false
  }

  func unzipNotarizedArchive() -> String? {
    if !validateIfNotarizedArchiveExists() {
      return nil
    }
    guard let notarizedArchive = notarizedArchive,
      let resourcePath = Bundle.main.resourcePath
    else {
      return nil
    }
    let tempFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(
      UUID().uuidString)
    let arguments: [String] = [notarizedArchive, "-d", tempFilePath]
    let unzipTask = Process()
    unzipTask.launchPath = "/usr/bin/unzip"
    unzipTask.currentDirectoryPath = resourcePath
    unzipTask.arguments = arguments
    unzipTask.launch()
    unzipTask.waitUntilExit()

    assert(unzipTask.terminationStatus == 0, "Must successfully unzipped")
    let result = (tempFilePath as NSString).appendingPathComponent(targetAppBundleName)
    assert(
      FileManager.default.fileExists(atPath: result),
      "App bundle must be unzipped at \(result)."
    )
    return result
  }

  private var notarizedArchivesPath: String? {
    guard let resourePath = Bundle.main.resourcePath else {
      return nil
    }
    let notarizedArchivesPath = (resourePath as NSString).appendingPathComponent(
      "NotarizedArchives")
    return notarizedArchivesPath
  }

  private var notarizedArchive: String? {
    guard let notarizedArchivesPath = notarizedArchivesPath,
      let bundleVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String]
        as? String
    else {
      return nil
    }
    let notarizedArchiveBasename = "\(appName)-r\(bundleVersion).zip"
    let notarizedArchive = (notarizedArchivesPath as NSString).appendingPathComponent(
      notarizedArchiveBasename)
    return notarizedArchive
  }
}
