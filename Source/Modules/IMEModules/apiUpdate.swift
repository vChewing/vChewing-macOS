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

struct VersionUpdateReport {
  var siteUrl: URL?
  var currentShortVersion: String = ""
  var currentVersion: String = ""
  var remoteShortVersion: String = ""
  var remoteVersion: String = ""
  var versionDescription: String = ""
}

enum VersionUpdateApiResult {
  case shouldUpdate(report: VersionUpdateReport)
  case noNeedToUpdate
  case ignored
}

enum VersionUpdateApiError: Error, LocalizedError {
  case connectionError(message: String)

  var errorDescription: String? {
    switch self {
      case .connectionError(let message):
        return String(
          format: NSLocalizedString(
            "There may be no internet connection or the server failed to respond.\n\nError message: %@",
            comment: ""
          ), message
        )
    }
  }
}

enum VersionUpdateApi {
  static let kCheckUpdateAutomatically = "CheckUpdateAutomatically"
  static let kNextUpdateCheckDateKey = "NextUpdateCheckDate"
  static let kUpdateInfoEndpointKey = "UpdateInfoEndpoint"
  static let kUpdateInfoSiteKey = "UpdateInfoSite"
  static let kVersionDescription = "VersionDescription"
  static let kNextCheckInterval: TimeInterval = 86400.0
  static let kTimeoutInterval: TimeInterval = 60.0
  static func check(
    forced: Bool, callback: @escaping (Result<VersionUpdateApiResult, Error>) -> Void
  ) -> URLSessionTask? {
    guard let infoDict = Bundle.main.infoDictionary,
      let updateInfoURLString = infoDict[kUpdateInfoEndpointKey] as? String,
      let updateInfoURL = URL(string: updateInfoURLString)
    else {
      return nil
    }

    let request = URLRequest(
      url: updateInfoURL, cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: kTimeoutInterval
    )
    let task = URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        DispatchQueue.main.async {
          forced
            ? callback(
              .failure(
                VersionUpdateApiError.connectionError(
                  message: error.localizedDescription)))
            : callback(.success(.ignored))
        }
        return
      }

      do {
        guard
          let plist = try PropertyListSerialization.propertyList(
            from: data ?? Data(), options: [], format: nil
          ) as? [AnyHashable: Any],
          let remoteVersion = plist[kCFBundleVersionKey] as? String,
          let infoDict = Bundle.main.infoDictionary
        else {
          DispatchQueue.main.async {
            forced
              ? callback(.success(.noNeedToUpdate))
              : callback(.success(.ignored))
          }
          return
        }

        // TODO: Validate info (e.g. bundle identifier)
        // TODO: Use HTML to display change log, need a new key like UpdateInfoChangeLogURL for this

        let currentVersion = infoDict[kCFBundleVersionKey as String] as? String ?? ""
        let result = currentVersion.compare(
          remoteVersion, options: .numeric, range: nil, locale: nil
        )

        if result != .orderedAscending {
          DispatchQueue.main.async {
            forced
              ? callback(.success(.noNeedToUpdate))
              : callback(.success(.ignored))
          }
          IME.prtDebugIntel(
            "vChewingDebug: Update // Order is not Ascending, assuming that there's no new version available."
          )
          return
        }
        IME.prtDebugIntel(
          "vChewingDebug: Update // New version detected, proceeding to the next phase.")
        guard let siteInfoURLString = plist[kUpdateInfoSiteKey] as? String,
          let siteInfoURL = URL(string: siteInfoURLString)
        else {
          DispatchQueue.main.async {
            forced
              ? callback(.success(.noNeedToUpdate))
              : callback(.success(.ignored))
          }
          IME.prtDebugIntel(
            "vChewingDebug: Update // Failed from retrieving / parsing URL intel.")
          return
        }
        IME.prtDebugIntel(
          "vChewingDebug: Update // URL intel retrieved, proceeding to the next phase.")
        var report = VersionUpdateReport(siteUrl: siteInfoURL)
        var versionDescription = ""
        let versionDescriptions = plist[kVersionDescription] as? [AnyHashable: Any]
        if let versionDescriptions = versionDescriptions {
          var locale = "en"
          let preferredTags = Bundle.preferredLocalizations(from: IME.arrSupportedLocales)
          if let first = preferredTags.first {
            locale = first
          }
          versionDescription =
            versionDescriptions[locale] as? String ?? versionDescriptions["en"]
            as? String ?? ""
          if !versionDescription.isEmpty {
            versionDescription = "\n\n" + versionDescription
          }
        }
        report.currentShortVersion = infoDict["CFBundleShortVersionString"] as? String ?? ""
        report.currentVersion = currentVersion
        report.remoteShortVersion = plist["CFBundleShortVersionString"] as? String ?? ""
        report.remoteVersion = remoteVersion
        report.versionDescription = versionDescription
        DispatchQueue.main.async {
          callback(.success(.shouldUpdate(report: report)))
        }
        IME.prtDebugIntel("vChewingDebug: Update // Callbck Complete.")
      } catch {
        DispatchQueue.main.async {
          forced ? callback(.success(.noNeedToUpdate)) : callback(.success(.ignored))
        }
      }
    }
    task.resume()
    return task
  }
}
