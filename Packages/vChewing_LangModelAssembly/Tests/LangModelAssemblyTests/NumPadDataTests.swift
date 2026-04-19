// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import Testing

@testable import LangModelAssembly

@Suite(.serialized)
struct LMInstantiatorNumericPadTests {
  // MARK: Internal

  @Test
  func testNumPad() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: true)
    instance.setOptions { config in
      config.numPadFWHWStatus = nil
    }
    #expect(instance.unigramsFor(keyArray: ["_NumPad_0"]).description == "[]")
    instance.setOptions { config in
      config.numPadFWHWStatus = true
    }
    #expect(gramTriples(of: instance.unigramsFor(keyArray: ["_NumPad_0"])) == [
      .init(keyArray: ["_NumPad_0"], value: "０", probability: 0.0),
      .init(keyArray: ["_NumPad_0"], value: "0", probability: -0.1),
    ])
    instance.setOptions { config in
      config.numPadFWHWStatus = false
    }
    #expect(gramTriples(of: instance.unigramsFor(keyArray: ["_NumPad_0"])) == [
      .init(keyArray: ["_NumPad_0"], value: "0", probability: 0.0),
      .init(keyArray: ["_NumPad_0"], value: "０", probability: -0.1),
    ])
  }

  // MARK: Private

  private struct GramSnapshot: Equatable {
    // MARK: Lifecycle

    init(_ gram: Homa.Gram) {
      self.keyArray = gram.keyArray
      self.value = gram.current
      self.probability = gram.probability
    }

    init(keyArray: [String], value: String, probability: Double) {
      self.keyArray = keyArray
      self.value = value
      self.probability = probability
    }

    // MARK: Internal

    let keyArray: [String]
    let value: String
    let probability: Double
  }

  private func gramTriples(of grams: [Homa.Gram]) -> [GramSnapshot] {
    grams.map(GramSnapshot.init)
  }
}
