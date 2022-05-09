// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI

@available(macOS 11.0, *)
struct suiPrefPaneDictionary: View {
  private var fdrDefault = mgrLangModel.dataFolderPath(isDefaultFolder: true)
  @State private var tbxUserDataPathSpecified: String =
    UserDefaults.standard.string(forKey: UserDef.kUserDataFolderSpecified)
    ?? mgrLangModel.dataFolderPath(isDefaultFolder: true)
  @State private var selAutoReloadUserData: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kShouldAutoReloadUserDataFiles)
  @State private var selEnableCNS11643: Bool = UserDefaults.standard.bool(forKey: UserDef.kCNS11643Enabled)
  @State private var selEnableSymbolInputSupport: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kSymbolInputEnabled)
  private let contentWidth: Double = {
    switch mgrPrefs.appleLanguages[0] {
      case "ja":
        return 520
      default:
        if mgrPrefs.appleLanguages[0].contains("zh-Han") {
          return 480
        } else {
          return 550
        }
    }
  }()

  var body: some View {
    Preferences.Container(contentWidth: contentWidth) {
      Preferences.Section(title: "", bottomDivider: true) {
        Text(LocalizedStringKey("Choose your desired user data folder path. Will be omitted if invalid."))
        HStack {
          TextField(fdrDefault, text: $tbxUserDataPathSpecified).disabled(true)
            .help(tbxUserDataPathSpecified)
          Button {
            IME.dlgOpenPath.title = NSLocalizedString(
              "Choose your desired user data folder.", comment: ""
            )
            IME.dlgOpenPath.showsResizeIndicator = true
            IME.dlgOpenPath.showsHiddenFiles = true
            IME.dlgOpenPath.canChooseFiles = false
            IME.dlgOpenPath.canChooseDirectories = true

            let bolPreviousFolderValidity = mgrLangModel.checkIfSpecifiedUserDataFolderValid(
              NSString(string: mgrPrefs.userDataFolderSpecified).expandingTildeInPath)

            if let window = ctlPrefUI.shared.controller.window {
              IME.dlgOpenPath.beginSheetModal(for: window) { result in
                if result == NSApplication.ModalResponse.OK {
                  if IME.dlgOpenPath.url != nil {
                    // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
                    // 所以要手動補回來。
                    var newPath = IME.dlgOpenPath.url!.path
                    newPath.ensureTrailingSlash()
                    if mgrLangModel.checkIfSpecifiedUserDataFolderValid(newPath) {
                      mgrPrefs.userDataFolderSpecified = newPath
                      tbxUserDataPathSpecified = mgrPrefs.userDataFolderSpecified
                      IME.initLangModels(userOnly: true)
                      (NSApplication.shared.delegate as! AppDelegate).updateStreamHelperPath()
                    } else {
                      clsSFX.beep()
                      if !bolPreviousFolderValidity {
                        mgrPrefs.resetSpecifiedUserDataFolder()
                      }
                      return
                    }
                  }
                } else {
                  if !bolPreviousFolderValidity {
                    mgrPrefs.resetSpecifiedUserDataFolder()
                  }
                  return
                }
              }
            }  // End If self.window != nil
          } label: {
            Text("...")
          }
          Button {
            mgrPrefs.resetSpecifiedUserDataFolder()
            tbxUserDataPathSpecified = ""
          } label: {
            Text("↻")
          }
        }
        Toggle(
          LocalizedStringKey("Automatically reload user data files if changes detected"),
          isOn: $selAutoReloadUserData
        ).controlSize(.small).onChange(of: selAutoReloadUserData) { value in
          mgrPrefs.shouldAutoReloadUserDataFiles = value
        }
        Divider()
        Toggle(LocalizedStringKey("Enable CNS11643 Support (2022-01-27)"), isOn: $selEnableCNS11643)
          .onChange(of: selEnableCNS11643) { value in
            mgrPrefs.cns11643Enabled = value
            mgrLangModel.setCNSEnabled(value)
          }
        Toggle(
          LocalizedStringKey("Enable symbol input support (incl. certain emoji symbols)"),
          isOn: $selEnableSymbolInputSupport
        )
        .onChange(of: selEnableSymbolInputSupport) { value in
          mgrPrefs.symbolInputEnabled = value
          mgrLangModel.setSymbolEnabled(value)
        }
      }
    }
  }
}

@available(macOS 11.0, *)
struct suiPrefPaneDictionary_Previews: PreviewProvider {
  static var previews: some View {
    suiPrefPaneDictionary()
  }
}
