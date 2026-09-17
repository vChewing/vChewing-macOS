// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

// MARK: - LXMgr

public final class LXMgr {
  // MARK: Lifecycle

  private init() {
    initObserver()
  }

  deinit {
    observationDataFolderInvalidity?.invalidate()
    observationCassettePathInvalidity?.invalidate()
  }

  // MARK: Public

  /// Captured path-invalidity alerts during unit tests (modal suppressed).
  public struct PathInvalidityAlert: Sendable, Equatable {
    public let msg: String
    public let infoText: String
  }

  public static var shared = LXMgr()

  /// Accumulates path-invalidity alerts when ``UserDefaults/pendingUnitTests`` is true.
  /// Call ``resetRecordedPathInvalidityAlerts()`` between tests.
  /// Non-isolated so it can be written from KVO observer callbacks.
  public nonisolated(unsafe) static var recordedPathInvalidityAlerts = [PathInvalidityAlert]()

  public static var isCoreDBConnected: Bool { LXAssembly.LXFacade.isFactoryDictionaryLoaded }

  /// Clear the accumulated invalidity-alert buffer (call in test `init` / `deinit`).
  public static func resetRecordedPathInvalidityAlerts() {
    recordedPathInvalidityAlerts.removeAll()
  }

  public static func prepareForUnitTests() {
    guard UserDefaults.pendingUnitTests else { return }
    iCloudPathDetectionOverride = nil
    if #available(macOS 10.15, *) {
      prepareUnitTestSandbox()
    }
    Shared.InputMode.resetLexiconCache(forUnitTests: true)
    LXAssembly.applyEnvironmentDefaults()
  }

  public static func resetAfterUnitTests() {
    iCloudPathDetectionOverride = nil
    Shared.InputMode.resetLexiconCache()
    resetUnitTestSandbox()
    LXAssembly.resetSharedState()
  }

  // MARK: - Functions reacting directly with language models.

  public static func initUserLexicons() {
    // 先無條件清除所有 mode 的舊使用者資料，再載入新目錄的資料，
    // 防止舊目錄內容在切換目錄後殘留。
    Shared.InputMode.validCases.forEach { mode in
      mode.lexicon.purgeUserData()
      Self.chkUserLMFilesExist(mode)
    }
    // LXMgr 的 loadUserPhrases 等函式在自動讀取 dataFolderPath 時，
    // 如果發現自訂目錄不可用，則會自動抹去自訂目錄設定、改採預設目錄。
    // 所以這裡不需要特別處理。
    Self.loadUserPhrasesData()
    // 就關聯詞語登記惰性載入器，會趁首次需要完成載入。
    LXAssembly.LXFacade.associatesLazyLoader = {
      if PrefMgr.shared.associatedPhrasesEnabled {
        Self.loadUserAssociatesData()
      }
    }
    Self.loadUserPhraseReplacement()
  }

  // When asyncLoadingUserData is true, connectFactoryDictionary dispatches
  // the heavy work to a background queue; callers must treat the load state as pending
  // until the completion handler reports the final result. The FSM already guards against
  // unloaded factory dictionaries
  // (InputSession_HandleEvent shows "Factory dictionary not loaded yet." tooltip).
  public static func connectCoreDB(dbPath: String? = nil) {
    guard let path: String = dbPath ?? Self.getCoreDictionaryDBPath() else {
      preconditionFailure("vChewing factory TextMap data not found.")
    }
    Notifier.notify(
      message: "i18n:LXMgr.notification.FactoryLexiconLoadingStarted".i18n
    )
    LXAssembly.LXFacade.connectFactoryDictionary(
      textMapPath: path
    ) { resultBool in
      precondition(resultBool, "vChewing factory TextMap loading failed.")
      #if compiler(>=6.2)
        asyncOnMain {
          Notifier.notify(
            message: "i18n:LXMgr.notification.FactoryLexiconLoadingComplete".i18n
          )
        }
      #else
        // 5.10 側：本閉包是 `@Sendable` 的完成回呼，其內（連 `asyncOnMain` 的 block 閉包也不例外）
        // 一律被視為 nonisolated，呼叫 `Notifier.notify` 這種 MainActor 成員會直接報錯。
        // `DispatchQueue.main.async { @MainActor in … }` 是 legacy 倉在此處的既有寫法，也是
        // 5.10 唯一能在此情境通過的形狀（`mainSync`／`asyncOnMain` 皆不可）。
        DispatchQueue.main.async { @MainActor in
          Notifier.notify(
            message: "i18n:LXMgr.notification.FactoryLexiconLoadingComplete".i18n
          )
        }
      #endif
    }
  }

  /// 載入磁帶資料。
  /// - Remark: cassettePath() 會在輸入法停用磁帶時直接返回
  public static func loadCassetteData() {
    LXAssembly.LXFacade.setCassetCandidateKeyValidator {
      CandidateKey.validate(keys: $0) == nil
    }
    let resolvedPath = cassettePath()
    // If the external path was resolved successfully, refresh the internal cache
    // so that the cache stays up-to-date for future fallback (e.g. after reboot when
    // iCloud Drive bookmark becomes stale).
    if !resolvedPath.isEmpty {
      let rawPath = PrefMgr.shared.cassettePath.expandingTildeInPath
      if resolvedPath == rawPath {
        importCassetteFileToCache(from: URL(fileURLWithPath: rawPath))
      }
    }
    LXAssembly.LXFacade.loadCassetteData(path: resolvedPath)
  }

  public static func loadUserPhrasesData(
    type: LXAssembly.ReplacableUserDataType? = nil,
    async: Bool? = nil
  ) {
    guard let type = type else {
      Shared.InputMode.validCases.forEach { mode in
        mode.lexicon.loadUserPhrasesData(
          path: userDictDataURL(mode: mode, type: .thePhrases).path,
          filterPath: userDictDataURL(mode: mode, type: .theFilter).path,
          async: async
        )
        mode.lexicon.loadUserSymbolData(path: userDictDataURL(mode: mode, type: .theSymbols).path)
        mode.lexicon.pomReducedLifetime = PrefMgr.shared.reducePOMLifetimeToNoMoreThan12Hours
        mode.lexicon.loadPOMData()
      }

      if PrefMgr.shared.associatedPhrasesEnabled { Self.loadUserAssociatesData() }
      if PrefMgr.shared.phraseReplacementEnabled { Self.loadUserPhraseReplacement() }

      CandidateNode.load(url: Self.userSymbolMenuDataURL())
      return
    }
    Shared.InputMode.validCases.forEach { mode in
      switch type {
      case .thePhrases:
        mode.lexicon.loadUserPhrasesData(
          path: userDictDataURL(mode: mode, type: .thePhrases).path,
          filterPath: nil,
          async: async
        )
      case .theFilter:
        // We have to enforce the toggle of async loading here for this case:
        if UserDefaults.pendingUnitTests {
          Self.reloadUserFilterDirectly(mode: mode)
        } else {
          asyncOnMain {
            Self.reloadUserFilterDirectly(mode: mode)
          }
        }
      case .theReplacements:
        if PrefMgr.shared.phraseReplacementEnabled { Self.loadUserPhraseReplacement() }
      case .theAssociates:
        if PrefMgr.shared.associatedPhrasesEnabled { Self.loadUserAssociatesData() }
      case .theSymbols:
        mode.lexicon.loadUserSymbolData(
          path: Self.userDictDataURL(mode: mode, type: .theSymbols).path
        )
      }
    }
  }

  public static func loadUserAssociatesData() {
    Shared.InputMode.validCases.forEach { mode in
      mode.lexicon.loadUserAssociatesData(
        path: Self.userDictDataURL(mode: mode, type: .theAssociates).path
      )
    }
  }

  public static func loadUserPhraseReplacement() {
    Shared.InputMode.validCases.forEach { mode in
      mode.lexicon.loadReplacementsData(
        path: Self.userDictDataURL(mode: mode, type: .theReplacements).path
      )
    }
  }

  public static func reloadUserFilterDirectly(mode: Shared.InputMode) {
    mode.lexicon
      .reloadUserFilterDirectly(path: userDictDataURL(mode: mode, type: .theFilter).path)
  }

  public static func checkIfPhrasePairExists(
    userPhrase: String,
    mode: Shared.InputMode,
    keyArray: [String],
    factoryDictionaryOnly: Bool = false,
    cassetteModeAlreadyBypassed: Bool = false
  )
    -> Bool {
    if cassetteModeAlreadyBypassed {
      return mode.lexicon.lxQuerier.hasKeyValuePairFor(
        keyArray: keyArray, value: userPhrase, factoryDictionaryOnly: factoryDictionaryOnly
      )
    }
    return shared.performSyncTaskBypassingCassetteMode {
      mode.lexicon.lxQuerier.hasKeyValuePairFor(
        keyArray: keyArray, value: userPhrase, factoryDictionaryOnly: factoryDictionaryOnly
      )
    }
  }

  public static func checkIfPhrasePairIsFiltered(
    userPhrase: String,
    mode: Shared.InputMode,
    keyArray: [String]
  )
    -> Bool {
    mode.lexicon.lxQuerier.isPairFiltered(pair: .init(keyArray: keyArray, value: userPhrase))
  }

  /// 偵測當前輸入狀態所標記的詞音配對是否可以被加入過濾清單。
  public static func isStateDataFilterableForMarked(_ state: IMEStateData) -> Bool {
    guard state.isMarkedLengthValid else { return false } // 範圍長度必須合規。
    guard state.markedTargetExists else { return false } // 必須得有在庫對象
    guard state.markedReadings.count == 1 else { return true } // 如果幅長大於 1，則直接批准。
    // 處理單個漢字的情形：當且僅當在庫量僅有一筆的時候，才禁止過濾。
    return countPhrasePairs(
      keyArray: state.markedReadings, mode: IMEApp.currentInputMode
    ) > 1
  }

  public static func countPhrasePairs(
    keyArray: [String],
    mode: Shared.InputMode,
    factoryDictionaryOnly: Bool = false
  )
    -> Int {
    mode.lexicon.lxQuerier.countKeyValuePairs(
      keyArray: keyArray, factoryDictionaryOnly: factoryDictionaryOnly
    )
  }

  public static func syncLMPrefs() {
    Shared.InputMode.validCases.forEach { mode in
      mode.lexicon.syncPrefs()
    }
  }

  /// 清除原廠辭典的所有 QueryBuffer 快取。
  /// 應在適當的時機呼叫，避免舊查詢結果污染新的查詢。
  public static func flushTrieCaches() {
    LXAssembly.LXFacade.flushTrieCaches()
  }

  /// 釋放原廠辭典反查索引佔用的記憶體。
  /// 關閉獨立 RevLookup 視窗後可呼叫；下次反查會自動重新建立。
  /// 所有載入/卸除操作均經由 UI 行為在 MainActor 上完成，無需額外同步佇列。
  public static func flushFactoryReverseLookupIndex() {
    LXAssembly.LXFacade.flushFactoryReverseLookupIndex()
  }

  /// 預先建立原廠辭典反查索引。
  /// 在 RevLookup 視窗顯示時呼叫，使首次查詢無需等待 lazy build。
  public static func preloadFactoryReverseLookupIndex() {
    LXAssembly.LXFacade.preloadFactoryReverseLookupIndex()
  }

  // MARK: POM

  public static func savePerceptionOverrideModelData(_ saveAllModes: Bool = true) {
    pomSavingCoordinator.savePerceptionOverrideModelData(saveAllModes: saveAllModes)
  }

  public static func bleachSpecifiedSuggestions(targets: [String], mode: Shared.InputMode) {
    mode.lexicon.bleachSpecifiedPOMSuggestions(targets: targets)
  }

  public static func bleachSpecifiedSuggestions(headReadings: [String], mode: Shared.InputMode) {
    mode.lexicon.bleachSpecifiedPOMSuggestions(headReadings: headReadings)
  }

  public static func removeUnigramsFromPerceptionOverrideModel(_ mode: Shared.InputMode) {
    mode.lexicon.bleachPOMUnigrams()
  }

  public static func relocateWreckedPOMData() {
    func dateStringTag(date givenDate: Date) -> String {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyyMMdd-HHmm"
      dateFormatter.timeZone = .current
      let strDate = dateFormatter.string(from: givenDate)
      return strDate
    }

    let urls: [URL] = [
      perceptionOverrideModelDataURL(.imeModeCHS),
      perceptionOverrideModelDataURL(.imeModeCHT),
    ]
    let folderURL = URL(fileURLWithPath: dataFolderPath(isDefaultFolder: true))
      .deletingLastPathComponent()
    urls.forEach { oldURL in
      let newFileName = "[POM-CRASH][\(dateStringTag(date: .init()))]\(oldURL.lastPathComponent)"
      let newURL = folderURL.appendingPathComponent(newFileName)
      try? FileManager.default.moveItem(at: oldURL, to: newURL)
    }
  }

  public static func clearPerceptionOverrideModelData(_ mode: Shared.InputMode = .imeModeNULL) {
    mode.lexicon.clearPOMData()
  }

  /// 清理語言模型記憶體，防止記憶體洩漏
  public static func performMemoryCleanup() {
    Shared.InputMode.validCases.forEach { mode in
      mode.lexicon.purgeInputTokenHashMap()
    }
  }

  // MARK: Internal

  static var iCloudPathDetectionOverride: ((String) -> Bool)?

  // MARK: Unit Test Sandbox

  @available(macOS 10.15, *)
  internal static func unitTestFolderPath(isDefaultFolder: Bool) -> String {
    var path = unitTestDataURL(isDefaultFolder: isDefaultFolder).path
    path.ensureTrailingSlash()
    return path
  }

  @available(macOS 10.15, *)
  internal static func unitTestDataURL(isDefaultFolder: Bool) -> URL {
    prepareUnitTestSandbox()
    guard let defaultURL = unitTestDefaultURL, let customURL = unitTestCustomURL else {
      fatalError("Unit test sandbox unavailable.")
    }
    return isDefaultFolder ? defaultURL : customURL
  }

  @available(macOS 10.15, *)
  internal static func prepareUnitTestSandbox() {
    guard UserDefaults.pendingUnitTests else { return }
    if let defaultURL = unitTestDefaultURL, let customURL = unitTestCustomURL {
      ensureDirectoryExists(defaultURL)
      ensureDirectoryExists(customURL)
      return
    }
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewing-UnitTests", isDirectory: true)
      .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
    let defaultURL = root.appendingPathComponent("UserDataDefault", isDirectory: true)
    let customURL = root.appendingPathComponent("UserDataCustom", isDirectory: true)
    ensureDirectoryExists(defaultURL)
    ensureDirectoryExists(customURL)
    unitTestRootURL = root
    unitTestDefaultURL = defaultURL
    unitTestCustomURL = customURL
  }

  internal static func resetUnitTestSandbox() {
    if let root = unitTestRootURL {
      try? FileManager.default.removeItem(at: root)
    }
    unitTestRootURL = nil
    unitTestDefaultURL = nil
    unitTestCustomURL = nil
  }

  // MARK: Private

  // Debouncer for POM saves (keep compatible with 10.9)
  private static let pomSavingCoordinator = POMSavingCoordinator(
    queueName: "LXAssembly_POM", pomDebounceInterval: 2.0
  )

  private static var unitTestRootURL: URL?
  private static var unitTestDefaultURL: URL?
  private static var unitTestCustomURL: URL?

  // MARK: - Broadcaster Observers

  private var observationDataFolderInvalidity: NSKeyValueObservation?
  private var observationCassettePathInvalidity: NSKeyValueObservation?

  private static func ensureDirectoryExists(_ url: URL) {
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
      assertionFailure("Failed to ensure unit test sandbox directory: \(error)")
    }
  }

  private func initObserver() {
    // 觀察 Broadcaster 的失效路徑事件，並在必要時顯示警示視窗。
    observationDataFolderInvalidity = Broadcaster.shared
      .observe(\.lxMgrDataFolderPathInvalidityConfirmed, options: [.new, .old]) { _, change in
        let newValue = change.newValue ?? nil
        let oldValue = change.oldValue ?? nil
        // 若新舊值未實際變化（兩者皆為 nil，或字串完全相同），則不做任何處理。
        if oldValue == newValue { return }
        // 只有在發現 invalidity（非 nil 且非空字串）時才顯示警示
        guard let path = newValue, !path.isEmpty else { return }
        asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
          self.callModalAlert(
            msg: "i18n:LXMgr.pathInvalidityFound.userDataFolder.title".i18n,
            infoText: Self.userDataFolderInvalidityDescription(path: path)
          )
        }
      }

    observationCassettePathInvalidity = Broadcaster.shared
      .observe(\.lxMgrCassettePathInvalidityConfirmed, options: [.new, .old]) { _, change in
        let newValue = change.newValue ?? nil
        let oldValue = change.oldValue ?? nil
        // 若新舊值未實際變化（兩者皆為 nil，或字串完全相同），則不做任何處理。
        if oldValue == newValue { return }
        guard let path = newValue, !path.isEmpty else { return }
        asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
          self.callModalAlert(
            msg: "i18n:LXMgr.pathInvalidityFound.cassette.title".i18n,
            infoText: Self.cassettePathInvalidityDescription(path: path)
          )
        }
      }
  }

  nonisolated private func callModalAlert(msg: String, infoText: String) {
    // During unit tests suppress the modal dialog and capture the alert
    // so the test can assert on it.
    guard !UserDefaults.pendingUnitTests else {
      Self.recordedPathInvalidityAlerts.append(.init(msg: msg, infoText: infoText))
      return
    }
    #if compiler(>=6.2)
      mainSync {
        // 若當前已存在 modal 視窗，避免再開啟重複的 modal。
        if NSApp.modalWindow != nil { return }
        // 無動作：已停用 cooldown，觀察器改以舊/新值比較來避免重複警示。
        IMEApp.buzz()
        let alert = NSAlert()
        alert.messageText = msg
        alert.informativeText = infoText
        alert.addButton(withTitle: "i18n:Common.OK".i18n)
        _ = alert.runModal()
        NSApp.popup()
      }
    #else
      // 5.10 側：`mainSync` 的閉包不帶隔離，其內呼叫 `NSApp.popup()` 這類 Swift 端成員會被拒；
      // 本函式的呼叫端全在 `asyncOnMain` 內（即已在 main），故照 legacy 倉在此處的形狀改走
      // `DispatchQueue.main.async { @MainActor in … }`：隔離由閉包自己承擔，交付時機略後一拍但無害。
      DispatchQueue.main.async { @MainActor in
        // 若當前已存在 modal 視窗，避免再開啟重複的 modal。
        if NSApp.modalWindow != nil { return }
        // 無動作：已停用 cooldown，觀察器改以舊/新值比較來避免重複警示。
        IMEApp.buzz()
        let alert = NSAlert()
        alert.messageText = msg
        alert.informativeText = infoText
        alert.addButton(withTitle: "i18n:Common.OK".i18n)
        _ = alert.runModal()
        NSApp.popup()
      }
    #endif
  }
}

// MARK: LXMgr.POMSavingCoordinator

extension LXMgr {
  private final class POMSavingCoordinator {
    // MARK: Lifecycle

    init(
      queueName: String,
      pomDebounceInterval: TimeInterval = 2.0
    ) {
      self.pomDebounceQueue = DispatchQueue(label: queueName)
      self.pomDebounceInterval = pomDebounceInterval
      self.pomPendingSave4AllModes = false
      self.pomDebounceToken = 0
    }

    // MARK: Internal

    func savePerceptionOverrideModelData(
      saveAllModes: Bool = true
    ) {
      // 這樣故意繞到 Static 方法上，是為了防止在 async block 裡面引用到 self。
      Self.savePerceptionOverrideModelData(saveAllModes, coordinator: self)
    }

    // MARK: Private

    private let pomDebounceQueue: DispatchQueue
    private let pomDebounceInterval: TimeInterval
    private var pomPendingSave4AllModes: Bool
    private var pomDebounceToken: UInt64

    private static func savePerceptionOverrideModelData(
      _ saveAllModes: Bool = true,
      coordinator c: POMSavingCoordinator
    ) {
      // Debounce frequent save requests to reduce IO churn.
      // Coordinator mutable state is accessed on the main actor (satisfying isolation).
      // Disk I/O runs on pomDebounceQueue to avoid blocking MainActor.
      let interval = max(c.pomDebounceInterval, 0)
      c.pomDebounceQueue.async { [weak c] in
        guard let c else { return }
        let scheduledToken: UInt64 = mainSync {
          c.mergeIntent4PendingSaveAllModes(saveAllModes)
          c.pomDebounceToken &+= 1
          return c.pomDebounceToken
        }
        c.pomDebounceQueue.asyncAfter(deadline: .now() + interval) { [weak c] in
          // Read coordinator state and UI state on the main thread (no I/O here).
          let targetLexicons: [LXAssembly.LXFacade] = mainSync {
            guard let coordinator = c else { return [] }
            guard coordinator.pomDebounceToken == scheduledToken else { return [] }
            let shouldSaveAll = coordinator.pomPendingSave4AllModes
            coordinator.pomPendingSave4AllModes = false
            let targetModes: [Shared.InputMode]
            if shouldSaveAll {
              targetModes = Shared.InputMode.validCases
            } else {
              let currentMode = IMEApp.currentInputMode
              targetModes = currentMode == .imeModeNULL ? [] : [currentMode]
            }
            guard !targetModes.isEmpty else { return [] }
            AppDelegate.shared.suppressUserDataMonitor(
              for: Swift.max(0.8, coordinator.pomDebounceInterval + 0.2)
            )
            return targetModes.map(\.lexicon)
          }
          // POM 落盤改在主執行緒執行（非主執行緒只負責調度）：磁碟 I/O 因此不再有第二條執行緒
          // 與主執行緒互搶 POM 的鎖；本佇列僅負責 debounce 計時。
          asyncOnMain {
            targetLexicons.forEach {
              $0.savePOMData()
            }
          }
        }
      }
    }

    private func mergeIntent4PendingSaveAllModes(_ bool: Bool) {
      pomPendingSave4AllModes = pomPendingSave4AllModes || bool
    }
  }
}
