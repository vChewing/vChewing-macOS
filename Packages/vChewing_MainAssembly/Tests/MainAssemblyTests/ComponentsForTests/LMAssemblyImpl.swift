// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import LangModelAssembly
import MainAssembly

// MARK: - Converting Sample String Data to LMCoreJSON Instance.

extension String {
  func toDictMap(swapKeyValue: Bool = false, encrypt: Bool = false) -> [String: [String]] {
    var theDict = [String: [String]]()
    enumerateLines { currentLine, _ in
      if currentLine.isEmpty || currentLine.hasPrefix("#") {
        return
      }
      let linestream = currentLine.split(separator: " ")
      let col0 = String(linestream[0])
      let col1 = String(linestream[1])
      let col2: Double? = Double(linestream[2])
      var key = swapKeyValue ? col1 : col0
      if encrypt {
        key = vChewingLM.LMCoreJSON.cnvPhonabetToASCII(key)
      }
      var storedValue = swapKeyValue ? col0 : col1
      if let col2 = col2 {
        storedValue.insert(contentsOf: "\(col2.description) ", at: storedValue.startIndex)
      }
      theDict[key, default: []].append(storedValue)
    }
    return theDict
  }
}

// MARK: - Allow LMInstantiator to Load Test Data.

extension vChewingLM.LMInstantiator {
  static func construct(
    isCHS: Bool = false, completionHandler: @escaping (_ this: vChewingLM.LMInstantiator) -> Void
  ) -> vChewingLM.LMInstantiator {
    let this = vChewingLM.LMInstantiator(isCHS: isCHS)
    completionHandler(this)
    return this
  }

  func loadTestData() {
    resetFactoryJSONModels()
    loadLanguageModel(
      json: (
        dict: strSampleDataFactoryCore.toDictMap(swapKeyValue: false, encrypt: true),
        path: "/dev/null"
      )
    )
    loadSymbolData(
      json: (
        dict: strSampleDataFactorySymbol.toDictMap(swapKeyValue: true, encrypt: true),
        path: "/dev/null"
      )
    )
  }
}
