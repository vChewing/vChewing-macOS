// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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
