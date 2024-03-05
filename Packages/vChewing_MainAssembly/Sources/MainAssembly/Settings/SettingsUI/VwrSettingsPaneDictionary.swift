// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import OSFrameworkImpl
import Shared
import SwiftExtension
import SwiftUI

@available(macOS 13, *)
public struct VwrSettingsPaneDictionary: View {
  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: "", UserDef.kUserDataFolderSpecified.rawValue)
  private var userDataFolderSpecified: String

  @AppStorage(wrappedValue: true, UserDef.kShouldAutoReloadUserDataFiles.rawValue)
  private var shouldAutoReloadUserDataFiles: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseExternalFactoryDict.rawValue)
  private var useExternalFactoryDict: Bool

  @AppStorage(wrappedValue: false, UserDef.kCNS11643Enabled.rawValue)
  private var cns11643Enabled: Bool

  @AppStorage(wrappedValue: true, UserDef.kSymbolInputEnabled.rawValue)
  private var symbolInputEnabled: Bool

  @AppStorage(wrappedValue: true, UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue)
  private var fetchSuggestionsFromUserOverrideModel: Bool

  @AppStorage(wrappedValue: false, UserDef.kPhraseReplacementEnabled.rawValue)
  private var phraseReplacementEnabled: Bool

  @AppStorage(wrappedValue: false, UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue)
  private var allowBoostingSingleKanjiAsUserPhrase: Bool

  @AppStorage(wrappedValue: false, UserDef.kFilterNonCNSReadingsForCHTInput.rawValue)
  private var filterNonCNSReadingsForCHTInput: Bool

  // MARK: - Main View

  @State var keykeyImportButtonDisabled = false

  private var fdrUserDataDefault: String { LMMgr.dataFolderPath(isDefaultFolder: true) }

  private static let dlgOpenPath = NSOpenPanel()
  private static let dlgOpenFile = NSOpenPanel()

  public var body: some View {
    ScrollView {
      Form {
        // MARK: - User Data Folder Path Management

        Section {
          Group {
            VStack(alignment: .leading) {
              Text(LocalizedStringKey("Choose your desired user data folder path. Will be omitted if invalid."))
              HStack(spacing: 3) {
                PathControl(pathDroppable: $userDataFolderSpecified) { pathControl in
                  pathControl.allowedTypes = ["public.folder", "public.directory"]
                  pathControl.placeholderString = "Please drag the desired target from Finder to this place.".localized
                } acceptDrop: { pathControl, info in
                  let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
                  guard let url = urls?.first as? URL else { return false }
                  let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
                    PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath)
                  var newPath = url.path
                  newPath.ensureTrailingSlash()
                  if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
                    userDataFolderSpecified = newPath
                    pathControl.url = url
                    BookmarkManager.shared.saveBookmark(for: url)
                    AppDelegate.shared.updateDirectoryMonitorPath()
                    return true
                  }
                  // On Error:
                  IMEApp.buzz()
                  if !bolPreviousFolderValidity {
                    userDataFolderSpecified = fdrUserDataDefault
                    pathControl.url = URL(fileURLWithPath: fdrUserDataDefault)
                  }
                  return false
                }
                Button {
                  if NSEvent.keyModifierFlags == .option, !userDataFolderSpecified.isEmpty {
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

                  if let window = CtlSettingsUI.shared?.window {
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
                            userDataFolderSpecified = fdrUserDataDefault
                          }
                          return
                        }
                      } else {
                        if !bolPreviousFolderValidity {
                          userDataFolderSpecified = fdrUserDataDefault
                        }
                        return
                      }
                    }
                  }
                } label: {
                  Text("...")
                }.frame(minWidth: 25)
                Button {
                  userDataFolderSpecified = fdrUserDataDefault
                } label: {
                  Text("↻")
                }.frame(minWidth: 25)
              }
              Spacer()
              Text(
                LocalizedStringKey(
                  "Due to security concerns, we don't consider implementing anything related to shell script execution here. An input method doing this without implementing App Sandbox will definitely have system-wide vulnerabilities, considering that its related UserDefaults are easily tamperable to execute malicious shell scripts. vChewing is designed to be invulnerable from this kind of attack. Also, official releases of vChewing are Sandboxed."
                )
              )
              .settingsDescription()
              UserDef.kShouldAutoReloadUserDataFiles.bind(
                $shouldAutoReloadUserDataFiles.didChange {
                  if shouldAutoReloadUserDataFiles {
                    LMMgr.initUserLangModels()
                  }
                }
              ).render()
            }
          }
        }

        Section {
          UserDef.kUseExternalFactoryDict.bind(
            $useExternalFactoryDict.didChange {
              LMMgr.connectCoreDB()
            }
          ).render()
          UserDef.kFilterNonCNSReadingsForCHTInput.bind(
            $filterNonCNSReadingsForCHTInput.didChange {
              LMMgr.connectCoreDB()
            }
          ).render()
          UserDef.kCNS11643Enabled.bind(
            $cns11643Enabled.didChange {
              LMMgr.syncLMPrefs()
            }
          ).render()
          UserDef.kSymbolInputEnabled.bind(
            $symbolInputEnabled.didChange {
              LMMgr.syncLMPrefs()
            }
          ).render()
          UserDef.kFetchSuggestionsFromUserOverrideModel.bind($fetchSuggestionsFromUserOverrideModel).render()
          UserDef.kPhraseReplacementEnabled.bind(
            $phraseReplacementEnabled.didChange {
              LMMgr.syncLMPrefs()
              if phraseReplacementEnabled {
                LMMgr.loadUserPhraseReplacement()
              }
            }
          ).render()
        }
        Section {
          UserDef.kAllowBoostingSingleKanjiAsUserPhrase.bind($allowBoostingSingleKanjiAsUserPhrase).render()
          LabeledContent("i18n:settings.importFromKimoTxt.label") {
            Button("…") {
              Self.dlgOpenFile.title = NSLocalizedString(
                "i18n:settings.importFromKimoTxt.label", comment: ""
              ) + ":"
              Self.dlgOpenFile.showsResizeIndicator = true
              Self.dlgOpenFile.showsHiddenFiles = true
              Self.dlgOpenFile.canChooseFiles = true
              Self.dlgOpenFile.allowsMultipleSelection = false
              Self.dlgOpenFile.canChooseDirectories = false
              Self.dlgOpenFile.allowedContentTypes = [.init(filenameExtension: "txt")].compactMap { $0 }

              if let window = CtlSettingsUI.shared?.window {
                Self.dlgOpenFile.beginSheetModal(for: window) { result in
                  if result == NSApplication.ModalResponse.OK {
                    keykeyImportButtonDisabled = true
                    defer { keykeyImportButtonDisabled = false }
                    guard let url = Self.dlgOpenFile.url else { return }
                    guard var rawString = try? String(contentsOf: url) else { return }
                    let maybeCount = try? LMMgr.importYahooKeyKeyUserDictionary(text: &rawString)
                    let count: Int = maybeCount ?? 0
                    window.callAlert(title: String(format: "i18n:settings.importFromKimoTxt.finishedCount:%@".localized, count.description))
                  }
                }
              }
            }
            Button("i18n:settings.importFromKimoTxt.DirectlyImport") {
              do {
                let count = try LMMgr.importYahooKeyKeyUserDictionaryByXPC()
                CtlSettingsUI.shared?.window.callAlert(
                  title: String(format: "i18n:settings.importFromKimoTxt.finishedCount:%@".localized, count.description)
                )
              } catch {
                let error = NSAlert(error: error)
                error.beginSheetModal(at: CtlSettingsUI.shared?.window) { _ in
                  // DO NOTHING.
                }
              }
            }
          }.disabled(keykeyImportButtonDisabled)
        }
      }.formStyled()
    }
    .frame(
      minWidth: CtlSettingsUI.formWidth,
      maxHeight: CtlSettingsUI.contentMaxHeight
    )
  }
}

@available(macOS 13, *)
struct VwrSettingsPaneDictionary_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneDictionary()
  }
}
