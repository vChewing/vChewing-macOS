// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import SSPreferences
import Shared
import SwiftExtension
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPaneDictionary: View {
  private var fdrUserDataDefault: String { LMMgr.dataFolderPath(isDefaultFolder: true) }
  @State private var tbxUserDataPathSpecified: String =
    UserDefaults.standard.string(forKey: UserDef.kUserDataFolderSpecified.rawValue)
    ?? LMMgr.dataFolderPath(isDefaultFolder: true)
  @State private var selAutoReloadUserData: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kShouldAutoReloadUserDataFiles.rawValue)
  @State private var selOnlyLoadFactoryLangModelsIfNeeded: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kOnlyLoadFactoryLangModelsIfNeeded.rawValue)
  @State private var selEnableCNS11643: Bool = UserDefaults.standard.bool(forKey: UserDef.kCNS11643Enabled.rawValue)
  @State private var selEnableSymbolInputSupport: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kSymbolInputEnabled.rawValue)
  @State private var selAllowBoostingSingleKanjiAsUserPhrase: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue)
  @State private var selFetchSuggestionsFromUserOverrideModel: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue)
  @State private var selUseFixecCandidateOrderOnSelection: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kUseFixecCandidateOrderOnSelection.rawValue)
  @State private var selConsolidateContextOnCandidateSelection: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kConsolidateContextOnCandidateSelection.rawValue)
  @State private var selHardenVerticalPunctuations: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kHardenVerticalPunctuations.rawValue)

  private static let dlgOpenPath = NSOpenPanel()
  private static let dlgOpenFile = NSOpenPanel()

  private let contentMaxHeight: Double = 440
  private let contentWidth: Double = {
    switch PrefMgr.shared.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 580
        }
    }
  }()

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: contentWidth) {
        // MARK: - User Data Folder Path Management

        SSPreferences.Section(title: "", bottomDivider: true) {
          Text(LocalizedStringKey("Choose your desired user data folder path. Will be omitted if invalid."))
          HStack {
            TextField(fdrUserDataDefault, text: $tbxUserDataPathSpecified).disabled(true)
              .help(tbxUserDataPathSpecified)
            Button {
              Self.dlgOpenPath.title = NSLocalizedString(
                "Choose your desired user data folder.", comment: ""
              )
              Self.dlgOpenPath.showsResizeIndicator = true
              Self.dlgOpenPath.showsHiddenFiles = true
              Self.dlgOpenPath.canChooseFiles = false
              Self.dlgOpenPath.allowsMultipleSelection = false
              Self.dlgOpenPath.canChooseDirectories = true

              let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
                PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath)

              if let window = CtlPrefUI.shared.controller.window {
                Self.dlgOpenPath.beginSheetModal(for: window) { result in
                  if result == NSApplication.ModalResponse.OK {
                    guard let url = Self.dlgOpenPath.url else { return }
                    // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
                    // 所以要手動補回來。
                    var newPath = url.path
                    newPath.ensureTrailingSlash()
                    if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
                      PrefMgr.shared.userDataFolderSpecified = newPath
                      tbxUserDataPathSpecified = PrefMgr.shared.userDataFolderSpecified
                      BookmarkManager.shared.saveBookmark(for: url)
                      (NSApp.delegate as? AppDelegate)?.updateDirectoryMonitorPath()
                    } else {
                      IMEApp.buzz()
                      if !bolPreviousFolderValidity {
                        LMMgr.resetSpecifiedUserDataFolder()
                      }
                      return
                    }
                  } else {
                    if !bolPreviousFolderValidity {
                      LMMgr.resetSpecifiedUserDataFolder()
                    }
                    return
                  }
                }
              }
            } label: {
              Text("...")
            }
            Button {
              LMMgr.resetSpecifiedUserDataFolder()
              tbxUserDataPathSpecified = ""
            } label: {
              Text("↻")
            }
          }
          Toggle(
            LocalizedStringKey("Automatically reload user data files if changes detected"),
            isOn: $selAutoReloadUserData.onChange {
              PrefMgr.shared.shouldAutoReloadUserDataFiles = selAutoReloadUserData
              if selAutoReloadUserData {
                LMMgr.initUserLangModels()
              }
            }
          ).controlSize(.small)
        }

        // MARK: - Something Else

        SSPreferences.Section(title: "") {
          Toggle(
            LocalizedStringKey("Only load factory language models if needed"),
            isOn: $selOnlyLoadFactoryLangModelsIfNeeded.onChange {
              PrefMgr.shared.onlyLoadFactoryLangModelsIfNeeded = selOnlyLoadFactoryLangModelsIfNeeded
            }
          )
          Toggle(
            LocalizedStringKey("Enable CNS11643 Support (2022-10-04)"),
            isOn: $selEnableCNS11643.onChange {
              PrefMgr.shared.cns11643Enabled = selEnableCNS11643
              LMMgr.setCNSEnabled(PrefMgr.shared.cns11643Enabled)
            }
          )
          Toggle(
            LocalizedStringKey("Enable symbol input support (incl. certain emoji symbols)"),
            isOn: $selEnableSymbolInputSupport.onChange {
              PrefMgr.shared.symbolInputEnabled = selEnableSymbolInputSupport
              LMMgr.setSymbolEnabled(PrefMgr.shared.symbolInputEnabled)
            }
          )
          Toggle(
            LocalizedStringKey("Allow boosting / excluding a candidate of single kanji"),
            isOn: $selAllowBoostingSingleKanjiAsUserPhrase.onChange {
              PrefMgr.shared.allowBoostingSingleKanjiAsUserPhrase = selAllowBoostingSingleKanjiAsUserPhrase
            }
          )
          Toggle(
            LocalizedStringKey("Applying typing suggestions from half-life user override model"),
            isOn: $selFetchSuggestionsFromUserOverrideModel.onChange {
              PrefMgr.shared.fetchSuggestionsFromUserOverrideModel = selFetchSuggestionsFromUserOverrideModel
            }
          )
          Toggle(
            LocalizedStringKey("Always use fixed listing order in candidate window"),
            isOn: $selUseFixecCandidateOrderOnSelection.onChange {
              PrefMgr.shared.useFixecCandidateOrderOnSelection = selUseFixecCandidateOrderOnSelection
            }
          )
          Toggle(
            LocalizedStringKey("Consolidate the context on confirming candidate selection"),
            isOn: $selConsolidateContextOnCandidateSelection.onChange {
              PrefMgr.shared.consolidateContextOnCandidateSelection = selConsolidateContextOnCandidateSelection
            }
          )
          Text(
            LocalizedStringKey(
              "For example: When typing “章太炎” and you want to override the “太” with “泰”, and the raw operation index range [1,2) which bounds are cutting the current node “章太炎” in range [0,3). If having lack of the pre-consolidation process, this word will become something like “張泰言” after the candidate selection. Only if we enable this consolidation, this word will become “章泰炎” which is the expected result that the context is kept as-is."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
          Toggle(
            LocalizedStringKey("Harden vertical punctuations during vertical typing (not recommended)"),
            isOn: $selHardenVerticalPunctuations.onChange {
              PrefMgr.shared.hardenVerticalPunctuations = selHardenVerticalPunctuations
            }
          )
          Text(
            LocalizedStringKey(
              "⚠︎ This feature is useful ONLY WHEN the font you are using doesn't support dynamic vertical punctuations. However, typed vertical punctuations will always shown as vertical punctuations EVEN IF your editor has changed the typing direction to horizontal."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneDictionary_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneDictionary()
  }
}
