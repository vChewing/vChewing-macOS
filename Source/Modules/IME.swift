// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

@objc public class IME: NSObject {

	static let dlgOpenPath = NSOpenPanel()

	// MARK: - 開關判定當前應用究竟是？
	@objc static var areWeUsingOurOwnPhraseEditor: Bool = false

	// MARK: - 自 ctlInputMethod 讀取當前輸入法的簡繁體模式
	static func getInputMode() -> InputMode {
		return ctlInputMethod.currentKeyHandler.inputMode
	}

	// MARK: - Print debug information to the console.
	@objc static func prtDebugIntel(_ strPrint: String) {
		if mgrPrefs.isDebugModeEnabled {
			NSLog("vChewingErrorCallback: %@", strPrint)
		}
	}

	// MARK: - Tell whether this IME is running with Root privileges.
	@objc static var isSudoMode: Bool {
		NSUserName() == "root"
	}

	// MARK: - Initializing Language Models.
	@objc static func initLangModels(userOnly: Bool) {
		if !userOnly {
			mgrLangModel.loadDataModels()  // 這句還是不要砍了。
		}
		// mgrLangModel 的 loadUserPhrases 等函數在自動讀取 dataFolderPath 時，
		// 如果發現自訂目錄不可用，則會自動抹去自訂目錄設定、改採預設目錄。
		// 所以這裡不需要特別處理。
		mgrLangModel.loadUserPhrases()
		mgrLangModel.loadUserPhraseReplacement()
		mgrLangModel.loadUserAssociatedPhrases()
	}

	// MARK: - System Dark Mode Status Detector.
	@objc static func isDarkMode() -> Bool {
		if #available(macOS 10.15, *) {
			let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription
				.lowercased()
			if appearanceDescription.contains("dark") {
				return true
			}
		} else if #available(macOS 10.14, *) {
			if let appleInterfaceStyle = UserDefaults.standard.object(forKey: "AppleInterfaceStyle")
				as? String
			{
				if appleInterfaceStyle.lowercased().contains("dark") {
					return true
				}
			}
		}
		return false
	}

	// MARK: - Open a phrase data file.
	static func openPhraseFile(userFileAt path: String) {
		func checkIfUserFilesExist() -> Bool {
			if !mgrLangModel.checkIfUserLanguageModelFilesExist() {
				let content = String(
					format: NSLocalizedString(
						"Please check the permission at \"%@\".", comment: ""),
					mgrLangModel.dataFolderPath(isDefaultFolder: false))
				ctlNonModalAlertWindow.shared.show(
					title: NSLocalizedString("Unable to create the user phrase file.", comment: ""),
					content: content, confirmButtonTitle: NSLocalizedString("OK", comment: ""),
					cancelButtonTitle: nil, cancelAsDefault: false, delegate: nil)
				NSApp.setActivationPolicy(.accessory)
				return false
			}
			return true
		}

		if !checkIfUserFilesExist() {
			return
		}
		NSWorkspace.shared.openFile(path, withApplication: "vChewingPhraseEditor")
	}

	// MARK: - Trash a file if it exists.
	@discardableResult static func trashTargetIfExists(_ path: String) -> Bool {
		do {
			if FileManager.default.fileExists(atPath: path) {
				// 塞入垃圾桶
				try FileManager.default.trashItem(
					at: URL(fileURLWithPath: path), resultingItemURL: nil)
			} else {
				NSLog("Item doesn't exist: \(path)")
			}
		} catch let error as NSError {
			NSLog("Failed from removing this object: \(path) || Error: \(error)")
			return false
		}
		return true
	}

	// MARK: - Uninstall the input method.
	@discardableResult static func uninstall(isSudo: Bool = false, selfKill: Bool = true) -> Int32 {
		// 輸入法自毀處理。這裡不用「Bundle.main.bundleURL」是為了方便使用者以 sudo 身分來移除被錯誤安裝到系統目錄內的輸入法。
		guard let bundleID = Bundle.main.bundleIdentifier else {
			NSLog("Failed to ensure the bundle identifier.")
			return -1
		}

		let kTargetBin = "vChewing"
		let kTargetBundle = "/vChewing.app"
		let pathLibrary =
			isSudo
			? "/Library"
			: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].path
		let pathIMELibrary =
			isSudo
			? "/Library/Input Methods"
			: FileManager.default.urls(for: .inputMethodsDirectory, in: .userDomainMask)[0].path
		let pathUnitKeyboardLayouts = "/Keyboard Layouts"
		let arrKeyLayoutFiles = [
			"/vChewing ETen.keylayout", "/vChewingKeyLayout.bundle", "/vChewing MiTAC.keylayout",
			"/vChewing IBM.keylayout", "/vChewing FakeSeigyou.keylayout",
			"/vChewing Dachen.keylayout",
		]

		// 先移除各種鍵盤佈局。
		for objPath in arrKeyLayoutFiles {
			let objFullPath = pathLibrary + pathUnitKeyboardLayouts + objPath
			if !IME.trashTargetIfExists(objFullPath) { return -1 }
		}
		if CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "--all"
			&& CommandLine.arguments[1] == "uninstall"
		{
			// 再處理是否需要移除放在預設使用者資料夾內的檔案的情況。
			// 如果使用者有在輸入法偏好設定內將該目錄改到別的地方（而不是用 symbol link）的話，則不處理。
			// 目前暫時無法應對 symbol link 的情況。
			IME.trashTargetIfExists(mgrLangModel.dataFolderPath(isDefaultFolder: true))
			IME.trashTargetIfExists(pathLibrary + "/Preferences/" + bundleID + ".plist")  // 之後移除 App 偏好設定
		}
		if !IME.trashTargetIfExists(pathIMELibrary + kTargetBundle) { return -1 }  // 最後移除 App 自身
		// 幹掉殘留在記憶體內的執行緒。
		if selfKill {
			let killTask = Process()
			killTask.launchPath = "/usr/bin/killall"
			killTask.arguments = ["-9", kTargetBin]
			killTask.launch()
			killTask.waitUntilExit()
		}
		return 0
	}

	// MARK: - Registering the input method.
	@discardableResult static func registerInputMethod() -> Int32 {
		guard let bundleID = Bundle.main.bundleIdentifier else {
			return -1
		}
		let bundleUrl = Bundle.main.bundleURL
		var maybeInputSource = InputSourceHelper.inputSource(for: bundleID)

		if maybeInputSource == nil {
			NSLog("Registering input source \(bundleID) at \(bundleUrl.absoluteString)")
			// then register
			let status = InputSourceHelper.registerTnputSource(at: bundleUrl)

			if !status {
				NSLog(
					"Fatal error: Cannot register input source \(bundleID) at \(bundleUrl.absoluteString)."
				)
				return -1
			}

			maybeInputSource = InputSourceHelper.inputSource(for: bundleID)
		}

		guard let inputSource = maybeInputSource else {
			NSLog("Fatal error: Cannot find input source \(bundleID) after registration.")
			return -1
		}

		if !InputSourceHelper.inputSourceEnabled(for: inputSource) {
			NSLog("Enabling input source \(bundleID) at \(bundleUrl.absoluteString).")
			let status = InputSourceHelper.enable(inputSource: inputSource)
			if !status {
				NSLog("Fatal error: Cannot enable input source \(bundleID).")
				return -1
			}
			if !InputSourceHelper.inputSourceEnabled(for: inputSource) {
				NSLog("Fatal error: Cannot enable input source \(bundleID).")
				return -1
			}
		}

		if CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "--all" {
			let enabled = InputSourceHelper.enableAllInputMode(for: bundleID)
			NSLog(
				enabled
					? "All input sources enabled for \(bundleID)"
					: "Cannot enable all input sources for \(bundleID), but this is ignored")
		}
		return 0
	}

}
