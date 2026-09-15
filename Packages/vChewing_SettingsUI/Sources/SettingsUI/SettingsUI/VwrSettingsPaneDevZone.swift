// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬，legacy 倉庫（＝本倉的「子集 ＋ Swift 5.10 Dialect」，砍掉了 SwiftUI）無對位模組可繼承；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

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
            "i18n:Settings.DevZoneWarning"
          )
        }
        Section {
          UserDef.kCheckAbusersOfSecureEventInputAPI.renderUI()
          UserDef.kUserPhrasesDatabaseBypassed.renderUI()
          UserDef.kAllowRescoringSingleKanjiCandidates.renderUI()
        } footer: {
          Text("i18n:Settings.OptionsMovedToOtherTabs".i18n)
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
          Button("i18n:Common.OK".i18n, role: .cancel) {}
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
      try mainSync {
        guard let data = UserDef.exportAsJSON() else {
          throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
      }
    }
  }

  // MARK: - VwrSettingsPaneDevZone_Previews

  @available(macOS 14, *)
  struct VwrSettingsPaneDevZone_Previews: PreviewProvider {
    static var previews: some View {
      VwrSettingsPaneDevZone()
    }
  }

#endif
