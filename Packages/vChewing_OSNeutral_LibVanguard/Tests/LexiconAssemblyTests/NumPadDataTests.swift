// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Testing

@testable import LexiconAssembly

@Suite(.serialized)
struct LXFacadeNumericPadTests {
  // MARK: Internal

  @Test
  func testNumPad() throws {
    let instance = LXAssembly.LXFacade(isCHS: true)
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
