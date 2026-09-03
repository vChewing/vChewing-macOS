// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import UniformTypeIdentifiers

extension SettingsPanesCocoa {
  public final class DevZone: NSViewController {
    // MARK: Public

    override public func loadView() {
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    }

    // MARK: Internal

    let dragRetrieverJSONImport: NSFileDragRetrieverButton = .init()

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }

    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.build(.horizontal, insets: .new(all: 0, left: 16, right: 16)) {
          "i18n:Settings.DevZoneWarning"
            .makeNSLabel(fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kSecurityHardenedCompositionBuffer.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabDevZone
          )
          UserDef.kAlwaysUsePCBWithElectronBasedClients.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabDevZone
          )
          UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients
            .renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabDevZone
            )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kCheckAbusersOfSecureEventInputAPI.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabDevZone
          )
          UserDef.kUserPhrasesDatabaseBypassed.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabDevZone
          )
          UserDef.kAllowRescoringSingleKanjiCandidates.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabDevZone
          )
        }?.boxed()
        NSStackView.build(.horizontal, insets: .new(all: 0, left: 16, right: 16)) {
          "i18n:Settings.OptionsMovedToOtherTabs"
            .makeNSLabel(descriptive: true, fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(width: contentWidth) {
          NSStackView.build(.vertical) {
            NSStackView.build(.horizontal) {
              "i18n:DevZone.JSONPrefsExchange.SectionTitle"
                .makeNSLabel(fixWidth: contentWidth - 200)
              NSView()
              NSButton(
                "i18n:DevZone.JSONPrefsExchange.Export",
                target: self,
                action: #selector(exportPrefsAsJSON(_:))
              )
              jsonImportDragButton()
            }
            "i18n:DevZone.JSONPrefsExchange.Description"
              .makeNSLabel(descriptive: true, fixWidth: contentWidth)
          }
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    static func formatImportResult(_ result: UserDef.ImportResult) -> String {
      var lines = [String]()
      let successCount = result.successes.count
      let failureCount = result.failures.count
      lines.append(
        String(
          format: "i18n:DevZone.JSONPrefsExchange.ImportSummary:%d%d".i18n,
          successCount, failureCount
        )
      )
      if !result.failures.isEmpty {
        for failure in result.failures {
          lines.append("⚠ \(failure.key): \(failure.reason)")
        }
      }
      return lines.joined(separator: "\n")
    }

    func jsonImportDragButton() -> NSFileDragRetrieverButton {
      dragRetrieverJSONImport.title = "i18n:DevZone.JSONPrefsExchange.Import".i18n
      dragRetrieverJSONImport.target = self
      dragRetrieverJSONImport.allowedTypes = ["json"]
      dragRetrieverJSONImport.action = #selector(importPrefsFromJSON(_:))
      dragRetrieverJSONImport.postDragHandler = { [weak self] url in
        self?.importPrefsFromJSONFile(at: url)
      }
      return dragRetrieverJSONImport
    }

    @IBAction
    func sanityCheck(_: NSControl) {}

    @objc
    func exportPrefsAsJSON(_: Any) {
      guard let data = UserDef.exportAsJSON(),
            let jsonString = String(data: data, encoding: .utf8)
      else {
        let alert = NSAlert()
        alert.messageText = "i18n:DevZone.JSONPrefsExchange.ExportError".i18n
        alert.alertStyle = .warning
        alert.addButton(withTitle: "i18n:Common.OK".i18n)
        alert.beginSheetModal(at: CtlSettingsCocoa.shared?.window)
        return
      }
      guard #available(macOS 10.13, *) else {
        exportPrefsAsJSONToFileDump(jsonString)
        return
      }
      let dlgSave = NSSavePanel()
      dlgSave.title = "i18n:DevZone.JSONPrefsExchange.Export".i18n
      dlgSave.nameFieldStringValue = "vChewing_Preferences.json"
      if #available(macOS 11, *) {
        dlgSave.allowedContentTypes = [.json]
      } else {
        dlgSave.allowedFileTypes = ["json"]
      }
      let window = CtlSettingsCocoa.shared?.window
      dlgSave.beginSheetModal(at: window) { result in
        guard result == .OK, let url = dlgSave.url else { return }
        do {
          try jsonString.write(to: url, atomically: true, encoding: .utf8)
        } catch {
          let alert = NSAlert()
          alert.messageText = "i18n:DevZone.JSONPrefsExchange.ExportError".i18n
          alert.informativeText = error.localizedDescription
          alert.alertStyle = .warning
          alert.addButton(withTitle: "i18n:Common.OK".i18n)
          alert.beginSheetModal(at: window)
        }
      }
    }

    @objc
    func importPrefsFromJSON(_: Any) {
      guard #available(macOS 10.13, *) else {
        SettingsPanesCocoa.warnAboutComDlg32Inavailability()
        return
      }
      let dlgOpen = NSOpenPanel()
      dlgOpen.title = "i18n:DevZone.JSONPrefsExchange.Import".i18n
      if #available(macOS 11, *) {
        dlgOpen.allowedContentTypes = [.json]
      } else {
        dlgOpen.allowedFileTypes = ["json"]
      }
      dlgOpen.allowsMultipleSelection = false
      let window = CtlSettingsCocoa.shared?.window
      dlgOpen.beginSheetModal(at: window) { [weak self] result in
        guard result == .OK, let url = dlgOpen.url else { return }
        self?.importPrefsFromJSONFile(at: url)
      }
    }

    func importPrefsFromJSONFile(at url: URL) {
      let window = CtlSettingsCocoa.shared?.window
      guard let data = try? Data(contentsOf: url) else {
        let alert = NSAlert()
        alert.messageText = "i18n:DevZone.JSONPrefsExchange.ImportResultTitle".i18n
        alert.informativeText = "i18n:DevZone.JSONPrefsExchange.ImportError.ReadFailure".i18n
        alert.alertStyle = .warning
        alert.addButton(withTitle: "i18n:Common.OK".i18n)
        alert.beginSheetModal(at: window)
        return
      }
      let importResult = UserDef.importFromJSON(data)
      PrefMgr.shared.fixOddPreferencesCore()
      let message = Self.formatImportResult(importResult)
      let alert = NSAlert()
      alert.messageText = "i18n:DevZone.JSONPrefsExchange.ImportResultTitle".i18n
      alert.informativeText = message
      alert.alertStyle = importResult.failures.isEmpty ? .informational : .warning
      alert.addButton(withTitle: "i18n:Common.OK".i18n)
      alert.beginSheetModal(at: window)
    }

    // MARK: Private

    // MARK: - macOS 10.12 與更早版本（ComDlg32 不可用）的匯出替代方案。

    // 此段一律不使用 NSOpenPanel / NSSavePanel。

    private func exportPrefsAsJSONToFileDump(_ jsonString: String) {
      do {
        let appSupportURL = FileManager.default.urls(
          for: .applicationSupportDirectory,
          in: .userDomainMask
        )[0]
        let dumpDirURL = appSupportURL.appendingPathComponent("fileDump")
        try FileManager.default.createDirectory(
          at: dumpDirURL,
          withIntermediateDirectories: true
        )
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "ddMMyy-HHmmss"
        let stamp = formatter.string(from: Date())
        let destURL = dumpDirURL.appendingPathComponent(
          "vChewing_Preferences_\(stamp).json"
        )
        try jsonString.write(to: destURL, atomically: true, encoding: .utf8)
        let window = CtlSettingsCocoa.shared?.window
        let alert = NSAlert()
        alert.messageText = "i18n:DevZone.JSONPrefsExchange.ExportDumpedTitle".i18n
        alert.informativeText = String(
          format: "i18n:DevZone.JSONPrefsExchange.ExportDumpedMessage:%@".i18n,
          destURL.path
        )
        alert.addButton(withTitle: "i18n:Common.OK".i18n)
        alert.beginSheetModal(at: window) { _ in
          NSWorkspace.shared.activateFileViewerSelecting([destURL])
        }
      } catch {
        let alert = NSAlert()
        alert.messageText = "i18n:DevZone.JSONPrefsExchange.ExportError".i18n
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "i18n:Common.OK".i18n)
        alert.beginSheetModal(at: CtlSettingsCocoa.shared?.window)
      }
    }
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.DevZone()
}
