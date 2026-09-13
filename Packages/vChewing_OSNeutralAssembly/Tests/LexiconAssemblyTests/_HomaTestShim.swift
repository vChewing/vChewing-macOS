// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import HomaSharedTestComponents

nonisolated extension TestLX {
  func asGramQuerier(partiallyMatch: Bool = false) -> Homa.GramQuerier {
    { queryKeys in
      self.queryGrams(queryKeys, partiallyMatch: partiallyMatch)
    }
  }
}
