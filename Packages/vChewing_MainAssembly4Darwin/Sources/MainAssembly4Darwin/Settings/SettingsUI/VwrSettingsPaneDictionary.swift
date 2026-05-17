// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - VwrSettingsPaneDictionary

@available(macOS 14, *)
public struct VwrSettingsPaneDictionary: View {
  // MARK: Public

  public var body: some View {
    Form {
      // MARK: - User Data Folder Path Management

      Section {
        Group {
          VStack(alignment: .leading) {
            HStack(spacing: 3) {
              PathControl(pathDroppable: $userDataFolderSpecified) { pathControl in
                pathControl.allowedTypes = ["public.folder", "public.directory"]
                pathControl
                  .placeholderString = "Please drag the desired target from Finder to this place."
                  .i18n
              } acceptDrop: { pathControl, info in
                let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
                guard let droppedURL = urls?.first as? URL else { return false }
                let url = LMMgr.resolveUserSpecifiedURL(droppedURL)
                let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
                  PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath
                )
                var newPath = url.path
                newPath.ensureTrailingSlash()
                if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
                  let oldPath = LMMgr.dataFolderPath(isDefaultFolder: false)
                  userDataFolderSpecified = newPath
                  pathControl.url = url
                  BookmarkManager.shared.saveBookmark(for: url)
                  AppDelegate.shared.updateDirectoryMonitorPath()
                  maybePromptMergeInSwiftUI(oldPath: oldPath)
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
                let oldPath = LMMgr.dataFolderPath(isDefaultFolder: false)
                userDataFolderSpecified = fdrUserDataDefault
                AppDelegate.shared.updateDirectoryMonitorPath()
                maybePromptMergeInSwiftUI(oldPath: oldPath)
              } label: {
                Text("↻")
              }.frame(minWidth: 25)
            }
            Text(LocalizedStringKey("i18n:settings.Prompt.ChooseDesiredUserDataFolderPath"))
              .settingsDescription()
          }
          VStack(alignment: .leading) {
            UserDef.kShouldAutoReloadUserDataFiles.renderUI {
              if PrefMgr.shared.shouldAutoReloadUserDataFiles {
                LMMgr.initUserLangModels()
              }
            }
            Text(
              LocalizedStringKey(
                "Due to security concerns, we don't consider implementing anything related to shell script execution here. An input method doing this without implementing App Sandbox will definitely have system-wide vulnerabilities, considering that its related UserDefaults are easily tamperable to execute malicious shell scripts. vChewing is designed to be invulnerable from this kind of attack. Also, official releases of vChewing are Sandboxed."
              )
            )
            .settingsDescription()
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
            guard let selectedURL = urls.first else { return }
            let url = LMMgr.resolveUserSpecifiedURL(selectedURL)
            var newPath = url.path
            newPath.ensureTrailingSlash()
            if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
              let oldPath = LMMgr.dataFolderPath(isDefaultFolder: false)
              userDataFolderSpecified = newPath
              BookmarkManager.shared.saveBookmark(for: url)
              AppDelegate.shared.updateDirectoryMonitorPath()
              maybePromptMergeInSwiftUI(oldPath: oldPath)
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
        UserDef.kEnforceETenDOSCandidateSequence.renderUI {
          LMMgr.syncLMPrefs()
        }
        UserDef.kUseExternalFactoryDict.renderUI {
          LMMgr.connectCoreDB()
        }
        UserDef.kFilterNonCNSReadingsForCHTInput.renderUI {
          LMMgr.connectCoreDB()
        }
        UserDef.kFilterFactoryKanjisOfNonCurrentInputMode.renderUI {
          LMMgr.syncLMPrefs()
        }
        UserDef.kCNS11643Enabled.renderUI {
          LMMgr.syncLMPrefs()
        }
        UserDef.kSymbolInputEnabled.renderUI {
          LMMgr.syncLMPrefs()
        }
        UserDef.kReplaceSymbolMenuNodeWithUserSuppliedData.renderUI()
        UserDef.kPhraseReplacementEnabled.renderUI {
          LMMgr.syncLMPrefs()
          if PrefMgr.shared.phraseReplacementEnabled {
            LMMgr.loadUserPhraseReplacement()
          }
        }
        UserDef.kSuppressFactoryUnigramsOfKanaSyllables.renderUI()
      }

      Section {
        UserDef.kFetchSuggestionsFromPerceptionOverrideModel.renderUI()
        UserDef.kReducePOMLifetimeToNoMoreThan12Hours.renderUI()
      }

      Section {
        VStack(alignment: .leading) {
          LabeledContent("i18n:settings.importFromKimoTxt.label") {
            Button("…") {
              isShowingFileImporter = true
            }
            .fileImporter(
              isPresented: $isShowingFileImporter,
              allowedContentTypes: ["txt", "db"].compactMap {
                .init(filenameExtension: $0)
              },
              allowsMultipleSelection: false
            ) { result in
              keykeyImportButtonDisabled = true
              defer { keykeyImportButtonDisabled = false }

              switch result {
              case let .success(urls):
                guard let url = urls.first else { return }
                task4ImportingKeyKeyUserDict(url)
              case .failure:
                break
              }
            }
            Button("i18n:settings.importFromKimoTxt.DirectlyImport") {
              task4ImportingKeyKeyUserDict()
            }
          }
          .disabled(keykeyImportButtonDisabled)
          .frame(maxWidth: .infinity)
          Text(LocalizedStringKey("i18n:settings.importFromKimoTxt.description"))
            .settingsDescription()
        }
      }
    }.formStyled()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
      .alert(
        importAlertTitle,
        isPresented: $isShowingImportAlert
      ) {
        Button("OK".i18n, role: .cancel) {}
      } message: {
        if let msg = importAlertMessage {
          Text(msg)
        }
      }
      .alert(
        "i18n:settings.dictionary.mergeUserDataToNewTarget.prompt.title".i18n,
        isPresented: $isShowingMergeAlert
      ) {
        Button("i18n:settings.dictionary.mergeUserDataToNewTarget.button.merge".i18n) {
          let newPath = LMMgr.dataFolderPath(isDefaultFolder: false)
          let count = LMMgr.migrateUserDataFrom(oldPath: pendingMergeOldPath, to: newPath)
          if count > 0 {
            LMMgr.initUserLangModels()
            Notifier.notify(message: String(
              format: "i18n:settings.dictionary.mergeUserDataToNewTarget.notification.filesMerged".i18n,
              count
            ))
          } else {
            Notifier.notify(
              message: "i18n:settings.dictionary.mergeUserDataToNewTarget.notification.noFilesMigrated".i18n
            )
          }
        }
        Button("i18n:settings.dictionary.mergeUserDataToNewTarget.button.skip".i18n, role: .cancel) {}
      } message: {
        Text("i18n:settings.dictionary.mergeUserDataToNewTarget.prompt.body".i18n)
      }
  }

  // MARK: Private

  // MARK: - State Variables

  @State
  private var isShowingFolderImporter = false
  @State
  private var isShowingFileImporter = false
  @State
  private var isShowingImportAlert = false
  @State
  private var importAlertTitle: String = ""
  @State
  private var importAlertMessage: String?

  // MARK: - Merge prompt state

  @State
  private var isShowingMergeAlert = false
  @State
  private var pendingMergeOldPath: String = ""

  // MARK: - AppStorage Variables（僅保留需經 PathControl 繫結的屬性）

  @AppStorage(wrappedValue: "", UserDef.kUserDataFolderSpecified.rawValue)
  private var userDataFolderSpecified: String

  // MARK: - Main View

  @State
  private var keykeyImportButtonDisabled = false

  private var fdrUserDataDefault: String { LMMgr.dataFolderPath(isDefaultFolder: true) }

  /// 檢查是否需要顯示合併提示，若是則觸發 SwiftUI alert。
  private func maybePromptMergeInSwiftUI(oldPath: String) {
    let newPath = LMMgr.dataFolderPath(isDefaultFolder: false)
    guard oldPath != newPath,
          FileManager.default.fileExists(atPath: oldPath) else { return }
    // 先確保新目錄的 template 檔案已存在，避免 migrateUserDataFrom 因檔案缺失而靜默跳過。
    for mode in Shared.InputMode.validCases {
      LMMgr.chkUserLMFilesExist(mode)
    }
    pendingMergeOldPath = oldPath
    isShowingMergeAlert = true
  }

  private func task4ImportingKeyKeyUserDict(_ url: URL? = nil) {
    do {
      let countResult = try LMMgr.importYahooKeyKeyUserDictionary(url: url)
      let allImported = countResult.importedCount == countResult.totalFound
      importAlertTitle = String(
        format: "i18n:settings.importFromKimoTxt.finishedCount:%@%@".i18n,
        countResult.totalFound.description,
        countResult.importedCount.description
      )
      importAlertMessage = allImported
        ? nil
        : "i18n:settings.importFromKimoTxt.postOpsNotice".i18n
      isShowingImportAlert = true
    } catch {
      importAlertTitle = error.localizedDescription
      importAlertMessage = nil
      isShowingImportAlert = true
    }
  }
}

// MARK: - VwrSettingsPaneDictionary_Previews

@available(macOS 14, *)
struct VwrSettingsPaneDictionary_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneDictionary()
  }
}
