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

public protocol PhraseEditorDelegate {
  var currentInputMode: Shared.InputMode { get }
  func retrieveData(mode: Shared.InputMode, type: LMAssembly.ReplacableUserDataType) -> String
  @discardableResult
  func saveData(
    mode: Shared.InputMode,
    type: LMAssembly.ReplacableUserDataType,
    data: String
  )
    -> String
  func checkIfPhrasePairExists(userPhrase: String, mode: Shared.InputMode, key unigramKey: String)
    -> Bool
  func consolidate(text strProcessed: inout String, pragma shouldCheckPragma: Bool)
  func openPhraseFile(
    mode: Shared.InputMode,
    type: LMAssembly.ReplacableUserDataType,
    using: FileOpenMethod
  )
  func tagOverrides(in strProcessed: inout String, mode: Shared.InputMode)
}
