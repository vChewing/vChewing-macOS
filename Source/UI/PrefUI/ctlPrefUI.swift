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

@available(macOS 11.0, *)
class ctlPrefUI {
	lazy var controller = PreferencesWindowController(
		panes: [
			Preferences.Pane(
				identifier: Preferences.PaneIdentifier(rawValue: "General"),
				title: NSLocalizedString("General", comment: ""),
				toolbarIcon: NSImage(
					systemSymbolName: "wrench.and.screwdriver.fill", accessibilityDescription: "General Preferences"
				)
					?? NSImage(named: NSImage.homeTemplateName)!
			) {
				suiPrefPaneGeneral()
			},
			Preferences.Pane(
				identifier: Preferences.PaneIdentifier(rawValue: "Experiences"),
				title: NSLocalizedString("Experience", comment: ""),
				toolbarIcon: NSImage(
					systemSymbolName: "person.fill.questionmark", accessibilityDescription: "Experiences Preferences"
				)
					?? NSImage(named: NSImage.listViewTemplateName)!
			) {
				suiPrefPaneExperience()
			},
			Preferences.Pane(
				identifier: Preferences.PaneIdentifier(rawValue: "Dictionary"),
				title: NSLocalizedString("Dictionary", comment: ""),
				toolbarIcon: NSImage(
					systemSymbolName: "character.book.closed.fill", accessibilityDescription: "Dictionary Preferences"
				)
					?? NSImage(named: NSImage.bookmarksTemplateName)!
			) {
				suiPrefPaneDictionary()
			},
			Preferences.Pane(
				identifier: Preferences.PaneIdentifier(rawValue: "Keyboard"),
				title: NSLocalizedString("Keyboard", comment: ""),
				toolbarIcon: NSImage(
					systemSymbolName: "keyboard.macwindow", accessibilityDescription: "Keyboard Preferences"
				)
					?? NSImage(named: NSImage.actionTemplateName)!
			) {
				suiPrefPaneKeyboard()
			},
		],
		style: .toolbarItems
	)
	static let shared = ctlPrefUI()
}
