// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

public protocol PhraseEditorDelegate: AnyObject {
  var currentInputMode: Shared.InputMode { get }
  var isCassetteModeEnabledInLM: Bool { get set }
  func retrieveData(mode: Shared.InputMode, type: LXAssembly.ReplacableUserDataType) -> String
  @discardableResult
  func saveData(
    mode: Shared.InputMode,
    type: LXAssembly.ReplacableUserDataType,
    data: String
  )
    -> String
  func consolidate(text strProcessed: inout String, pragma shouldCheckPragma: Bool)
  func openPhraseFile(
    mode: Shared.InputMode,
    type: LXAssembly.ReplacableUserDataType,
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
