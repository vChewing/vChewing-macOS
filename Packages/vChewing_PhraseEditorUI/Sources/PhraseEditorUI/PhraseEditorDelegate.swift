// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LangModelAssembly
import Shared

public protocol PhraseEditorDelegate {
  var currentInputMode: Shared.InputMode { get }
  func retrieveData(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType) -> String
  @discardableResult func saveData(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType, data: String)
    -> String
  func checkIfUserPhraseExist(userPhrase: String, mode: Shared.InputMode, key unigramKey: String) -> Bool
  func consolidate(text strProcessed: inout String, pragma shouldCheckPragma: Bool)
  func openPhraseFile(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType, app: String)
}
