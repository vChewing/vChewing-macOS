// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CandidateWindow
import IMKUtils
import InputMethodKit
import NotifierUI
import PopupCompositionBuffer
import Shared
import Shared_DarwinImpl
import ShiftKeyUpChecker
import SwiftExtension
import TooltipUI
import Typewriter

// MARK: - SessionProtocol

/// 輸入法控制模組，乃在輸入法端用以控制輸入行為的基礎型別。
///
/// IMKInputController 完全實現了相關協定所定義的內容。
/// 一般情況下，研發者不會複寫此型別，而是提供一個委任物件、
/// 藉此實現研發者想製作的方法/函式。協定方法的 IMKInputController 版本
/// 檢查委任物件是否實現了方法：若存在的話，就調用委任物件內的版本。
/// - Remark: 在輸入法的主函式中分配的 IMKServer 型別為客體應用程式創建的每個
/// 輸入會話創建一個控制器型別。因此，對於每個輸入會話，都有一個對應的 IMKInputController。
public protocol SessionProtocol: AnyObject, IMKInputControllerProtocol, CtlCandidateDelegate,
  SessionCoreProtocol where Handler: InputHandlerProtocol {
  static var current: Self? { get set }
  /// 標記狀態來聲明目前新增的詞彙是否需要賦以非常低的權重。
  static var areWeNerfing: Bool { get set }
  /// Shift 按鍵事件分析器的副本。
  /// - Remark: 警告：該工具必須為 Struct 且全專案只能有一個唯一初期化副本。否則會在動 Caps Lock 的時候誤以為是在摁 Shift。
  static var theShiftKeyDetector: ShiftKeyUpChecker { get set }
  /// 記錄當前輸入環境是縱排輸入還是橫排輸入。
  static var isVerticalTyping: Bool { get }
  /// 用以記錄最近存取過的十個客體（亂序），相關內容會在客體管理器當中用得到。
  static var recentClientBundleIdentifiers: [String: Int] { get set } // Has DidSet.
  /// 給所有副本共用的 isASCIIMode 追蹤用餐數。
  static var isASCIIModeForAllClients: Bool { get set }
  /// 一個共用辭典，專門用來給每個副本用的 isASCIIMode 追蹤用餐數。
  static var isASCIIModeForEachClient: [String: Bool] { get set }
  /// 偏好設定。
  var prefs: PrefMgrProtocol { get }
  /// 共用的 NSAlert 副本、用於在輸入法切換失敗時提示使用者修改系統偏好設定。
  var sharedAlertForInputModeToggling: NSAlert { get }
  /// 上一個被處理過的鍵盤事件。
  var previouslyHandledEvents: [KBEvent] { get set }
  /// 目前在用的的選字窗副本。
  var candidateUI: CtlCandidateProtocol? { get set }
  /// 工具提示視窗的副本。
  var tooltipInstance: any TooltipUIProtocol { get set }
  /// 浮動組字窗的副本。
  var popupCompositionBuffer: PopupCompositionBuffer { get set }
  /// 用來標記當前副本是否已處於活動狀態。
  var isActivated: Bool { get set }
  /// 當前副本的客體是否是輸入法本體？
  var isServingIMEItself: Bool { get set }
  /// 輸入調度模組的副本。
  var inputHandler: Handler? { get set }
  /// 最近一個被 set 的 marked text。
  var recentMarkedText: (text: NSAttributedString?, selectionRange: NSRange?) { get set }
  /// 當前選字窗是否為縱向。（縱排輸入時，只會啟用縱排選字窗。）
  var isVerticalCandidateWindow: Bool { get set }
  /// 當前客體應用是否採用 Web 技術構築（例：Electron）。
  var isClientElectronBased: Bool { get set }
  /// 用以存儲客體的 bundleIdentifier。
  /// 由於每次動態獲取都會耗時，所以這裡直接靜態記載之。
  var clientBundleIdentifier: String { get set }
  /// 用以記錄當前輸入法狀態的變數。
  var state: State { get set } // Has DidSet.
  /// 記錄當前輸入環境是縱排輸入還是橫排輸入。
  var isVerticalTyping: Bool { get set }
  /// InputMode 需要在每次出現內容變更的時候都連帶重設組字器與各項語言模組，
  /// 順帶更新 IME 模組及 UserPrefs 當中對於當前語言模式的記載。
  var inputMode: Shared.InputMode { get set }

  func initInputHandler()
}

extension SessionProtocol {
  public typealias ClientObj = IMKTextInput & NSObjectProtocol

  public static var isVerticalTyping: Bool { Self.current?.isVerticalTyping ?? false }

  public static func makeTooltipUI() -> TooltipUIProtocol {
    TooltipUI_LateCocoa()
  }

  public var selectionKeys: String {
    // 磁帶模式的 `%quick` 有單獨的選字鍵判定，會在資料不合規時使用 1234567890 選字鍵。
    cassetteQuick: if state.type == .ofInputting, state.isCandidateContainer {
      guard PrefMgr.shared.cassetteEnabled else { break cassetteQuick }
      guard let cinCandidateKey = inputMode.langModel.cassetteSelectionKey,
            PrefMgr.shared.validate(candidateKeys: cinCandidateKey) == nil
      else {
        return "1234567890"
      }
      return cinCandidateKey
    }
    return PrefMgr.shared.candidateKeys
  }

  /// 給每個副本用的 isASCIIMode 追蹤用餐數。
  public var isASCIIModeForThisClient: Bool {
    get {
      Self.isASCIIModeForEachClient[clientBundleIdentifier] ?? false
    }
    set {
      Self.isASCIIModeForEachClient[clientBundleIdentifier] = newValue
    }
  }

  /// 當前這個 SessionCtl 副本是否處於英數輸入模式。
  public var isASCIIMode: Bool {
    get {
      prefs.shareAlphanumericalModeStatusAcrossClients
        ? Self.isASCIIModeForAllClients : isASCIIModeForThisClient
    }
    set {
      if PrefMgr.shared.shareAlphanumericalModeStatusAcrossClients {
        Self.isASCIIModeForAllClients = newValue
      } else {
        isASCIIModeForThisClient = newValue
      }
      resetInputHandler()
      setKeyLayout()
    }
  }

  /// 重設輸入調度模組，會將當前尚未遞交的內容遞交出去。
  public func resetInputHandler(forceComposerCleanup forceCleanup: Bool = false) {
    guard let inputHandler = inputHandler else { return }
    var textToCommit = ""
    // 過濾掉尚未完成拼寫的注音。
    let sansReading: Bool =
      (state.type == .ofInputting)
        && (PrefMgr.shared.trimUnfinishedReadingsOnCommit || forceCleanup)
    if state.hasComposition {
      textToCommit = inputHandler.generateStateOfInputting(sansReading: sansReading).displayedText
    }
    // 威注音不再在這裡對 IMKTextInput 客體黑名單當中的應用做資安措施。
    // 有相關需求者，請在切換掉輸入法或者切換至新的客體應用之前敲一下 Shift+Delete。
    switchState(.ofCommitting(textToCommit: textToCommit))
  }

  /// 專門用來就地切換繁簡模式的函式。
  /// This method is non-ObjC, requiring an ObjC wrapper.
  public func toggleInputMode() {
    guard let client: IMKTextInput = client() else { return }
    defer { isASCIIMode = false }
    let nowMode = IMEApp.currentInputMode
    guard nowMode != .imeModeNULL else { return }
    modeCheck: for neta in TISInputSource.allRegisteredInstancesOfThisInputMethod {
      guard !neta.isActivated else { continue }
      osCheck: if #unavailable(macOS 12) {
        neta.activate()
        if !neta.isActivated {
          break osCheck
        }
        break modeCheck
      }
      let result = sharedAlertForInputModeToggling.runModal()
      NSApp.popup()
      if result == NSApplication.ModalResponse.alertFirstButtonReturn {
        neta.activate()
      }
      return
    }
    let status = "NotificationSwitchRevolver".localized
    asyncOnMain {
      Notifier.notify(
        message: nowMode.reversed.localizedDescription + "\n" + status
      )
    }
    client.selectMode(nowMode.reversed.rawValue)
  }

  /// 所有建構子都會執行的共用部分，在 super.init() 之後執行。
  public func construct(client theClient: (IMKTextInput & NSObjectProtocol)? = nil) {
    asyncOnMain { [weak self] in
      guard let self = self else { return }
      // 關掉所有之前的副本的視窗。
      Self.current?.hidePalettes()
      Self.current = self
      self.initInputHandler()
      LMMgr.syncLMPrefs()
      // 下述兩行很有必要，否則輸入法會在手動重啟之後無法立刻生效。
      let maybeClient = theClient ?? self.client()
      self.activateServer(maybeClient)
      // GCD 會觸發 didSet，所以不用擔心。
      self.inputMode = .init(rawValue: PrefMgr.shared.mostRecentInputMode) ?? .imeModeNULL
    }
  }

  @discardableResult
  public func updateVerticalTypingStatus() -> CGRect {
    guard let client = client() else {
      isVerticalTyping = false
      return .seniorTheBeast
    }
    var textFrame = CGRect.seniorTheBeast
    let attributes: [AnyHashable: Any]? = client.attributes(
      forCharacterIndex: 0,
      lineHeightRectangle: &textFrame
    )
    let result = (attributes?[IMKTextOrientationName] as? NSNumber)?.intValue == 0 || false
    isVerticalTyping = result
    return textFrame
  }

  /// 強制重設當前鍵盤佈局、使其與偏好設定同步。
  public func setKeyLayout() {
    asyncOnMain { [weak self] in
      guard let self = self else { return }
      guard let client = self.client(), !self.isServingIMEItself else { return }
      if self.isASCIIMode, IMKHelper.isDynamicBasicKeyboardLayoutEnabled {
        client.overrideKeyboard(withKeyboardNamed: PrefMgr.shared.alphanumericalKeyboardLayout)
        return
      }
      client.overrideKeyboard(withKeyboardNamed: PrefMgr.shared.basicKeyboardLayout)
    }
  }

  public static func callError(_ logMessage: String) {
    vCLog(logMessage)
    IMEApp.buzz()
  }

  public func performServerDeactivation() {
    let deactivation = { [weak self] in
      guard let self = self else { return }
      self.isActivated = false
      self.resetInputHandler() // 這條會自動搞定 Empty 狀態。
      self.switchState(.ofDeactivated())
      self.inputHandler = nil
      // IMK 選字窗可以不用 nil，不然反而會出問題。反正 IMK 選字窗記憶體開銷可以不計。
      if self.candidateUI is CtlCandidateTDK {
        self.candidateUI = nil
      }
    }
    if UserDefaults.pendingUnitTests {
      deactivation()
    } else {
      asyncOnMain(execute: deactivation)
    }
  }

  public func performServerActivation(client: ClientObj?) {
    hidePalettes()
    let activation1 = { [weak self] in
      guard let self = self else { return }
      if let senderBundleID: String = client?.bundleIdentifier() {
        vCLog("activateServer(\(senderBundleID))")
        self.isServingIMEItself = Bundle.main.bundleIdentifier == senderBundleID
        self.clientBundleIdentifier = senderBundleID
        // 只要使用者沒有勾選檢查更新、沒有主動做出要檢查更新的操作，就不要檢查更新。
        if PrefMgr.shared.checkUpdateAutomatically {
          AppDelegate.shared.checkUpdate(forced: false) {
            senderBundleID == "com.apple.SecurityAgent"
          }
        }
        // 檢查當前客體軟體是否採用 Web 技術構築（例：Electron）。
        self.isClientElectronBased =
          NSRunningApplication
            .isElectronBasedApp(identifier: senderBundleID)
      }
    }
    if UserDefaults.pendingUnitTests {
      activation1()
    } else {
      asyncOnMain(execute: activation1)
    }
    let activation2 = {
      // 自動啟用肛塞（廉恥模式），除非這一天是愚人節。
      if !Date.isTodayTheDate(from: 0_401), !PrefMgr.shared.shouldNotFartInLieuOfBeep {
        PrefMgr.shared.shouldNotFartInLieuOfBeep = true
      }
    }
    if UserDefaults.pendingUnitTests {
      activation2()
    } else {
      asyncOnMain(execute: activation2)
    }
    let activation3 = { [weak self] in
      guard let self = self else { return }
      if self.inputMode != IMEApp.currentInputMode {
        self.inputMode = IMEApp.currentInputMode
      }
    }
    if UserDefaults.pendingUnitTests {
      activation3()
    } else {
      asyncOnMain(execute: activation3)
    }
    let activation4 = { [weak self] in
      guard let self = self else { return }
      // 清理掉上一個會話的選字窗及其選單。
      if self.candidateUI is CtlCandidateTDK {
        self.candidateUI = nil
      }
      CtlCandidateTDK.currentMenu?.cancelTracking()
      CtlCandidateTDK.currentMenu = nil
      CtlCandidateTDK.currentWindow?.orderOut(nil)
      CtlCandidateTDK.currentWindow = nil
    }
    if UserDefaults.pendingUnitTests {
      activation4()
    } else {
      asyncOnMain(execute: activation4)
    }
    let activation5 = { [weak self] in
      guard let self = self else { return }
      if self.isActivated { return }

      // 這裡不需要 setValue()，因為 IMK 會在自動呼叫 activateServer() 之後自動執行 setValue()。
      self.initInputHandler()
      LMMgr.syncLMPrefs()

      Self.theShiftKeyDetector.toggleWithLShift =
        PrefMgr.shared
          .togglingAlphanumericalModeWithLShift
      Self.theShiftKeyDetector.toggleWithRShift =
        PrefMgr.shared
          .togglingAlphanumericalModeWithRShift

      if self.isASCIIMode, !IMEApp.isKeyboardJIS {
        if #available(macOS 10.15, *) {
          if !Self.theShiftKeyDetector.enabled {
            self.isASCIIMode = false
          }
        } else {
          self.isASCIIMode = false
        }
      }

      let memoryCheck = {
        _ = AppDelegate.shared.checkMemoryUsage()
      }
      if UserDefaults.pendingUnitTests {
        memoryCheck()
      } else {
        asyncOnMain(execute: memoryCheck)
      }

      self.state = .ofEmpty()
      self.isActivated = true // 登記啟用狀態。
      self.setKeyLayout()
    }
    if UserDefaults.pendingUnitTests {
      activation5()
    } else {
      asyncOnMain(execute: activation5)
    }
  }
}
