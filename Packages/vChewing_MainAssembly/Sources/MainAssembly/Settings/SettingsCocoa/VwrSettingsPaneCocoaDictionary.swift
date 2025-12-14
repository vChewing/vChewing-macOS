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
          UserDef.kUserDataFolderSpecified.render(fixWidth: contentWidth) { renderable in
            renderable.currentControl = self.pctUserDictionaryFolder
            renderable.mainViewOverride = self.pathControlMainView
          }
          NSStackView.build(.vertical) {
            UserDef.kShouldAutoReloadUserDataFiles.render(fixWidth: contentWidth) { renderable in
              renderable.currentControl?.target = self
              renderable.currentControl?.action = #selector(self.lmmgrInitUserLMsWhenShould(_:))
            }
            "Due to security concerns, we don't consider implementing anything related to shell script execution here. An input method doing this without implementing App Sandbox will definitely have system-wide vulnerabilities, considering that its related UserDefaults are easily tamperable to execute malicious shell scripts. vChewing is designed to be invulnerable from this kind of attack. Also, official releases of vChewing are Sandboxed."
              .makeNSLabel(descriptive: true, fixWidth: contentWidth)
          }
        }?.boxed()
        NSTabView.build {
          NSTabView.TabPage(title: "Ａ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kFetchSuggestionsFromPerceptionOverrideModel.render(fixWidth: innerContentWidth)
              UserDef.kReducePOMLifetimeToNoMoreThan12Hours.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kFilterNonCNSReadingsForCHTInput
                .render(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
                }
              UserDef.kCNS11643Enabled.render(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
              }
              UserDef.kSymbolInputEnabled.render(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
              }
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kEnforceETenDOSCandidateSequence
                .render(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.lmmgrSyncLMPrefs(_:))
                }
              UserDef.kUseExternalFactoryDict.render(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.lmmgrConnectCoreDB(_:))
              }
              UserDef.kPhraseReplacementEnabled.render(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?
                  .action = #selector(self.lmmgrSyncLMPrefsWithReplacementTable(_:))
              }
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
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
      dragRetrieverKimo.title = "i18n:kimoImportButton.DragFileToHere".i18n
      dragRetrieverKimo.target = self
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
      if #available(macOS 10.10, *) {
        pathCtl.controlSize = .small
      }
      pathCtl.backgroundColor = .controlBackgroundColor
      pathCtl.target = self
      pathCtl.doubleAction = #selector(pathControlDoubleAction(_:))
      pathCtl.setContentHuggingPriority(.defaultLow, for: .horizontal)
      pathCtl.setContentHuggingPriority(.defaultHigh, for: .vertical)
      pathCtl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      pathCtl.makeSimpleConstraint(.height, relation: .equal, value: NSFont.smallSystemFontSize * 2)
      pathCtl.makeSimpleConstraint(.width, relation: .equal, value: windowWidth - 145)
      pathCtl.url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
      pathCtl.toolTip = "Please drag the desired target from Finder to this place.".i18n
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
      dlgOpenFile.beginSheetModal(at: window) { result in
        if result == NSApplication.ModalResponse.OK {
          guard let url = dlgOpenFile.url else { return }
          self.task4ImportingKeyKeyUserDict(url)
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
        error.beginSheetModal(at: CtlSettingsCocoa.shared?.window) { _ in
          // DO NOTHING.
        }
      }
    }
  }
}

// MARK: - SettingsPanesCocoa.Dictionary + NSPathControlDelegate

extension SettingsPanesCocoa.Dictionary: NSPathControlDelegate {
  public func pathControl(_ pathControl: NSPathControl, acceptDrop info: NSDraggingInfo) -> Bool {
    let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
    guard let url = urls?.first as? URL else { return false }
    guard pathControl === pctUserDictionaryFolder else { return false }
    let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
      PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath
    )
    var newPath = url.path
    newPath.ensureTrailingSlash()
    if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
      PrefMgr.shared.userDataFolderSpecified = newPath
      BookmarkManager.shared.saveBookmark(for: url)
      AppDelegate.shared.updateDirectoryMonitorPath()
      pathControl.url = url
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
    LMMgr.resetSpecifiedUserDataFolder()
    pctUserDictionaryFolder.url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: true))
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
    dlgOpenPath.title = "Choose your desired user data folder.".i18n
    dlgOpenPath.showsResizeIndicator = true
    dlgOpenPath.showsHiddenFiles = true
    dlgOpenPath.canChooseFiles = false
    dlgOpenPath.canChooseDirectories = true
    dlgOpenPath.allowsMultipleSelection = false

    let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
      PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath
    )
    let window = CtlSettingsCocoa.shared?.window
    dlgOpenPath.beginSheetModal(at: window) { result in
      if result == NSApplication.ModalResponse.OK {
        guard let url = dlgOpenPath.url else { return }
        // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
        // 所以要手動補回來。
        var newPath = url.path
        newPath.ensureTrailingSlash()
        if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
          PrefMgr.shared.userDataFolderSpecified = newPath
          BookmarkManager.shared.saveBookmark(for: url)
          AppDelegate.shared.updateDirectoryMonitorPath()
          self.pctUserDictionaryFolder.url = url
        } else {
          IMEApp.buzz()
          if !bolPreviousFolderValidity {
            LMMgr.resetSpecifiedUserDataFolder()
            self.pctUserDictionaryFolder
              .url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: true))
          }
          return
        }
      } else {
        if !bolPreviousFolderValidity {
          LMMgr.resetSpecifiedUserDataFolder()
          self.pctUserDictionaryFolder
            .url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: true))
        }
        return
      }
    }
  }
}

// MARK: - Preview

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Dictionary()
}
