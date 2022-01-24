/* 
 *  PreferencesWindowController.swift
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
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

// Please note that the class should be exposed as "PreferencesWindowController"
// in Objective-C in order to let IMK to see the same class name as
// the "InputMethodServerPreferencesWindowControllerClass" in Info.plist.
@objc(PreferencesWindowController) class PreferencesWindowController: NSWindowController {
    @IBOutlet weak var fontSizePopUpButton: NSPopUpButton!
    @IBOutlet weak var uiLanguageButton: NSPopUpButton!
    @IBOutlet weak var basisKeyboardLayoutButton: NSPopUpButton!
    @IBOutlet weak var selectionKeyComboBox: NSComboBox!
    @IBOutlet weak var clickedWhetherIMEShouldNotFartToggle: NSButton!
    
    var currentLanguageSelectItem: NSMenuItem? = nil

    override func awakeFromNib() {
        let languages = ["auto", "en-US", "zh-CN", "zh-TW", "ja-JP"]
        var autoSelectItem: NSMenuItem? = nil
        var chosenLanguageItem: NSMenuItem? = nil
        uiLanguageButton.menu?.removeAllItems()
        
        let appleLanguages = Preferences.appleLanguages
        for language in languages {
            let menuItem = NSMenuItem()
            menuItem.title = NSLocalizedString(language, comment: "")
            menuItem.representedObject = language
            
            if language == "auto" {
                autoSelectItem = menuItem
            }
            
            if !appleLanguages.isEmpty {
                if appleLanguages[0] == language {
                    chosenLanguageItem = menuItem
                }
            }
            uiLanguageButton.menu?.addItem(menuItem)
        }
        
        currentLanguageSelectItem = chosenLanguageItem ?? autoSelectItem
        uiLanguageButton.select(currentLanguageSelectItem)

        let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
        var usKeyboardLayoutItem: NSMenuItem? = nil
        var chosenItem: NSMenuItem? = nil

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

            if let iconPtr = TISGetInputSourceProperty(source, kTISPropertyIconRef) {
                let icon = IconRef(iconPtr)
                let image = NSImage(iconRef: icon)

                func resize( _ image: NSImage) -> NSImage {
                    let newImage = NSImage(size: NSSize(width: 16, height: 16))
                    newImage.lockFocus()
                    image.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
                    newImage.unlockFocus()
                    return newImage
                }
                menuItem.image = resize(image)
            }

            if sourceID == "com.apple.keylayout.US" {
                usKeyboardLayoutItem = menuItem
            }
            if basisKeyboardLayoutID == sourceID {
                chosenItem = menuItem
            }
            basisKeyboardLayoutButton.menu?.addItem(menuItem)
        }

        basisKeyboardLayoutButton.select(chosenItem ?? usKeyboardLayoutItem)
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
