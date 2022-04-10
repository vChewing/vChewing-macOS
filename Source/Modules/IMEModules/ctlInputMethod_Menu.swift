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

import Cocoa

extension Bool {
	fileprivate var state: NSControl.StateValue {
		self ? .on : .off
	}
}

// MARK: - IME Menu Manager
// 因為選單部分的內容又臭又長，所以就單獨拉到一個檔案內管理了。

extension ctlInputMethod {
	override func menu() -> NSMenu! {
		let optionKeyPressed = NSEvent.modifierFlags.contains(.option)

		let menu = NSMenu(title: "Input Method Menu")

		let useSCPCTypingModeItem = menu.addItem(
			withTitle: NSLocalizedString("Per-Char Select Mode", comment: ""),
			action: #selector(toggleSCPCTypingMode(_:)), keyEquivalent: "P")
		useSCPCTypingModeItem.keyEquivalentModifierMask = [.command, .control]
		useSCPCTypingModeItem.state = mgrPrefs.useSCPCTypingMode.state

		let userAssociatedPhrasesItem = menu.addItem(
			withTitle: NSLocalizedString("Per-Char Associated Phrases", comment: ""),
			action: #selector(toggleAssociatedPhrasesEnabled(_:)), keyEquivalent: "O")
		userAssociatedPhrasesItem.keyEquivalentModifierMask = [.command, .control]
		userAssociatedPhrasesItem.state = mgrPrefs.associatedPhrasesEnabled.state

		let useCNS11643SupportItem = menu.addItem(
			withTitle: NSLocalizedString("CNS11643 Mode", comment: ""),
			action: #selector(toggleCNS11643Enabled(_:)), keyEquivalent: "L")
		useCNS11643SupportItem.keyEquivalentModifierMask = [.command, .control]
		useCNS11643SupportItem.state = mgrPrefs.cns11643Enabled.state

		if IME.getInputMode() == InputMode.imeModeCHT {
			let chineseConversionItem = menu.addItem(
				withTitle: NSLocalizedString("Force KangXi Writing", comment: ""),
				action: #selector(toggleChineseConverter(_:)), keyEquivalent: "K")
			chineseConversionItem.keyEquivalentModifierMask = [.command, .control]
			chineseConversionItem.state = mgrPrefs.chineseConversionEnabled.state

			let shiftJISConversionItem = menu.addItem(
				withTitle: NSLocalizedString("JIS Shinjitai Output", comment: ""),
				action: #selector(toggleShiftJISShinjitaiOutput(_:)), keyEquivalent: "J")
			shiftJISConversionItem.keyEquivalentModifierMask = [.command, .control]
			shiftJISConversionItem.state = mgrPrefs.shiftJISShinjitaiOutputEnabled.state
		}

		let halfWidthPunctuationItem = menu.addItem(
			withTitle: NSLocalizedString("Half-Width Punctuation Mode", comment: ""),
			action: #selector(toggleHalfWidthPunctuation(_:)), keyEquivalent: "H")
		halfWidthPunctuationItem.keyEquivalentModifierMask = [.command, .control]
		halfWidthPunctuationItem.state = mgrPrefs.halfWidthPunctuationEnabled.state

		if optionKeyPressed {
			let phaseReplacementItem = menu.addItem(
				withTitle: NSLocalizedString("Use Phrase Replacement", comment: ""),
				action: #selector(togglePhraseReplacement(_:)), keyEquivalent: "")
			phaseReplacementItem.state = mgrPrefs.phraseReplacementEnabled.state

			let toggleSymbolInputItem = menu.addItem(
				withTitle: NSLocalizedString("Symbol & Emoji Input", comment: ""),
				action: #selector(toggleSymbolEnabled(_:)), keyEquivalent: "")
			toggleSymbolInputItem.state = mgrPrefs.symbolInputEnabled.state
		}

		menu.addItem(NSMenuItem.separator())  // ---------------------

		menu.addItem(
			withTitle: NSLocalizedString("Open User Data Folder", comment: ""),
			action: #selector(openUserDataFolder(_:)), keyEquivalent: "")
		menu.addItem(
			withTitle: NSLocalizedString("Edit User Phrases…", comment: ""),
			action: #selector(openUserPhrases(_:)), keyEquivalent: "")

		if optionKeyPressed {
			menu.addItem(
				withTitle: NSLocalizedString("Edit Excluded Phrases…", comment: ""),
				action: #selector(openExcludedPhrases(_:)), keyEquivalent: "")
			menu.addItem(
				withTitle: NSLocalizedString("Edit Phrase Replacement Table…", comment: ""),
				action: #selector(openPhraseReplacement(_:)), keyEquivalent: "")
			menu.addItem(
				withTitle: NSLocalizedString("Edit Associated Phrases…", comment: ""),
				action: #selector(openAssociatedPhrases(_:)), keyEquivalent: "")
			menu.addItem(
				withTitle: NSLocalizedString("Edit User Symbol & Emoji Data…", comment: ""),
				action: #selector(openUserSymbols(_:)), keyEquivalent: "")
		}

		if optionKeyPressed || !mgrPrefs.shouldAutoReloadUserDataFiles {
			menu.addItem(
				withTitle: NSLocalizedString("Reload User Phrases", comment: ""),
				action: #selector(reloadUserPhrases(_:)), keyEquivalent: "")
		}

		menu.addItem(NSMenuItem.separator())  // ---------------------

		menu.addItem(
			withTitle: NSLocalizedString("vChewing Preferences…", comment: ""),
			action: #selector(showPreferences(_:)), keyEquivalent: "")
		if !optionKeyPressed {
			menu.addItem(
				withTitle: NSLocalizedString("Check for Updates…", comment: ""),
				action: #selector(checkForUpdate(_:)), keyEquivalent: "")
		}
		menu.addItem(
			withTitle: NSLocalizedString("Reboot vChewing…", comment: ""),
			action: #selector(selfTerminate(_:)), keyEquivalent: "")
		menu.addItem(
			withTitle: NSLocalizedString("About vChewing…", comment: ""),
			action: #selector(showAbout(_:)), keyEquivalent: "")
		if optionKeyPressed {
			menu.addItem(
				withTitle: NSLocalizedString("Uninstall vChewing…", comment: ""),
				action: #selector(selfUninstall(_:)), keyEquivalent: "")
		}

		// NSMenu 會阻止任何 modified key 相關的訊號傳回輸入法，所以咱們在此重設鍵盤佈局
		setKeyLayout()

		return menu
	}

	// MARK: - IME Menu Items

	@objc override func showPreferences(_ sender: Any?) {
		(NSApp.delegate as? AppDelegate)?.showPreferences()
		NSApp.activate(ignoringOtherApps: true)
	}

	@objc func toggleSCPCTypingMode(_ sender: Any?) {
		NotifierController.notify(
			message: String(
				format: "%@%@%@", NSLocalizedString("Per-Char Select Mode", comment: ""), "\n",
				mgrPrefs.toggleSCPCTypingModeEnabled()
					? NSLocalizedString("NotificationSwitchON", comment: "")
					: NSLocalizedString("NotificationSwitchOFF", comment: "")))
		resetKeyHandler()
	}

	@objc func toggleChineseConverter(_ sender: Any?) {
		NotifierController.notify(
			message: String(
				format: "%@%@%@", NSLocalizedString("Force KangXi Writing", comment: ""), "\n",
				mgrPrefs.toggleChineseConversionEnabled()
					? NSLocalizedString("NotificationSwitchON", comment: "")
					: NSLocalizedString("NotificationSwitchOFF", comment: "")))
		resetKeyHandler()
	}

	@objc func toggleShiftJISShinjitaiOutput(_ sender: Any?) {
		NotifierController.notify(
			message: String(
				format: "%@%@%@", NSLocalizedString("JIS Shinjitai Output", comment: ""), "\n",
				mgrPrefs.toggleShiftJISShinjitaiOutputEnabled()
					? NSLocalizedString("NotificationSwitchON", comment: "")
					: NSLocalizedString("NotificationSwitchOFF", comment: "")))
		resetKeyHandler()
	}

	@objc func toggleHalfWidthPunctuation(_ sender: Any?) {
		NotifierController.notify(
			message: String(
				format: "%@%@%@", NSLocalizedString("Half-Width Punctuation Mode", comment: ""),
				"\n",
				mgrPrefs.toggleHalfWidthPunctuationEnabled()
					? NSLocalizedString("NotificationSwitchON", comment: "")
					: NSLocalizedString("NotificationSwitchOFF", comment: "")))
		resetKeyHandler()
	}

	@objc func toggleCNS11643Enabled(_ sender: Any?) {
		NotifierController.notify(
			message: String(
				format: "%@%@%@", NSLocalizedString("CNS11643 Mode", comment: ""), "\n",
				mgrPrefs.toggleCNS11643Enabled()
					? NSLocalizedString("NotificationSwitchON", comment: "")
					: NSLocalizedString("NotificationSwitchOFF", comment: "")))
		resetKeyHandler()
	}

	@objc func toggleSymbolEnabled(_ sender: Any?) {
		NotifierController.notify(
			message: String(
				format: "%@%@%@", NSLocalizedString("Symbol & Emoji Input", comment: ""), "\n",
				mgrPrefs.toggleSymbolInputEnabled()
					? NSLocalizedString("NotificationSwitchON", comment: "")
					: NSLocalizedString("NotificationSwitchOFF", comment: "")))
		resetKeyHandler()
	}

	@objc func toggleAssociatedPhrasesEnabled(_ sender: Any?) {
		NotifierController.notify(
			message: String(
				format: "%@%@%@", NSLocalizedString("Per-Char Associated Phrases", comment: ""),
				"\n",
				mgrPrefs.toggleAssociatedPhrasesEnabled()
					? NSLocalizedString("NotificationSwitchON", comment: "")
					: NSLocalizedString("NotificationSwitchOFF", comment: "")))
		resetKeyHandler()
	}

	@objc func togglePhraseReplacement(_ sender: Any?) {
		NotifierController.notify(
			message: String(
				format: "%@%@%@", NSLocalizedString("Use Phrase Replacement", comment: ""), "\n",
				mgrPrefs.togglePhraseReplacementEnabled()
					? NSLocalizedString("NotificationSwitchON", comment: "")
					: NSLocalizedString("NotificationSwitchOFF", comment: "")))
		resetKeyHandler()
	}

	@objc func selfUninstall(_ sender: Any?) {
		(NSApp.delegate as? AppDelegate)?.selfUninstall()
	}

	@objc func selfTerminate(_ sender: Any?) {
		NSApp.terminate(nil)
	}

	@objc func checkForUpdate(_ sender: Any?) {
		(NSApp.delegate as? AppDelegate)?.checkForUpdate(forced: true)
	}

	@objc func openUserPhrases(_ sender: Any?) {
		IME.openPhraseFile(userFileAt: mgrLangModel.userPhrasesDataPath(IME.getInputMode()))
	}

	@objc func openUserDataFolder(_ sender: Any?) {
		if !mgrLangModel.checkIfUserDataFolderExists() {
			return
		}
		NSWorkspace.shared.openFile(
			mgrLangModel.dataFolderPath(isDefaultFolder: false), withApplication: "Finder")
	}

	@objc func openExcludedPhrases(_ sender: Any?) {
		IME.openPhraseFile(userFileAt: mgrLangModel.excludedPhrasesDataPath(IME.getInputMode()))
	}

	@objc func openUserSymbols(_ sender: Any?) {
		IME.openPhraseFile(userFileAt: mgrLangModel.userSymbolDataPath(IME.getInputMode()))
	}

	@objc func openPhraseReplacement(_ sender: Any?) {
		IME.openPhraseFile(userFileAt: mgrLangModel.phraseReplacementDataPath(IME.getInputMode()))
	}

	@objc func openAssociatedPhrases(_ sender: Any?) {
		IME.openPhraseFile(userFileAt: mgrLangModel.userAssociatedPhrasesDataPath(IME.getInputMode()))
	}

	@objc func reloadUserPhrases(_ sender: Any?) {
		mgrLangModel.loadUserPhrases()
		mgrLangModel.loadUserPhraseReplacement()
	}

	@objc func showAbout(_ sender: Any?) {
		(NSApp.delegate as? AppDelegate)?.showAbout()
		NSApp.activate(ignoringOtherApps: true)
	}
}
