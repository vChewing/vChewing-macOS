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

// InputMethodServerPreferencesWindowControllerClass 非必需。

class CtlPrefWindow: NSWindowController, NSWindowDelegate {
  @IBOutlet var uiLanguageButton: NSPopUpButton!
  @IBOutlet var parserButton: NSPopUpButton!
  @IBOutlet var basicKeyboardLayoutButton: NSPopUpButton!
  @IBOutlet var selectionKeyComboBox: NSComboBox!
  @IBOutlet var chkTrad2KangXi: NSButton!
  @IBOutlet var chkTrad2JISShinjitai: NSButton!
  @IBOutlet var lblCurrentlySpecifiedUserDataFolder: NSTextFieldCell!
  @IBOutlet var tglControlDevZoneIMKCandidate: NSButton!
  @IBOutlet var cmbCandidateFontSize: NSPopUpButton!
  @IBOutlet var chkFartSuppressor: NSButton!

  @IBOutlet var chkRevLookupInCandidateWindow: NSButton!
  @IBOutlet var btnBrowseFolderForUserPhrases: NSButton!
  @IBOutlet var txtUserPhrasesFolderPath: NSTextField!
  @IBOutlet var lblUserPhraseFolderChangeDescription: NSTextField!

  @IBOutlet var cmbPEInputModeMenu: NSPopUpButton!
  @IBOutlet var cmbPEDataTypeMenu: NSPopUpButton!
  @IBOutlet var btnPEReload: NSButton!
  @IBOutlet var btnPEConsolidate: NSButton!
  @IBOutlet var btnPESave: NSButton!
  @IBOutlet var btnPEAdd: NSButton!
  @IBOutlet var btnPEOpenExternally: NSButton!
  @IBOutlet var tfdPETextEditor: NSTextView!
  @IBOutlet var txtPECommentField: NSTextField!
  @IBOutlet var txtPEField1: NSTextField!
  @IBOutlet var txtPEField2: NSTextField!
  @IBOutlet var txtPEField3: NSTextField!
  var isLoading = false {
    didSet { setPEUIControlAvailability() }
  }

  @IBOutlet var vwrGeneral: NSView!
  @IBOutlet var vwrCandidates: NSView!
  @IBOutlet var vwrBehavior: NSView!
  @IBOutlet var vwrDictionary: NSView!
  @IBOutlet var vwrPhrases: NSView!
  @IBOutlet var vwrCassette: NSView!
  @IBOutlet var vwrKeyboard: NSView!
  @IBOutlet var vwrDevZone: NSView!

  public static var shared: CtlPrefWindow?

  static func show() {
    let resetPhraseEditor: Bool = shared?.window == nil || !(shared?.window?.isVisible ?? false) || shared == nil
    if shared == nil { shared = CtlPrefWindow(windowNibName: "frmPrefWindow") }
    guard let shared = shared, let sharedWindow = shared.window else { return }
    sharedWindow.delegate = shared
    if !sharedWindow.isVisible {
      shared.windowDidLoad()
    }
    sharedWindow.setPosition(vertical: .top, horizontal: .right, padding: 20)
    sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
    sharedWindow.level = .statusBar
    shared.showWindow(shared)
    if resetPhraseEditor { shared.initPhraseEditor() }
    NSApp.activate(ignoringOtherApps: true)
  }

  private var currentLanguageSelectItem: NSMenuItem?

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.setPosition(vertical: .top, horizontal: .right, padding: 20)

    chkFartSuppressor.isHidden = !Date.isTodayTheDate(from: 0401)
    chkFartSuppressor.isEnabled = !chkFartSuppressor.isHidden

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
    toolbar.selectedItemIdentifier = PrefUITabs.tabGeneral.toolbarIdentifier
    toolbar.showsBaselineSeparator = true
    if #available(macOS 11.0, *) {
      window?.toolbarStyle = .preference
    }
    window?.toolbar = toolbar
    window?.title = preferencesTitleName
    window?.titlebarAppearsTransparent = false
    use(view: vwrGeneral, animate: false)

    lblCurrentlySpecifiedUserDataFolder.placeholderString = LMMgr.dataFolderPath(
      isDefaultFolder: true)

    // Credit: Hiraku Wang (for the implementation of the UI language select support in Cocoa PrefWindow.
    // Note: The SwiftUI PrefWindow has the same feature implemented by Shiki Suen.
    do {
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
    }

    refreshBasicKeyboardLayoutMenu()
    refreshParserMenu()

    selectionKeyComboBox.usesDataSource = false
    selectionKeyComboBox.removeAllItems()
    selectionKeyComboBox.addItems(withObjectValues: CandidateKey.suggestions)

    var candidateSelectionKeys = PrefMgr.shared.candidateKeys
    if candidateSelectionKeys.isEmpty {
      candidateSelectionKeys = CandidateKey.defaultKeys
    }

    selectionKeyComboBox.stringValue = candidateSelectionKeys
    if PrefMgr.shared.useIMKCandidateWindow {
      selectionKeyComboBox.isEnabled = false // 無法與 IMKCandidates 協作，故禁用。
    }

    initPhraseEditor()
  }

  func windowWillClose(_: Notification) {
    tfdPETextEditor.string = ""
  }

  func refreshBasicKeyboardLayoutMenu() {
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
  }

  func refreshParserMenu() {
    var defaultParserItem: NSMenuItem?
    var chosenParserItem: NSMenuItem?
    parserButton.menu?.removeAllItems()
    let basicParserID = PrefMgr.shared.keyboardParser
    KeyboardParser.allCases.forEach { item in
      if [7, 100].contains(item.rawValue) {
        parserButton.menu?.addItem(NSMenuItem.separator())
      }
      let menuItem = NSMenuItem()
      menuItem.title = item.localizedMenuName
      menuItem.tag = item.rawValue
      if item.rawValue == 0 { defaultParserItem = menuItem }
      if basicParserID == item.rawValue { chosenParserItem = menuItem }
      parserButton.menu?.addItem(menuItem)
    }
    parserButton.select(chosenParserItem ?? defaultParserItem)
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

  @IBAction func updateParserAction(_: Any) {
    if let sourceID = parserButton.selectedItem?.tag as? Int {
      PrefMgr.shared.keyboardParser = sourceID
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
    let content = String(
      format: NSLocalizedString(
        "You are about to uncheck this fart suppressor. You are responsible for all consequences lead by letting people nearby hear the fart sound come from your computer. We strongly advise against unchecking this in any public circumstance that prohibits NSFW netas.",
        comment: ""
      ))
    let alert = NSAlert(error: NSLocalizedString("Warning", comment: ""))
    alert.informativeText = content
    alert.addButton(withTitle: NSLocalizedString("Uncheck", comment: ""))
    if #available(macOS 11, *) {
      alert.buttons.forEach { button in
        button.hasDestructiveAction = true
      }
    }
    alert.addButton(withTitle: NSLocalizedString("Leave it checked", comment: ""))
    if let window = window, !PrefMgr.shared.shouldNotFartInLieuOfBeep {
      PrefMgr.shared.shouldNotFartInLieuOfBeep = true
      alert.beginSheetModal(for: window) { result in
        switch result {
        case .alertFirstButtonReturn:
          PrefMgr.shared.shouldNotFartInLieuOfBeep = false
        case .alertSecondButtonReturn:
          PrefMgr.shared.shouldNotFartInLieuOfBeep = true
        default: break
        }
        IMEApp.buzz()
      }
      return
    }
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

  @IBAction func toggledExternalFactoryPlistDataOnOff(_: NSButton) {
    LMMgr.reloadFactoryDictionaryPlists()
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
          AppDelegate.shared.updateDirectoryMonitorPath()
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
  }

  @IBAction func onToggleCassetteMode(_: Any) {
    if PrefMgr.shared.cassetteEnabled, !LMMgr.checkCassettePathValidity(PrefMgr.shared.cassettePath) {
      if let window = window {
        IMEApp.buzz()
        let alert = NSAlert(error: NSLocalizedString("Path invalid or file access error.", comment: ""))
        alert.informativeText = NSLocalizedString(
          "Please reconfigure the cassette path to a valid one before enabling this mode.", comment: ""
        )
        alert.beginSheetModal(for: window) { _ in
          LMMgr.resetCassettePath()
          PrefMgr.shared.cassetteEnabled = false
        }
      }
    } else {
      LMMgr.loadCassetteData()
    }
  }

  @IBAction func resetSpecifiedCassettePath(_: Any) {
    LMMgr.resetCassettePath()
  }

  @IBAction func chooseCassettePath(_: Any) {
    guard let window = window else { return }
    let dlgOpenFile = NSOpenPanel()
    dlgOpenFile.title = NSLocalizedString(
      "Choose your desired cassette file path.", comment: ""
    )
    dlgOpenFile.showsResizeIndicator = true
    dlgOpenFile.showsHiddenFiles = true
    dlgOpenFile.canChooseFiles = true
    dlgOpenFile.canChooseDirectories = false
    dlgOpenFile.allowsMultipleSelection = false
    dlgOpenFile.allowedFileTypes = ["cin2", "vcin", "cin"]
    dlgOpenFile.allowsOtherFileTypes = true

    let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
      PrefMgr.shared.cassettePath.expandingTildeInPath)

    dlgOpenFile.beginSheetModal(for: window) { result in
      if result == NSApplication.ModalResponse.OK {
        guard let url = dlgOpenFile.url else { return }
        if LMMgr.checkCassettePathValidity(url.path) {
          PrefMgr.shared.cassettePath = url.path
          LMMgr.loadCassetteData()
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
}

// MARK: - NSToolbarDelegate Methods

extension CtlPrefWindow: NSToolbarDelegate {
  func use(view newView: NSView, animate: Bool = true) {
    guard let window = window, let existingContentView = window.contentView else { return }
    let temporaryViewOld = NSView(frame: existingContentView.frame)
    window.contentView = temporaryViewOld
    var newWindowRect = NSRect(origin: window.frame.origin, size: newView.bounds.size)
    newWindowRect.size.height += kWindowTitleHeight
    newWindowRect.origin.y = window.frame.maxY - newWindowRect.height
    window.setFrame(newWindowRect, display: true, animate: animate)
    window.contentView = newView
  }

  var toolbarIdentifiers: [NSToolbarItem.Identifier] {
    PrefUITabs.allCases.filter {
      $0 != .tabOutput
    }.map(\.toolbarIdentifier)
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

  @objc func updateTab(_ target: NSToolbarItem) {
    guard let tab = PrefUITabs.fromInt(target.tag) else { return }
    switch tab {
    case .tabGeneral: use(view: vwrGeneral)
    case .tabCandidates: use(view: vwrCandidates)
    case .tabBehavior: use(view: vwrBehavior)
    case .tabOutput: return
    case .tabDictionary: use(view: vwrDictionary)
    case .tabPhrases: use(view: vwrPhrases)
    case .tabCassette: use(view: vwrCassette)
    case .tabKeyboard: use(view: vwrKeyboard)
    case .tabDevZone: use(view: vwrDevZone)
    }
    window?.toolbar?.selectedItemIdentifier = tab.toolbarIdentifier
  }

  func toolbar(
    _: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar _: Bool
  ) -> NSToolbarItem? {
    guard let tab = PrefUITabs(rawValue: itemIdentifier.rawValue) else { return nil }
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.target = self
    item.image = tab.icon
    item.label = tab.i18nTitle
    item.tag = tab.cocoaTag
    item.action = #selector(updateTab(_:))
    return item
  }
}
