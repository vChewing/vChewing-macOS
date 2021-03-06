// Copyright (c) 2018 and onwards Sindre Sorhus (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

final class ToolbarItemStyleViewController: NSObject, PreferencesStyleController {
  let toolbar: NSToolbar
  let centerToolbarItems: Bool
  let preferencePanes: [PreferencePane]
  var isKeepingWindowCentered: Bool { centerToolbarItems }
  weak var delegate: PreferencesStyleControllerDelegate?

  init(preferencePanes: [PreferencePane], toolbar: NSToolbar, centerToolbarItems: Bool) {
    self.preferencePanes = preferencePanes
    self.toolbar = toolbar
    self.centerToolbarItems = centerToolbarItems
  }

  func toolbarItemIdentifiers() -> [NSToolbarItem.Identifier] {
    var toolbarItemIdentifiers = [NSToolbarItem.Identifier]()

    if centerToolbarItems {
      toolbarItemIdentifiers.append(.flexibleSpace)
    }

    for preferencePane in preferencePanes {
      toolbarItemIdentifiers.append(preferencePane.toolbarItemIdentifier)
    }

    if centerToolbarItems {
      toolbarItemIdentifiers.append(.flexibleSpace)
    }

    return toolbarItemIdentifiers
  }

  func toolbarItem(preferenceIdentifier: Preferences.PaneIdentifier) -> NSToolbarItem? {
    guard let preference = (preferencePanes.first { $0.preferencePaneIdentifier == preferenceIdentifier }) else {
      preconditionFailure()
    }

    let toolbarItem = NSToolbarItem(itemIdentifier: preferenceIdentifier.toolbarItemIdentifier)
    toolbarItem.label = preference.preferencePaneTitle
    toolbarItem.image = preference.toolbarItemIcon
    toolbarItem.target = self
    toolbarItem.action = #selector(toolbarItemSelected)
    return toolbarItem
  }

  @IBAction private func toolbarItemSelected(_ toolbarItem: NSToolbarItem) {
    delegate?.activateTab(
      preferenceIdentifier: Preferences.PaneIdentifier(fromToolbarItemIdentifier: toolbarItem.itemIdentifier),
      animated: true
    )
  }

  func selectTab(index: Int) {
    toolbar.selectedItemIdentifier = preferencePanes[index].toolbarItemIdentifier
  }
}
