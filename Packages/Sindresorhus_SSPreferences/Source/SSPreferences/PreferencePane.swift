// (c) 2018 and onwards Sindre Sorhus (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Cocoa

public extension SSPreferences {
  struct PaneIdentifier: Hashable, RawRepresentable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}

public protocol PreferencePane: NSViewController {
  var preferencePaneIdentifier: SSPreferences.PaneIdentifier { get }
  var preferencePaneTitle: String { get }
  var toolbarItemIcon: NSImage { get }
}

public extension PreferencePane {
  var toolbarItemIdentifier: NSToolbarItem.Identifier {
    preferencePaneIdentifier.toolbarItemIdentifier
  }

  var toolbarItemIcon: NSImage { .empty }
}

public extension SSPreferences.PaneIdentifier {
  init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }

  init(fromToolbarItemIdentifier itemIdentifier: NSToolbarItem.Identifier) {
    self.init(rawValue: itemIdentifier.rawValue)
  }

  var toolbarItemIdentifier: NSToolbarItem.Identifier {
    NSToolbarItem.Identifier(rawValue)
  }
}
