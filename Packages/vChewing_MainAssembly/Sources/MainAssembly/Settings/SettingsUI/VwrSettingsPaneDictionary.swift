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
import UniformTypeIdentifiers

// MARK: - VwrSettingsPaneDictionary

@available(macOS 14, *)
public struct VwrSettingsPaneDictionary: View {
  // MARK: - State Variables

  @State
  private var isShowingFolderImporter = false
  @State
  private var isShowingFileImporter = false

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

  @State
  var keykeyImportButtonDisabled = false

  private var fdrUserDataDefault: String { LMMgr.dataFolderPath(isDefaultFolder: true) }

  public var body: some View {
    NavigationStack {
      Form {
        // MARK: - User Data Folder Path Management

        Section {
          Group {
            VStack(alignment: .leading) {
              Text(
                LocalizedStringKey(
                  "Choose your desired user data folder path. Will be omitted if invalid."
                )
              )
              HStack(spacing: 3) {
                PathControl(pathDroppable: $userDataFolderSpecified) { pathControl in
                  pathControl.allowedTypes = ["public.folder", "public.directory"]
                  pathControl
                    .placeholderString = "Please drag the desired target from Finder to this place."
                    .localized
                } acceptDrop: { pathControl, info in
                  let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
                  guard let url = urls?.first as? URL else { return false }
                  let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
                    PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath
                  )
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
                  isShowingFolderImporter = true
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
          .fileImporter(
            isPresented: $isShowingFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
          ) { result in
            let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
              userDataFolderSpecified.expandingTildeInPath
            )

            switch result {
            case let .success(urls):
              guard let url = urls.first else { return }
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
              }
            case .failure:
              if !bolPreviousFolderValidity {
                userDataFolderSpecified = fdrUserDataDefault
              }
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
          UserDef.kFetchSuggestionsFromUserOverrideModel
            .bind($fetchSuggestionsFromUserOverrideModel).render()
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
          UserDef.kAllowBoostingSingleKanjiAsUserPhrase.bind($allowBoostingSingleKanjiAsUserPhrase)
            .render()
          LabeledContent("i18n:settings.importFromKimoTxt.label") {
            Button("…") {
              isShowingFileImporter = true
            }
            .fileImporter(
              isPresented: $isShowingFileImporter,
              allowedContentTypes: [.plainText],
              allowsMultipleSelection: false
            ) { result in
              keykeyImportButtonDisabled = true
              defer { keykeyImportButtonDisabled = false }

              switch result {
              case let .success(urls):
                guard let url = urls.first else { return }
                guard var rawString = try? String(contentsOf: url) else { return }
                let maybeCount = try? LMMgr.importYahooKeyKeyUserDictionary(text: &rawString)
                let count: Int = maybeCount ?? 0

                CtlSettingsUI.shared?.window.callAlert(title: String(
                  format: "i18n:settings.importFromKimoTxt.finishedCount:%@".localized,
                  count.description
                ))
              case .failure:
                break
              }
            }
            Button("i18n:settings.importFromKimoTxt.DirectlyImport") {
              do {
                let count = try LMMgr.importYahooKeyKeyUserDictionaryByXPC()
                CtlSettingsUI.shared?.window.callAlert(
                  title: String(
                    format: "i18n:settings.importFromKimoTxt.finishedCount:%@".localized,
                    count.description
                  )
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

// MARK: - VwrSettingsPaneDictionary_Previews

@available(macOS 14, *)
struct VwrSettingsPaneDictionary_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneDictionary()
  }
}
