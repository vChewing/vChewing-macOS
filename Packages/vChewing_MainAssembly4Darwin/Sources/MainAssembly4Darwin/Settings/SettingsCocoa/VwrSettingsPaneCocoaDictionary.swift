// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - SettingsPanesCocoa.Dictionary

extension SettingsPanesCocoa {
  public final class Dictionary: NSViewController {
    // MARK: Public

    override public func loadView() {
      prepareUserDictionaryFolderPathControl(pctUserDictionaryFolder)
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
      prepareUserDictionaryFolderPathControl(pctUserDictionaryFolder) // 需要這第二次。
    }

    // MARK: Internal

    let pctUserDictionaryFolder: NSPathControl = .init()
    let dragRetrieverKimo: NSFileDragRetrieverButton = .init()

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }
    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kUserDataFolderSpecified.renderCocoa(fixWidth: contentWidth) { renderable in
            renderable.currentControl = self.pctUserDictionaryFolder
            renderable.mainViewOverride = self.pathControlMainView
          }
        }?.boxed()
        NSTabView.build {
          NSTabView.TabPage(title: "Ａ") {
            NSStackView.buildSection(width: innerContentWidth) {
              NSStackView.build(.vertical) {
                UserDef.kShouldAutoReloadUserDataFiles.renderCocoa(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.lmmgrInitUserLMsWhenShould(_:))
                }
                "i18n:InfoMessage.SecurityConcernsNoShellScript".i18n
                  .makeNSLabel(descriptive: true, fixWidth: innerContentWidth)
              }
              UserDef.kUseExternalFactoryDict.renderCocoa(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.lmmgrConnectCoreDB(_:))
              }
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kFetchSuggestionsFromPerceptionOverrideModel.renderCocoa(fixWidth: innerContentWidth)
              UserDef.kReducePOMLifetimeToNoMoreThan12Hours.renderCocoa(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kFilterNonCNSReadingsForCHTInput
                .renderCocoa(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
                }
              UserDef.kFilterFactoryKanjisOfNonCurrentInputMode
                .renderCocoa(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
                }
              UserDef.kCNS11643Enabled.renderCocoa(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
              }
              UserDef.kSymbolInputEnabled.renderCocoa(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
              }
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｃ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kEnforceETenDOSCandidateSequence
                .renderCocoa(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
                }
              UserDef.kReplaceSymbolMenuNodeWithUserSuppliedData.renderCocoa(fixWidth: innerContentWidth)
              UserDef.kPhraseReplacementEnabled.renderCocoa(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?
                  .action = #selector(self.lmmgrSyncLMPrefsWithReplacementTable(_:))
              }
              UserDef.kSuppressFactoryUnigramsOfKanaSyllables.renderCocoa(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｄ") {
            NSStackView.buildSection(width: innerContentWidth) {
              NSStackView.build(.vertical) {
                NSStackView.build(.horizontal) {
                  "i18n:settings.importFromKimoTxt.label".makeNSLabel(fixWidth: innerContentWidth)
                  NSView()
                  NSStackView.build(.horizontal, spacing: 4) {
                    importKimoDragButton()
                    NSButton(
                      "i18n:settings.importFromKimoTxt.DirectlyImport",
                      target: self,
                      action: #selector(importKeyKeyUserPhraseSQLiteDBAction(_:))
                    )
                  }
                }
                "i18n:settings.importFromKimoTxt.description"
                  .makeNSLabel(descriptive: true, fixWidth: contentWidth)
              }
            }?.boxed()
            NSView()
          }
        }?.makeSimpleConstraint(.width, relation: .equal, value: tabContainerWidth)
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    func importKimoDragButton() -> NSFileDragRetrieverButton {
      dragRetrieverKimo.postDragHandler = { [weak self] url in
        self?.task4ImportingKeyKeyUserDict(url)
      }
      dragRetrieverKimo.title = "i18n:fileDragImportButton.DragFileToHere".i18n
      dragRetrieverKimo.target = self
      dragRetrieverKimo.allowedTypes = ["txt", "db"]
      dragRetrieverKimo.action = #selector(importKeyKeyUserDictionaryDataAction(_:))
      return dragRetrieverKimo
    }

    func pathControlMainView() -> NSView? {
      NSStackView.build(.horizontal) {
        self.pctUserDictionaryFolder
        NSButton(
          verbatim: "...",
          target: self,
          action: #selector(chooseUserDataFolderToSpecify(_:))
        )
        NSButton(verbatim: "↻", target: self, action: #selector(resetSpecifiedUserDataFolder(_:)))
      }
    }

    func prepareUserDictionaryFolderPathControl(_ pathCtl: NSPathControl) {
      pathCtl.delegate = self
      if let cell = pathCtl.cell as? NSPathCell {
        cell.lineBreakMode = .byTruncatingTail
        cell.truncatesLastVisibleLine = true
      }
      pathCtl.allowsExpansionToolTips = true
      pathCtl.translatesAutoresizingMaskIntoConstraints = false
      pathCtl.font = NSFont(name: "Arial Narrow", size: NSFont.smallSystemFontSize)
        ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
      pathCtl.cell?.controlSize = .small
      pathCtl.backgroundColor = .controlBackgroundColor
      pathCtl.target = self
      pathCtl.doubleAction = #selector(pathControlDoubleAction(_:))
      pathCtl.setContentHuggingPriority(.defaultLow, for: .horizontal)
      pathCtl.setContentHuggingPriority(.defaultHigh, for: .vertical)
      pathCtl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      pathCtl.makeSimpleConstraint(.height, relation: .equal, value: NSFont.smallSystemFontSize * 2)
      pathCtl.makeSimpleConstraint(.width, relation: .equal, value: windowWidth - 145)
      pathCtl.url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
      pathCtl.toolTip = "i18n:ClientManager.DragTargetInstruction".i18n
    }

    @IBAction
    func lmmgrInitUserLMsWhenShould(_: NSControl) {
      if PrefMgr.shared.shouldAutoReloadUserDataFiles {
        LMMgr.initUserLangModels()
      }
    }

    @IBAction
    func lmmgrConnectCoreDB(_: NSControl) {
      LMMgr.connectCoreDB()
    }

    @IBAction
    func lmmgrSyncLMPrefs(_: NSControl) {
      LMMgr.syncLMPrefs()
    }

    @IBAction
    func lmmgrSyncLMPrefsWithReplacementTable(_: NSControl) {
      LMMgr.syncLMPrefs()
      if PrefMgr.shared.phraseReplacementEnabled {
        LMMgr.loadUserPhraseReplacement()
      }
    }

    @IBAction
    func importKeyKeyUserPhraseSQLiteDBAction(_: NSButton) {
      task4ImportingKeyKeyUserDict()
    }

    @IBAction
    func importKeyKeyUserDictionaryDataAction(_: NSButton) {
      guard #available(macOS 10.13, *) else {
        SettingsPanesCocoa.warnAboutComDlg32Inavailability()
        return
      }
      let dlgOpenFile = NSOpenPanel()
      dlgOpenFile.title = "i18n:settings.importFromKimoTxt.label".i18n + ":"
      dlgOpenFile.showsResizeIndicator = true
      dlgOpenFile.showsHiddenFiles = true
      dlgOpenFile.canChooseFiles = true
      dlgOpenFile.allowsMultipleSelection = false
      dlgOpenFile.canChooseDirectories = false
      let allowedExtensions: [String] = ["txt", "db"]
      if #unavailable(macOS 11) {
        dlgOpenFile.allowedFileTypes = allowedExtensions
      } else {
        dlgOpenFile.allowedContentTypes = allowedExtensions.compactMap {
          .init(filenameExtension: $0)
        }
      }

      let window = CtlSettingsCocoa.shared?.window
      dlgOpenFile.beginSheetModal(at: window) { [weak self] result in
        if result == NSApplication.ModalResponse.OK {
          guard let url = dlgOpenFile.url else { return }
          self?.task4ImportingKeyKeyUserDict(url)
        }
      }
    }

    // MARK: Private

    private func task4ImportingKeyKeyUserDict(_ url: URL? = nil) {
      do {
        let countResult = try LMMgr.importYahooKeyKeyUserDictionary(url: url)
        let allImported = countResult.importedCount == countResult.totalFound
        let postOpsNotice: String? = allImported
          ? nil
          : "i18n:settings.importFromKimoTxt.postOpsNotice".i18n
        CtlSettingsCocoa.shared?.window.callAlert(
          title: String(
            format: "i18n:settings.importFromKimoTxt.finishedCount:%@%@".i18n,
            countResult.totalFound.description,
            countResult.importedCount.description
          ),
          text: postOpsNotice
        )
      } catch {
        let error = NSAlert(error: error)
        error.beginSheetModal(at: CtlSettingsCocoa.shared?.window)
      }
    }
  }
}

// MARK: - SettingsPanesCocoa.Dictionary + NSPathControlDelegate

extension SettingsPanesCocoa.Dictionary: NSPathControlDelegate {
  public func pathControl(_ pathControl: NSPathControl, acceptDrop info: NSDraggingInfo) -> Bool {
    let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
    guard let droppedURL = urls?.first as? URL else { return false }
    guard pathControl === pctUserDictionaryFolder else { return false }
    let url = LMMgr.resolveUserSpecifiedURL(droppedURL)
    let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
      PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath
    )
    var newPath = url.path
    newPath.ensureTrailingSlash()
    if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
      let oldPath = LMMgr.dataFolderPath(isDefaultFolder: false)
      PrefMgr.shared.userDataFolderSpecified = newPath
      BookmarkManager.shared.saveBookmark(for: url)
      AppDelegate.shared.updateDirectoryMonitorPath()
      pathControl.url = url
      maybePromptToMergeUserData(oldPath: oldPath)
      return true
    }
    // On Error:
    IMEApp.buzz()
    if !bolPreviousFolderValidity {
      LMMgr.resetSpecifiedUserDataFolder()
      pathControl.url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: true))
    }
    return false
  }

  @IBAction
  func resetSpecifiedUserDataFolder(_: Any) {
    let oldPath = LMMgr.dataFolderPath(isDefaultFolder: false)
    LMMgr.resetSpecifiedUserDataFolder()
    pctUserDictionaryFolder.url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: true))
    AppDelegate.shared.updateDirectoryMonitorPath()
    maybePromptToMergeUserData(oldPath: oldPath)
  }

  @IBAction
  func pathControlDoubleAction(_ sender: NSPathControl) {
    guard let url = sender.url else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  @IBAction
  func chooseUserDataFolderToSpecify(_: Any) {
    if NSEvent.keyModifierFlags == .option, let url = pctUserDictionaryFolder.url {
      NSWorkspace.shared.activateFileViewerSelecting([url])
      return
    }
    guard #available(macOS 10.13, *) else {
      SettingsPanesCocoa.warnAboutComDlg32Inavailability()
      return
    }
    let dlgOpenPath = NSOpenPanel()
    dlgOpenPath.title = "i18n:Settings.ChooseUserDataFolder".i18n
    dlgOpenPath.showsResizeIndicator = true
    dlgOpenPath.showsHiddenFiles = true
    dlgOpenPath.canChooseFiles = false
    dlgOpenPath.canChooseDirectories = true
    dlgOpenPath.allowsMultipleSelection = false

    let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
      PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath
    )
    let window = CtlSettingsCocoa.shared?.window
    dlgOpenPath.beginSheetModal(at: window) { [weak self] result in
      if result == NSApplication.ModalResponse.OK {
        guard let selectedURL = dlgOpenPath.url else { return }
        let url = LMMgr.resolveUserSpecifiedURL(selectedURL)
        // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
        // 所以要手動補回來。
        var newPath = url.path
        newPath.ensureTrailingSlash()
        if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
          let oldPath = LMMgr.dataFolderPath(isDefaultFolder: false)
          PrefMgr.shared.userDataFolderSpecified = newPath
          BookmarkManager.shared.saveBookmark(for: url)
          AppDelegate.shared.updateDirectoryMonitorPath()
          self?.pctUserDictionaryFolder.url = url
          self?.maybePromptToMergeUserData(oldPath: oldPath)
        } else {
          IMEApp.buzz()
          if !bolPreviousFolderValidity {
            LMMgr.resetSpecifiedUserDataFolder()
            self?.pctUserDictionaryFolder
              .url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: true))
          }
          return
        }
      } else {
        if !bolPreviousFolderValidity {
          LMMgr.resetSpecifiedUserDataFolder()
          self?.pctUserDictionaryFolder
            .url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: true))
        }
        return
      }
    }
  }

  // MARK: - Merge prompt

  /// 在目錄變更後提示使用者是否合併舊目錄資料至新目錄。
  /// 以 sheet 形式吸附在設定視窗上。
  private func maybePromptToMergeUserData(oldPath: String) {
    let newPath = LMMgr.dataFolderPath(isDefaultFolder: false)
    guard oldPath != newPath,
          FileManager.default.fileExists(atPath: oldPath) else { return }
    // 先確保新目錄的 template 檔案已存在，避免 migrateUserDataFrom 因檔案缺失而靜默跳過。
    for mode in Shared.InputMode.validCases {
      LMMgr.chkUserLMFilesExist(mode)
    }
    let alert = NSAlert()
    alert.messageText = "i18n:settings.dictionary.mergeUserDataToNewTarget.prompt.title".i18n
    alert.informativeText = "i18n:settings.dictionary.mergeUserDataToNewTarget.prompt.body".i18n
    alert.addButton(withTitle: "i18n:settings.dictionary.mergeUserDataToNewTarget.button.merge".i18n)
    alert.addButton(withTitle: "i18n:settings.dictionary.mergeUserDataToNewTarget.button.skip".i18n)
    alert.beginSheetModal(at: CtlSettingsCocoa.shared?.window) { response in
      guard response == .alertFirstButtonReturn else { return }
      let count = LMMgr.migrateUserDataFrom(oldPath: oldPath, to: newPath)
      if count > 0 {
        LMMgr.initUserLangModels()
        Notifier.notify(message: String(
          format: "i18n:settings.dictionary.mergeUserDataToNewTarget.notification.filesMerged:%d".i18n,
          count
        ))
      } else {
        Notifier.notify(
          message: "i18n:settings.dictionary.mergeUserDataToNewTarget.notification.noFilesMigrated".i18n
        )
      }
    }
  }
}

// MARK: - Preview

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Dictionary()
}
