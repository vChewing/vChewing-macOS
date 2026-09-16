// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

// MARK: - LXAssembly

public enum LXAssembly {
  // MARK: Public

  public enum ReplacableUserDataType: String, CaseIterable, Identifiable {
    case thePhrases
    case theFilter
    case theReplacements
    case theAssociates
    case theSymbols

    // MARK: Public

    public var id: String { rawValue }

    public var localizedDescription: String {
      switch self {
      case .thePhrases: return "i18n:PhraseEditor.TabPhrases".i18n
      case .theFilter: return "i18n:PhraseEditor.TabFilter".i18n
      case .theReplacements: return "i18n:PhraseEditor.TabReplacements".i18n
      case .theAssociates: return "i18n:PhraseEditor.TabAssociates".i18n
      case .theSymbols: return "i18n:PhraseEditor.TabSymbols".i18n
      }
    }
  }

  /// 檔案 IO 專用佇列。
  /// - Important: 本佇列僅用於調度——實際任務一律以 `mainSync` 交回 MainActor 執行。
  public static let fileHandleQueue: DispatchQueue = {
    let queue = DispatchQueue(
      label: "org.vChewing.LXMgr.unitedUserFileIOQueue"
    )
    queue.setSpecific(key: fileHandleQueueKey, value: fileHandleQueueIdentifier)
    return queue
  }()

  /// 經 fileHandleQueue 調度、於 MainActor 上就地執行閉包（同步、可重入）。
  /// - Note: 兩種情形一律就地執行、不進 `fileHandleQueue.sync`：
  ///   ① 呼叫方已在 fileHandleQueue 上——再 sync 同一條序列佇列即為遞迴 sync；
  ///   ② 呼叫方已在主佇列上——`sync` 之後的內層 `mainSync` 會與之互鎖。
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
    if isOnMainQueue() { return try execute() }
    return try fileHandleQueue.sync { try mainSync { try execute() } }
  }

  /// 經 fileHandleQueue 調度、於 MainActor 上非同步執行閉包，不阻塞呼叫方。
  public static func withFileHandleQueueAsync(_ execute: @escaping @Sendable () -> ()) {
    fileHandleQueue.async {
      mainSync { execute() }
    }
  }

  /// 經 fileHandleQueue 調度讀取檔案內容（含可選的 consolidation），
  /// 完成後在 MainActor 上回呼結果。不阻塞呼叫方（通常是 MainActor）。
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
      completion: @MainActor @escaping @Sendable (String) -> ()
    ) {
      fileHandleQueue.async {
        mainSync {
          do {
            if shouldConsolidate {
              LXConsolidator.fixEOF(path: path)
              LXConsolidator.consolidate(path: path, pragma: true)
            }
            let rawStrData = try String(contentsOfFile: path, encoding: .utf8)
            asyncOnMain { completion(rawStrData) }
          } catch {
            vCLMLog("readFileContentAsync failed at: \(path). Details: \(error)")
          }
        }
      }
    }
  #else
    public static func readFileContentAsync(
      path: String,
      shouldConsolidate: Bool,
      completion: @escaping @Sendable (String) -> ()
    ) {
      fileHandleQueue.async {
        mainSync {
          do {
            if shouldConsolidate {
              LXConsolidator.fixEOF(path: path)
              LXConsolidator.consolidate(path: path, pragma: true)
            }
            let rawStrData = try String(contentsOfFile: path, encoding: .utf8)
            asyncOnMain { completion(rawStrData) }
          } catch {
            vCLMLog("readFileContentAsync failed at: \(path). Details: \(error)")
          }
        }
      }
    }
  #endif

  // MARK: Internal

  enum FileErrors: Error {
    case fileHandleError(String)
  }

  // MARK: Private

  private static let fileHandleQueueKey = DispatchSpecificKey<UUID>()
  private static let fileHandleQueueIdentifier = UUID()
}

func vCLMLog(_ strPrint: StringLiteralType) {
  // 測試模式下僅於指定過濾參數（如 swift test --filter ...）時輸出，
  // 以免 mixedAlnum 等大量觸發 POM 儲存路徑的案例在完整測試時刷屏。
  if UserDefaults.pendingUnitTests, !hasTestFilterArguments() {
    return
  }
  let toLog = UserDefaults.standard.object(forKey: "_DebugMode") as? Bool ?? true
  if toLog {
    Process.consoleLog("vChewingDebug: \(strPrint)")
  }
}

/// 偵測目前程序是否帶有測試過濾參數（例如 `swift test --filter ...`、`--skip ...` 或 XCTest 的 `-XCTest ...`）。
private func hasTestFilterArguments() -> Bool {
  ProcessInfo.processInfo.arguments.contains {
    $0.hasPrefix("--filter") || $0.hasPrefix("--skip") || $0.hasPrefix("-XCTest")
  }
}

// MARK: - Runtime Context Management

extension LXAssembly {
  public static func applyEnvironmentDefaults() {
    LXAssembly.LXFacade.asyncLoadingUserData = !UserDefaults.pendingUnitTests
  }

  public static func resetSharedState(restoreAsyncLoadingStrategy: Bool = true) {
    LXAssembly.LXFacade.resetSharedResources(
      restoreAsyncLoadingStrategy: restoreAsyncLoadingStrategy
    )
  }
}
