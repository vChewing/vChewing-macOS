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

// MARK: - HotenkaTests

@Suite(.serialized)
final class HotenkaTests {
  // MARK: Lifecycle

  init() throws {
    guard let url = HotenkaTestDictData.testResourceURL else {
      Issue.record("Test Resource URL is nil")
      throw NSError()
    }
    self.testDataPath = url.path
  }

  // MARK: Internal

  let testDataPath: String

  @Test
  func testGeneratingPlist() throws {
    let testInstance: HotenkaChineseConverter = .init(dictDir: testDataPath)
    Hotenka.consoleLog("// Loading complete. Generating plist dict file.")
    do {
      try PropertyListSerialization.data(
        fromPropertyList: testInstance.dict,
        format: .binary,
        options: 0
      ).write(
        to: URL(fileURLWithPath: testDataPath + "convdict.plist")
      )
    } catch {
      Hotenka.consoleLog("// Error on writing strings to file: \(error)")
    }
  }

  @Test
  func testSampleWithPlist() throws {
    let testInstance2: HotenkaChineseConverter = .init(plistDir: testDataPath + "convdict.plist")
    Hotenka.consoleLog("// Successfully loading plist dictionary.")

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
