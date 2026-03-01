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
          Text(
            LocalizedStringKey(
              "Choose your desired cassette file path. Will be omitted if invalid."
            )
          )
          HStack(spacing: 3) {
            PathControl(pathDroppable: $cassettePath) { pathControl in
              pathControl.allowedTypes = ["cin2", "cin", "vcin"]
              pathControl
                .placeholderString = "Please drag the desired target from Finder to this place."
                .i18n
            } acceptDrop: { pathControl, info in
              let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
              guard let url = urls?.first as? URL else { return false }
              let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
                PrefMgr.shared.cassettePath.expandingTildeInPath
              )
              if LMMgr.checkCassettePathValidity(url.path) {
                cassettePath = url.path
                pathControl.url = url
                LMMgr.loadCassetteData()
                BookmarkManager.shared.saveBookmark(for: url)
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
        }
        UserDef.kCassetteEnabled.renderUI {
          if PrefMgr.shared.cassetteEnabled, !LMMgr.checkCassettePathValidity(PrefMgr.shared.cassettePath) {
            IMEApp.buzz()
            LMMgr.resetCassettePath()
            PrefMgr.shared.cassetteEnabled = false
            isShowingCassetteError = true
          } else {
            LMMgr.loadCassetteData()
          }
          LMMgr.syncLMPrefs()
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
        Button("OK".i18n, role: .cancel) {}
      } message: {
        Text("i18n:LMMgr.accessFailure.cassette.description".i18n)
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
        let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
          cassettePath.expandingTildeInPath
        )

        switch result {
        case let .success(urls):
          guard let url = urls.first else { return }
          if LMMgr.checkCassettePathValidity(url.path) {
            cassettePath = url.path
            LMMgr.loadCassetteData()
            BookmarkManager.shared.saveBookmark(for: url)
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
