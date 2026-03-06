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

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }

    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.build(.horizontal, insets: .new(all: 0, left: 16, right: 16)) {
          "Warning: This page is for testing future features. \nFeatures listed here may not work as expected."
            .makeNSLabel(fixWidth: contentWidth)
          NSView()
        }
        NSTabView.build {
          NSTabView.TabPage(title: "Ａ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kSecurityHardenedCompositionBuffer.render(fixWidth: innerContentWidth)
              UserDef.kAlwaysUsePCBWithElectronBasedClients.render(fixWidth: innerContentWidth)
              UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients
                .render(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kCheckAbusersOfSecureEventInputAPI.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kUserPhrasesDatabaseBypassed.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kAllowRescoringSingleKanjiCandidates.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｃ") {
            NSStackView.buildSection(width: innerContentWidth) {
              NSStackView.build(.vertical) {
                NSStackView.build(.horizontal) {
                  "i18n:DevZone.JSONPrefsExchange.SectionTitle"
                    .makeNSLabel(fixWidth: innerContentWidth - 200)
                  NSView()
                  NSButton(
                    "i18n:DevZone.JSONPrefsExchange.Export",
                    target: self,
                    action: #selector(exportPrefsAsJSON(_:))
                  )
                  NSButton(
                    "i18n:DevZone.JSONPrefsExchange.Import",
                    target: self,
                    action: #selector(importPrefsFromJSON(_:))
                  )
                }
                "i18n:DevZone.JSONPrefsExchange.Description"
                  .makeNSLabel(descriptive: true, fixWidth: innerContentWidth)
              }
            }?.boxed()
            NSView()
          }
        }?.makeSimpleConstraint(.width, relation: .equal, value: tabContainerWidth)
        NSStackView.build(.horizontal, insets: .new(all: 0, left: 16, right: 16)) {
          "Some previous options are moved to other tabs."
            .makeNSLabel(descriptive: true, fixWidth: contentWidth)
          NSView()
        }
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    static func formatImportResult(_ result: UserDef.ImportResult) -> String {
      var lines = [String]()
      let successCount = result.successes.count
      let failureCount = result.failures.count
      lines.append(
        String(
          format: "i18n:DevZone.JSONPrefsExchange.ImportSummary".i18n,
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
        alert.addButton(withTitle: "OK".i18n)
        alert.beginSheetModal(at: CtlSettingsCocoa.shared?.window)
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
          alert.addButton(withTitle: "OK".i18n)
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
      dlgOpen.beginSheetModal(at: window) { result in
        guard result == .OK, let url = dlgOpen.url else { return }
        guard let data = try? Data(contentsOf: url) else {
          let alert = NSAlert()
          alert.messageText = "i18n:DevZone.JSONPrefsExchange.ImportResultTitle".i18n
          alert.informativeText = "i18n:DevZone.JSONPrefsExchange.ImportError.ReadFailure".i18n
          alert.alertStyle = .warning
          alert.addButton(withTitle: "OK".i18n)
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
        alert.addButton(withTitle: "OK".i18n)
        alert.beginSheetModal(at: window)
      }
    }
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.DevZone()
}
