// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - VwrSettingsPaneDevZone

@available(macOS 14, *)
public struct VwrSettingsPaneDevZone: View {
  // MARK: Public

  // MARK: - Main View

  public var body: some View {
    Form {
      Section {
        UserDef.kSecurityHardenedCompositionBuffer.renderUI()
        UserDef.kAlwaysUsePCBWithElectronBasedClients.renderUI()
        UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients.renderUI()
      } header: {
        Text(
          "Warning: This page is for testing future features. \nFeatures listed here may not work as expected."
        )
      }
      Section {
        UserDef.kCheckAbusersOfSecureEventInputAPI.renderUI()
        UserDef.kUserPhrasesDatabaseBypassed.renderUI()
        UserDef.kAllowRescoringSingleKanjiCandidates.renderUI()
      } footer: {
        Text("Some previous options are moved to other tabs.".i18n)
          .settingsDescription()
      }
      Section("i18n:DevZone.JSONPrefsExchange.SectionTitle".i18n) {
        HStack {
          Button("i18n:DevZone.JSONPrefsExchange.Export".i18n) {
            isShowingExporter = true
          }
          Button("i18n:DevZone.JSONPrefsExchange.Import".i18n) {
            isShowingImporter = true
          }
        }
        Text("i18n:DevZone.JSONPrefsExchange.Description".i18n)
          .settingsDescription()
      }
    }.formStyled()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
      .fileExporter(
        isPresented: $isShowingExporter,
        document: UserDefJSONDocument(),
        contentType: .json,
        defaultFilename: "vChewing_Preferences.json"
      ) { _ in }
      .fileImporter(
        isPresented: $isShowingImporter,
        allowedContentTypes: [.json],
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case let .success(urls):
          guard let url = urls.first else { return }
          guard url.startAccessingSecurityScopedResource() else {
            importResultMessage = "i18n:DevZone.JSONPrefsExchange.ImportError.AccessDenied".i18n
            isShowingImportResult = true
            return
          }
          defer { url.stopAccessingSecurityScopedResource() }
          guard let data = try? Data(contentsOf: url) else {
            importResultMessage = "i18n:DevZone.JSONPrefsExchange.ImportError.ReadFailure".i18n
            isShowingImportResult = true
            return
          }
          let importResult = UserDef.importFromJSON(data)
          PrefMgr.shared.fixOddPreferencesCore()
          importResultMessage = Self.formatImportResult(importResult)
          isShowingImportResult = true
        case .failure:
          importResultMessage = "i18n:DevZone.JSONPrefsExchange.ImportError.ReadFailure".i18n
          isShowingImportResult = true
        }
      }
      .alert(
        "i18n:DevZone.JSONPrefsExchange.ImportResultTitle".i18n,
        isPresented: $isShowingImportResult
      ) {
        Button("OK".i18n, role: .cancel) {}
      } message: {
        Text(importResultMessage)
      }
  }

  // MARK: Internal

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

  // MARK: Private

  @State
  private var isShowingExporter = false
  @State
  private var isShowingImporter = false
  @State
  private var importResultMessage = ""
  @State
  private var isShowingImportResult = false
}

// MARK: - UserDefJSONDocument

@available(macOS 14, *)
struct UserDefJSONDocument: FileDocument {
  // MARK: Lifecycle

  init() {}

  init(configuration _: ReadConfiguration) throws {
    // Not used for import; import is handled via fileImporter.
  }

  // MARK: Internal

  static var readableContentTypes: [UTType] { [.json] }
  static var writableContentTypes: [UTType] { [.json] }

  func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
    guard let data = UserDef.exportAsJSON() else {
      throw CocoaError(.fileWriteUnknown)
    }
    return FileWrapper(regularFileWithContents: data)
  }
}

// MARK: - VwrSettingsPaneDevZone_Previews

@available(macOS 14, *)
struct VwrSettingsPaneDevZone_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneDevZone()
  }
}
