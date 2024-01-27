// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez

public extension vChewingLM.LMInstantiator {
  func supplyNumPadUnigrams(key: String) -> [Megrez.Unigram] {
    guard let status = config.numPadFWHWStatus else { return [] }
    let initials = "_NumPad_"
    guard key.hasPrefix(initials) else { return [] }
    let char = key.replacingOccurrences(of: initials, with: "")
    guard char.count == 1 else { return [] }
    let gram1 = Megrez.Unigram(value: char.applyingTransformFW2HW(reverse: status), score: 0)
    let gram2 = Megrez.Unigram(value: char.applyingTransformFW2HW(reverse: !status), score: -0.1)
    return [gram1, gram2]
  }
}
