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
  /// - Note: 呼叫方若已在 MainActor 上（本側所有呼叫方皆然）則直接執行——
  ///   否則 `fileHandleQueue.sync` 會與 `mainSync` 互鎖。
  @discardableResult
  public static func withFileHandleQueueSync<T>(_ execute: () throws -> T) rethrows -> T {
    if Thread.isMainThread { return try execute() }
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
