// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

@available(macOS 10.15, *)
struct suiPrefPaneDictionary: View {
  private var fdrDefault = mgrLangModel.dataFolderPath(isDefaultFolder: true)
  @State private var tbxUserDataPathSpecified: String =
    UserDefaults.standard.string(forKey: UserDef.kUserDataFolderSpecified.rawValue)
    ?? mgrLangModel.dataFolderPath(isDefaultFolder: true)
  @State private var selAutoReloadUserData: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kShouldAutoReloadUserDataFiles.rawValue)
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

  private let contentMaxHeight: Double = 432
  private let contentWidth: Double = {
    switch mgrPrefs.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if mgrPrefs.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 550
        }
    }
  }()

  var body: some View {
    ScrollView {
      Preferences.Container(contentWidth: contentWidth) {
        Preferences.Section(title: "", bottomDivider: true) {
          Text(LocalizedStringKey("Choose your desired user data folder path. Will be omitted if invalid."))
          HStack {
            if #available(macOS 11.0, *) {
              TextField(fdrDefault, text: $tbxUserDataPathSpecified).disabled(true)
                .help(tbxUserDataPathSpecified)
            } else {
              TextField(fdrDefault, text: $tbxUserDataPathSpecified).disabled(true)
                .toolTip(tbxUserDataPathSpecified)
            }
            Button {
              IME.dlgOpenPath.title = NSLocalizedString(
                "Choose your desired user data folder.", comment: ""
              )
              IME.dlgOpenPath.showsResizeIndicator = true
              IME.dlgOpenPath.showsHiddenFiles = true
              IME.dlgOpenPath.canChooseFiles = false
              IME.dlgOpenPath.canChooseDirectories = true

              let bolPreviousFolderValidity = mgrLangModel.checkIfSpecifiedUserDataFolderValid(
                mgrPrefs.userDataFolderSpecified.expandingTildeInPath)

              if let window = ctlPrefUI.shared.controller.window {
                IME.dlgOpenPath.beginSheetModal(for: window) { result in
                  if result == NSApplication.ModalResponse.OK {
                    guard let url = IME.dlgOpenPath.url else { return }
                    // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
                    // 所以要手動補回來。
                    var newPath = url.path
                    newPath.ensureTrailingSlash()
                    if mgrLangModel.checkIfSpecifiedUserDataFolderValid(newPath) {
                      mgrPrefs.userDataFolderSpecified = newPath
                      tbxUserDataPathSpecified = mgrPrefs.userDataFolderSpecified
                      BookmarkManager.shared.saveBookmark(for: url)
                      IME.initLangModels(userOnly: true)
                      (NSApplication.shared.delegate as! AppDelegate).updateStreamHelperPath()
                    } else {
                      clsSFX.beep()
                      if !bolPreviousFolderValidity {
                        mgrPrefs.resetSpecifiedUserDataFolder()
                      }
                      return
                    }
                  } else {
                    if !bolPreviousFolderValidity {
                      mgrPrefs.resetSpecifiedUserDataFolder()
                    }
                    return
                  }
                }
              }
            } label: {
              Text("...")
            }
            Button {
              mgrPrefs.resetSpecifiedUserDataFolder()
              tbxUserDataPathSpecified = ""
            } label: {
              Text("↻")
            }
          }
          Toggle(
            LocalizedStringKey("Automatically reload user data files if changes detected"),
            isOn: $selAutoReloadUserData.onChange {
              mgrPrefs.shouldAutoReloadUserDataFiles = selAutoReloadUserData
            }
          ).controlSize(.small)
        }
        Preferences.Section(title: "") {
          Toggle(
            LocalizedStringKey("Enable CNS11643 Support (2022-08-02)"),
            isOn: $selEnableCNS11643.onChange {
              mgrPrefs.cns11643Enabled = selEnableCNS11643
              mgrLangModel.setCNSEnabled(mgrPrefs.cns11643Enabled)
            }
          )
          Toggle(
            LocalizedStringKey("Enable symbol input support (incl. certain emoji symbols)"),
            isOn: $selEnableSymbolInputSupport.onChange {
              mgrPrefs.symbolInputEnabled = selEnableSymbolInputSupport
              mgrLangModel.setSymbolEnabled(mgrPrefs.symbolInputEnabled)
            }
          )
          Toggle(
            LocalizedStringKey("Allow boosting / excluding a candidate of single kanji"),
            isOn: $selAllowBoostingSingleKanjiAsUserPhrase.onChange {
              mgrPrefs.allowBoostingSingleKanjiAsUserPhrase = selAllowBoostingSingleKanjiAsUserPhrase
            }
          )
          Toggle(
            LocalizedStringKey("Applying typing suggestions from half-life user override model"),
            isOn: $selFetchSuggestionsFromUserOverrideModel.onChange {
              mgrPrefs.fetchSuggestionsFromUserOverrideModel = selFetchSuggestionsFromUserOverrideModel
            }
          )
          Toggle(
            LocalizedStringKey("Always use fixed listing order in candidate window"),
            isOn: $selUseFixecCandidateOrderOnSelection.onChange {
              mgrPrefs.useFixecCandidateOrderOnSelection = selUseFixecCandidateOrderOnSelection
            }
          )
          Toggle(
            LocalizedStringKey("Consolidate the context on confirming candidate selection"),
            isOn: $selConsolidateContextOnCandidateSelection.onChange {
              mgrPrefs.consolidateContextOnCandidateSelection = selConsolidateContextOnCandidateSelection
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
              mgrPrefs.hardenVerticalPunctuations = selHardenVerticalPunctuations
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
struct suiPrefPaneDictionary_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneDictionary()
  }
}
