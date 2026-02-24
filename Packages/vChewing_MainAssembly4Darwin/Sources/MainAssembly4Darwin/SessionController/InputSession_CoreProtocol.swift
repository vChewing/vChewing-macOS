// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

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
  /// 輸入調度模組的副本。
  var inputHandler: Handler? { get set }
  /// 當前副本的客體是否是輸入法本體？
  var isServingIMEItself: Bool { get set }
  /// 用以存儲客體的 bundleIdentifier。
  /// 由於每次動態獲取都會耗時，所以這裡直接靜態記載之。
  var clientBundleIdentifier: String { get set }
  /// 最近的 Client 的 ObjectID，以記憶體位址來辨識。
  var clientObjectIdentifier: ObjectIdentifier? { get set }
  /// 當前客體應用是否採用 Web 技術構築（例：Electron）。
  var isClientElectronBased: Bool { get set }
  /// 共用的 NSAlert 副本、用於在輸入法切換失敗時提示使用者修改系統偏好設定。
  var sharedAlertForInputModeToggling: NSAlert { get }
  /// 標記狀態來聲明目前新增的詞彙是否需要賦以非常低的權重。
  static var areWeNerfing: Bool { get set }
  /// 用以記錄最近存取過的十個客體（亂序），相關內容會在客體管理器當中用得到。
  static var recentClientBundleIdentifiers: [String: Int] { get set } // Has DidSet.
  /// 給所有副本共用的 isASCIIMode 追蹤用餐數。
  static var isASCIIModeForAllClients: Bool { get set }
  /// 一個共用辭典，專門用來給每個副本用的 isASCIIMode 追蹤用餐數。
  static var isASCIIModeForEachClient: [String: Bool] { get set }
  /// 偏好設定。
  var prefs: PrefMgrProtocol { get set }
  /// 上一個被處理過的鍵盤事件。
  var previouslyHandledEvents: [KBEvent] { get set }
  /// 用來標記當前副本是否已處於活動狀態。
  var isActivated: Bool { get set }
  /// 最近一個被 set 的 marked text。
  var recentMarkedText: (text: NSAttributedString?, selectionRange: NSRange?) { get set }
  /// 當前選字窗是否為縱向。（縱排輸入時，只會啟用縱排選字窗。）
  var isVerticalCandidateWindow: Bool { get }
  /// 記錄當前輸入環境是縱排輸入還是橫排輸入。
  var isVerticalTyping: Bool { get set }
  /// InputMode 需要在每次出現內容變更的時候都連帶重設組字器與各項語言模組，
  /// 順帶更新 IME 模組及 UserPrefs 當中對於當前語言模式的記載。
  var inputMode: Shared.InputMode { get set }
  /// 記錄語言模型配置同步專用函式。
  var synchronizer4LMPrefs: (() -> ())? { get set }
  /// 蜂鳴專用函式。
  var buzzer: (() -> ())? { get set }
  /// 上次實際套用至 client 的鍵盤佈局名稱，用以跳過重複的 overrideKeyboard() 呼叫。
  var lastAppliedKeyboardLayout: String? { get set }

  func initInputHandler()
}

nonisolated extension SessionProtocol {
  public typealias ClientObj = IMKTextInput & NSObjectProtocol & NSObject
}

extension SessionProtocol {
  /// 記錄當前輸入環境是縱排輸入還是橫排輸入。
  public static var isVerticalTyping: Bool { Self.current?.isVerticalTyping ?? false }

  public var selectionKeys: String {
    // 磁帶模式的 `%quick` 有單獨的選字鍵判定，會在資料不合規時使用 1234567890 選字鍵。
    cassetteQuick: if state.type == .ofInputting, state.isCandidateContainer {
      guard prefs.cassetteEnabled else { break cassetteQuick }
      guard let cinCandidateKey = inputMode.langModel.cassetteSelectionKey,
            prefs.validate(candidateKeys: cinCandidateKey) == nil
      else {
        return "1234567890"
      }
      return cinCandidateKey
    }
    // 如果有啟用 JKHL 鍵的特殊行為的話，則不再將 JKHL 鍵盤視為選字鍵。
    // 注意：無論 candidateStateJKHLBehavior 是 1 還是 2，JKHL 四個鍵都有特定用途，
    // 因此都需要排除在選字鍵之外。
    if prefs.candidateStateJKHLBehavior != 0 {
      return prefs.candidateKeys.filter {
        !"jkhl".contains($0.lowercased())
      }
    }
    return prefs.candidateKeys
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
      if prefs.shareAlphanumericalModeStatusAcrossClients {
        Self.isASCIIModeForAllClients = newValue
      } else {
        isASCIIModeForThisClient = newValue
      }
      resetInputHandler()
      setKeyLayout()
    }
  }

  public func syncCurrentSessionID() {
    ui?.currentSessionID = id
  }

  /// 重設輸入調度模組，會將當前尚未遞交的內容遞交出去。
  public func resetInputHandler(
    forceComposerCleanup forceCleanup: Bool = false,
    commitExisting: Bool = true
  ) {
    guard let inputHandler = inputHandler else { return }
    guard commitExisting else {
      switchState(.ofEmpty())
      return
    }
    var textToCommit = ""
    // 過濾掉尚未完成拼寫的注音。
    let sansReading: Bool =
      (state.type == .ofInputting)
        && (prefs.trimUnfinishedReadingsOnCommit || forceCleanup)
    if state.hasComposition {
      textToCommit = inputHandler
        .generateStateOfInputting(sansReading: sansReading)
        .displayedTextConverted
    }
    // 唯音不再在這裡對 IMKTextInput 客體黑名單當中的應用做資安措施。
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
    let status = "NotificationSwitchRevolver".i18n
    asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
      Notifier.notify(
        message: nowMode.reversed.localizedDescription + "\n" + status
      )
    }
    client.selectMode(nowMode.reversed.rawValue)
  }

  /// 所有建構子都會執行的共用部分，在 super.init() 之後執行。
  public func construct(client theClient: (IMKTextInput & NSObjectProtocol)? = nil) {
    // AsyncOnMain 自身的 Lambda Expression 可能與 Swift 6.2 的 Concurrency 相性不太好。
    // 於是這裡單獨判斷。
    if UserDefaults.pendingUnitTests {
      constructSansAsync(client: theClient)
    } else {
      asyncOnMain { [weak self] in
        self?.constructSansAsync(client: theClient)
      }
    }
  }

  public func constructSansAsync(client theClient: (IMKTextInput & NSObjectProtocol)? = nil) {
    // Self.current?.hidePalettes() <- 該操作由 activateServer() 全權負責。
    Self.current = self
    initInputHandler()
    synchronizer4LMPrefs?()
    // 下述兩行很有必要，否則輸入法會在手動重啟之後無法立刻生效。
    let maybeClient = theClient ?? client()
    activateServer(maybeClient)
    // GCD 會觸發 didSet，所以不用擔心。
    inputMode = .init(rawValue: prefs.mostRecentInputMode) ?? .imeModeNULL
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
    let imkTO = (attributes?[IMKTextOrientationName] as? NSNumber)?.intValue
    isVerticalTyping = imkTO == 0
    return textFrame
  }

  /// 強制重設當前鍵盤佈局、使其與偏好設定同步。
  /// 內部會比對目標佈局與上次實際套用的佈局，若相同則跳過 `overrideKeyboard()` 阻塞操作。
  public func setKeyLayout() {
    let targetLayout: String =
      (isASCIIMode && IMKHelper.isDynamicBasicKeyboardLayoutEnabled)
        ? prefs.alphanumericalKeyboardLayout
        : prefs.basicKeyboardLayout
    guard targetLayout != lastAppliedKeyboardLayout else { return }
    lastAppliedKeyboardLayout = targetLayout
    asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) { [weak self] in
      guard let this = self else { return }
      guard let client = this.client(), !this.isServingIMEItself else { return }
      client.overrideKeyboard(withKeyboardNamed: targetLayout)
    }
  }

  public func callError(_ logMessage: String) {
    vCLog(logMessage)
    buzzer?()
  }

  public func performServerDeactivation() {
    guard Self.current?.id != id else { return }
    isActivated = false
    // `resetInputHandler()` 會自動搞定 Empty 狀態。
    resetInputHandler(commitExisting: false)
    // macOS 不再處理 deactivated 狀態。
    // 選字窗不用管，交給新的 Session 的 ActivateServer 來管理。
  }

  public func isStillTheSameClientObj(_ client: NSObject?) -> Bool {
    guard let client else { return false }
    return clientObjectIdentifier == .init(client)
  }

  public func updateClientObjectIdentifier(_ client: ClientObj?) {
    guard let client else { return }
    clientObjectIdentifier = .init(client)
  }

  public func performServerActivation(client: ClientObj?) {
    // MARK: 快速路徑 — 最佳化 CapsLock 中英頻繁切換的場景。

    // 當目前的副本已處於活動狀態、仍為當前副本、且輸入調度模組仍存在時，
    // 僅執行輕量更新即可，省去 initInputHandler()、asyncOnMain 任務排程等高成本操作。
    // 原理：performServerDeactivation() 對當前副本是 no-op（因 guard 提前返回），
    // 故 isActivated 仍為 true、inputHandler 仍然存在，無需重新初始化。
    if isActivated, Self.current?.id == id, inputHandler != nil {
      syncCurrentSessionID()
      let resolvedInputMode = IMEApp.currentInputMode
      if inputMode != resolvedInputMode {
        inputMode = resolvedInputMode
      }
      state = .ofEmpty()
      setKeyLayout()
      return
    }

    // MARK: 完整路徑 — 首次啟用或由其他副本接管後的重新啟用。

    hidePalettes()
    syncCurrentSessionID()
    Self.current = self
    let this = self
    if let senderBundleID: String = client?.bundleIdentifier() {
      vCLog("activateServer(\(senderBundleID))")
      this.isServingIMEItself = Bundle.main.bundleIdentifier == senderBundleID
      this.clientBundleIdentifier = senderBundleID
      // 只要使用者沒有勾選檢查更新、沒有主動做出要檢查更新的操作，就不要檢查更新。
      if this.prefs.checkUpdateAutomatically {
        asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
          AppDelegate.shared.checkUpdate(forced: false) {
            senderBundleID == "com.apple.SecurityAgent"
          }
        }
      }
      // 檢查當前客體軟體是否採用 Web 技術構築（例：Electron）。
      // isElectronBasedApp 涉及 NSRunningApplication 列舉、Bundle plist 讀取、
      // FileManager 目錄掃描等 I/O 操作，延遲至下一個 RunLoop 迭代以避免阻塞啟用流程。
      this.isClientElectronBased = false
      asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) { [weak self] in
        self?.isClientElectronBased =
          NSRunningApplication
            .isElectronBasedApp(identifier: senderBundleID)
      }
    }
    this.updateClientObjectIdentifier(client)
    // 自動啟用肛塞（廉恥模式），除非這一天是愚人節。
    // Date.isTodayTheDate 會建立 DateFormatter，延遲處理以避免阻塞。
    asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) { [weak self] in
      guard let this = self else { return }
      if !Date.isTodayTheDate(from: 0_401), !this.prefs.shouldNotFartInLieuOfBeep {
        this.prefs.shouldNotFartInLieuOfBeep = true
      }
    }
    let resolvedInputMode = IMEApp.currentInputMode
    if this.inputMode != resolvedInputMode {
      this.inputMode = resolvedInputMode
    }

    // 下面這段步驟 無論 isActivated 是否為 true 都得執行。
    // 不然的話，可能會在 FileSaveDialog 內無法正常打字（所有 events 全部被忽略掉）。
    // 這裡不需要 setValue()，因為 IMK 會在自動呼叫 activateServer() 之後自動執行 setValue()。
    this.initInputHandler()
    this.synchronizer4LMPrefs?()
    let shiftKeyDetector = this.ui?.shiftKeyUpChecker
    if let shiftKeyDetector {
      shiftKeyDetector.toggleWithLShift =
        this.prefs
          .togglingAlphanumericalModeWithLShift
      shiftKeyDetector.toggleWithRShift =
        this.prefs
          .togglingAlphanumericalModeWithRShift
    }
    if this.isASCIIMode, !IMEApp.isKeyboardJIS {
      if #available(macOS 10.15, *) {
        if let shiftKeyDetector, !shiftKeyDetector.enabled {
          this.isASCIIMode = false
        }
      } else {
        this.isASCIIMode = false
      }
    }

    this.state = .ofEmpty()
    this.isActivated = true // 登記啟用狀態。
    this.setKeyLayout()

    if !UserDefaults.pendingUnitTests {
      asyncOnMain {
        AppDelegate.shared.checkMemoryUsage()
      }
    }
  }
}
