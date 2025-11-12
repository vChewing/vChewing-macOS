// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - SettingsPanesCocoa

public final class SettingsPanesCocoa {
  public static let windowWidth: CGFloat = 614

  public static var contentWidth: CGFloat { windowWidth - 65 }
  public static var innerContentWidth: CGFloat { contentWidth - 37 }
  public static var tabContainerWidth: CGFloat { contentWidth + 20 }
  public static var contentHalfWidth: CGFloat { contentWidth / 2 - 4 }

  public let ctlPageGeneral = SettingsPanesCocoa.General()
  public let ctlPageCandidates = SettingsPanesCocoa.Candidates()
  public let ctlPageBehavior = SettingsPanesCocoa.Behavior()
  public let ctlPageOutput = SettingsPanesCocoa.Output()
  public let ctlPageDictionary = SettingsPanesCocoa.Dictionary()
  public let ctlPagePhrases = SettingsPanesCocoa.Phrases()
  public let ctlPageCassette = SettingsPanesCocoa.Cassette()
  public let ctlPageKeyboard = SettingsPanesCocoa.Keyboard()
  public let ctlPageDevZone = SettingsPanesCocoa.DevZone()
}

extension SettingsPanesCocoa {
  public func preload() {
    ctlPageGeneral.loadView()
    ctlPageCandidates.loadView()
    ctlPageBehavior.loadView()
    ctlPageOutput.loadView()
    ctlPageDictionary.loadView()
    ctlPagePhrases.loadView()
    ctlPageCassette.loadView()
    ctlPageKeyboard.loadView()
    ctlPageDevZone.loadView()
  }

  public static func warnAboutComDlg32Inavailability() {
    let title = "Please drag the desired target from Finder to this place.".localized
    let message =
      "[Technical Reason] macOS releases earlier than 10.13 have an issue: If calling NSOpenPanel directly from an input method, both the input method and its current client app hang in a dead-loop. Furthermore, it makes other apps hang in the same way when you switch into another app. If you don't want to hard-reboot your computer, your last resort is to use SSH to connect to your current computer from another computer and kill the input method process by Terminal commands. That's why vChewing cannot offer access to NSOpenPanel for macOS 10.12 and earlier."
        .localized
    CtlSettingsCocoa.shared?.window.callAlert(title: title, text: message)
  }
}

// MARK: - SettingsPreview

final class SettingsPreview: NSViewController {
  let panes = SettingsPanesCocoa()

  override func loadView() {
    addChild(panes.ctlPageGeneral)
    addChild(panes.ctlPageCandidates)
    addChild(panes.ctlPageBehavior)
    addChild(panes.ctlPageOutput)
    addChild(panes.ctlPageDictionary)
    addChild(panes.ctlPagePhrases)
    addChild(panes.ctlPageCassette)
    addChild(panes.ctlPageKeyboard)
    addChild(panes.ctlPageDevZone)
    view = NSTabView.build {
      NSTabView.TabPage(title: "GENERAL", view: panes.ctlPageGeneral.view)
      NSTabView.TabPage(title: "CANDIDATES", view: panes.ctlPageCandidates.view)
      NSTabView.TabPage(title: "BEHAVIOR", view: panes.ctlPageBehavior.view)
      NSTabView.TabPage(title: "OUTPUT", view: panes.ctlPageOutput.view)
      NSTabView.TabPage(title: "DICT", view: panes.ctlPageDictionary.view)
      NSTabView.TabPage(title: "PHRASES", view: panes.ctlPagePhrases.view)
      NSTabView.TabPage(title: "CASSETTE", view: panes.ctlPageCassette.view)
      NSTabView.TabPage(title: "KEYBOARD", view: panes.ctlPageKeyboard.view)
      NSTabView.TabPage(title: "DEVZONE", view: panes.ctlPageDevZone.view)
    } ?? .init()
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPreview()
}
