// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為雙拼方案編輯器之 SwiftUI 版（macOS 14+）。
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition；
// 5.10 路徑之對位實作為 `SettingsCocoa/DualpinSchemaEditorCocoa.swift`。
#if compiler(>=6.2)

  import Arimitsu
  import SwiftUI
  import UniformTypeIdentifiers

  // MARK: - DualpinSchemaDocument

  /// 匯出方案檔用之 `FileDocument` 包裝。
  @available(macOS 14, *)
  internal struct DualpinSchemaDocument: FileDocument {
    // MARK: Lifecycle

    internal init(text: String) {
      self.text = text
    }

    internal init(configuration: ReadConfiguration) throws {
      guard let data = configuration.file.regularFileContents,
            let text = String(data: data, encoding: .utf8)
      else { throw CocoaError(.fileReadCorruptFile) }
      self.text = text
    }

    // MARK: Internal

    internal static var readableContentTypes: [UTType] { [.json] }

    internal var text: String

    internal func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
      guard let data = text.data(using: .utf8) else {
        throw CocoaError(.fileWriteInapplicableStringEncoding)
      }
      return FileWrapper(regularFileWithContents: data)
    }
  }

  // MARK: - VwrDualpinSchemaEditor

  /// 雙拼方案編輯器（SwiftUI 版）。
  ///
  /// 始終展開，落於「鍵盤設定 → 雙拼方案」Section 之底端；只消費引擎之公開面
  /// （解碼、校驗、標題）與 `DualpinSchemaStore` 之序列化，不自行實作檢證邏輯。
  @available(macOS 14, *)
  public struct VwrDualpinSchemaEditor: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
      // 校驗成本為整份詞幹表，故每輪重繪只算一次、逐區傳遞。
      let report = draft.validateReport()
      return VStack(alignment: .leading, spacing: NSFont.systemFontSize / 2) {
        identityRows
        Divider()
        templateRow
        Divider()
        nullOnsetRows
        Divider()
        keyboardGrid(report)
        Divider()
        assignmentRows
        Divider()
        validationRows(report)
        Divider()
        actionRow(report)
        if let statusText {
          Divider()
          Text(statusText)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .onAppear(perform: loadDraftFromPreferences)
      .confirmationDialog(
        DualpinEditorText.saveAsBuiltinCopy,
        isPresented: $isConfirmingTemplate,
        titleVisibility: .visible
      ) {
        Button(DualpinEditorText.saveAsBuiltinCopy) { applyPendingTemplate() }
        Button("i18n:Common.Cancel".i18n, role: .cancel) {
          pendingTemplate = nil
          selectedTemplate = appliedTemplate
        }
      }
      .fileExporter(
        isPresented: $isShowingExporter,
        document: DualpinSchemaDocument(text: exportedText),
        contentType: .json,
        defaultFilename: DualpinEditorText.suggestedFileName(rawTitle: draft.rawTitle)
      ) { result in
        switch result {
        case let .success(url):
          statusText = DualpinEditorText.exportSucceededText(destination: url.path)
        case let .failure(error):
          statusText = DualpinEditorText.exportFailedText(reason: error.localizedDescription)
        }
      }
    }

    // MARK: Private

    @AppStorage(
      wrappedValue: UserDef.kDualpinSchemaJSON.stringDefaultValue,
      UserDef.kDualpinSchemaJSON.rawValue
    )
    private var dualpinSchemaJSON: String

    @State
    private var draft = DualpinSchemaDraft.make(template: .blank, current: nil)
    @State
    private var fixedNullOnsetKey: Character = "o"
    @State
    private var appliedTemplate: DualpinSchemaTemplate = .blank
    @State
    private var selectedTemplate: DualpinSchemaTemplate = .blank
    @State
    private var pendingTemplate: DualpinSchemaTemplate?
    @State
    private var isConfirmingTemplate = false
    @State
    private var selectedInitialSyllable = ""
    @State
    private var selectedFinalSyllable = ""
    @State
    private var statusText: String?
    @State
    private var isShowingValidationDetails = false
    @State
    private var isShowingExporter = false
    @State
    private var exportedText = ""
  }

  // MARK: - 版面

  @available(macOS 14, *)
  extension VwrDualpinSchemaEditor {
    @ViewBuilder
    private var identityRows: some View {
      HStack(alignment: .firstTextBaseline) {
        Text(DualpinEditorText.name)
          .containerRelativeFrame(.horizontal, alignment: .leading) { value, _ in
            value * 0.4
          }
        TextField(
          "".description,
          text: Binding(
            get: { draft.rawTitle },
            set: { draft.updateTitle(String($0.prefix(32))) }
          ),
          prompt: Text(verbatim: DualpinEditorText.namePlaceholder)
        )
        .multilineTextAlignment(.trailing)
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
      }
      Divider()
      HStack(alignment: .firstTextBaseline) {
        Text(DualpinEditorText.rawID)
          .containerRelativeFrame(.horizontal, alignment: .leading) { value, _ in
            value * 0.4
          }
        TextField(
          "dualPin.User.Custom",
          text: Binding(get: { draft.rawID }, set: { draft.updateRawID($0) })
        )
        .multilineTextAlignment(.trailing)
        .textFieldStyle(.roundedBorder)
        .font(.body.monospaced())
        .labelsHidden()
      }
      Text(DualpinEditorText.rawIDHelp)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var templateRow: some View {
      HStack(alignment: .firstTextBaseline) {
        Text(DualpinEditorText.template)
          .containerRelativeFrame(.horizontal, alignment: .leading) { value, _ in
            value * 0.6
          }
        Picker("".description, selection: $selectedTemplate) {
          ForEach(DualpinSchemaTemplate.allCases, id: \.self) { template in
            Text(DualpinEditorText.templateName(template)).tag(template)
          }
        }
        .labelsHidden()
        .onChange(of: selectedTemplate) { _, newValue in
          guard newValue != appliedTemplate else { return }
          pendingTemplate = newValue
          isConfirmingTemplate = true
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }

    @ViewBuilder
    private var nullOnsetRows: some View {
      HStack(alignment: .firstTextBaseline) {
        Text(DualpinEditorText.nullOnsetMode)
          .containerRelativeFrame(.horizontal, alignment: .leading) { value, _ in
            value * 0.6
          }
        Picker("".description, selection: nullOnsetModeBinding) {
          ForEach(DualpinNullOnsetMode.allCases, id: \.self) { mode in
            Text(DualpinEditorText.nullOnsetModeName(mode)).tag(mode)
          }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
      if draft.nullOnset.fixedKeyCharacter != nil {
        Divider()
        HStack(alignment: .firstTextBaseline) {
          Text(DualpinEditorText.nullOnsetKey)
            .containerRelativeFrame(.horizontal, alignment: .leading) { value, _ in
              value * 0.6
            }
          Picker("".description, selection: nullOnsetKeyBinding) {
            ForEach(DualpinEditorKeyboard.allKeys, id: \.self) { key in
              Text(DualpinEditorText.keyLabel(key)).tag(key)
            }
          }
          .labelsHidden()
          .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
    }

    @ViewBuilder
    private func keyboardGrid(_ report: DualpinValidationReport) -> some View {
      let annotations = Dictionary(
        uniqueKeysWithValues: draft.keyAnnotations(report: report).map { ($0.key, $0) }
      )
      Text(DualpinEditorText.keyboardPreview).font(.callout)
      VStack(alignment: .center, spacing: 2) {
        ForEach(0 ..< DualpinEditorKeyboard.rows.count, id: \.self) { rowIndex in
          HStack(spacing: 2) {
            ForEach(DualpinEditorKeyboard.rows[rowIndex], id: \.self) { key in
              if let annotation = annotations[key] {
                DualpinKeyCell(annotation: annotation)
              }
            }
          }
        }
      }
      .padding(.vertical, 2)
      .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var assignmentRows: some View {
      Grid {
        GridRow {
          Text("".description)
            .font(.caption)
          Text(DualpinEditorText.assignmentSyllable)
            .font(.caption)
            .containerRelativeFrame(.horizontal, alignment: .trailing) { value, _ in
              value * 0.2
            }
          Text(DualpinEditorText.assignmentKey)
            .font(.caption)
            .containerRelativeFrame(.horizontal, alignment: .trailing) { value, _ in
              value * 0.2
            }
          Text("".description)
            .font(.caption)
            .containerRelativeFrame(.horizontal, alignment: .leading) { value, _ in
              value * 0.3
            }
        }
        ForEach(DualpinEditorTable.allCases, id: \.self) { table in
          GridRow {
            Text(DualpinEditorText.tableName(table))
            Picker(DualpinEditorText.assignmentSyllable, selection: syllableBinding(table)) {
              ForEach(draft.syllables(in: table), id: \.self) { syllable in
                Text(syllable).tag(syllable)
              }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .trailing)
            HStack {
              Image(systemName: "arrow.right")
              Picker(DualpinEditorText.assignmentKey, selection: keyBinding(table)) {
                ForEach(DualpinEditorKeyboard.allKeys, id: \.self) { key in
                  Text(DualpinEditorText.keyLabel(key)).tag(key)
                }
              }
              .labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            let occupiedHintStr = occupiedHint(table)
            if !occupiedHintStr.isEmpty {
              Text(occupiedHintStr)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            } else {
              Text("".description)
            }
          }
        }
      }
    }

    @ViewBuilder
    private func validationRows(_ report: DualpinValidationReport) -> some View {
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .top) {
          // 採顯式按鈕風格：整顆按鈕皆為點擊區，不以裸三角形作唯一熱區。
          Button {
            isShowingValidationDetails.toggle()
          } label: {
            Label(
              DualpinEditorText.validationAdvanced,
              systemImage: isShowingValidationDetails ? "chevron.down" : "chevron.right"
            )
          }
          .buttonStyle(.bordered)
          VStack(alignment: .leading, spacing: 2) {
            Text(DualpinEditorText.validationSummary(report))
              .foregroundStyle(report.isUsable ? Color.secondary : Color.red)
              .fixedSize(horizontal: false, vertical: true)
            Text(DualpinEditorText.codableSummary(report))
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        if isShowingValidationDetails {
          GroupBox(label: Text(DualpinEditorText.validationDetails).font(.caption)) {
            VStack(alignment: .leading, spacing: 2) {
              ForEach(report.errors + report.warnings, id: \.self) { issue in
                Text(DualpinEditorText.issueLine(issue))
                  .font(.caption.monospaced())
                  .foregroundStyle(issue.level == .error ? Color.red : Color.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Text(DualpinEditorText.validationDIPENote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
          }
          // 明細盒一律填滿本編輯器之容器寬。
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }

    @ViewBuilder
    private func actionRow(_ report: DualpinValidationReport) -> some View {
      HStack {
        Button(DualpinEditorText.save) { saveDraft() }
          .disabled(!report.isUsable)
        Button(DualpinEditorText.export) { exportDraft() }
          .disabled(!report.isUsable)
        Button(DualpinEditorText.revert) { loadDraftFromPreferences() }
        Spacer()
      }
    }
  }

  // MARK: - 綁定與動作

  @available(macOS 14, *)
  extension VwrDualpinSchemaEditor {
    private var nullOnsetModeBinding: Binding<DualpinNullOnsetMode> {
      Binding(
        get: { DualpinNullOnsetMode(draft.nullOnset) },
        set: { newMode in
          if case let .fixedKey(key) = draft.nullOnset { fixedNullOnsetKey = key }
          draft.updateNullOnset(newMode.policy(fixedKey: fixedNullOnsetKey))
        }
      )
    }

    private var nullOnsetKeyBinding: Binding<Character> {
      Binding(
        get: { draft.nullOnset.fixedKeyCharacter ?? fixedNullOnsetKey },
        set: { newKey in
          fixedNullOnsetKey = newKey
          draft.updateNullOnset(.fixedKey(newKey))
        }
      )
    }

    private func syllableBinding(_ table: DualpinEditorTable) -> Binding<String> {
      Binding(
        get: {
          let stored = table == .initials ? selectedInitialSyllable : selectedFinalSyllable
          if draft.syllables(in: table).contains(stored) { return stored }
          return draft.syllables(in: table).first ?? ""
        },
        set: { newValue in
          if table == .initials {
            selectedInitialSyllable = newValue
          } else {
            selectedFinalSyllable = newValue
          }
        }
      )
    }

    /// 該表當前音節之按鍵。設值即即時改配（與微軟拼音之預覽格同款互動）。
    private func keyBinding(_ table: DualpinEditorTable) -> Binding<Character> {
      Binding(
        get: {
          let syllable = syllableBinding(table).wrappedValue
          return draft.key(ofSyllable: syllable, in: table) ?? "z"
        },
        set: { newKey in
          let syllable = syllableBinding(table).wrappedValue
          draft.assign(key: newKey, toSyllable: syllable, in: table)
        }
      )
    }

    /// 當前所選按鍵之佔用情形；無人共用時為空字串。
    private func occupiedHint(_ table: DualpinEditorTable) -> String {
      let syllable = syllableBinding(table).wrappedValue
      guard let key = draft.key(ofSyllable: syllable, in: table) else { return "" }
      let others = draft.syllables(atKey: key, in: table).filter { $0 != syllable }
      guard !others.isEmpty else { return "" }
      return String(
        format: "i18n:Settings.DualpinEditor.Assignment.KeyTaken:%@".i18n,
        arguments: [others.joined(separator: "／")]
      )
    }

    private func applyPendingTemplate() {
      defer { pendingTemplate = nil }
      guard let template = pendingTemplate else { return }
      draft = DualpinSchemaDraft.make(
        template: template,
        current: DualpinSchemaStore.currentParser,
        schemaURLString: DualpinSchemaStore.currentSchemaURLString
      )
      appliedTemplate = template
      resetSelection()
    }

    private func loadDraftFromPreferences() {
      let current = DualpinSchemaStore.currentParser
      let template: DualpinSchemaTemplate = current == nil ? .blank : .current
      draft = DualpinSchemaDraft.make(
        template: template,
        current: current,
        schemaURLString: DualpinSchemaStore.currentSchemaURLString
      )
      appliedTemplate = template
      resetSelection()
      statusText = nil
    }

    private func resetSelection() {
      fixedNullOnsetKey = draft.nullOnset.fixedKeyCharacter ?? "o"
      selectedInitialSyllable = draft.syllables(in: .initials).first ?? ""
      selectedFinalSyllable = draft.syllables(in: .finals).first ?? ""
      selectedTemplate = appliedTemplate
    }

    private func saveDraft() {
      let outcome = DualpinSchemaStore.save(draft.parser, schemaURLString: draft.schemaURLString)
      statusText = DualpinEditorText.statusText(outcome)
      if case .success = outcome, let current = DualpinSchemaStore.currentParser {
        draft = DualpinSchemaDraft(parser: current, schemaURLString: DualpinSchemaStore.currentSchemaURLString)
        appliedTemplate = .current
        resetSelection()
      }
    }

    private func exportDraft() {
      guard let text = DualpinSchemaStore.serialize(
        draft.parser,
        schemaURLString: draft.schemaURLString
      )
      else { return }
      exportedText = text
      isShowingExporter = true
    }
  }

  // MARK: - DualpinKeyCell

  @available(macOS 14, *)
  internal struct DualpinKeyCell: View {
    // MARK: Internal

    internal let annotation: DualpinEditorKeyAnnotation

    internal var body: some View {
      VStack(spacing: 0) {
        ForEach(annotation.initialSyllables, id: \.self) { syllable in
          Text(syllable)
            .font(.system(size: 9, weight: .semibold))
        }
        ForEach(annotation.finalSyllables, id: \.self) { syllable in
          Text(syllable)
            .font(.system(size: 9))
        }
        if annotation.initialSyllables.isEmpty, annotation.finalSyllables.isEmpty {
          Text("—")
            .font(.system(size: 9))
        }
      }
      .frame(width: 46, height: 58)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 3))
      .overlay(RoundedRectangle(cornerRadius: 3).stroke(borderColor, lineWidth: 1))
      .overlay(alignment: .topLeading) {
        Text(DualpinEditorText.keyLabel(annotation.key))
          .font(.system(size: 8))
          .foregroundStyle(.tertiary)
          .padding(.leading, 2)
      }
      .accessibilityLabel(Text(DualpinEditorText.keyLabel(annotation.key)))
    }

    // MARK: Private

    private var background: Color {
      if annotation.isReservedInUse { return Color.red.opacity(0.12) }
      if annotation.isUnusedTableKey { return Color.orange.opacity(0.10) }
      return annotation.isUsedByAnyCode ? Color.secondary.opacity(0.08) : Color.clear
    }

    private var borderColor: Color {
      annotation.isReservedInUse ? .red.opacity(0.6) : .secondary.opacity(0.35)
    }
  }

  // MARK: - VwrSettingsPanePhrases_Previews

  @available(macOS 14, *)
  struct VwrDualpinSchemaEditor_Previews: PreviewProvider {
    static var previews: some View {
      VwrDualpinSchemaEditor()
        .padding()
    }
  }

#endif
