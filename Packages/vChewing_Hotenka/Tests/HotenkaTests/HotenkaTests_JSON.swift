// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Nick Chen's Obj-C library "NCChineseConverter" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import HotenkaTestDictData
import Testing

@testable import Hotenka

extension HotenkaTests {
  @Test
  func testGeneratingJSON() throws {
    let testInstance: HotenkaChineseConverter = .init(dictDir: testDataPath)
    Hotenka.consoleLog("// Loading complete. Generating json dict file.")
    do {
      let urlOutput = URL(fileURLWithPath: testDataPath + "convdict.json")
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      try encoder.encode(testInstance.dict).write(to: urlOutput, options: .atomic)
    } catch {
      Hotenka.consoleLog("// Error on writing strings to file: \(error)")
    }
  }

  @Test
  func testSampleWithJSON() throws {
    let testInstance2: HotenkaChineseConverter = .init(jsonDir: testDataPath + "convdict.json")
    Hotenka.consoleLog("// Successfully loading json dictionary.")

    let oriString = "为中华崛起而读书"
    let result1 = testInstance2.convert(oriString, to: .zhHantTW)
    let result2 = testInstance2.convert(result1, to: .zhHantKX)
    let result3 = testInstance2.convert(result2, to: .zhHansJP)
    Hotenka.consoleLog("// Results: \(result1) \(result2) \(result3)")
    #expect(result1 == "為中華崛起而讀書")
    #expect(result2 == "爲中華崛起而讀書")
    #expect(result3 == "為中華崛起而読書")
  }
}
