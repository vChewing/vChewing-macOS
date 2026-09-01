// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - VwrSettingsPaneCassette

@available(macOS 14, *)
public struct VwrSettingsPaneCassette: View {
  // MARK: Public

  public var body: some View {
    Form {
      // MARK: - Cassette Data Path Management

      Section {
        VStack(alignment: .leading) {
          HStack(spacing: 3) {
            PathControl(pathDroppable: $cassettePath) { pathControl in
              pathControl.allowedTypes = ["cin2", "cin", "vcin"]
              pathControl
                .placeholderString = "i18n:ClientManager.DragTargetInstruction".i18n
            } acceptDrop: { pathControl, info in
              let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
              guard let droppedURL = urls?.first as? URL else { return false }
              let url = SettingsUIHost.shared.resolveUserSpecifiedURL(droppedURL)
              let bolPreviousPathValidity = SettingsUIHost.shared.checkCassettePathValidity(
                PrefMgr.shared.cassettePath.expandingTildeInPath
              )
              if SettingsUIHost.shared.checkCassettePathValidity(url.path) {
                cassettePath = url.path
                pathControl.url = url
                SettingsUIHost.shared.loadCassetteData()
                BookmarkManager.shared.saveBookmark(for: url)
                SettingsUIHost.shared.importCassetteFileToCache(url)
                return true
              }
              // On Error:
              IMEApp.buzz()
              if !bolPreviousPathValidity {
                cassettePath = ""
              }
              return false
            }
            Button {
              if NSEvent.keyModifierFlags == .option, !cassettePath.isEmpty {
                NSWorkspace.shared.activateFileViewerSelecting(
                  [URL(fileURLWithPath: cassettePath)]
                )
                return
              }
              isShowingFileImporter = true
            } label: {
              Text("...")
            }
            Button {
              cassettePath = ""
            } label: {
              Text("×")
            }
          }
          Text(LocalizedStringKey("i18n:UserDef.kCassettePath.description"))
            .settingsDescription()
        }
        UserDef.kCassetteEnabled.renderUI {
          // Use cassettePath() which includes internal cache fallback.
          if PrefMgr.shared.cassetteEnabled, SettingsUIHost.shared.cassettePath().isEmpty {
            IMEApp.buzz()
            SettingsUIHost.shared.resetCassettePath()
            PrefMgr.shared.cassetteEnabled = false
            isShowingCassetteError = true
          } else {
            SettingsUIHost.shared.loadCassetteData()
          }
          SettingsUIHost.shared.syncLMPrefs()
        }
      }

      // MARK: - Something Else

      Section {
        UserDef.kAutoCompositeWithLongestPossibleCassetteKey.renderUI()
        UserDef.kShowTranslatedStrokesInCompositionBuffer.renderUI()
        UserDef.kForceCassetteChineseConversion.renderUI()
      }
    }.formStyled()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
      .alert(
        "i18n:LMMgr.accessFailure.cassette.title".i18n,
        isPresented: $isShowingCassetteError
      ) {
        Button("i18n:Common.OK".i18n, role: .cancel) {}
      } message: {
        Text(SettingsUIHost.shared.cassetteAccessFailureDescription(cassettePath))
      }
      .fileImporter(
        isPresented: $isShowingFileImporter,
        allowedContentTypes: [
          UTType(filenameExtension: "cin2")!,
          UTType(filenameExtension: "vcin")!,
          UTType(filenameExtension: "cin")!,
        ],
        allowsMultipleSelection: false
      ) { result in
        let bolPreviousPathValidity = SettingsUIHost.shared.checkCassettePathValidity(
          cassettePath.expandingTildeInPath
        )

        switch result {
        case let .success(urls):
          guard let selectedURL = urls.first else { return }
          let url = SettingsUIHost.shared.resolveUserSpecifiedURL(selectedURL)
          if SettingsUIHost.shared.checkCassettePathValidity(url.path) {
            cassettePath = url.path
            SettingsUIHost.shared.loadCassetteData()
            BookmarkManager.shared.saveBookmark(for: url)
            SettingsUIHost.shared.importCassetteFileToCache(url)
          } else {
            IMEApp.buzz()
            if !bolPreviousPathValidity {
              cassettePath = ""
            }
          }
        case .failure:
          if !bolPreviousPathValidity {
            cassettePath = ""
          }
        }
      }
  }

  // MARK: Private

  @State
  private var isShowingFileImporter = false
  @State
  private var isShowingCassetteError = false

  // MARK: - AppStorage Variables（僅保留需經 PathControl 繫結的屬性）

  @AppStorage(wrappedValue: "", UserDef.kCassettePath.rawValue)
  private var cassettePath: String
}

// MARK: - VwrSettingsPaneCassette_Previews

@available(macOS 14, *)
struct VwrSettingsPaneCassette_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneCassette()
  }
}
