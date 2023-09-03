// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import MainAssembly
import Shared
import SSPreferences
import SwiftExtension
import SwiftUI
import SwiftUIBackports

@available(macOS 10.15, *)
struct VwrPrefPaneCassette: View {
  // MARK: - AppStorage Variables

  @Backport.AppStorage(wrappedValue: "", UserDef.kCassettePath.rawValue)
  private var cassettePath: String

  @Backport.AppStorage(wrappedValue: false, UserDef.kCassetteEnabled.rawValue)
  private var cassetteEnabled: Bool

  @Backport.AppStorage(wrappedValue: 0, UserDef.kForceCassetteChineseConversion.rawValue)
  private var forceCassetteChineseConversion: Int

  @Backport.AppStorage(wrappedValue: true, UserDef.kShowTranslatedStrokesInCompositionBuffer.rawValue)
  private var showTranslatedStrokesInCompositionBuffer: Bool

  @Backport.AppStorage(wrappedValue: true, UserDef.kAutoCompositeWithLongestPossibleCassetteKey.rawValue)
  private var autoCompositeWithLongestPossibleCassetteKey: Bool

  // MARK: - Main View

  private static let dlgOpenFile = NSOpenPanel()

  var body: some View {
    ScrollView {
      SSPreferences.Settings.Container(contentWidth: CtlPrefUIShared.contentWidth) {
        // MARK: - Cassette Data Path Management

        SSPreferences.Settings.Section(bottomDivider: true) {
          Text(LocalizedStringKey("Choose your desired cassette file path. Will be omitted if invalid."))
          HStack {
            PathControl(pathDroppable: $cassettePath) { pathControl in
              pathControl.allowedTypes = ["cin2", "cin", "vcin"]
              pathControl.heightAnchor.constraint(equalToConstant: 20).isActive = true
              pathControl.widthAnchor.constraint(equalToConstant: CtlPrefUIShared.maxDescriptionWidth).isActive = true
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

              if let window = CtlPrefUIShared.sharedWindow {
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
          Toggle(
            LocalizedStringKey("Enable cassette mode, suppressing phonabet input"),
            isOn: $cassetteEnabled.onChange {
              if cassetteEnabled, !LMMgr.checkCassettePathValidity(cassettePath) {
                if let window = CtlPrefUIShared.sharedWindow {
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
              LMMgr.setCassetteEnabled(cassetteEnabled)
            }
          ).controlSize(.small)
          Text(
            LocalizedStringKey(
              "Cassette mode is similar to the CIN support of the Yahoo Kimo IME, allowing users to use their own CIN tables to implement their stroked-based input schema (e.g. Wubi, Cangjie, Boshiamy, etc.) as a plan-B in vChewing IME. However, since vChewing won't compromise its phonabet input mode experience for this cassette mode, users might not feel comfortable enough comparing to their experiences with RIME (recommended) or OpenVanilla (deprecated)."
            )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }

        // MARK: - Something Else

        SSPreferences.Settings.Section {
          Toggle(
            LocalizedStringKey("Auto-composite when the longest possible key is formed"),
            isOn: $autoCompositeWithLongestPossibleCassetteKey
          )
          Toggle(
            LocalizedStringKey("Show translated strokes in composition buffer"),
            isOn: $showTranslatedStrokesInCompositionBuffer
          )
          Text(
            LocalizedStringKey(
              "All strokes in the composition buffer will be shown as ASCII keyboard characters unless this option is enabled. Stroke is definable in the “%keyname” section of the CIN file."
            )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
          Picker(
            "",
            selection: $forceCassetteChineseConversion
          ) {
            Text(LocalizedStringKey("Disable forced conversion for cassette outputs")).tag(0)
            Text(LocalizedStringKey("Enforce conversion in both input modes")).tag(1)
            Text(LocalizedStringKey("Only enforce conversion in Simplified Chinese mode")).tag(2)
            Text(LocalizedStringKey("Only enforce conversion in Traditional Chinese mode")).tag(3)
          }
          .labelsHidden()
          .pickerStyle(RadioGroupPickerStyle())
          Text(
            LocalizedStringKey(
              "This conversion only affects the cassette module, converting typed contents to either Simplified Chinese or Traditional Chinese in accordance with this setting and your current input mode."
            )
          )
          .preferenceDescription(maxWidth: CtlPrefUIShared.maxDescriptionWidth)
        }
      }
    }
    .frame(maxHeight: CtlPrefUIShared.contentMaxHeight)
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneCassette_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneDictionary()
  }
}
