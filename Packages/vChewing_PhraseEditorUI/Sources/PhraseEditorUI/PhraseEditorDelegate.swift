// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LangModelAssembly
import Shared_DarwinImpl

public protocol PhraseEditorDelegate: AnyObject {
  var currentInputMode: Shared.InputMode { get }
  var isCassetteModeEnabledInLM: Bool { get set }
  func retrieveData(mode: Shared.InputMode, type: LMAssembly.ReplacableUserDataType) -> String
  @discardableResult
  func saveData(
    mode: Shared.InputMode,
    type: LMAssembly.ReplacableUserDataType,
    data: String
  )
    -> String
  func consolidate(text strProcessed: inout String, pragma shouldCheckPragma: Bool)
  func openPhraseFile(
    mode: Shared.InputMode,
    type: LMAssembly.ReplacableUserDataType,
    using: FileOpenMethod
  )
  func tagOverrides(in strProcessed: inout String, mode: Shared.InputMode)
  func performAsyncTaskBypassingCassetteMode<T>(
    _ task: @escaping (@escaping () -> ()) throws -> T
  ) rethrows -> T
  func performSyncTaskBypassingCassetteMode<T>(
    _ task: () throws -> T
  ) rethrows -> T
}
