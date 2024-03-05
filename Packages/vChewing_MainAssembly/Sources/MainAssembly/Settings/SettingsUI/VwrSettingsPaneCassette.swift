// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import OSFrameworkImpl
import Shared
import SwiftUI

@available(macOS 13, *)
public struct VwrSettingsPaneCassette: View {
  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: "", UserDef.kCassettePath.rawValue)
  private var cassettePath: String

  @AppStorage(wrappedValue: false, UserDef.kCassetteEnabled.rawValue)
  private var cassetteEnabled: Bool

  @AppStorage(wrappedValue: 0, UserDef.kForceCassetteChineseConversion.rawValue)
  private var forceCassetteChineseConversion: Int

  @AppStorage(wrappedValue: true, UserDef.kShowTranslatedStrokesInCompositionBuffer.rawValue)
  private var showTranslatedStrokesInCompositionBuffer: Bool

  @AppStorage(wrappedValue: true, UserDef.kAutoCompositeWithLongestPossibleCassetteKey.rawValue)
  private var autoCompositeWithLongestPossibleCassetteKey: Bool

  // MARK: - Main View

  private static let dlgOpenFile = NSOpenPanel()

  public var body: some View {
    ScrollView {
      Form {
        // MARK: - Cassette Data Path Management

        Section {
          VStack(alignment: .leading) {
            Text(LocalizedStringKey("Choose your desired cassette file path. Will be omitted if invalid."))
            HStack(spacing: 3) {
              PathControl(pathDroppable: $cassettePath) { pathControl in
                pathControl.allowedTypes = ["cin2", "cin", "vcin"]
                pathControl.placeholderString = "Please drag the desired target from Finder to this place.".localized
              } acceptDrop: { pathControl, info in
                let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self])
                guard let url = urls?.first as? URL else { return false }
                let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
                  PrefMgr.shared.cassettePath.expandingTildeInPath)
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
                Self.dlgOpenFile.showsResizeIndicator = true
                Self.dlgOpenFile.showsHiddenFiles = true
                Self.dlgOpenFile.canChooseFiles = true
                Self.dlgOpenFile.canChooseDirectories = false
                Self.dlgOpenFile.allowsMultipleSelection = false
                Self.dlgOpenFile.allowedFileTypes = ["cin2", "vcin", "cin"]
                Self.dlgOpenFile.allowsOtherFileTypes = true

                let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
                  cassettePath.expandingTildeInPath)

                if let window = CtlSettingsUI.shared?.window {
                  Self.dlgOpenFile.beginSheetModal(for: window) { result in
                    if result == NSApplication.ModalResponse.OK {
                      guard let url = Self.dlgOpenFile.url else { return }
                      if LMMgr.checkCassettePathValidity(url.path) {
                        cassettePath = url.path
                        LMMgr.loadCassetteData()
                        BookmarkManager.shared.saveBookmark(for: url)
                      } else {
                        IMEApp.buzz()
                        if !bolPreviousPathValidity {
                          cassettePath = ""
                        }
                        return
                      }
                    } else {
                      if !bolPreviousPathValidity {
                        cassettePath = ""
                      }
                      return
                    }
                  }
                }
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
          UserDef.kCassetteEnabled.bind(
            $cassetteEnabled.didChange {
              if cassetteEnabled, !LMMgr.checkCassettePathValidity(cassettePath) {
                if let window = CtlSettingsUI.shared?.window {
                  IMEApp.buzz()
                  let alert = NSAlert(error: NSLocalizedString("Path invalid or file access error.", comment: ""))
                  alert.informativeText = NSLocalizedString(
                    "Please reconfigure the cassette path to a valid one before enabling this mode.", comment: ""
                  )
                  alert.beginSheetModal(for: window) { _ in
                  }
                }
                LMMgr.resetCassettePath()
                cassetteEnabled = false
              } else {
                LMMgr.loadCassetteData()
              }
              LMMgr.syncLMPrefs()
            }
          ).render()
        }

        // MARK: - Something Else

        Section {
          UserDef.kAutoCompositeWithLongestPossibleCassetteKey.bind($autoCompositeWithLongestPossibleCassetteKey).render()
          UserDef.kShowTranslatedStrokesInCompositionBuffer.bind($showTranslatedStrokesInCompositionBuffer).render()
          UserDef.kForceCassetteChineseConversion.bind($forceCassetteChineseConversion).render()
        }
      }.formStyled()
    }
    .frame(
      minWidth: CtlSettingsUI.formWidth,
      maxHeight: CtlSettingsUI.contentMaxHeight
    )
  }
}

@available(macOS 13, *)
struct VwrSettingsPaneCassette_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneDictionary()
  }
}
