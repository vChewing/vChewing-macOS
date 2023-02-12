// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SSPreferences
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
extension PrefUITabs {
  var ssPaneIdentifier: SSPreferences.PaneIdentifier { .init(rawValue: rawValue) }
}

@available(macOS 10.15, *)
class CtlPrefUI {
  var controller = PreferencesWindowController(
    panes: [
      SSPreferences.Pane(
        identifier: PrefUITabs.tabGeneral.ssPaneIdentifier,
        title: PrefUITabs.tabGeneral.i18nTitle,
        toolbarIcon: PrefUITabs.tabGeneral.icon
      ) { VwrPrefPaneGeneral() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabCandidates.ssPaneIdentifier,
        title: PrefUITabs.tabCandidates.i18nTitle,
        toolbarIcon: PrefUITabs.tabCandidates.icon
      ) { VwrPrefPaneExperience() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabBehavior.ssPaneIdentifier,
        title: PrefUITabs.tabBehavior.i18nTitle,
        toolbarIcon: PrefUITabs.tabBehavior.icon
      ) { VwrPrefPaneExperience() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabOutput.ssPaneIdentifier,
        title: PrefUITabs.tabOutput.i18nTitle,
        toolbarIcon: PrefUITabs.tabOutput.icon
      ) { VwrPrefPaneExperience() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabDictionary.ssPaneIdentifier,
        title: PrefUITabs.tabDictionary.i18nTitle,
        toolbarIcon: PrefUITabs.tabDictionary.icon
      ) { VwrPrefPaneDictionary() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabPhrases.ssPaneIdentifier,
        title: PrefUITabs.tabPhrases.i18nTitle,
        toolbarIcon: PrefUITabs.tabPhrases.icon
      ) { VwrPrefPanePhrases() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabCassette.ssPaneIdentifier,
        title: PrefUITabs.tabCassette.i18nTitle,
        toolbarIcon: PrefUITabs.tabCassette.icon
      ) { VwrPrefPaneCassette() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabKeyboard.ssPaneIdentifier,
        title: PrefUITabs.tabKeyboard.i18nTitle,
        toolbarIcon: PrefUITabs.tabKeyboard.icon
      ) { VwrPrefPaneKeyboard() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabDevZone.ssPaneIdentifier,
        title: PrefUITabs.tabDevZone.i18nTitle,
        toolbarIcon: PrefUITabs.tabDevZone.icon
      ) { VwrPrefPaneDevZone() },
      SSPreferences.Pane(
        identifier: PrefUITabs.tabExperience.ssPaneIdentifier,
        title: PrefUITabs.tabExperience.i18nTitle,
        toolbarIcon: PrefUITabs.tabExperience.icon
      ) { VwrPrefPaneExperience() },
    ],
    style: .toolbarItems
  )
  static let shared = CtlPrefUI()
}
