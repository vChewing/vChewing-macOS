// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - SessionProtocol

/// 輸入法控制模組，乃在輸入法端用以控制輸入行為的基礎型別。
///
/// IMKInputController 完全實現了相關協定所定義的內容。
/// 一般情況下，研發者不會複寫此型別，而是提供一個委任物件、
/// 藉此實現研發者想製作的方法/函式。協定方法的 IMKInputController 版本
/// 檢查委任物件是否實現了方法：若存在的話，就調用委任物件內的版本。
/// - Remark: 在輸入法的主函式中分配的 IMKServer 型別為客體應用程式創建的每個
/// 輸入會話創建一個控制器型別。因此，對於每個輸入會話，都有一個對應的 IMKInputController。
public protocol SessionProtocol: AnyObject, CtlCandidateDelegate,
  SessionCoreProtocol {
  static var current: Self? { get set }
  /// 當前副本的客體是否是輸入法本體？
  var isServingIMEItself: Bool { get set }
  /// 用以存儲客體的 bundleIdentifier。
  /// 由於每次動態獲取都會耗時，所以這裡直接靜態記載之。
  var clientBundleIdentifier: String { get set }
  /// 最近的 Client 的 ObjectID，以記憶體位址來辨識。
  var clientProxyObjectIdentifier: ObjectIdentifier? { get set }
  /// 當前客體應用是否採用 Web 技術構築（例：Electron）。
  var isClientElectronBased: Bool { get set }
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
  /// 取得當前客戶端 proxy（跨平台抽象）。
  var clientProxy: (any SessionClientProxy)? { get }

  func initInputHandler()
  func hidePalettes()
  func replacementRange() -> NSRange
}

extension SessionProtocol {
  /// 記錄當前輸入環境是縱排輸入還是橫排輸入。
  public static var isVerticalTyping: Bool { Self.current?.isVerticalTyping ?? false }

  public var selectionKeys: String {
    // 磁帶模式的 `%quick` 有單獨的選字鍵判定，會在資料不合規時使用 1234567890 選字鍵。
    cassetteQuick: if state.type == .ofInputting, state.isCandidateContainer {
      guard prefs.cassetteEnabled else { break cassetteQuick }
      guard let cinCandidateKey = inputMode.lexicon.cassetteSelectionKey,
            SessionHost.shared.validateCandidateKeys(prefs, cinCandidateKey) == nil
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

  /// 當前這個 Session 副本是否處於英數輸入模式。
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

  /// 所有建構子都會執行的共用部分，在 super.init() 之後執行。
  public func construct(clientProxy theClientProxy: (any SessionClientProxy)? = nil) {
    // AsyncOnMain 自身的 Lambda Expression 可能與 Swift 6.2 的 Concurrency 相性不太好。
    // 於是這裡單獨判斷。
    if UserDefaults.pendingUnitTests {
      constructSansAsync(clientProxy: theClientProxy)
    } else {
      asyncOnMain { [weak self] in
        self?.constructSansAsync(clientProxy: theClientProxy)
      }
    }
  }

  public func constructSansAsync(clientProxy theClientProxy: (any SessionClientProxy)? = nil) {
    // Self.current?.hidePalettes() <- 該操作由 activateServer() 全權負責。
    Self.current = self
    initInputHandler()
    synchronizer4LMPrefs?()
    // 下述兩行很有必要，否則輸入法會在手動重啟之後無法立刻生效。
    if (theClientProxy ?? clientProxy) != nil {
      performServerActivation()
    }
    // GCD 會觸發 didSet，所以不用擔心。
    inputMode = .init(rawValue: prefs.mostRecentInputMode) ?? .imeModeNULL
  }

  @discardableResult
  public func updateVerticalTypingStatus() -> CGRect {
    // `textFrame` 的尺寸不能是 0，否則 `attributes()` 在某些客體上的不良實作可能會炸掉客體。
    // 所以需要使用 `CGRect.seniorTheBeast` 作為基底資料值。
    if let clientProxy {
      var textFrame = CGRect.seniorTheBeast
      let attributes = clientProxy.clientAttributesForCharacterIndex(atU16Pos: 0, lineHeightRectangle: &textFrame)
      // IMKTextOrientationName 的值為 "IMKTextOrientation"（1 = 橫排、0 = 縱排）。
      let imkTO = (attributes?["IMKTextOrientation"] as? NSNumber)?.intValue
      isVerticalTyping = imkTO == 0
      return textFrame
    }
    isVerticalTyping = false
    return .seniorTheBeast
  }

  /// 強制重設當前鍵盤佈局、使其與偏好設定同步。
  /// 內部會比對目標佈局與上次實際套用的佈局，若相同則跳過 `overrideKeyboard()` 阻塞操作。
  /// - Note: `lastAppliedKeyboardLayout` 在 async block 內部寫入（而非同步寫入），
  ///   避免 async task 靜默失敗（例：clientProxy 為 nil）時緩存變成「已套用但未實際發生」的髒狀態。
  public func setKeyLayout() {
    let targetLayout: String =
      (isASCIIMode && SessionHost.shared.isDynamicBasicKeyboardLayoutEnabled())
        ? prefs.alphanumericalKeyboardLayout
        : prefs.basicKeyboardLayout
    guard targetLayout != lastAppliedKeyboardLayout else { return }
    asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) { [weak self] in
      guard let this = self else { return }
      if let clientProxy = this.clientProxy, !this.isServingIMEItself {
        clientProxy.clientOverrideKeyboard(withName: targetLayout)
        this.lastAppliedKeyboardLayout = targetLayout
      }
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

  public func isStillTheSameClientProxyObj(_ clientProxy: NSObject?) -> Bool {
    guard let clientProxy else { return false }
    return clientProxyObjectIdentifier == .init(clientProxy)
  }

  public func updateClientProxyObjectIdentifier(_ clientProxy: (any SessionClientProxy)?) {
    guard let clientProxy else { return }
    clientProxyObjectIdentifier = .init(clientProxy)
  }

  public func performServerActivation() {
    // 延遲 0.05s 執行打字模式提示，以避免 flickering、避免被緊跟著 Server Activation 執行
    // 的 setValue 連續技打斷（所有操作都在 MainActor 上，不會有時序錯亂）。
    // 快速路徑與完整路徑皆由此 defer 收尾，僅需撰寫一次；單元測試環境同步執行（bypass）。
    defer {
      asyncOnMain(after: 0.05, bypassAsync: UserDefaults.pendingUnitTests) { [weak self] in
        self?.maybeShowModeDescriptionHintUponActivation()
      }
    }

    // MARK: 快速路徑 — 最佳化 CapsLock 中英頻繁切換的場景。

    /// 每次 activateServer 都是一次全新的啟用事件，
    /// 必須重置 `lastAppliedKeyboardLayout` 使其強制重新套用鍵盤佈局——
    /// 因為 parity 雙緩衝下同一 Session 實例可能被不同 client 跨生命週期復用，
    /// 前次 cache 對新 client 無效。

    if isActivated, Self.current?.id == id, inputHandler != nil,
       let proxy = clientProxy, isStillTheSameClientProxyObj(proxy as? NSObject) {
      syncCurrentSessionID()
      let resolvedInputMode = IMEApp.currentInputMode
      if inputMode != resolvedInputMode {
        inputMode = resolvedInputMode
      }
      state = .ofEmpty()
      lastAppliedKeyboardLayout = nil
      setKeyLayout()
      return
    }

    // MARK: 完整路徑

    hidePalettes()
    syncCurrentSessionID()
    Self.current = self
    let this = self
    this.lastAppliedKeyboardLayout = nil
    let senderBundleID: String? = clientProxy?.clientBundleIdentifier()
    if let senderBundleID {
      vCLog("activateServer(\(senderBundleID))")
      this.isServingIMEItself = Bundle.main.bundleIdentifier == senderBundleID
      this.clientBundleIdentifier = senderBundleID
      // 只要使用者沒有勾選檢查更新、沒有主動做出要檢查更新的操作，就不要檢查更新。
      if this.prefs.checkUpdateAutomatically {
        asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
          SessionHost.shared.checkUpdate(false) {
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
          SessionHost.shared.isElectronBasedApp(senderBundleID)
      }
    }
    this.updateClientProxyObjectIdentifier(clientProxy)
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
    if this.isASCIIMode, !SessionHost.shared.isKeyboardJIS() {
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
        SessionHost.shared.checkMemoryUsage()
      }
    }
  }

  /// 若使用者啟用了「對接輸入客體時顯示目前打字模式提示」，則：① 把提示記錄於 state
  /// （`.ofEmpty()`＋tooltip，**直接賦值不經 switchState**——作為「提示顯示中」旗標，
  /// 供 `InputSession.setValue(_:forTag:)` 在 hidePalettes 之後偵測並重發）；② 以
  /// `ui?.statusUI` 顯示（實際 show 延後至主執行緒下一拍，排在 activation 序列中可能
  /// 已入隊的 close-all 之後）。分支：英數模式→`…ascii`；Caps Lock 亮燈且未關閉唯音
  /// 內建 Caps Lock 處理→`…asciiCpLk`（此際字母鍵可直接敲出英數小寫）；其餘→
  /// `typingMode` key。訊息滯留 0.7 秒。
  ///
  /// 一過性輸入方法（內碼／漢音鍵盤符號／羅馬數字等）僅存活於單次按鍵事件處理，每次
  /// activateServer 皆回到 vChewingFactory 語境，故無需檢查 `currentTypingMethod`。
  func maybeShowModeDescriptionHintUponActivation() {
    guard prefs.showModeDescriptionOnActivatingServer else { return }
    let hintKey: String
    if isASCIIMode {
      hintKey = "i18n:TypingMode.i18nKey4InlineModeHint.ascii"
    } else if !prefs.bypassNonAppleCapsLockHandling, ui?.capsLockToggler?.isOn ?? false {
      hintKey = "i18n:TypingMode.i18nKey4InlineModeHint.asciiCpLk"
    } else if let inputHandler {
      hintKey = inputHandler.typingMode.i18nKey4InlineModeHint
    } else {
      return
    }
    let hintTooltip = "► \(hintKey.i18n)"
    var hintState = IMEState.ofEmpty()
    hintState.tooltip = hintTooltip
    hintState.tooltipDuration = 0.7
    state = hintState
    guard let statusUI = ui?.statusUI else { return }
    // 顯示前依客體 accent 同步外觀（文字色／實色背景；StatusUI 實作、tooltip 為 no-op）。
    statusUI.sync(accent: clientAccentColor, locale: localeForFontFallbacks)
    // IMK 的 lineHeightRectangle 為螢幕座標（原點在左下角），故左上角頂點＝origin.y＋height；
    // statusUI 會將此點視為其視窗左下角。坐標與文案在入隊前算妥，closure 不捕獲 self。
    let lineHeightRect = updateVerticalTypingStatus()
    // 若浮動組字窗（PCB）正在顯示，將給定點上抬至 PCB 頂端之上、避免提示與 PCB 重疊。
    // 座標語義：PCB 橫排時以打字列底緣為窗底向上長出、可高於打字列頂端；直排時以打字列
    // 底緣為窗頂（setFrameTopLeftPoint）向下長出、頂端恆不高於打字列頂端——故一律比對
    // PCB 窗頂（frame 的 origin.y + height）即可，直排自然不觸發抬升（相容）。
    // 坐標於入隊前算妥，closure 不捕獲 self。
    var topLeftY = lineHeightRect.origin.y + lineHeightRect.size.height
    if let pcb = ui?.pcb, pcb.isShown, let pcbFrame = pcb.frame {
      topLeftY = max(topLeftY, pcbFrame.origin.y + pcbFrame.size.height)
    }
    let topLeftPoint = CGPoint(
      x: lineHeightRect.origin.x, y: topLeftY
    )
    let heightDelta = lineHeightRect.size.height + 4.0
    asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
      statusUI.show(
        tooltip: hintTooltip,
        at: topLeftPoint,
        bottomOutOfScreenAdjustmentHeight: heightDelta,
        direction: .horizontal,
        duration: 0.7
      )
    }
  }
}
