// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import IMKUtils
import Shared

private let kWindowTitleHeight: Double = 78

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
@objc(CtlPrefWindow)
class CtlPrefWindow: NSWindowController {
  @IBOutlet var fontSizePopUpButton: NSPopUpButton!
  @IBOutlet var uiLanguageButton: NSPopUpButton!
  @IBOutlet var basicKeyboardLayoutButton: NSPopUpButton!
  @IBOutlet var selectionKeyComboBox: NSComboBox!
  @IBOutlet var chkTrad2KangXi: NSButton!
  @IBOutlet var chkTrad2JISShinjitai: NSButton!
  @IBOutlet var lblCurrentlySpecifiedUserDataFolder: NSTextFieldCell!
  @IBOutlet var tglControlDevZoneIMKCandidate: NSButton!
  @IBOutlet var cmbCandidateFontSize: NSPopUpButton!

  @IBOutlet var vwrGeneral: NSView!
  @IBOutlet var vwrExperience: NSView!
  @IBOutlet var vwrDictionary: NSView!
  @IBOutlet var vwrKeyboard: NSView!
  @IBOutlet var vwrDevZone: NSView!

  public static var shared: CtlPrefWindow?

  static func show() {
    if shared == nil { shared = CtlPrefWindow(windowNibName: "frmPrefWindow") }
    guard let sharedWindow = shared?.window else { return }
    sharedWindow.center()
    sharedWindow.orderFrontRegardless()  // 逼著視窗往最前方顯示
    sharedWindow.level = .statusBar
    sharedWindow.titlebarAppearsTransparent = true
    NSApp.setActivationPolicy(.accessory)
  }

  private var currentLanguageSelectItem: NSMenuItem?

  override func windowDidLoad() {
    super.windowDidLoad()

    cmbCandidateFontSize.isEnabled = true

    if #unavailable(macOS 10.14) {
      if PrefMgr.shared.useIMKCandidateWindow {
        cmbCandidateFontSize.isEnabled = false
      }
    }

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

    lblCurrentlySpecifiedUserDataFolder.placeholderString = LMMgr.dataFolderPath(
      isDefaultFolder: true)

    let languages = ["auto", "en", "zh-Hans", "zh-Hant", "ja"]
    var autoMUISelectItem: NSMenuItem?
    var chosenLanguageItem: NSMenuItem?
    uiLanguageButton.menu?.removeAllItems()

    let appleLanguages = PrefMgr.shared.appleLanguages
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

    var usKeyboardLayoutItem: NSMenuItem?
    var chosenBaseKeyboardLayoutItem: NSMenuItem?

    basicKeyboardLayoutButton.menu?.removeAllItems()

    let basicKeyboardLayoutID = PrefMgr.shared.basicKeyboardLayout

    for source in IMKHelper.allowedBasicLayoutsAsTISInputSources {
      guard let source = source else {
        basicKeyboardLayoutButton.menu?.addItem(NSMenuItem.separator())
        continue
      }
      let menuItem = NSMenuItem()
      menuItem.title = source.vChewingLocalizedName
      menuItem.representedObject = source.identifier
      if source.identifier == "com.apple.keylayout.US" { usKeyboardLayoutItem = menuItem }
      if basicKeyboardLayoutID == source.identifier { chosenBaseKeyboardLayoutItem = menuItem }
      basicKeyboardLayoutButton.menu?.addItem(menuItem)
    }

    basicKeyboardLayoutButton.select(chosenBaseKeyboardLayoutItem ?? usKeyboardLayoutItem)

    selectionKeyComboBox.usesDataSource = false
    selectionKeyComboBox.removeAllItems()
    selectionKeyComboBox.addItems(withObjectValues: CandidateKey.suggestions)

    var candidateSelectionKeys = PrefMgr.shared.candidateKeys
    if candidateSelectionKeys.isEmpty {
      candidateSelectionKeys = CandidateKey.defaultKeys
    }

    selectionKeyComboBox.stringValue = candidateSelectionKeys
    if PrefMgr.shared.useIMKCandidateWindow {
      selectionKeyComboBox.isEnabled = false  // 無法與 IMKCandidates 協作，故禁用。
    }
  }

  // 這裡有必要加上這段處理，用來確保藉由偏好設定介面動過的 CNS 開關能夠立刻生效。
  // 所有涉及到語言模型開關的內容均需要這樣處理。
  @IBAction func toggleCNSSupport(_: Any) {
    LMMgr.setCNSEnabled(PrefMgr.shared.cns11643Enabled)
  }

  @IBAction func toggleSymbolInputEnabled(_: Any) {
    LMMgr.setSymbolEnabled(PrefMgr.shared.symbolInputEnabled)
  }

  @IBAction func toggleTrad2KangXiAction(_: Any) {
    if chkTrad2KangXi.state == .on, chkTrad2JISShinjitai.state == .on {
      PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggle()
    }
  }

  @IBAction func toggleTrad2JISShinjitaiAction(_: Any) {
    if chkTrad2KangXi.state == .on, chkTrad2JISShinjitai.state == .on {
      PrefMgr.shared.chineseConversionEnabled.toggle()
    }
  }

  @IBAction func updateBasicKeyboardLayoutAction(_: Any) {
    if let sourceID = basicKeyboardLayoutButton.selectedItem?.representedObject as? String {
      PrefMgr.shared.basicKeyboardLayout = sourceID
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
        PrefMgr.shared.appleLanguages = [language]
      } else {
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
      }

      NSLog("vChewing App self-terminated due to UI language change.")
      NSApp.terminate(nil)
    }
  }

  @IBAction func updateIMKCandidateEnableStatusAction(_: Any) {
    NSLog("vChewing App self-terminated due to enabling / disabling IMK candidate window.")
    NSApp.terminate(nil)
  }

  @IBAction func clickedWhetherIMEShouldNotFartToggleAction(_: Any) {
    IMEApp.buzz()
  }

  @IBAction func changeSelectionKeyAction(_ sender: Any) {
    guard
      let keys = (sender as AnyObject).stringValue?.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      .deduplicated
    else {
      selectionKeyComboBox.stringValue = PrefMgr.shared.candidateKeys
      return
    }
    guard let errorResult = CandidateKey.validate(keys: keys) else {
      PrefMgr.shared.candidateKeys = keys
      selectionKeyComboBox.stringValue = PrefMgr.shared.candidateKeys
      return
    }
    if let window = window {
      let alert = NSAlert(error: NSLocalizedString("Invalid Selection Keys.", comment: ""))
      alert.informativeText = errorResult
      alert.beginSheetModal(for: window) { _ in
        self.selectionKeyComboBox.stringValue = PrefMgr.shared.candidateKeys
      }
      IMEApp.buzz()
    }
  }

  @IBAction func resetSpecifiedUserDataFolder(_: Any) {
    LMMgr.resetSpecifiedUserDataFolder()
  }

  @IBAction func chooseUserDataFolderToSpecify(_: Any) {
    guard let window = window else { return }
    let dlgOpenPath = NSOpenPanel()
    dlgOpenPath.title = NSLocalizedString(
      "Choose your desired user data folder.", comment: ""
    )
    dlgOpenPath.showsResizeIndicator = true
    dlgOpenPath.showsHiddenFiles = true
    dlgOpenPath.canChooseFiles = false
    dlgOpenPath.canChooseDirectories = true
    dlgOpenPath.allowsMultipleSelection = false

    let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
      PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath)

    dlgOpenPath.beginSheetModal(for: window) { result in
      if result == NSApplication.ModalResponse.OK {
        guard let url = dlgOpenPath.url else { return }
        // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
        // 所以要手動補回來。
        var newPath = url.path
        newPath.ensureTrailingSlash()
        if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
          PrefMgr.shared.userDataFolderSpecified = newPath
          BookmarkManager.shared.saveBookmark(for: url)
          (NSApp.delegate as! AppDelegate).updateDirectoryMonitorPath()
        } else {
          IMEApp.buzz()
          if !bolPreviousFolderValidity {
            LMMgr.resetSpecifiedUserDataFolder()
          }
          return
        }
      } else {
        if !bolPreviousFolderValidity {
          LMMgr.resetSpecifiedUserDataFolder()
        }
        return
      }
    }
  }  // End IBAction
}

extension CtlPrefWindow: NSToolbarDelegate {
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
    // if #unavailable(macOS 10.13) { return [.ofGeneral, .ofExperience, .ofDictionary, .ofKeyboard] }
    // return [.ofGeneral, .ofExperience, .ofDictionary, .ofKeyboard, .ofDevZone]
    [.ofGeneral, .ofExperience, .ofDictionary, .ofKeyboard]
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
