// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - VwrSettingsPaneClients

@available(macOS 14, *)
public struct VwrSettingsPaneClients: View {
  // MARK: Public

  public var body: some View {
    GroupBox {
      VStack(spacing: 10) {
        HStack(spacing: 6) {
          Button {
            isShowingAddSheet = true
          } label: {
            Label {
              Text("i18n:ClientManager.AddClient".i18n)
                .fontWidth(.condensed)
            } icon: {
              Image(systemName: "plus")
                .contentShape(.rect)
                .frame(height: 12)
            }
            .help("i18n:ClientManager.AddClient".i18n)
          }
          .sheet(isPresented: $isShowingAddSheet) {
            AddClientSheetView { bundleIDs, enableMitigation in
              bundleIDs.forEach { bundleID in
                var dict = PrefMgr.shared.clientsIMKTextInputIncapable
                dict[bundleID] = enableMitigation
                PrefMgr.shared.clientsIMKTextInputIncapable = dict
              }
              reloadList()
            }
          }
          Button {
            isShowingAppPicker = true
          } label: {
            Label {
              Text("i18n:Common.JustSelect".i18n + "…")
                .fontWidth(.condensed)
            } icon: {
              Image(systemName: "app.badge.checkmark")
                .contentShape(.rect)
                .frame(height: 12)
            }
            .help("i18n:Common.JustSelect".i18n)
          }
          .fileImporter(
            isPresented: $isShowingAppPicker,
            allowedContentTypes: [.applicationBundle],
            allowsMultipleSelection: true
          ) { result in
            switch result {
            case let .success(urls):
              for url in urls {
                guard let bundle = Bundle(url: url),
                      let identifier = bundle.bundleIdentifier else {
                  invalidBundleAlertPath = url.path
                  isShowingInvalidBundleAlert = true
                  continue
                }
                pendingBundleIdentifier = identifier
                isShowingMitigationPrompt = true
              }
            case .failure: break
            }
          }
          .alert(
            "i18n:ClientManager.EnablePopupCompositionBuffer".i18n,
            isPresented: $isShowingMitigationPrompt
          ) {
            Button("i18n:Common.Yes".i18n) {
              if let id = pendingBundleIdentifier {
                var dict = PrefMgr.shared.clientsIMKTextInputIncapable
                dict[id] = true
                PrefMgr.shared.clientsIMKTextInputIncapable = dict
                reloadList()
                pendingBundleIdentifier = nil
              }
            }
            Button("i18n:Common.No".i18n) {
              if let id = pendingBundleIdentifier {
                var dict = PrefMgr.shared.clientsIMKTextInputIncapable
                dict[id] = false
                PrefMgr.shared.clientsIMKTextInputIncapable = dict
                reloadList()
                pendingBundleIdentifier = nil
              }
            }
          } message: {
            Text(
              (pendingBundleIdentifier ?? "") + "\n\n"
                + "i18n:ClientManager.CompatibilityNote".i18n
            )
          }
          Spacer()
          Button {
            removeClientClicked()
          } label: {
            Image(systemName: "minus")
              .contentShape(.rect)
              .frame(height: 12)
          }
          .help("i18n:Common.RemoveSelected".i18n)
          .disabled(selectedIDs.isEmpty)
          .alert(
            "i18n:ErrorMessage.InvalidAppBundle".i18n,
            isPresented: $isShowingInvalidBundleAlert
          ) {
            Button("i18n:Common.OK".i18n, role: .cancel) {}
          } message: {
            Text((invalidBundleAlertPath ?? "") + "\n\n" + "i18n:Common.PleaseTryAgain".i18n)
          }
        }
        .controlSize(.small)
        Table(clientsList, selection: $selectedIDs) {
          TableColumn("") { client in
            Toggle(isOn: getToggleBinding(client: client)) {
              Text(client.bundleID)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
          }
        }
        .tableColumnHeaders(.hidden)
        .tableStyle(.bordered)
        .frame(minHeight: 200)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
          handleClientDrop(providers: providers)
        }
        HStack(alignment: .top) {
          VStack(alignment: .leading) {
            Text(
              "i18n:ClientManager.ManageClientsDescription"
                .i18n
            ).settingsDescription()
          }
          Spacer()
        }
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

  // MARK: - IdentifiableClient

  private struct IdentifiableClient: Identifiable {
    // MARK: Lifecycle

    init(bundleID: String) {
      self.bundleID = bundleID
    }

    // MARK: Internal

    let bundleID: String

    var id: String { bundleID }
  }

  @State
  private var clientsList: [IdentifiableClient] = []
  @State
  private var selectedIDs: Set<String> = []
  @State
  private var isShowingAddSheet = false
  @State
  private var isShowingAppPicker = false
  @State
  private var isShowingMitigationPrompt = false
  @State
  private var isShowingInvalidBundleAlert = false
  @State
  private var pendingBundleIdentifier: String?
  @State
  private var invalidBundleAlertPath: String?

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

  private func getToggleBinding(client: IdentifiableClient) -> Binding<Bool> {
    Binding(
      get: {
        PrefMgr.shared.clientsIMKTextInputIncapable[client.bundleID] ?? true
      },
      set: { newValue in
        PrefMgr.shared.clientsIMKTextInputIncapable[client.bundleID] = newValue
        reloadList()
      }
    )
  }

  private func reloadList() {
    clientsList = PrefMgr.shared.clientsIMKTextInputIncapable.keys.sorted()
      .map { IdentifiableClient(bundleID: $0) }
  }

  private func removeClientClicked() {
    var dict = PrefMgr.shared.clientsIMKTextInputIncapable
    for item in clientsList where selectedIDs.contains(item.id) {
      dict[item.bundleID] = nil
    }
    PrefMgr.shared.clientsIMKTextInputIncapable = dict
    selectedIDs.removeAll()
    reloadList()
  }

  private func handleClientDrop(providers: [NSItemProvider]) -> Bool {
    let acceptableProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }
    guard !acceptableProviders.isEmpty else { return false }
    acceptableProviders.forEach { provider in
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
        item, _ in
        guard let droppedURL = Self.parseFileURL(from: item) else { return }
        guard let bundle = Bundle(url: droppedURL),
              let identifier = bundle.bundleIdentifier else { return }
        DispatchQueue.main.async {
          var dict = PrefMgr.shared.clientsIMKTextInputIncapable
          dict[identifier] = true
          PrefMgr.shared.clientsIMKTextInputIncapable = dict
          reloadList()
        }
      }
    }
    return true
  }
}

// MARK: - AddClientSheetView

@available(macOS 14, *)
private struct AddClientSheetView: View {
  @Environment(\.dismiss)
  private var dismiss
  @State
  private var inputText: String = {
    let recentClients = InputSession.recentClientBundleIdentifiers.keys.compactMap {
      PrefMgr.shared.clientsIMKTextInputIncapable.keys.contains($0) ? nil : $0
    }
    return recentClients.sorted().joined(separator: "\n")
  }()

  var onCommit: ([String], Bool) -> ()

  var body: some View {
    VStack(spacing: 12) {
      Text("i18n:ClientManager.EnterBundleIdentifier".i18n)
        .font(.headline)
      Text("i18n:PhraseEditor.OneRecordPerLine".i18n)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
      TextEditor(text: $inputText)
        .font(.system(.body, design: .monospaced))
        .frame(minWidth: 350, minHeight: 180)
        .border(Color.secondary.opacity(0.3))
      HStack {
        Spacer()
        Button("i18n:Common.Cancel".i18n, role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("i18n:Common.OK".i18n) {
          let ids = inputText.components(separatedBy: "\n").filter { !$0.isEmpty }
          onCommit(ids, true)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding()
    .frame(minWidth: 420)
  }
}

// MARK: - VwrSettingsPaneClients_Previews

@available(macOS 14, *)
struct VwrSettingsPaneClients_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneClients()
  }
}
