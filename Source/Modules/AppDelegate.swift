/* 
 *  AppDelegate.swift
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa
import InputMethodKit

private let kCheckUpdateAutomatically = "CheckUpdateAutomatically"
private let kNextUpdateCheckDateKey = "NextUpdateCheckDate"
private let kUpdateInfoEndpointKey = "UpdateInfoEndpoint"
private let kUpdateInfoSiteKey = "UpdateInfoSite"
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
                    return
                }

                guard let siteInfoURLString = plist[kUpdateInfoSiteKey] as? String,
                      let siteInfoURL = URL(string: siteInfoURLString)
                        else {
                    DispatchQueue.main.async {
                        forced ? callback(.success(.noNeedToUpdate)) : callback(.success(.ignored))
                    }
                    return
                }

                var report = VersionUpdateReport(siteUrl: siteInfoURL)
                var versionDescription = ""
                let versionDescriptions = plist["Description"] as? [AnyHashable: Any]
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
		DispatchQueue.main.async {
			if Preferences.shouldAutoReloadUserDataFiles {
				LanguageModelManager.loadUserPhrases()
				LanguageModelManager.loadUserPhraseReplacement()
			}
		}
	}

    @IBOutlet weak var window: NSWindow?
    private var ctlPrefWindowInstance: ctlPrefWindow?
    private var ctlAboutWindowInstance: ctlAboutWindow? // New About Window
    private var checkTask: URLSessionTask?
    private var updateNextStepURL: URL?
	private var fsStreamHelper = FSEventStreamHelper(path: LanguageModelManager.dataFolderPath, queue: DispatchQueue(label: "User Phrases"))

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
        LanguageModelManager.loadDataModels()
        LanguageModelManager.loadCNSData()
        LanguageModelManager.loadUserPhrases()
        LanguageModelManager.loadUserPhraseReplacement()
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
    }
    
    // New About Window
    @objc func showAbout() {
        if (ctlAboutWindowInstance == nil) {
            ctlAboutWindowInstance = ctlAboutWindow.init(windowNibName: "frmAboutWindow")
        }
        ctlAboutWindowInstance?.window?.center()
        ctlAboutWindowInstance?.window?.orderFrontRegardless() // 逼著關於視窗往最前方顯示
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
