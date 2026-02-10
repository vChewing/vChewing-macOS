// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - SettingsPanesCocoa.Cassette

extension SettingsPanesCocoa {
  public final class Cassette: NSViewController {
    // MARK: Public

    override public func loadView() {
      prepareCassetteFolderPathControl(pctCassetteFilePath)
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
      prepareCassetteFolderPathControl(pctCassetteFilePath) // 需要這第二次。
    }

    // MARK: Internal

    let pctCassetteFilePath: NSPathControl = .init()

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }
    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kCassettePath.render(fixWidth: contentWidth) { renderable in
            renderable.currentControl = self.pctCassetteFilePath
            renderable.mainViewOverride = self.pathControlMainView
          }
          UserDef.kCassetteEnabled.render(fixWidth: contentWidth) { renderable in
            renderable.currentControl?.target = self
            renderable.currentControl?.action = #selector(self.cassetteEnabledToggled(_:))
          }
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kAutoCompositeWithLongestPossibleCassetteKey.render(fixWidth: contentWidth)
          UserDef.kShowTranslatedStrokesInCompositionBuffer.render(fixWidth: contentWidth)
          UserDef.kForceCassetteChineseConversion.render(fixWidth: contentWidth)
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    func pathControlMainView() -> NSView? {
      NSStackView.build(.horizontal) {
        self.pctCassetteFilePath
        NSButton(verbatim: "...", target: self, action: #selector(chooseCassetteFileToSpecify(_:)))
        NSButton(verbatim: "×", target: self, action: #selector(resetCassettePath(_:)))
      }
    }

    func prepareCassetteFolderPathControl(_ pathCtl: NSPathControl) {
      pathCtl.delegate = self
      (pathCtl.cell as? NSTextFieldCell)?
        .placeholderString = "Please drag the desired target from Finder to this place.".i18n
      if let cell = pathCtl.cell as? NSPathCell {
        cell.lineBreakMode = .byTruncatingTail
        cell.truncatesLastVisibleLine = true
      }
      pathCtl.allowsExpansionToolTips = true
      (pathCtl.cell as? NSPathCell)?.allowedTypes = ["cin2", "cin", "vcin"]
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
      let currentPath = LMMgr.cassettePath()
      pathCtl.url = currentPath.isEmpty ? nil : URL(fileURLWithPath: LMMgr.cassettePath())
      pathCtl.toolTip = "Please drag the desired target from Finder to this place.".i18n
    }

    @IBAction
    func cassetteEnabledToggled(_: NSControl) {}
  }
}

// MARK: - SettingsPanesCocoa.Cassette + NSPathControlDelegate

extension SettingsPanesCocoa.Cassette: NSPathControlDelegate {
  public func pathControl(_ pathControl: NSPathControl, acceptDrop info: NSDraggingInfo) -> Bool {
    let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
    guard let url = urls?.first as? URL else { return false }
    guard pathControl === pctCassetteFilePath else { return false }
    let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
      PrefMgr.shared.cassettePath.expandingTildeInPath
    )
    if LMMgr.checkCassettePathValidity(url.path) {
      PrefMgr.shared.cassettePath = url.path
      LMMgr.loadCassetteData()
      BookmarkManager.shared.saveBookmark(for: url)
      pathControl.url = url
      return true
    }
    // On Error:
    IMEApp.buzz()
    if !bolPreviousPathValidity {
      LMMgr.resetCassettePath()
    }
    return false
  }

  @IBAction
  func resetCassettePath(_: Any) {
    LMMgr.resetCassettePath()
  }

  @IBAction
  func pathControlDoubleAction(_ sender: NSPathControl) {
    guard let url = sender.url else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  @IBAction
  func chooseCassetteFileToSpecify(_: Any) {
    if NSEvent.keyModifierFlags == .option, let url = pctCassetteFilePath.url {
      NSWorkspace.shared.activateFileViewerSelecting([url])
      return
    }
    guard #available(macOS 10.13, *) else {
      SettingsPanesCocoa.warnAboutComDlg32Inavailability()
      return
    }
    let dlgOpenFile = NSOpenPanel()
    dlgOpenFile.showsResizeIndicator = true
    dlgOpenFile.showsHiddenFiles = true
    dlgOpenFile.canChooseFiles = true
    dlgOpenFile.canChooseDirectories = false
    dlgOpenFile.allowsMultipleSelection = false

    if #available(macOS 11.0, *) {
      dlgOpenFile.allowedContentTypes = ["cin2", "vcin", "cin"]
        .compactMap { .init(filenameExtension: $0) }
    } else {
      dlgOpenFile.allowedFileTypes = ["cin2", "vcin", "cin"]
    }
    dlgOpenFile.allowsOtherFileTypes = true

    let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
      PrefMgr.shared.cassettePath.expandingTildeInPath
    )

    let window = CtlSettingsCocoa.shared?.window
    dlgOpenFile.beginSheetModal(at: window) { result in
      if result == NSApplication.ModalResponse.OK {
        guard let url = dlgOpenFile.url else { return }
        if LMMgr.checkCassettePathValidity(url.path) {
          PrefMgr.shared.cassettePath = url.path
          LMMgr.loadCassetteData()
          BookmarkManager.shared.saveBookmark(for: url)
          self.pctCassetteFilePath.url = url
        } else {
          IMEApp.buzz()
          if !bolPreviousPathValidity {
            LMMgr.resetCassettePath()
          }
          return
        }
      } else {
        if !bolPreviousPathValidity {
          LMMgr.resetCassettePath()
        }
        return
      }
    }
  }
}

// MARK: - Preview

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Cassette()
}
