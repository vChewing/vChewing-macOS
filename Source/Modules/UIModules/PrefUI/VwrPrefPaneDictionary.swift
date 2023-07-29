// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import Shared
import SSPreferences
import SwiftExtension
import SwiftUI
import SwiftUIBackports

@available(macOS 10.15, *)
struct VwrPrefPaneDictionary: View {
  // MARK: - AppStorage Variables

  @Backport.AppStorage(wrappedValue: "", UserDef.kUserDataFolderSpecified.rawValue)
  private var userDataFolderSpecified: String

  @Backport.AppStorage(wrappedValue: true, UserDef.kShouldAutoReloadUserDataFiles.rawValue)
  private var shouldAutoReloadUserDataFiles: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kUseExternalFactoryDict.rawValue)
  private var useExternalFactoryDict: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kOnlyLoadFactoryLangModelsIfNeeded.rawValue)
  private var onlyLoadFactoryLangModelsIfNeeded: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kCNS11643Enabled.rawValue)
  private var cns11643Enabled: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kSymbolInputEnabled.rawValue)
  private var symbolInputEnabled: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue)
  private var fetchSuggestionsFromUserOverrideModel: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kPhraseReplacementEnabled.rawValue)
  private var phraseReplacementEnabled: Bool

  @Backport.AppStorage(wrappedValue: false, UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue)
  private var allowBoostingSingleKanjiAsUserPhrase: Bool

  // MARK: - Main View

  private var fdrUserDataDefault: String { LMMgr.dataFolderPath(isDefaultFolder: true) }

  private static let dlgOpenPath = NSOpenPanel()
  private static let dlgOpenFile = NSOpenPanel()

  var body: some View {
    ScrollView {
      SSPreferences.Settings.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        // MARK: - User Data Folder Path Management

        SSPreferences.Settings.Section(bottomDivider: true) {
          Group {
            Text(LocalizedStringKey("Choose your desired user data folder path. Will be omitted if invalid."))
            HStack {
              TextField(fdrUserDataDefault, text: $userDataFolderSpecified).disabled(true)
                .help(userDataFolderSpecified)
              Button {
                if NSEvent.modifierFlags == .option, !userDataFolderSpecified.isEmpty {
                  NSWorkspace.shared.activateFileViewerSelecting(
                    [URL(fileURLWithPath: userDataFolderSpecified)]
                  )
                  return
                }
                Self.dlgOpenPath.title = NSLocalizedString(
                  "Choose your desired user data folder.", comment: ""
                )
                Self.dlgOpenPath.showsResizeIndicator = true
                Self.dlgOpenPath.showsHiddenFiles = true
                Self.dlgOpenPath.canChooseFiles = false
                Self.dlgOpenPath.allowsMultipleSelection = false
                Self.dlgOpenPath.canChooseDirectories = true

                let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
                  userDataFolderSpecified.expandingTildeInPath)

                if let window = CtlPrefUIShared.sharedWindow {
                  Self.dlgOpenPath.beginSheetModal(for: window) { result in
                    if result == NSApplication.ModalResponse.OK {
                      guard let url = Self.dlgOpenPath.url else { return }
                      // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
                      // 所以要手動補回來。
                      var newPath = url.path
                      newPath.ensureTrailingSlash()
                      if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
                        userDataFolderSpecified = newPath
                        BookmarkManager.shared.saveBookmark(for: url)
                        AppDelegate.shared.updateDirectoryMonitorPath()
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
                userDataFolderSpecified = ""
                LMMgr.resetSpecifiedUserDataFolder()
              } label: {
                Text("↻")
              }
            }
            Toggle(
              LocalizedStringKey("Automatically reload user data files if changes detected"),
              isOn: $shouldAutoReloadUserDataFiles.onChange {
                if shouldAutoReloadUserDataFiles {
                  LMMgr.initUserLangModels()
                }
              }
            ).controlSize(.small)
            Text(
              LocalizedStringKey(
                "Due to security concerns, we don't consider implementing anything related to shell script execution here. An input method doing this without implementing App Sandbox will definitely have system-wide vulnerabilities, considering that its related UserDefaults are easily tamperable to execute malicious shell scripts. vChewing is designed to be invulnerable from this kind of attack. Also, official releases of vChewing are Sandboxed."
              )
            )

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          }
          Divider()
          Group {
            Toggle(
              LocalizedStringKey("Read external factory dictionary plists if possible"),
              isOn: $useExternalFactoryDict.onChange {
                LMMgr.reloadFactoryDictionaryFiles()
              }
            )
            Text(
              LocalizedStringKey(
                "This will use the plist files deployed by the “make install” command from libvChewing-Data if possible."
              )
            )

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
            Toggle(
              LocalizedStringKey("Only load factory language models if needed"),
              isOn: $onlyLoadFactoryLangModelsIfNeeded.onChange {
                if !onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModelsOnAppDelegate() }
              }
            )
            Toggle(
              LocalizedStringKey("Enable CNS11643 Support (2023-05-19)"),
              isOn: $cns11643Enabled.onChange {
                LMMgr.setCNSEnabled(cns11643Enabled)
              }
            )
            Toggle(
              LocalizedStringKey("Enable symbol input support (incl. certain emoji symbols)"),
              isOn: $symbolInputEnabled.onChange {
                LMMgr.setSymbolEnabled(symbolInputEnabled)
              }
            )
            Toggle(
              LocalizedStringKey("Applying typing suggestions from half-life user override model"),
              isOn: $fetchSuggestionsFromUserOverrideModel
            )
            Text(
              "The user override model only possesses memories temporarily. Each memory record gradually becomes ineffective within approximately less than 6 days. You can erase all memory records through the input method menu.".localized
            )

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
            Toggle(
              LocalizedStringKey("Enable phrase replacement table"),
              isOn: $phraseReplacementEnabled.onChange {
                LMMgr.setPhraseReplacementEnabled(phraseReplacementEnabled)
                if phraseReplacementEnabled {
                  LMMgr.loadUserPhraseReplacement()
                }
              }
            )
            Text("This will batch-replace specified candidates.".localized)
              .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          }
          Divider()
          Group {
            Toggle(
              LocalizedStringKey("Allow boosting / excluding a candidate of single kanji when marking"),
              isOn: $allowBoostingSingleKanjiAsUserPhrase
            )
            Text(
              LocalizedStringKey(
                "⚠︎ This may hinder the walking algorithm from giving appropriate results."
              )
            )

            .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          }
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneDictionary_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneDictionary()
  }
}
