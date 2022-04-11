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

@objc extension mgrLangModel {

	// MARK: - 獲取當前輸入法封包內的原廠核心語彙檔案所在路徑
	static func getBundleDataPath(_ filenameSansExt: String) -> String {
		return Bundle.main.path(forResource: filenameSansExt, ofType: "txt")!
	}

	// MARK: - 使用者語彙檔案的具體檔案名稱路徑定義
	// Swift 的 appendingPathComponent 需要藉由 URL 完成，最後再用 .path 轉為路徑。

	static func userPhrasesDataPath(_ mode: InputMode) -> String {
		let fileName = (mode == InputMode.imeModeCHT) ? "userdata-cht.txt" : "userdata-chs.txt"
		return URL(fileURLWithPath: self.dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName).path
	}

	static func userSymbolDataPath(_ mode: InputMode) -> String {
		let fileName = (mode == InputMode.imeModeCHT) ? "usersymbolphrases-cht.txt" : "usersymbolphrases-chs.txt"
		return URL(fileURLWithPath: self.dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName).path
	}

	static func userAssociatedPhrasesDataPath(_ mode: InputMode) -> String {
		let fileName = (mode == InputMode.imeModeCHT) ? "associatedPhrases-cht.txt" : "associatedPhrases-chs.txt"
		return URL(fileURLWithPath: self.dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName).path
	}

	static func excludedPhrasesDataPath(_ mode: InputMode) -> String {
		let fileName = (mode == InputMode.imeModeCHT) ? "exclude-phrases-cht.txt" : "exclude-phrases-chs.txt"
		return URL(fileURLWithPath: self.dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName).path
	}

	static func phraseReplacementDataPath(_ mode: InputMode) -> String {
		let fileName = (mode == InputMode.imeModeCHT) ? "phrases-replacement-cht.txt" : "phrases-replacement-chs.txt"
		return URL(fileURLWithPath: self.dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName).path
	}

	// MARK: - 檢查具體的使用者語彙檔案是否存在

	static func ensureFileExists(
		_ filePath: String, populateWithTemplate templateBasename: String = "1145141919810",
		extension ext: String = "txt"
	) -> Bool {
		if !FileManager.default.fileExists(atPath: filePath) {
			let templateURL = Bundle.main.url(forResource: templateBasename, withExtension: ext)
			var templateData = Data("".utf8)
			if templateBasename != "" {
				do {
					try templateData = Data(contentsOf: templateURL ?? URL(fileURLWithPath: ""))
				} catch {
					templateData = Data("".utf8)
				}
				do {
					try templateData.write(to: URL(fileURLWithPath: filePath))
				} catch {
					IME.prtDebugIntel("Failed to write file")
					return false
				}
			}
		}
		return true
	}

	static func chkUserLMFilesExist(_ mode: InputMode) -> Bool {
		if !self.checkIfUserDataFolderExists() {
			return false
		}
		if !ensureFileExists(userPhrasesDataPath(mode))
			|| !ensureFileExists(userAssociatedPhrasesDataPath(mode))
			|| !ensureFileExists(excludedPhrasesDataPath(mode))
			|| !ensureFileExists(phraseReplacementDataPath(mode))
			|| !ensureFileExists(userSymbolDataPath(mode))
		{
			return false
		}

		return true
	}

	// MARK: - 使用者語彙檔案專用目錄的合規性檢查

	// 一次性檢查給定的目錄是否存在寫入合規性（僅用於偏好設定檢查等初步檢查場合，不做任何糾偏行為）
	static func checkIfSpecifiedUserDataFolderValid(_ folderPath: String?) -> Bool {
		var isFolder = ObjCBool(false)
		let folderExist = FileManager.default.fileExists(atPath: folderPath ?? "", isDirectory: &isFolder)
		// The above "&" mutates the "isFolder" value to the real one received by the "folderExist".

		// 路徑沒有結尾斜槓的話，會導致目錄合規性判定失準。
		// 出於每個型別每個函數的自我責任原則，這裡多檢查一遍也不壞。
		var folderPath = folderPath  // Convert the incoming constant to a variable.
		if isFolder.boolValue {
			folderPath?.ensureTrailingSlash()
		}
		let isFolderWritable = FileManager.default.isWritableFile(atPath: folderPath ?? "")

		if ((folderExist && !isFolder.boolValue) || !folderExist) || !isFolderWritable {
			return false
		}

		return true
	}

	// ⚠︎ 私有函數：檢查且糾偏，不接受任何傳入變數。該函數不用於其他型別。
	// 待辦事項：擇日合併至另一個同類型的函數當中。
	static func checkIfUserDataFolderExists() -> Bool {
		let folderPath = mgrLangModel.dataFolderPath(isDefaultFolder: false)
		var isFolder = ObjCBool(false)
		var folderExist = FileManager.default.fileExists(atPath: folderPath, isDirectory: &isFolder)
		// The above "&" mutates the "isFolder" value to the real one received by the "folderExist".
		// 發現目標路徑不是目錄的話：
		// 如果要找的目標路徑是原廠目標路徑的話，先將這個路徑的所指對象更名、再認為目錄不存在。
		// 如果要找的目標路徑不是原廠目標路徑的話，則直接報錯。
		if folderExist && !isFolder.boolValue {
			do {
				if self.dataFolderPath(isDefaultFolder: false)
					== self.dataFolderPath(isDefaultFolder: true)
				{
					let formatter = DateFormatter.init()
					formatter.dateFormat = "YYYYMMDD-HHMM'Hrs'-ss's'"
					let dirAlternative = folderPath + formatter.string(from: Date())
					try FileManager.default.moveItem(atPath: folderPath, toPath: dirAlternative)
				} else {
					throw folderPath
				}
			} catch {
				print("Failed to make path available at: \(error)")
				return false
			}
			folderExist = false
		}
		if !folderExist {
			do {
				try FileManager.default.createDirectory(
					atPath: folderPath,
					withIntermediateDirectories: true,
					attributes: nil)
			} catch {
				print("Failed to create folder: \(error)")
				return false
			}
		}
		return true
	}

	// MARK: - 用以讀取使用者語彙檔案目錄的函數，會自動對 mgrPrefs 當中的參數糾偏。
	// 當且僅當 mgrPrefs 當中的參數不合規（比如非實在路徑、或者無權限寫入）時，才會糾偏。

	static func dataFolderPath(isDefaultFolder: Bool) -> String {
		let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].path
		var userDictPathSpecified = (mgrPrefs.userDataFolderSpecified as NSString).expandingTildeInPath
		var userDictPathDefault =
			(URL(fileURLWithPath: appSupportPath).appendingPathComponent("vChewing").path as NSString)
			.expandingTildeInPath

		userDictPathDefault.ensureTrailingSlash()
		userDictPathSpecified.ensureTrailingSlash()

		if (userDictPathSpecified == userDictPathDefault)
			|| isDefaultFolder
		{
			return userDictPathDefault
		}
		if mgrPrefs.ifSpecifiedUserDataPathExistsInPlist() {
			if mgrLangModel.checkIfSpecifiedUserDataFolderValid(userDictPathSpecified) {
				return userDictPathSpecified
			} else {
				UserDefaults.standard.removeObject(forKey: "UserDataFolderSpecified")
			}
		}
		return userDictPathDefault
	}

	// MARK: - 寫入使用者檔案
	static func writeUserPhrase(
		_ userPhrase: String?, inputMode mode: InputMode, areWeDuplicating: Bool, areWeDeleting: Bool
	) -> Bool {
		if var currentMarkedPhrase: String = userPhrase {
			if !self.chkUserLMFilesExist(InputMode.imeModeCHS)
				|| !self.chkUserLMFilesExist(InputMode.imeModeCHT)
			{
				return false
			}

			let path = areWeDeleting ? self.excludedPhrasesDataPath(mode) : self.userPhrasesDataPath(mode)

			if areWeDuplicating && !areWeDeleting {
				// Do not use ASCII characters to comment here.
				// Otherwise, it will be scrambled by cnvHYPYtoBPMF
				// module shipped in the vChewing Phrase Editor.
				currentMarkedPhrase += "\t#𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎"
			}
			currentMarkedPhrase += "\n"

			if let writeFile = FileHandle(forUpdatingAtPath: path),
				let data = currentMarkedPhrase.data(using: .utf8)
			{
				writeFile.seekToEndOfFile()
				writeFile.write(data)
				writeFile.closeFile()
			} else {
				return false
			}

			// We enforce the format consolidation here, since the pragma header
			// will let the UserPhraseLM bypasses the consolidating process on load.
			self.consolidate(givenFile: path, shouldCheckPragma: false)

			// We use FSEventStream to monitor possible changes of the user phrase folder, hence the
			// lack of the needs of manually load data here unless FSEventStream is disabled by user.
			if !mgrPrefs.shouldAutoReloadUserDataFiles {
				self.loadUserPhrases()
			}
			return true
		}
		return false
	}

}
