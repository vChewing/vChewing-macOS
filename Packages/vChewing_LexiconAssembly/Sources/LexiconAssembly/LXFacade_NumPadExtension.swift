// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa

extension LXAssembly.LXFacade {
  public func supplyNumPadUnigrams(key: String, keyArray: [String]) -> [Homa.Gram] {
    guard let status = config.numPadFWHWStatus else { return [] }
    let initials = "_NumPad_"
    guard key.hasPrefix(initials) else { return [] }
    let char = key.replacingOccurrences(of: initials, with: "")
    guard char.count == 1 else { return [] }
    let gram1 = Homa.Gram(
      keyArray: keyArray,
      value: char.applyingTransformFW2HW(reverse: status),
      score: 0
    )
    let gram2 = Homa.Gram(
      keyArray: keyArray,
      value: char.applyingTransformFW2HW(reverse: !status),
      score: -0.1
    )
    return [gram1, gram2]
  }
}
