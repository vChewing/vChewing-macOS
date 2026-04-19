// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import HomaSharedTestComponents

nonisolated extension TestLM {
  func asGramQuerier(partiallyMatch: Bool = false) -> Homa.GramQuerier {
    { queryKeys in
      self.queryGrams(queryKeys, partiallyMatch: partiallyMatch)
    }
  }

  func asGramAvailabilityChecker(
    partiallyMatch: Bool = false
  )
    -> Homa.GramAvailabilityChecker {
    { querykeys in
      self.hasGrams(querykeys, partiallyMatch: partiallyMatch)
    }
  }
}
