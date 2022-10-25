// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import SSPreferences
import Shared
import SwiftUI

@available(macOS 10.15, *)
struct VwrPrefPaneCassette: View {
  private var fdrCassetteDataDefault: String { "" }
  @State private var tbxCassettePath: String =
    UserDefaults.standard.string(forKey: UserDef.kCassettePath.rawValue)
    ?? ""
  @State private var selCassetteEnabled: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kCassetteEnabled.rawValue)
  @State private var selForceCassetteChineseConversion: Int = UserDefaults.standard.integer(
    forKey: UserDef.kForceCassetteChineseConversion.rawValue)
  @State private var selShowTranslatedStrokesInCompositionBuffer: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kShowTranslatedStrokesInCompositionBuffer.rawValue)
  @State private var selAutoCompositeWithLongestPossibleCassetteKey = UserDefaults.standard.bool(
    forKey: UserDef.kAutoCompositeWithLongestPossibleCassetteKey.rawValue)

  private static let dlgOpenFile = NSOpenPanel()

  private let contentMaxHeight: Double = 440
  private let contentWidth: Double = {
    switch PrefMgr.shared.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 580
        }
    }
  }()

  var body: some View {
    ScrollView {
      SSPreferences.Container(contentWidth: contentWidth) {
        // MARK: - Cassette Data Path Management

        SSPreferences.Section(title: "", bottomDivider: true) {
          Text(LocalizedStringKey("Choose your desired cassette file path. Will be omitted if invalid."))
          HStack {
            TextField(fdrCassetteDataDefault, text: $tbxCassettePath).disabled(true)
              .help(tbxCassettePath)
            Button {
              Self.dlgOpenFile.title = NSLocalizedString(
                "Choose your desired cassette file path.", comment: ""
              )
              Self.dlgOpenFile.showsResizeIndicator = true
              Self.dlgOpenFile.showsHiddenFiles = true
              Self.dlgOpenFile.canChooseFiles = true
              Self.dlgOpenFile.canChooseDirectories = false
              Self.dlgOpenFile.allowsMultipleSelection = false
              Self.dlgOpenFile.allowedFileTypes = ["cin2", "vcin", "cin"]
              Self.dlgOpenFile.allowsOtherFileTypes = true

              let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
                PrefMgr.shared.cassettePath.expandingTildeInPath)

              if let window = CtlPrefUI.shared.controller.window {
                Self.dlgOpenFile.beginSheetModal(for: window) { result in
                  if result == NSApplication.ModalResponse.OK {
                    guard let url = Self.dlgOpenFile.url else { return }
                    if LMMgr.checkCassettePathValidity(url.path) {
                      PrefMgr.shared.cassettePath = url.path
                      LMMgr.loadCassetteData()
                      tbxCassettePath = PrefMgr.shared.cassettePath
                      BookmarkManager.shared.saveBookmark(for: url)
                    } else {
                      IMEApp.buzz()
                      if !bolPreviousPathValidity {
                        LMMgr.resetCassettePath()
                      }
                      return
                    }
                  } else {
                    if !bolPreviousPathValidity {
                      LMMgr.resetCassettePath()
                    }
                    return
                  }
                }
              }
            } label: {
              Text("...")
            }
            Button {
              LMMgr.resetCassettePath()
              tbxCassettePath = ""
            } label: {
              Text("×")
            }
          }
          Toggle(
            LocalizedStringKey("Enable cassette mode, suppressing phonabet input"),
            isOn: $selCassetteEnabled.onChange {
              if selCassetteEnabled, !LMMgr.checkCassettePathValidity(PrefMgr.shared.cassettePath) {
                if let window = CtlPrefUI.shared.controller.window {
                  IMEApp.buzz()
                  let alert = NSAlert(error: NSLocalizedString("Path invalid or file access error.", comment: ""))
                  alert.informativeText = NSLocalizedString(
                    "Please reconfigure the cassette path to a valid one before enabling this mode.", comment: ""
                  )
                  alert.beginSheetModal(for: window) { _ in
                    LMMgr.resetCassettePath()
                    PrefMgr.shared.cassetteEnabled = false
                    selCassetteEnabled = false
                  }
                }
              } else {
                PrefMgr.shared.cassetteEnabled = selCassetteEnabled
                LMMgr.loadCassetteData()
              }
            }
          ).controlSize(.small)
          Text(
            LocalizedStringKey(
              "Cassette mode is similar to the CIN support of the Yahoo Kimo IME, allowing users to use their own CIN tables to implement their stroked-based input schema (e.g. Wubi, Cangjie, Boshiamy, etc.) as a plan-B in vChewing IME. However, since vChewing won't compromise its phonabet input mode experience for this cassette mode, users might not feel comfortable enough comparing to their experiences with RIME (recommended) or OpenVanilla (deprecated)."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
        }

        // MARK: - Something Else

        SSPreferences.Section(title: "") {
          Toggle(
            LocalizedStringKey("Auto-composite when the longest possible key is formed"),
            isOn: $selAutoCompositeWithLongestPossibleCassetteKey.onChange {
              PrefMgr.shared.autoCompositeWithLongestPossibleCassetteKey =
                selAutoCompositeWithLongestPossibleCassetteKey
            }
          )
          Toggle(
            LocalizedStringKey("Show translated strokes in composition buffer"),
            isOn: $selShowTranslatedStrokesInCompositionBuffer.onChange {
              PrefMgr.shared.showTranslatedStrokesInCompositionBuffer = selShowTranslatedStrokesInCompositionBuffer
            }
          )
          Text(
            LocalizedStringKey(
              "All strokes in the composition buffer will be shown as ASCII keyboard characters unless this option is enabled. Stroke is definable in the “%keyname” section of the CIN file."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
          Picker(
            "",
            selection: $selForceCassetteChineseConversion.onChange {
              PrefMgr.shared.forceCassetteChineseConversion = selForceCassetteChineseConversion
            }
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
              "This conversion only affects the cassette module, converting typed contents to either Simplified Chinese or Traditional Chinese in accordance to this setting and your current input mode."
            )
          )
          .preferenceDescription().fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxHeight: contentMaxHeight).fixedSize(horizontal: false, vertical: true)
    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
  }
}

@available(macOS 11.0, *)
struct VwrPrefPaneCassette_Previews: PreviewProvider {
  static var previews: some View {
    VwrPrefPaneDictionary()
  }
}
