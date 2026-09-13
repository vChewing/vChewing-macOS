// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - LXAssembly.UserDictionarySummarized

extension LXAssembly {
  public struct UserDictionarySummarized: Codable {
    let isCHS: Bool
    let userPhrases: [String: [String]]
    let filter: [String: [String]]
    let userSymbols: [String: [String]]
    let replacements: [String: String]
    let associates: [String: [String]]
  }
}

extension LXAssembly.LXFacade {
  public func summarize(all: Bool) -> LXAssembly.UserDictionarySummarized {
    LXAssembly.UserDictionarySummarized(
      isCHS: isCHS,
      userPhrases: lxUserPhrases.dictRepresented,
      filter: lxFiltered.dictRepresented,
      userSymbols: lxUserSymbols.dictRepresented,
      replacements: lxReplacements.dictRepresented,
      associates: all ? lxAssociates.dictRepresented : [:]
    )
  }
}
