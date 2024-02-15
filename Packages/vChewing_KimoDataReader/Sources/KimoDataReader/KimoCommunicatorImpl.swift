// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import ObjcKimoCommunicator

public class KimoCommunicator: ObjcKimoCommunicator {
  public static let shared: KimoCommunicator = .init()

  public func prepareData(handler: @escaping (_ key: String, _ value: String) -> Void) {
    guard KimoCommunicator.shared.establishConnection() else { return }
    assert(KimoCommunicator.shared.hasValidConnection())
    let loopAmount = KimoCommunicator.shared.userPhraseDBTotalAmountOfRows()
    for i in 0 ..< loopAmount {
      let fetched = KimoCommunicator.shared.userPhraseDBDictionary(atRow: i)
      guard let key = fetched["BPMF"], let text = fetched["Text"] else { continue }
      handler(key, text)
    }
  }
}
