// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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
import Carbon

// Extend the RangeReplaceableCollection to allow it clean duplicated characters.
extension RangeReplaceableCollection where Element: Hashable {
    var charDeDuplicate: Self {
        var set = Set<Element>()
        return filter{ set.insert($0).inserted }
    }
}

// Please note that the class should be exposed using the same class name
// in Objective-C in order to let IMK to see the same class name as
// the "InputMethodServerPreferencesWindowControllerClass" in Info.plist.
@objc(ctlPrefWindow) class ctlPrefWindow: NSWindowController {
    @IBOutlet weak var fontSizePopUpButton: NSPopUpButton!
    @IBOutlet weak var uiLanguageButton: NSPopUpButton!
    @IBOutlet weak var basisKeyboardLayoutButton: NSPopUpButton!
    @IBOutlet weak var selectionKeyComboBox: NSComboBox!
    
    var currentLanguageSelectItem: NSMenuItem? = nil

    override func awakeFromNib() {
        let languages = ["auto", "en", "zh-Hans", "zh-Hant", "ja"]
        var autoMUISelectItem: NSMenuItem? = nil
        var chosenLanguageItem: NSMenuItem? = nil
        uiLanguageButton.menu?.removeAllItems()
        
        let appleLanguages = Preferences.appleLanguages
        for language in languages {
            let menuItem = NSMenuItem()
            menuItem.title = NSLocalizedString(language, comment: "")
            menuItem.representedObject = language
            
            if language == "auto" {
                autoMUISelectItem = menuItem
            }
            
            if !appleLanguages.isEmpty {
                if appleLanguages[0] == language {
                    chosenLanguageItem = menuItem
                }
            }
            uiLanguageButton.menu?.addItem(menuItem)
        }
        
        currentLanguageSelectItem = chosenLanguageItem ?? autoMUISelectItem
        uiLanguageButton.select(currentLanguageSelectItem)

        let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
        var usKeyboardLayoutItem: NSMenuItem? = nil
        var chosenBaseKeyboardLayoutItem: NSMenuItem? = nil

        basisKeyboardLayoutButton.menu?.removeAllItems()

        let basisKeyboardLayoutID = Preferences.basisKeyboardLayout
        
        for source in list {

            func getString(_ key: CFString) -> String? {
                if let ptr = TISGetInputSourceProperty(source, key) {
                    return String(Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue())
                }
                return nil
            }

            func getBool(_ key: CFString) -> Bool? {
                if let ptr = TISGetInputSourceProperty(source, key) {
                    return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
                }
                return nil
            }

            if let category = getString(kTISPropertyInputSourceCategory) {
                if category != String(kTISCategoryKeyboardInputSource) {
                    continue
                }
            } else {
                continue
            }

            if let asciiCapable = getBool(kTISPropertyInputSourceIsASCIICapable) {
                if !asciiCapable {
                    continue
                }
            } else {
                continue
            }

            if let sourceType = getString(kTISPropertyInputSourceType) {
                if sourceType != String(kTISTypeKeyboardLayout) {
                    continue
                }
            } else {
                continue
            }

            guard let sourceID = getString(kTISPropertyInputSourceID),
                  let localizedName = getString(kTISPropertyLocalizedName) else {
                continue
            }

            let menuItem = NSMenuItem()
            menuItem.title = localizedName
            menuItem.representedObject = sourceID

            if sourceID == "com.apple.keylayout.US" {
                usKeyboardLayoutItem = menuItem
            }
            if basisKeyboardLayoutID == sourceID {
                chosenBaseKeyboardLayoutItem = menuItem
            }
            basisKeyboardLayoutButton.menu?.addItem(menuItem)
        }

        let menuItem_AppleZhuyinBopomofo = NSMenuItem()
        menuItem_AppleZhuyinBopomofo.title = String(format: NSLocalizedString("Apple Zhuyin Bopomofo", comment: ""))
        menuItem_AppleZhuyinBopomofo.representedObject = String("com.apple.keylayout.ZhuyinBopomofo")
        basisKeyboardLayoutButton.menu?.addItem(menuItem_AppleZhuyinBopomofo)

        let menuItem_AppleZhuyinEten = NSMenuItem()
        menuItem_AppleZhuyinEten.title = String(format: NSLocalizedString("Apple Zhuyin Eten", comment: ""))
        menuItem_AppleZhuyinEten.representedObject = String("com.apple.keylayout.ZhuyinEten")
        basisKeyboardLayoutButton.menu?.addItem(menuItem_AppleZhuyinEten)

        basisKeyboardLayoutButton.select(chosenBaseKeyboardLayoutItem ?? usKeyboardLayoutItem)

        selectionKeyComboBox.usesDataSource = false
        selectionKeyComboBox.removeAllItems()
        selectionKeyComboBox.addItems(withObjectValues: Preferences.suggestedCandidateKeys)

        var candidateSelectionKeys = Preferences.candidateKeys
        if candidateSelectionKeys.isEmpty {
            candidateSelectionKeys = Preferences.defaultCandidateKeys
        }

        selectionKeyComboBox.stringValue = candidateSelectionKeys
    }

    @IBAction func updateBasisKeyboardLayoutAction(_ sender: Any) {
        if let sourceID = basisKeyboardLayoutButton.selectedItem?.representedObject as? String {
            Preferences.basisKeyboardLayout = sourceID
        }
    }
    
    @IBAction func updateUiLanguageAction(_ sender: Any) {
        if let selectItem = uiLanguageButton.selectedItem {
            if currentLanguageSelectItem == selectItem {
                return
            }
        }
        if let language = uiLanguageButton.selectedItem?.representedObject as? String {
            if (language != "auto") {
                Preferences.appleLanguages = [language]
            }
            else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            }
            
            NSLog("vChewing App self-terminated due to UI language change.")
            NSApplication.shared.terminate(nil)
        }
    }

    @IBAction func clickedWhetherIMEShouldNotFartToggleAction(_ sender: Any) {
        clsSFX.beep()
    }

    @IBAction func changeSelectionKeyAction(_ sender: Any) {
        guard let keys = (sender as AnyObject).stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).charDeDuplicate else {
                    return
                }
                do {
                    try Preferences.validate(candidateKeys: keys)
                    Preferences.candidateKeys = keys
                }
                catch Preferences.CandidateKeyError.empty {
                    selectionKeyComboBox.stringValue = Preferences.candidateKeys
                }
                catch {
                    if let window = window {
                        let alert = NSAlert(error: error)
                        alert.beginSheetModal(for: window) { response in
                            self.selectionKeyComboBox.stringValue = Preferences.candidateKeys
                        }
                        clsSFX.beep()
                    }
                }
        
        selectionKeyComboBox.stringValue = keys
        Preferences.candidateKeys = keys
    }

}
