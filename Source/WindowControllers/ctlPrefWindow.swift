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

import Carbon
import Cocoa

// Please note that the class should be exposed using the same class name
// in Objective-C in order to let IMK to see the same class name as
// the "InputMethodServerPreferencesWindowControllerClass" in Info.plist.
@objc(ctlPrefWindow) class ctlPrefWindow: NSWindowController {
	@IBOutlet weak var fontSizePopUpButton: NSPopUpButton!
	@IBOutlet weak var uiLanguageButton: NSPopUpButton!
	@IBOutlet weak var basicKeyboardLayoutButton: NSPopUpButton!
	@IBOutlet weak var selectionKeyComboBox: NSComboBox!
	@IBOutlet weak var chkTrad2KangXi: NSButton!
	@IBOutlet weak var chkTrad2JISShinjitai: NSButton!
	@IBOutlet weak var lblCurrentlySpecifiedUserDataFolder: NSTextFieldCell!

	var currentLanguageSelectItem: NSMenuItem? = nil

	override func windowDidLoad() {
		super.windowDidLoad()

		lblCurrentlySpecifiedUserDataFolder.placeholderString = mgrLangModel.dataFolderPath(
			isDefaultFolder: true)

		let languages = ["auto", "en", "zh-Hans", "zh-Hant", "ja"]
		var autoMUISelectItem: NSMenuItem? = nil
		var chosenLanguageItem: NSMenuItem? = nil
		uiLanguageButton.menu?.removeAllItems()

		let appleLanguages = mgrPrefs.appleLanguages
		for language in languages {
			let menuItem = NSMenuItem()
			menuItem.title = NSLocalizedString(language, comment: "")
			menuItem.representedObject = language

			if language == "auto" {
				autoMUISelectItem = menuItem
			}

			if !appleLanguages.isEmpty {
				if appleLanguages[0] == language {
					chosenLanguageItem = menuItem
				}
			}
			uiLanguageButton.menu?.addItem(menuItem)
		}

		currentLanguageSelectItem = chosenLanguageItem ?? autoMUISelectItem
		uiLanguageButton.select(currentLanguageSelectItem)

		let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
		var usKeyboardLayoutItem: NSMenuItem? = nil
		var chosenBaseKeyboardLayoutItem: NSMenuItem? = nil

		basicKeyboardLayoutButton.menu?.removeAllItems()

		let itmAppleZhuyinBopomofo = NSMenuItem()
		itmAppleZhuyinBopomofo.title = String(
			format: NSLocalizedString("Apple Zhuyin Bopomofo (Dachen)", comment: ""))
		itmAppleZhuyinBopomofo.representedObject = String(
			"com.apple.keylayout.ZhuyinBopomofo")
		basicKeyboardLayoutButton.menu?.addItem(itmAppleZhuyinBopomofo)

		let itmAppleZhuyinEten = NSMenuItem()
		itmAppleZhuyinEten.title = String(
			format: NSLocalizedString("Apple Zhuyin Eten (Traditional)", comment: ""))
		itmAppleZhuyinEten.representedObject = String("com.apple.keylayout.ZhuyinEten")
		basicKeyboardLayoutButton.menu?.addItem(itmAppleZhuyinEten)

		let basicKeyboardLayoutID = mgrPrefs.basicKeyboardLayout

		for source in list {
			if let categoryPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) {
				let category = Unmanaged<CFString>.fromOpaque(categoryPtr).takeUnretainedValue()
				if category != kTISCategoryKeyboardInputSource {
					continue
				}
			} else {
				continue
			}

			if let asciiCapablePtr = TISGetInputSourceProperty(
				source, kTISPropertyInputSourceIsASCIICapable)
			{
				let asciiCapable = Unmanaged<CFBoolean>.fromOpaque(asciiCapablePtr)
					.takeUnretainedValue()
				if asciiCapable != kCFBooleanTrue {
					continue
				}
			} else {
				continue
			}

			if let sourceTypePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) {
				let sourceType = Unmanaged<CFString>.fromOpaque(sourceTypePtr).takeUnretainedValue()
				if sourceType != kTISTypeKeyboardLayout {
					continue
				}
			} else {
				continue
			}

			guard let sourceIDPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
				let localizedNamePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
			else {
				continue
			}

			let sourceID = String(Unmanaged<CFString>.fromOpaque(sourceIDPtr).takeUnretainedValue())
			let localizedName = String(
				Unmanaged<CFString>.fromOpaque(localizedNamePtr).takeUnretainedValue())

			let menuItem = NSMenuItem()
			menuItem.title = localizedName
			menuItem.representedObject = sourceID

			if sourceID == "com.apple.keylayout.US" {
				usKeyboardLayoutItem = menuItem
			}
			if basicKeyboardLayoutID == sourceID {
				chosenBaseKeyboardLayoutItem = menuItem
			}
			basicKeyboardLayoutButton.menu?.addItem(menuItem)
		}

		switch basicKeyboardLayoutID {
			case "com.apple.keylayout.ZhuyinBopomofo":
				chosenBaseKeyboardLayoutItem = itmAppleZhuyinBopomofo
			case "com.apple.keylayout.ZhuyinEten":
				chosenBaseKeyboardLayoutItem = itmAppleZhuyinEten
			default:
				break  // nothing to do
		}

		basicKeyboardLayoutButton.select(chosenBaseKeyboardLayoutItem ?? usKeyboardLayoutItem)

		selectionKeyComboBox.usesDataSource = false
		selectionKeyComboBox.removeAllItems()
		selectionKeyComboBox.addItems(withObjectValues: mgrPrefs.suggestedCandidateKeys)

		var candidateSelectionKeys = mgrPrefs.candidateKeys
		if candidateSelectionKeys.isEmpty {
			candidateSelectionKeys = mgrPrefs.defaultCandidateKeys
		}

		selectionKeyComboBox.stringValue = candidateSelectionKeys
	}

	// 這裡有必要加上這段處理，用來確保藉由偏好設定介面動過的 CNS 開關能夠立刻生效。
	// 所有涉及到語言模型開關的內容均需要這樣處理。
	@IBAction func toggleCNSSupport(_ sender: Any) {
		mgrLangModel.setCNSEnabled(mgrPrefs.cns11643Enabled)
	}

	@IBAction func toggleSymbolInputEnabled(_ sender: Any) {
		mgrLangModel.setSymbolEnabled(mgrPrefs.symbolInputEnabled)
	}

	@IBAction func toggleTrad2KangXiAction(_ sender: Any) {
		if chkTrad2KangXi.state == .on && chkTrad2JISShinjitai.state == .on {
			mgrPrefs.toggleShiftJISShinjitaiOutputEnabled()
		}
	}

	@IBAction func toggleTrad2JISShinjitaiAction(_ sender: Any) {
		if chkTrad2KangXi.state == .on && chkTrad2JISShinjitai.state == .on {
			mgrPrefs.toggleChineseConversionEnabled()
		}
	}

	@IBAction func updateBasicKeyboardLayoutAction(_ sender: Any) {
		if let sourceID = basicKeyboardLayoutButton.selectedItem?.representedObject as? String {
			mgrPrefs.basicKeyboardLayout = sourceID
		}
	}

	@IBAction func updateUiLanguageAction(_ sender: Any) {
		if let selectItem = uiLanguageButton.selectedItem {
			if currentLanguageSelectItem == selectItem {
				return
			}
		}
		if let language = uiLanguageButton.selectedItem?.representedObject as? String {
			if language != "auto" {
				mgrPrefs.appleLanguages = [language]
			} else {
				UserDefaults.standard.removeObject(forKey: "AppleLanguages")
			}

			NSLog("vChewing App self-terminated due to UI language change.")
			NSApplication.shared.terminate(nil)
		}
	}

	@IBAction func clickedWhetherIMEShouldNotFartToggleAction(_ sender: Any) {
		clsSFX.beep()
	}

	@IBAction func changeSelectionKeyAction(_ sender: Any) {
		guard
			let keys = (sender as AnyObject).stringValue?.trimmingCharacters(
				in: .whitespacesAndNewlines
			)
			.charDeDuplicate
		else {
			return
		}
		do {
			try mgrPrefs.validate(candidateKeys: keys)
			mgrPrefs.candidateKeys = keys
			selectionKeyComboBox.stringValue = mgrPrefs.candidateKeys
		} catch mgrPrefs.CandidateKeyError.empty {
			selectionKeyComboBox.stringValue = mgrPrefs.candidateKeys
		} catch {
			if let window = window {
				let alert = NSAlert(error: error)
				alert.beginSheetModal(for: window) { response in
					self.selectionKeyComboBox.stringValue = mgrPrefs.candidateKeys
				}
				clsSFX.beep()
			}
		}
	}

	@IBAction func resetSpecifiedUserDataFolder(_ sender: Any) {
		UserDefaults.standard.removeObject(forKey: "UserDataFolderSpecified")
		IME.initLangModels(userOnly: true)
	}

	@IBAction func chooseUserDataFolderToSpecify(_ sender: Any) {
		IME.dlgOpenPath.title = NSLocalizedString(
			"Choose your desired user data folder.", comment: "")
		IME.dlgOpenPath.showsResizeIndicator = true
		IME.dlgOpenPath.showsHiddenFiles = true
		IME.dlgOpenPath.canChooseFiles = false
		IME.dlgOpenPath.canChooseDirectories = true

		let bolPreviousFolderValidity = mgrLangModel.checkIfSpecifiedUserDataFolderValid(
			NSString(string: mgrPrefs.userDataFolderSpecified).expandingTildeInPath)

		if self.window != nil {
			IME.dlgOpenPath.beginSheetModal(for: self.window!) { result in
				if result == NSApplication.ModalResponse.OK {
					if IME.dlgOpenPath.url != nil {
						if mgrLangModel.checkIfSpecifiedUserDataFolderValid(
							IME.dlgOpenPath.url!.path)
						{
							mgrPrefs.userDataFolderSpecified = IME.dlgOpenPath.url!.path
							IME.initLangModels(userOnly: true)
						} else {
							clsSFX.beep()
							if !bolPreviousFolderValidity {
								self.resetSpecifiedUserDataFolder(self)
							}
							return
						}
					}
				} else {
					if !bolPreviousFolderValidity {
						self.resetSpecifiedUserDataFolder(self)
					}
					return
				}
			}
		}  // End If self.window != nil
	}  // End IBAction

}
