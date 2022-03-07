// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa
import InputMethodKit

private let kCheckUpdateAutomatically = "CheckUpdateAutomatically"
private let kNextUpdateCheckDateKey = "NextUpdateCheckDate"
private let kUpdateInfoEndpointKey = "UpdateInfoEndpoint"
private let kUpdateInfoSiteKey = "UpdateInfoSite"
private let kVersionDescription = "VersionDescription"
private let kNextCheckInterval: TimeInterval = 86400.0
private let kTimeoutInterval: TimeInterval = 60.0

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
            return String(format: NSLocalizedString("There may be no internet connection or the server failed to respond.\n\nError message: %@", comment: ""), message)
        }
    }
}

struct VersionUpdateApi {
    static func check(forced: Bool, callback: @escaping (Result<VersionUpdateApiResult, Error>) -> ()) -> URLSessionTask? {
        guard let infoDict = Bundle.main.infoDictionary,
              let updateInfoURLString = infoDict[kUpdateInfoEndpointKey] as? String,
              let updateInfoURL = URL(string: updateInfoURLString) else {
            return nil
        }

        let request = URLRequest(url: updateInfoURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: kTimeoutInterval)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    forced ?
                            callback(.failure(VersionUpdateApiError.connectionError(message: error.localizedDescription))) :
                            callback(.success(.ignored))
                }
                return
            }

            do {
                guard let plist = try PropertyListSerialization.propertyList(from: data ?? Data(), options: [], format: nil) as? [AnyHashable: Any],
                      let remoteVersion = plist[kCFBundleVersionKey] as? String,
                      let infoDict = Bundle.main.infoDictionary
                        else {
                    DispatchQueue.main.async {
                        forced ? callback(.success(.noNeedToUpdate)) : callback(.success(.ignored))
                    }
                    return
                }

                // TODO: Validate info (e.g. bundle identifier)
                // TODO: Use HTML to display change log, need a new key like UpdateInfoChangeLogURL for this

                let currentVersion = infoDict[kCFBundleVersionKey as String] as? String ?? ""
                let result = currentVersion.compare(remoteVersion, options: .numeric, range: nil, locale: nil)

                if result != .orderedAscending {
                    DispatchQueue.main.async {
                        forced ? callback(.success(.noNeedToUpdate)) : callback(.success(.ignored))
                    }
                    IME.prtDebugIntel("vChewingDebug: Update // Order is not Ascending, assuming that there's no new version available.")
                    return
                }
                IME.prtDebugIntel("vChewingDebug: Update // New version detected, proceeding to the next phase.")
                guard let siteInfoURLString = plist[kUpdateInfoSiteKey] as? String,
                      let siteInfoURL = URL(string: siteInfoURLString)
                        else {
                    DispatchQueue.main.async {
                        forced ? callback(.success(.noNeedToUpdate)) : callback(.success(.ignored))
                    }
                    IME.prtDebugIntel("vChewingDebug: Update // Failed from retrieving / parsing URL intel.")
                    return
                }
                IME.prtDebugIntel("vChewingDebug: Update // URL intel retrieved, proceeding to the next phase.")
                var report = VersionUpdateReport(siteUrl: siteInfoURL)
                var versionDescription = ""
                let versionDescriptions = plist[kVersionDescription] as? [AnyHashable: Any]
                if let versionDescriptions = versionDescriptions {
                    var locale = "en"
                    let supportedLocales = ["en", "zh-Hant", "zh-Hans", "ja"]
                    let preferredTags = Bundle.preferredLocalizations(from: supportedLocales)
                    if let first = preferredTags.first {
                        locale = first
                    }
                    versionDescription = versionDescriptions[locale] as? String ?? versionDescriptions["en"] as? String ?? ""
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

@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate, ctlNonModalAlertWindowDelegate, FSEventStreamHelperDelegate {
    func helper(_ helper: FSEventStreamHelper, didReceive events: [FSEventStreamHelper.Event]) {
        // 拖 100ms 再重載，畢竟有些有特殊需求的使用者可能會想使用巨型自訂語彙檔案。
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            if Preferences.shouldAutoReloadUserDataFiles {
                mgrLangModel.loadUserPhrases()
                mgrLangModel.loadUserPhraseReplacement()
                mgrLangModel.loadUserAssociatedPhrases()
            }
        }
    }

    // let vChewingKeyLayoutBundle = Bundle.init(path: URL(fileURLWithPath: Bundle.main.resourcePath ?? "").appendingPathComponent("vChewingKeyLayout.bundle").path)

    @IBOutlet weak var window: NSWindow?
    private var ctlPrefWindowInstance: ctlPrefWindow?
    private var ctlAboutWindowInstance: ctlAboutWindow? // New About Window
    private var checkTask: URLSessionTask?
    private var updateNextStepURL: URL?
    private var fsStreamHelper = FSEventStreamHelper(path: mgrLangModel.dataFolderPath, queue: DispatchQueue(label: "vChewing User Phrases"))

    // 補上 dealloc
    deinit {
        ctlPrefWindowInstance = nil
        ctlAboutWindowInstance = nil
        checkTask = nil
        updateNextStepURL = nil
        fsStreamHelper.stop()
        fsStreamHelper.delegate = nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        mgrLangModel.setupDataModelValueConverter()
        mgrLangModel.loadDataModels() // 這句還是不要砍了。
        mgrLangModel.loadUserPhrases()
        mgrLangModel.loadUserPhraseReplacement()
        mgrLangModel.loadUserAssociatedPhrases()
        fsStreamHelper.delegate = self
        _ = fsStreamHelper.start()

        Preferences.setMissingDefaults()
        
        // 只要使用者沒有勾選檢查更新、沒有主動做出要檢查更新的操作，就不要檢查更新。
        if (UserDefaults.standard.object(forKey: kCheckUpdateAutomatically) != nil) == true {
            checkForUpdate()
        }
    }

    @objc func showPreferences() {
        if (ctlPrefWindowInstance == nil) {
            ctlPrefWindowInstance = ctlPrefWindow.init(windowNibName: "frmPrefWindow")
        }
        ctlPrefWindowInstance?.window?.center()
        ctlPrefWindowInstance?.window?.orderFrontRegardless() // 逼著屬性視窗往最前方顯示
        ctlPrefWindowInstance?.window?.level = .statusBar
    }
    
    // New About Window
    @objc func showAbout() {
        if (ctlAboutWindowInstance == nil) {
            ctlAboutWindowInstance = ctlAboutWindow.init(windowNibName: "frmAboutWindow")
        }
        ctlAboutWindowInstance?.window?.center()
        ctlAboutWindowInstance?.window?.orderFrontRegardless() // 逼著關於視窗往最前方顯示
        ctlAboutWindowInstance?.window?.level = .statusBar
    }

    @objc(checkForUpdate)
    func checkForUpdate() {
        checkForUpdate(forced: false)
    }

    @objc(checkForUpdateForced:)
    func checkForUpdate(forced: Bool) {

        if checkTask != nil {
            // busy
            return
        }

        // time for update?
        if !forced {
            if UserDefaults.standard.bool(forKey: kCheckUpdateAutomatically) == false {
                return
            }
            let now = Date()
            let date = UserDefaults.standard.object(forKey: kNextUpdateCheckDateKey) as? Date ?? now
            if now.compare(date) == .orderedAscending {
                return
            }
        }

        let nextUpdateDate = Date(timeInterval: kNextCheckInterval, since: Date())
        UserDefaults.standard.set(nextUpdateDate, forKey: kNextUpdateCheckDateKey)

        checkTask = VersionUpdateApi.check(forced: forced) { result in
            defer {
                self.checkTask = nil
            }
            switch result {
            case .success(let apiResult):
                switch apiResult {
                case .shouldUpdate(let report):
                    self.updateNextStepURL = report.siteUrl
                    let content = String(format: NSLocalizedString("You're currently using vChewing %@ (%@), a new version %@ (%@) is now available. Do you want to visit vChewing's website to download the version?%@", comment: ""),
                            report.currentShortVersion,
                            report.currentVersion,
                            report.remoteShortVersion,
                            report.remoteVersion,
                            report.versionDescription)
                    IME.prtDebugIntel("vChewingDebug: \(content)")
                    ctlNonModalAlertWindow.shared.show(title: NSLocalizedString("New Version Available", comment: ""), content: content, confirmButtonTitle: NSLocalizedString("Visit Website", comment: ""), cancelButtonTitle: NSLocalizedString("Not Now", comment: ""), cancelAsDefault: false, delegate: self)
                case .noNeedToUpdate, .ignored:
                    break
                }
            case .failure(let error):
                switch error {
                case VersionUpdateApiError.connectionError(let message):
                    let title = NSLocalizedString("Update Check Failed", comment: "")
                    let content = String(format: NSLocalizedString("There may be no internet connection or the server failed to respond.\n\nError message: %@", comment: ""), message)
                    let buttonTitle = NSLocalizedString("Dismiss", comment: "")
                    IME.prtDebugIntel("vChewingDebug: \(content)")
                    ctlNonModalAlertWindow.shared.show(title: title, content: content, confirmButtonTitle: buttonTitle, cancelButtonTitle: nil, cancelAsDefault: false, delegate: nil)
                default:
                    break
                }
            }
        }
    }

    func ctlNonModalAlertWindowDidConfirm(_ controller: ctlNonModalAlertWindow) {
        if let updateNextStepURL = updateNextStepURL {
            NSWorkspace.shared.open(updateNextStepURL)
        }
        updateNextStepURL = nil
    }

    func ctlNonModalAlertWindowDidCancel(_ controller: ctlNonModalAlertWindow) {
        updateNextStepURL = nil
    }

    // New About Window
    @IBAction func about(_ sender: Any) {
        (NSApp.delegate as? AppDelegate)?.showAbout()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@objc public class IME: NSObject {
    // Print debug information to the console.
    @objc static func prtDebugIntel(_ strPrint: String) {
        if Preferences.isDebugModeEnabled {
            NSLog("vChewingErrorCallback: %@", strPrint)
        }
    }
}
