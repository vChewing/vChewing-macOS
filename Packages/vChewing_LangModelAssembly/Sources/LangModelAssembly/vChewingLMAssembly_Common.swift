// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SwiftExtension

// MARK: - LMAssembly

nonisolated public enum LMAssembly {
  // MARK: Public

  nonisolated public enum ReplacableUserDataType: String, CaseIterable, Identifiable {
    case thePhrases
    case theFilter
    case theReplacements
    case theAssociates
    case theSymbols

    // MARK: Public

    public var id: String { rawValue }

    public var localizedDescription: String { rawValue.i18n }
  }

  nonisolated public static let fileHandleQueue: DispatchQueue = {
    let queue = DispatchQueue(
      label: "org.vChewing.LMMgr.unitedUserFileIOQueue"
    )
    queue.setSpecific(key: fileHandleQueueKey, value: fileHandleQueueIdentifier)
    return queue
  }()

  @discardableResult
  nonisolated public static func withFileHandleQueueSync<T>(_ execute: () throws -> T) rethrows -> T {
    if DispatchQueue.getSpecific(key: fileHandleQueueKey) == fileHandleQueueIdentifier {
      return try execute()
    }
    return try fileHandleQueue.sync(execute: execute)
  }

  /// 在 fileHandleQueue 上非同步讀取檔案內容（含可選的 consolidation），
  /// 完成後在 MainActor 上回呼結果。不阻塞呼叫方（通常是 MainActor）。
  nonisolated public static func readFileContentAsync(
    path: String,
    shouldConsolidate: Bool,
    completion: @MainActor @escaping @Sendable (String) -> ()
  ) {
    fileHandleQueue.async {
      do {
        if shouldConsolidate {
          LMConsolidator.fixEOF(path: path)
          LMConsolidator.consolidate(path: path, pragma: true)
        }
        let rawStrData = try String(contentsOfFile: path, encoding: .utf8)
        asyncOnMain { completion(rawStrData) }
      } catch {
        vCLMLog("readFileContentAsync failed at: \(path). Details: \(error)")
      }
    }
  }

  // MARK: Internal

  nonisolated enum FileErrors: Error {
    case fileHandleError(String)
  }

  // MARK: Private

  nonisolated private static let fileHandleQueueKey = DispatchSpecificKey<UUID>()
  nonisolated private static let fileHandleQueueIdentifier = UUID()
}

nonisolated func vCLMLog(_ strPrint: StringLiteralType) {
  let toLog = UserDefaults.standard.object(forKey: "_DebugMode") as? Bool ?? true
  if toLog {
    Process.consoleLog("vChewingDebug: \(strPrint)")
  }
}

// MARK: - Runtime Context Management

extension LMAssembly {
  public static func applyEnvironmentDefaults() {
    LMAssembly.LMInstantiator.asyncLoadingUserData = !UserDefaults.pendingUnitTests
  }

  public static func resetSharedState(restoreAsyncLoadingStrategy: Bool = true) {
    LMAssembly.LMInstantiator.resetSharedResources(
      restoreAsyncLoadingStrategy: restoreAsyncLoadingStrategy
    )
  }
}
