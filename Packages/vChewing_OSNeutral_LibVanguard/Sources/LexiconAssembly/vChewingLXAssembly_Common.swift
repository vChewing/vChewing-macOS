// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

// MARK: - LXAssembly

public enum LXAssembly {
  // MARK: Public

  public enum ReplaceableUserDataType: String, CaseIterable, Identifiable {
    case thePhrases
    case theFilter
    case theReplacements
    case theAssociates
    case theSymbols
    /// 使用者自訂候選字詞排序表。格式與語彙表不同（每列「讀音 候選…」），故其編輯界面
    /// 之插入欄位語義亦不同；但仍屬「可整份置換」之使用者資料，故列入本枚舉。
    case theCandidateSequence

    // MARK: Public

    public var id: String { rawValue }

    public var localizedDescription: String {
      switch self {
      case .thePhrases: return "i18n:PhraseEditor.TabPhrases".i18n
      case .theFilter: return "i18n:PhraseEditor.TabFilter".i18n
      case .theReplacements: return "i18n:PhraseEditor.TabReplacements".i18n
      case .theAssociates: return "i18n:PhraseEditor.TabAssociates".i18n
      case .theSymbols: return "i18n:PhraseEditor.TabSymbols".i18n
      case .theCandidateSequence: return "i18n:PhraseEditor.TabCandidateSequence".i18n
      }
    }
  }

  /// 檔案 IO 專用佇列。
  /// - Important: 本佇列僅用於調度——實際任務一律以 `mainSync` 交回 MainActor 執行。
  nonisolated public static let fileHandleQueue: DispatchQueue = {
    let queue = DispatchQueue(
      label: "org.vChewing.LXMgr.unitedUserFileIOQueue"
    )
    queue.setSpecific(key: fileHandleQueueKey, value: fileHandleQueueIdentifier)
    return queue
  }()

  /// 使用者資料之寫入巷（序列）。
  ///
  /// 與 ``fileHandleQueue`` 的分工：後者只是**調度**（工作一律交回主執行緒），本巷則**切實執行**
  /// 使用者資料檔之讀寫。凡因輸入事件而起、需要落盤於使用者資料檔的工作（就地加詞／過濾之寫檔、
  /// 該寫檔之後續資料重載）一律派至此巷；主執行緒只負責派工與（回到主執行緒後的）記憶體狀態更新，
  /// **絕不在事件鏈路上等磁碟**。
  ///
  /// 理由（GH Issue #625）：使用者資料檔可能落在極慢或已失效的卷上（網路磁碟、iCloud Drive、
  /// 外接碟、權限卡住的目錄），而 IMK 之鍵盤事件鏈路一旦在其中等候，整個輸入法行程即失去回應、
  /// 連切換輸入法都辦不到。故「鍵盤事件 → 回報 IMK」這條鏈路上不得出現任何阻塞式 I/O。
  nonisolated public static let userDataWriteQueue: DispatchQueue = {
    // 不指定 QoS：`DispatchQueue.init(label:qos:)` 係 macOS 10.10 起才有，而本模組之部署地板
    // 為 10.9（legacy 發行版）。預設 QoS 對本巷（低頻、批次的使用者資料寫入）亦已足夠。
    let queue = DispatchQueue(
      label: "org.vChewing.LXAssembly.userDataWriteQueue"
    )
    queue.setSpecific(key: userDataWriteQueueKey, value: userDataWriteQueueIdentifier)
    return queue
  }()

  /// 使用者資料之檔案系統存取縫；生產環境即 ``DiskUserDataLocator``。
  ///
  /// 單元測試可於起手處換成 ``InMemoryUserDataLocator``（各用例各持一顆）或
  /// ``DisabledUserDataLocator``，即可在不動生產碼的前提下把落盤語意整個關掉。
  nonisolated public static var userDataLocator: any UserDataLocator {
    get { _userDataLocator.withLockRead { $0 } }
    set { _userDataLocator.withLock { $0 = newValue } }
  }

  /// 呼叫端是否已在使用者資料寫入巷上。
  nonisolated public static var isOnUserDataWriteQueue: Bool {
    DispatchQueue.getSpecific(key: userDataWriteQueueKey) == userDataWriteQueueIdentifier
  }

  /// 將工作派至使用者資料寫入巷（非同步、序列）。
  /// - Important: 回傳即代表已排入，**不等候其完成**——此即本巷存在之意義。
  nonisolated public static func withUserDataWriteQueueAsync(
    _ execute: @escaping @Sendable () -> ()
  ) {
    userDataWriteQueue.async(execute: execute)
  }

  /// 於使用者資料寫入巷上同步執行（若呼叫端已在該巷上則就地執行）。
  /// - Important: 僅供單元測試與收尾（flush）使用。**輸入事件鏈路不得呼叫**——那等於把阻塞語意
  ///   原樣搬回來；生產碼之事件鏈路一律走 ``withUserDataWriteQueueAsync(_:)``。
  nonisolated public static func onUserDataWriteQueueSync<T>(_ execute: () throws -> T) rethrows -> T {
    if isOnUserDataWriteQueue { return try execute() }
    return try userDataWriteQueue.sync(execute: execute)
  }

  /// 等候使用者資料寫入巷上既有工作全部完成（僅測試與收尾使用）。
  nonisolated public static func drainUserDataWriteQueue() {
    userDataWriteQueue.sync {}
  }

  /// 使用者資料檔之存取互斥鎖。
  ///
  /// 本鎖守的是「**同一批檔案不得被兩條執行緒同時讀寫**」：寫入巷上之 I/O（背景）與其餘仍在
  /// 主執行緒上就地執行之 I/O（啟動期載入、語彙編輯器之存檔、單元測試）必須互斥。鎖只圈住
  /// **單一檔案操作**（``DiskUserDataLocator`` 之各原語），不圈住跨檔案的序列——後者由寫入巷之
  /// 序列性與「一次寫入只排一筆工作」保證。
  /// - Important: 此鎖**不可重入**（`NSLock`）；取鎖範圍內不得再取，亦不得呼叫會取鎖之 API。
  nonisolated public static func withUserDataFileLock<T>(_ execute: () throws -> T) rethrows -> T {
    try _userDataFileLock.withLock { _ in try execute() }
  }

  /// 經 fileHandleQueue 調度、於 MainActor 上就地執行閉包（同步、可重入）。
  /// - Note: 三種情形一律就地執行、不進 `fileHandleQueue.sync`：
  ///   ① 呼叫方已在 fileHandleQueue 上——再 sync 同一條序列佇列即為遞迴 sync；
  ///   ② 呼叫方已在主佇列上——`sync` 之後的內層 `mainSync` 會與之互鎖；
  ///   ③ 呼叫方已在**使用者資料寫入巷**上——該巷之工作本即為 I/O 而生，就地執行即可，
  ///      毋須再繞回主執行緒（繞回去就把 I/O 又搬回主執行緒了）。
  /// - Important: ② 之判斷**不可用 `Thread.isMainThread`**，亦**不可推給內層的 `mainSync` 自查**。
  ///   在 swift-corelibs 平台（Linux／Windows）上，主佇列的工作可能由 dispatch worker 執行——該執行緒
  ///   `isMainThread` 為假，卻已持有主佇列之 drain 鎖；而 `fileHandleQueue.sync` 於未受競爭時**就地在
  ///   呼叫端執行**（libdispatch 之 `_dispatch_sync_f_fast`），於是內層 `mainSync` 眼中「當前正在執行的
  ///   佇列」已成了 fileHandleQueue——連 `DispatchQueue.getSpecific` 也問不出主佇列身分，遂對主佇列
  ///   下一次 `sync`，libdispatch 判為用戶端錯誤而直接崩潰（Darwin 上 SIGTRAP、Linux／Windows 上
  ///   ud2＝SIGILL）。故這一關必須把在主佇列上的呼叫方擋在外頭。實測證據：CI（linux／WinNT）之
  ///   `LXAssociatesTests.testSaveDataRoundTrip` 之符號化堆疊為
  ///   `testSaveDataRoundTrip` → `LXAssociates.saveData()` → `withFileHandleQueueSync` →
  ///   `closure #1` → `mainSync` → `DispatchQueue.sync` → `__DISPATCH_WAIT_FOR_QUEUE__`。
  @discardableResult
  public static func withFileHandleQueueSync<T>(_ execute: () throws -> T) rethrows -> T {
    if DispatchQueue.getSpecific(key: fileHandleQueueKey) == fileHandleQueueIdentifier {
      return try execute()
    }
    if isOnUserDataWriteQueue { return try execute() }
    if isOnMainQueue() { return try execute() }
    return try fileHandleQueue.sync { try mainSync { try execute() } }
  }

  /// 經 fileHandleQueue 調度、於 MainActor 上非同步執行閉包，不阻塞呼叫方。
  public static func withFileHandleQueueAsync(_ execute: @escaping @Sendable () -> ()) {
    fileHandleQueue.async {
      mainSync { execute() }
    }
  }

  /// 經使用者資料寫入巷讀取檔案內容（含可選的 consolidation），讀畢後在 MainActor 上回呼結果。
  /// 不阻塞呼叫方（通常是 MainActor）。
  ///
  /// - Important: I/O 一律在 ``userDataWriteQueue`` 上執行，**不得**繞回主執行緒
  ///   （本 API 於 P345 之前正是以 `mainSync` 就地於主執行緒讀檔＋整理格式；那使每次就地加詞／
  ///   過濾之後的資料重載都變成主執行緒上的一次全檔讀寫，即 GH Issue #625 之溫床）。
  ///   主執行緒只負責最後的「把解析結果套進語言模組」——那一步在本回呼裡做。
  /// 讀檔失敗時只印日誌；若有提供 `onFailure`，則同樣在 MainActor 上回呼之。
  ///
  /// 本 API 以 compiler flag 分隔為兩套寫法，係因 closure 參數的 actor 標註兩側互斥：
  ///
  /// - **Swift 6.2 以上**：`completion` 須標 `@MainActor`——呼叫端的閉包本體會觸及 MainActor
  ///   狀態，少了該標註即無法通過該側的隔離檢查。
  /// - **Swift 6.2 以下**：採 `vChewing-OSX-Legacy` 的寫法（closure 參數不帶 actor 標註）。
  ///   5.10 對「自非隔離閉包內呼叫 MainActor 閉包參數」一律報
  ///   `call to main actor-isolated parameter … in a synchronous nonisolated context`，而本側
  ///   沒有 `defaultIsolation`，該標註在此反而無從滿足。
  #if compiler(>=6.2)
    public static func readFileContentAsync(
      path: String,
      shouldConsolidate: Bool,
      using locator: any UserDataLocator = Self.userDataLocator,
      completion: @MainActor @escaping @Sendable (String) -> (),
      onFailure: (@MainActor @Sendable () -> ())? = nil
    ) {
      withUserDataWriteQueueAsync {
        do {
          if shouldConsolidate {
            LXConsolidator.fixEOF(path: path, using: locator)
            LXConsolidator.consolidate(path: path, pragma: true, using: locator)
          }
          let rawStrData = try readText(path: path, using: locator)
          asyncOnMain { completion(rawStrData) }
        } catch {
          let detail = "\(error)"
          asyncOnMain {
            vCLMLog("readFileContentAsync failed at: \(path). Details: \(detail)")
            if let onFailure { onFailure() }
          }
        }
      }
    }
  #else
    public static func readFileContentAsync(
      path: String,
      shouldConsolidate: Bool,
      using locator: any UserDataLocator = Self.userDataLocator,
      completion: @escaping @Sendable (String) -> (),
      onFailure: (@Sendable () -> ())? = nil
    ) {
      withUserDataWriteQueueAsync {
        do {
          if shouldConsolidate {
            LXConsolidator.fixEOF(path: path, using: locator)
            LXConsolidator.consolidate(path: path, pragma: true, using: locator)
          }
          let rawStrData = try readText(path: path, using: locator)
          asyncOnMain { completion(rawStrData) }
        } catch {
          let detail = "\(error)"
          asyncOnMain {
            vCLMLog("readFileContentAsync failed at: \(path). Details: \(detail)")
            if let onFailure { onFailure() }
          }
        }
      }
    }
  #endif

  // MARK: Internal

  enum FileErrors: Error {
    case fileHandleError(String)
  }

  /// 經給定后端讀出 UTF-8 文字；非法位元組一律視為讀取失敗。
  nonisolated static func readText(path: String, using locator: any UserDataLocator) throws -> String {
    let data = try locator.read(at: URL(fileURLWithPath: path))
    guard let text = String(data: data, encoding: .utf8) else {
      throw FileErrors.fileHandleError(path)
    }
    return text
  }

  /// 經 ``userDataLocator`` 讀出 UTF-8 文字；非法位元組一律視為讀取失敗。
  nonisolated static func readTextViaUserDataLocator(path: String) throws -> String {
    try readText(path: path, using: Self.userDataLocator)
  }

  // MARK: Private

  nonisolated private static let fileHandleQueueKey = DispatchSpecificKey<UUID>()
  nonisolated private static let fileHandleQueueIdentifier = UUID()
  nonisolated private static let userDataWriteQueueKey = DispatchSpecificKey<UUID>()
  nonisolated private static let userDataWriteQueueIdentifier = UUID()
  nonisolated private static let _userDataLocator: NSMutex<any UserDataLocator> = .init(
    DiskUserDataLocator()
  )
  nonisolated private static let _userDataFileLock: NSMutex<UInt8> = .init(0)
}

nonisolated func vCLMLog(_ strPrint: StringLiteralType) {
  // 測試模式下僅於指定過濾參數（如 swift test --filter ...）時輸出，
  // 以免 mixedAlnum 等大量觸發 POM 儲存路徑的案例在完整測試時刷屏。
  if OSUtils.isRunningUnitTests, !hasTestFilterArguments() {
    return
  }
  let toLog = OSUtils.defaultsStore.object(forKey: "_DebugMode") as? Bool ?? true
  if toLog {
    OSUtils.consoleLog("vChewingDebug: \(strPrint)")
  }
}

/// 偵測目前程序是否帶有測試過濾參數（例如 `swift test --filter ...`、`--skip ...` 或 XCTest 的 `-XCTest ...`）。
nonisolated private func hasTestFilterArguments() -> Bool {
  ProcessInfo.processInfo.arguments.contains {
    $0.hasPrefix("--filter") || $0.hasPrefix("--skip") || $0.hasPrefix("-XCTest")
  }
}

// MARK: - Runtime Context Management

extension LXAssembly {
  public static func applyEnvironmentDefaults() {
    LXAssembly.LXFacade.asyncLoadingUserData = !OSUtils.isRunningUnitTests
  }

  public static func resetSharedState(restoreAsyncLoadingStrategy: Bool = true) {
    LXAssembly.LXFacade.resetSharedResources(
      restoreAsyncLoadingStrategy: restoreAsyncLoadingStrategy
    )
  }
}
