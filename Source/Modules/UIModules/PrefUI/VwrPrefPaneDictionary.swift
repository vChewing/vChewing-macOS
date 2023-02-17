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

@available(macOS 10.15, *)
struct VwrPrefPaneDictionary: View {
  private var fdrUserDataDefault: String { LMMgr.dataFolderPath(isDefaultFolder: true) }
  @State private var tbxUserDataPathSpecified: String =
    UserDefaults.standard.string(forKey: UserDef.kUserDataFolderSpecified.rawValue)
      ?? LMMgr.dataFolderPath(isDefaultFolder: true)
  @State private var selAutoReloadUserData: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kShouldAutoReloadUserDataFiles.rawValue)
  @State private var selUseExternalFactoryDict: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kUseExternalFactoryDict.rawValue)
  @State private var selOnlyLoadFactoryLangModelsIfNeeded: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kOnlyLoadFactoryLangModelsIfNeeded.rawValue)
  @State private var selEnableCNS11643: Bool = UserDefaults.standard.bool(forKey: UserDef.kCNS11643Enabled.rawValue)
  @State private var selEnableSymbolInputSupport: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kSymbolInputEnabled.rawValue)
  @State private var selFetchSuggestionsFromUserOverrideModel: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue)
  @State private var selPhraseReplacementEnabled: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kPhraseReplacementEnabled.rawValue
  )

  private static let dlgOpenPath = NSOpenPanel()
  private static let dlgOpenFile = NSOpenPanel()

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: CtlPrefUI.contentWidth) {
        // MARK: - User Data Folder Path Management

        SSPreferences.Section(title: "", bottomDivider: true) {
          Group {
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
            Text(
              LocalizedStringKey(
                "Due to security concerns, we don't consider implementing anything related to shell script execution here. An input method doing this without implementing App Sandbox will definitely have system-wide vulnerabilities, considering that its related UserDefaults are easily tamperable to execute malicious shell scripts. vChewing is designed to be invulnerable from this kind of attack. Also, official releases of vChewing are Sandboxed."
              )
            )
            .preferenceDescription()
          }
          Divider()
          Group {
            Toggle(
              LocalizedStringKey("Read external factory dictionary plists if possible"),
              isOn: $selUseExternalFactoryDict.onChange {
                PrefMgr.shared.useExternalFactoryDict = selUseExternalFactoryDict
                LMMgr.reloadFactoryDictionaryPlists()
              }
            )
            Text(
              LocalizedStringKey(
                "This will use the plist files deployed by the “make install” command from libvChewing-Data if possible."
              )
            )
            .preferenceDescription()
            Toggle(
              LocalizedStringKey("Only load factory language models if needed"),
              isOn: $selOnlyLoadFactoryLangModelsIfNeeded.onChange {
                PrefMgr.shared.onlyLoadFactoryLangModelsIfNeeded = selOnlyLoadFactoryLangModelsIfNeeded
              }
            )
            Toggle(
              LocalizedStringKey("Enable CNS11643 Support (2023-01-06)"),
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
              LocalizedStringKey("Applying typing suggestions from half-life user override model"),
              isOn: $selFetchSuggestionsFromUserOverrideModel.onChange {
                PrefMgr.shared.fetchSuggestionsFromUserOverrideModel = selFetchSuggestionsFromUserOverrideModel
              }
            )
            Text(
              "The user override model only possesses memories temporarily. It won't memorize those unigrams consisting of only one Chinese character, except “你/他/妳/她/祢/衪/它/牠/再/在”. Each memory record gradually becomes ineffective within approximately less than 6 days. You can erase all memory records through the input method menu.".localized
            )
            .preferenceDescription()
            Toggle(
              LocalizedStringKey("Enable phrase replacement table"),
              isOn: $selPhraseReplacementEnabled.onChange {
                PrefMgr.shared.phraseReplacementEnabled = selPhraseReplacementEnabled
              }
            )
            Text("This will batch-replace specified candidates.".localized).preferenceDescription()
          }
        }
      }
    }
    .frame(maxHeight: CtlPrefUI.contentMaxHeight).fixedSize(horizontal: false, vertical: true)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneDictionary_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneDictionary()
  }
}
