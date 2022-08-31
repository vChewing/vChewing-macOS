// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Carbon
import Cocoa

private let kWindowTitleHeight: CGFloat = 78

extension NSToolbarItem.Identifier {
  fileprivate static let ofGeneral = NSToolbarItem.Identifier(rawValue: "tabGeneral")
  fileprivate static let ofExperience = NSToolbarItem.Identifier(rawValue: "tabExperience")
  fileprivate static let ofDictionary = NSToolbarItem.Identifier(rawValue: "tabDictionary")
  fileprivate static let ofKeyboard = NSToolbarItem.Identifier(rawValue: "tabKeyboard")
  fileprivate static let ofDevZone = NSToolbarItem.Identifier(rawValue: "tabDevZone")
}

// Please note that the class should be exposed using the same class name
// in Objective-C in order to let IMK to see the same class name as
// the "InputMethodServerPreferencesWindowControllerClass" in Info.plist.
@objc(ctlPrefWindow)
class ctlPrefWindow: NSWindowController {
  @IBOutlet var fontSizePopUpButton: NSPopUpButton!
  @IBOutlet var uiLanguageButton: NSPopUpButton!
  @IBOutlet var basicKeyboardLayoutButton: NSPopUpButton!
  @IBOutlet var selectionKeyComboBox: NSComboBox!
  @IBOutlet var chkTrad2KangXi: NSButton!
  @IBOutlet var chkTrad2JISShinjitai: NSButton!
  @IBOutlet var lblCurrentlySpecifiedUserDataFolder: NSTextFieldCell!
  @IBOutlet var tglControlDevZoneIMKCandidate: NSButton!

  @IBOutlet var vwrGeneral: NSView!
  @IBOutlet var vwrExperience: NSView!
  @IBOutlet var vwrDictionary: NSView!
  @IBOutlet var vwrKeyboard: NSView!
  @IBOutlet var vwrDevZone: NSView!

  var currentLanguageSelectItem: NSMenuItem?

  override func windowDidLoad() {
    super.windowDidLoad()

    var preferencesTitleName = NSLocalizedString("vChewing Preferences…", comment: "")
    preferencesTitleName.removeLast()

    let toolbar = NSToolbar(identifier: "preference toolbar")
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.sizeMode = .default
    toolbar.delegate = self
    toolbar.selectedItemIdentifier = .ofGeneral
    toolbar.showsBaselineSeparator = true
    window?.titlebarAppearsTransparent = false
    if #available(macOS 11.0, *) {
      window?.toolbarStyle = .preference
    }
    window?.toolbar = toolbar
    window?.title = preferencesTitleName
    use(view: vwrGeneral)

    lblCurrentlySpecifiedUserDataFolder.placeholderString = mgrLangModel.dataFolderPath(
      isDefaultFolder: true)

    let languages = ["auto", "en", "zh-Hans", "zh-Hant", "ja"]
    var autoMUISelectItem: NSMenuItem?
    var chosenLanguageItem: NSMenuItem?
    uiLanguageButton.menu?.removeAllItems()

    let appleLanguages = mgrPrefs.appleLanguages
    for language in languages {
      let menuItem = NSMenuItem()
      menuItem.title = NSLocalizedString(language, comment: language)
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
    var usKeyboardLayoutItem: NSMenuItem?
    var chosenBaseKeyboardLayoutItem: NSMenuItem?

    basicKeyboardLayoutButton.menu?.removeAllItems()

    let itmAppleZhuyinBopomofo = NSMenuItem()
    itmAppleZhuyinBopomofo.title = String(
      format: NSLocalizedString("Apple Zhuyin Bopomofo (Dachen)", comment: ""))
    itmAppleZhuyinBopomofo.representedObject = String(
      "com.apple.keylayout.ZhuyinBopomofo")
    basicKeyboardLayoutButton.menu?.addItem(itmAppleZhuyinBopomofo)

    let itmAppleZhuyinEten = NSMenuItem()
    itmAppleZhuyinEten.title = String(
      format: NSLocalizedString("Apple Zhuyin Eten (Traditional)", comment: ""))
    itmAppleZhuyinEten.representedObject = String("com.apple.keylayout.ZhuyinEten")
    basicKeyboardLayoutButton.menu?.addItem(itmAppleZhuyinEten)

    let basicKeyboardLayoutID = mgrPrefs.basicKeyboardLayout

    for source in list {
      if let categoryPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) {
        let category = Unmanaged<CFString>.fromOpaque(categoryPtr).takeUnretainedValue()
        if category != kTISCategoryKeyboardInputSource {
          continue
        }
      } else {
        continue
      }

      if let asciiCapablePtr = TISGetInputSourceProperty(
        source, kTISPropertyInputSourceIsASCIICapable
      ) {
        let asciiCapable = Unmanaged<CFBoolean>.fromOpaque(asciiCapablePtr)
          .takeUnretainedValue()
        if asciiCapable != kCFBooleanTrue {
          continue
        }
      } else {
        continue
      }

      if let sourceTypePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) {
        let sourceType = Unmanaged<CFString>.fromOpaque(sourceTypePtr).takeUnretainedValue()
        if sourceType != kTISTypeKeyboardLayout {
          continue
        }
      } else {
        continue
      }

      guard let sourceIDPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
        let localizedNamePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
      else {
        continue
      }

      let sourceID = String(Unmanaged<CFString>.fromOpaque(sourceIDPtr).takeUnretainedValue())
      let localizedName = String(
        Unmanaged<CFString>.fromOpaque(localizedNamePtr).takeUnretainedValue())

      let menuItem = NSMenuItem()
      menuItem.title = localizedName
      menuItem.representedObject = sourceID

      if sourceID == "com.apple.keylayout.US" {
        usKeyboardLayoutItem = menuItem
      }
      if basicKeyboardLayoutID == sourceID {
        chosenBaseKeyboardLayoutItem = menuItem
      }
      if IME.arrWhitelistedKeyLayoutsASCII.contains(sourceID) || sourceID.contains("vChewing") {
        basicKeyboardLayoutButton.menu?.addItem(menuItem)
      }
    }

    switch basicKeyboardLayoutID {
      case "com.apple.keylayout.ZhuyinBopomofo":
        chosenBaseKeyboardLayoutItem = itmAppleZhuyinBopomofo
      case "com.apple.keylayout.ZhuyinEten":
        chosenBaseKeyboardLayoutItem = itmAppleZhuyinEten
      default:
        break  // nothing to do
    }

    basicKeyboardLayoutButton.select(chosenBaseKeyboardLayoutItem ?? usKeyboardLayoutItem)

    selectionKeyComboBox.usesDataSource = false
    selectionKeyComboBox.removeAllItems()
    selectionKeyComboBox.addItems(withObjectValues: mgrPrefs.suggestedCandidateKeys)

    var candidateSelectionKeys = mgrPrefs.candidateKeys
    if candidateSelectionKeys.isEmpty {
      candidateSelectionKeys = mgrPrefs.defaultCandidateKeys
    }

    selectionKeyComboBox.stringValue = candidateSelectionKeys
  }

  // 這裡有必要加上這段處理，用來確保藉由偏好設定介面動過的 CNS 開關能夠立刻生效。
  // 所有涉及到語言模型開關的內容均需要這樣處理。
  @IBAction func toggleCNSSupport(_: Any) {
    mgrLangModel.setCNSEnabled(mgrPrefs.cns11643Enabled)
  }

  @IBAction func toggleSymbolInputEnabled(_: Any) {
    mgrLangModel.setSymbolEnabled(mgrPrefs.symbolInputEnabled)
  }

  @IBAction func toggleTrad2KangXiAction(_: Any) {
    if chkTrad2KangXi.state == .on, chkTrad2JISShinjitai.state == .on {
      mgrPrefs.toggleShiftJISShinjitaiOutputEnabled()
    }
  }

  @IBAction func toggleTrad2JISShinjitaiAction(_: Any) {
    if chkTrad2KangXi.state == .on, chkTrad2JISShinjitai.state == .on {
      mgrPrefs.toggleChineseConversionEnabled()
    }
  }

  @IBAction func updateBasicKeyboardLayoutAction(_: Any) {
    if let sourceID = basicKeyboardLayoutButton.selectedItem?.representedObject as? String {
      mgrPrefs.basicKeyboardLayout = sourceID
    }
  }

  @IBAction func updateUiLanguageAction(_: Any) {
    if let selectItem = uiLanguageButton.selectedItem {
      if currentLanguageSelectItem == selectItem {
        return
      }
    }
    if let language = uiLanguageButton.selectedItem?.representedObject as? String {
      if language != "auto" {
        mgrPrefs.appleLanguages = [language]
      } else {
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
      }

      NSLog("vChewing App self-terminated due to UI language change.")
      NSApplication.shared.terminate(nil)
    }
  }

  @IBAction func updateIMKCandidateEnableStatusAction(_: Any) {
    NSLog("vChewing App self-terminated due to enabling / disabling IMK candidate window.")
    NSApplication.shared.terminate(nil)
  }

  @IBAction func clickedWhetherIMEShouldNotFartToggleAction(_: Any) {
    clsSFX.beep()
  }

  @IBAction func changeSelectionKeyAction(_ sender: Any) {
    guard
      let keys = (sender as AnyObject).stringValue?.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      .deduplicate
    else {
      return
    }
    do {
      try mgrPrefs.validate(candidateKeys: keys)
      mgrPrefs.candidateKeys = keys
      selectionKeyComboBox.stringValue = mgrPrefs.candidateKeys
    } catch mgrPrefs.CandidateKeyError.empty {
      selectionKeyComboBox.stringValue = mgrPrefs.candidateKeys
    } catch {
      if let window = window {
        let alert = NSAlert(error: error)
        alert.beginSheetModal(for: window) { _ in
          self.selectionKeyComboBox.stringValue = mgrPrefs.candidateKeys
        }
        clsSFX.beep()
      }
    }
  }

  @IBAction func resetSpecifiedUserDataFolder(_: Any) {
    mgrPrefs.resetSpecifiedUserDataFolder()
  }

  @IBAction func chooseUserDataFolderToSpecify(_: Any) {
    guard let window = window else { return }
    IME.dlgOpenPath.title = NSLocalizedString(
      "Choose your desired user data folder.", comment: ""
    )
    IME.dlgOpenPath.showsResizeIndicator = true
    IME.dlgOpenPath.showsHiddenFiles = true
    IME.dlgOpenPath.canChooseFiles = false
    IME.dlgOpenPath.canChooseDirectories = true

    let bolPreviousFolderValidity = mgrLangModel.checkIfSpecifiedUserDataFolderValid(
      mgrPrefs.userDataFolderSpecified.expandingTildeInPath)

    IME.dlgOpenPath.beginSheetModal(for: window) { result in
      if result == NSApplication.ModalResponse.OK {
        guard let url = IME.dlgOpenPath.url else { return }
        // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
        // 所以要手動補回來。
        var newPath = url.path
        newPath.ensureTrailingSlash()
        if mgrLangModel.checkIfSpecifiedUserDataFolderValid(newPath) {
          mgrPrefs.userDataFolderSpecified = newPath
          BookmarkManager.shared.saveBookmark(for: url)
          IME.initLangModels(userOnly: true)
          (NSApplication.shared.delegate as! AppDelegate).updateStreamHelperPath()
        } else {
          clsSFX.beep()
          if !bolPreviousFolderValidity {
            mgrPrefs.resetSpecifiedUserDataFolder()
          }
          return
        }
      } else {
        if !bolPreviousFolderValidity {
          mgrPrefs.resetSpecifiedUserDataFolder()
        }
        return
      }
    }
  }  // End IBAction
}

extension ctlPrefWindow: NSToolbarDelegate {
  func use(view: NSView) {
    guard let window = window else {
      return
    }
    window.contentView?.subviews.first?.removeFromSuperview()
    let viewFrame = view.frame
    var windowRect = window.frame
    windowRect.size.height = kWindowTitleHeight + viewFrame.height
    windowRect.size.width = viewFrame.width
    windowRect.origin.y = window.frame.maxY - (viewFrame.height + kWindowTitleHeight)
    window.setFrame(windowRect, display: true, animate: true)
    window.contentView?.frame = view.bounds
    window.contentView?.addSubview(view)
  }

  var toolbarIdentifiers: [NSToolbarItem.Identifier] {
    if #available(macOS 10.14, *) {
      return [.ofGeneral, .ofExperience, .ofDictionary, .ofKeyboard, .ofDevZone]
    }
    return [.ofGeneral, .ofExperience, .ofDictionary, .ofKeyboard]
  }

  func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  @objc func showGeneralView(_: Any?) {
    use(view: vwrGeneral)
    window?.toolbar?.selectedItemIdentifier = .ofGeneral
  }

  @objc func showExperienceView(_: Any?) {
    use(view: vwrExperience)
    window?.toolbar?.selectedItemIdentifier = .ofExperience
  }

  @objc func showDictionaryView(_: Any?) {
    use(view: vwrDictionary)
    window?.toolbar?.selectedItemIdentifier = .ofDictionary
  }

  @objc func showKeyboardView(_: Any?) {
    use(view: vwrKeyboard)
    window?.toolbar?.selectedItemIdentifier = .ofKeyboard
  }

  @objc func showDevZoneView(_: Any?) {
    use(view: vwrDevZone)
    window?.toolbar?.selectedItemIdentifier = .ofDevZone
  }

  func toolbar(
    _: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar _: Bool
  ) -> NSToolbarItem? {
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.target = self
    switch itemIdentifier {
      case .ofGeneral:
        let title = NSLocalizedString("General", comment: "")
        item.label = title
        item.image = .tabImageGeneral
        item.action = #selector(showGeneralView(_:))

      case .ofExperience:
        let title = NSLocalizedString("Experience", comment: "")
        item.label = title
        item.image = .tabImageExperience
        item.action = #selector(showExperienceView(_:))

      case .ofDictionary:
        let title = NSLocalizedString("Dictionary", comment: "")
        item.label = title
        item.image = .tabImageDictionary
        item.action = #selector(showDictionaryView(_:))

      case .ofKeyboard:
        let title = NSLocalizedString("Keyboard", comment: "")
        item.label = title
        item.image = .tabImageKeyboard
        item.action = #selector(showKeyboardView(_:))

      case .ofDevZone:
        let title = NSLocalizedString("DevZone", comment: "")
        item.label = title
        item.image = .tabImageDevZone
        item.action = #selector(showDevZoneView(_:))

      default:
        return nil
    }
    return item
  }
}
