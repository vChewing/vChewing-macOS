// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

@objc public class IME: NSObject {

    static let dlgOpenPath = NSOpenPanel();

    // MARK: - Functions

    // Print debug information to the console.
    @objc static func prtDebugIntel(_ strPrint: String) {
        if mgrPrefs.isDebugModeEnabled {
            NSLog("vChewingErrorCallback: %@", strPrint)
        }
    }

    @objc static func initLangModels(userOnly: Bool) {
        if !userOnly {
            mgrLangModel.loadDataModels() // 這句還是不要砍了。
        }
        // mgrLangModel 的 loadUserPhrases 等函數在自動讀取 dataFolderPath 時，
        // 如果發現自訂目錄不可用，則會自動抹去自訂目錄設定、改採預設目錄。
        // 所以這裡不需要特別處理。
        mgrLangModel.loadUserPhrases()
        mgrLangModel.loadUserPhraseReplacement()
        mgrLangModel.loadUserAssociatedPhrases()
    }

    @objc static func isDarkMode() -> Bool {
        if #available(macOS 10.15, *) {
            let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription.lowercased()
            if appearanceDescription.contains("dark") {
                return true
            }
        } else if #available(macOS 10.14, *) {
            if let appleInterfaceStyle = UserDefaults.standard.object(forKey: "AppleInterfaceStyle") as? String {
                if appleInterfaceStyle.lowercased().contains("dark") {
                    return true
                }
            }
        }
        return false
    }
}
