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
    // 直接在 AppleKeyboardConverter 內使用 KeyParser 判定修飾鍵狀態的話，會出現蛇吞自己尾巴的現象。
    // 所以就藉由 ctlInputMethod 的這幾個常態變數來判斷。
    // 這裡不會列出全部的 modifier flags，只會列出可能會影響符號輸入的 flags、主要用於 AppleKeyboardConverter。
    @objc static var isOptionPressed: Bool = false
    @objc static var isShiftPressed: Bool = false
    @objc static var isCapsLockOn: Bool = false
    @objc static var isCommandPressed: Bool = false
    @objc static var isNumericPad: Bool = false
    @objc static var isFunction: Bool = false

    // MARK: - Functions

    // Print debug information to the console.
    @objc static func prtDebugIntel(_ strPrint: String) {
        if mgrPrefs.isDebugModeEnabled {
            NSLog("vChewingErrorCallback: %@", strPrint)
        }
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
