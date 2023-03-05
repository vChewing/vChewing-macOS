// (c) 2018 and onwards Sindre Sorhus (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Cocoa

protocol SettingsStyleController: AnyObject {
  var delegate: SettingsStyleControllerDelegate? { get set }
  var isKeepingWindowCentered: Bool { get }

  func toolbarItemIdentifiers() -> [NSToolbarItem.Identifier]
  func toolbarItem(paneIdentifier: Settings.PaneIdentifier) -> NSToolbarItem?
  func selectTab(index: Int)
}

protocol SettingsStyleControllerDelegate: AnyObject {
  func activateTab(paneIdentifier: Settings.PaneIdentifier, animated: Bool)
  func activateTab(index: Int, animated: Bool)
}
