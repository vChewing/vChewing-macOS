// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - VwrSettingsPaneServices

@available(macOS 14, *)
public struct VwrSettingsPaneServices: View {
  // MARK: Public

  public var body: some View {
    GroupBox {
      VStack(spacing: 10) {
        HStack {
          Button { isShowingAddSheet = true } label: {
            Image(systemName: "plus")
              .contentShape(.rect)
              .help("Add Service".i18n)
          }
          .sheet(isPresented: $isShowingAddSheet) {
            AddServiceSheetView { newRawText in
              let newServices = newRawText
                .components(separatedBy: .newlines)
                .parseIntoCandidateTextServiceStack()
              guard !newServices.isEmpty else { return }
              var current = PrefMgr.shared.candidateServiceMenuContents
                .parseIntoCandidateTextServiceStack()
              current.append(contentsOf: newServices)
              PrefMgr.shared.candidateServiceMenuContents = current.rawRepresentation
              reloadList()
            }
          }
          Button { removeServiceClicked() } label: {
            Image(systemName: "minus")
              .contentShape(.rect)
              .help("Remove Selected".i18n)
          }
          .disabled(selectedIDs.isEmpty)
          Spacer()
          Button {
            moveSelectedServices(direction: .up)
          } label: {
            Image(systemName: "chevron.up")
              .contentShape(.rect)
          }
          .disabled(!canMoveUp)
          .help("Move Up".i18n)
          Button {
            moveSelectedServices(direction: .down)
          } label: {
            Image(systemName: "chevron.down")
              .contentShape(.rect)
              .help("Move Down".i18n)
          }
          .disabled(!canMoveDown)
          Spacer()
          Button { copyAllToClipboard() } label: {
            Image(systemName: "doc.on.clipboard")
              .contentShape(.rect)
              .help("Copy All to Clipboard".i18n)
          }
          Button { isShowingInstructions = true } label: {
            Image(systemName: "questionmark.circle")
              .contentShape(.rect)
              .help("How to Fill".i18n)
          }
          .alert(
            "How to Fill".i18n,
            isPresented: $isShowingInstructions
          ) {
            Button("OK".i18n, role: .cancel) {}
          } message: {
            Text("i18n:CandidateServiceMenuEditor.formatGuide".i18n)
          }
          Button { isShowingResetConfirmation = true } label: {
            Image(systemName: "arrow.counterclockwise")
              .contentShape(.rect)
              .help("Reset Default".i18n)
          }
          .confirmationDialog(
            "Reset Default".i18n,
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
          ) {
            Button("Reset Default".i18n, role: .destructive) {
              PrefMgr.shared.candidateServiceMenuContents = UserDef.defaultValue4CandidateServiceMenuContents
              reloadList()
            }
            Button("Cancel".i18n, role: .cancel) {}
          }
        }
        .controlSize(.small)
        Table(servicesList, selection: $selectedIDs) {
          TableColumn("i18n:CandidateServiceMenuEditor.table.field.MenuTitle".i18n) { service in
            Text(service.key)
          }.width(min: 100, ideal: 110, max: 120)
          TableColumn("i18n:CandidateServiceMenuEditor.table.field.Value".i18n) { service in
            Text(service.definedValue)
          }.width(min: 100, ideal: 300)
        }
        .tableStyle(.bordered)
        .frame(minHeight: 200)
        .fontWidth(.condensed)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
          importServicesFromDroppedFiles(providers: providers)
        }
        Text("i18n:CandidateServiceMenuEditor.description".i18n)
          .settingsDescription()
      }
      .padding(4)
    }
    .padding()
    .frame(
      minWidth: CtlSettingsUI.formWidth,
      maxHeight: CtlSettingsUI.contentMaxHeight
    )
    .onAppear { reloadList() }
  }

  // MARK: Private

  private enum MoveDirection { case up, down }

  // MARK: - IdentifiableCandidateTextService

  private struct IdentifiableCandidateTextService: Identifiable {
    // MARK: Lifecycle

    init(index: Int, service: CandidateTextService) {
      self.id = "\(index)-\(service.key)-\(service.definedValue)"
      self.service = service
    }

    // MARK: Internal

    let id: String
    let service: CandidateTextService

    var key: String { service.key }
    var definedValue: String { service.definedValue }
  }

  @State
  private var servicesList: [IdentifiableCandidateTextService] = []
  @State
  private var selectedIDs: Set<String> = []
  @State
  private var isShowingAddSheet = false
  @State
  private var isShowingInstructions = false
  @State
  private var isShowingResetConfirmation = false

  private var canMoveUp: Bool {
    guard !selectedIDs.isEmpty else { return false }
    let selectedIndices = servicesList.enumerated().compactMap { offset, item in
      selectedIDs.contains(item.id) ? offset : nil
    }
    return selectedIndices.min() ?? 0 > 0
  }

  private var canMoveDown: Bool {
    guard !selectedIDs.isEmpty else { return false }
    let selectedIndices = servicesList.enumerated().compactMap { offset, item in
      selectedIDs.contains(item.id) ? offset : nil
    }
    return (selectedIndices.max() ?? servicesList.count) < servicesList.count - 1
  }

  nonisolated private static func parseFileURL(from item: NSSecureCoding?) -> URL? {
    if let data = item as? Data {
      return URL(dataRepresentation: data, relativeTo: nil)
    }
    if let url = item as? URL {
      return url
    }
    if let url = item as? NSURL {
      return url as URL
    }
    if let string = item as? String {
      return URL(string: string)
    }
    return nil
  }

  private func reloadList() {
    servicesList = PrefMgr.shared.candidateServiceMenuContents
      .parseIntoCandidateTextServiceStack()
      .enumerated()
      .map { IdentifiableCandidateTextService(index: $0.offset, service: $0.element) }
  }

  private func moveSelectedServices(direction: MoveDirection) {
    var current = PrefMgr.shared.candidateServiceMenuContents
      .parseIntoCandidateTextServiceStack()
    let selectedIndices = servicesList.enumerated().compactMap { offset, item in
      selectedIDs.contains(item.id) ? offset : nil
    }.sorted()
    guard !selectedIndices.isEmpty else { return }
    switch direction {
    case .up:
      guard let first = selectedIndices.first, first > 0 else { return }
      for index in selectedIndices {
        current.swapAt(index, index - 1)
      }
    case .down:
      guard let last = selectedIndices.last, last < current.count - 1 else { return }
      for index in selectedIndices.reversed() {
        current.swapAt(index, index + 1)
      }
    }
    PrefMgr.shared.candidateServiceMenuContents = current.rawRepresentation
    // 記住選取狀態。
    let newSelectedIDs: Set<String> = Set(selectedIndices.map { index in
      let newIndex = direction == .up ? index - 1 : index + 1
      let svc = current[newIndex]
      return "\(newIndex)-\(svc.key)-\(svc.definedValue)"
    })
    reloadList()
    selectedIDs = newSelectedIDs
  }

  private func removeServiceClicked() {
    var current = PrefMgr.shared.candidateServiceMenuContents
      .parseIntoCandidateTextServiceStack()
    let indicesToRemove = servicesList.enumerated().compactMap { offset, item in
      selectedIDs.contains(item.id) ? offset : nil
    }
    for index in indicesToRemove.sorted().reversed() {
      guard index < current.count else { continue }
      current.remove(at: index)
    }
    PrefMgr.shared.candidateServiceMenuContents = current.rawRepresentation
    selectedIDs.removeAll()
    reloadList()
  }

  private func copyAllToClipboard() {
    let current = PrefMgr.shared.candidateServiceMenuContents
      .parseIntoCandidateTextServiceStack()
    var resultArrayLines = [String]()
    current.forEach { currentService in
      resultArrayLines.append("\(currentService.key)\t\(currentService.definedValue)")
    }
    let result = resultArrayLines.joined(separator: "\n").appending("\n")
    NSPasteboard.general.declareTypes([.string], owner: nil)
    NSPasteboard.general.setString(result, forType: .string)
  }

  private func importServicesFromDroppedFiles(providers: [NSItemProvider]) -> Bool {
    let acceptableProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }
    guard !acceptableProviders.isEmpty else { return false }
    acceptableProviders.forEach { provider in
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
        item, _ in
        guard let droppedURL = Self.parseFileURL(from: item) else { return }
        guard let string = try? String(contentsOf: droppedURL) else { return }
        let importedServices = string.components(separatedBy: .newlines)
          .parseIntoCandidateTextServiceStack()
        guard !importedServices.isEmpty else { return }
        DispatchQueue.main.async {
          var current = PrefMgr.shared.candidateServiceMenuContents
            .parseIntoCandidateTextServiceStack()
          current.append(contentsOf: importedServices)
          PrefMgr.shared.candidateServiceMenuContents = current.rawRepresentation
          reloadList()
        }
      }
    }
    return true
  }
}

// MARK: - AddServiceSheetView

@available(macOS 14, *)
private struct AddServiceSheetView: View {
  @Environment(\.dismiss)
  private var dismiss
  @State
  private var inputText: String = ""

  var onCommit: (String) -> ()

  var body: some View {
    VStack(spacing: 12) {
      Text("i18n:CandidateServiceMenuEditor.prompt".i18n)
        .font(.headline)
      Text("i18n:CandidateServiceMenuEditor.howToGetGuide".i18n)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      TextEditor(text: $inputText)
        .font(.system(.body, design: .monospaced))
        .frame(minWidth: 480, minHeight: 180)
        .border(Color.secondary.opacity(0.3))
      Text("i18n:CandidateServiceMenuEditor.formatGuide".i18n)
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("Cancel".i18n, role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("OK".i18n) {
          onCommit(inputText)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding()
    .frame(minWidth: 540)
  }
}

// MARK: - VwrSettingsPaneServices_Previews

@available(macOS 14, *)
struct VwrSettingsPaneServices_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneServices()
  }
}
