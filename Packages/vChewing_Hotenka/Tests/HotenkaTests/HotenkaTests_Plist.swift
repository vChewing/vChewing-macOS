// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Nick Chen's Obj-C library "NCChineseConverter" (MIT License).
/*
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. No trademark license is granted to use the trade names, trademarks, service
 marks, or product names of Contributor, except as required to fulfill notice
 requirements above.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation
import Testing

@testable import Hotenka

private let packageRootPath = URL(fileURLWithPath: #file).pathComponents
  .prefix(while: { $0 != "Tests" }).joined(
    separator: "/"
  ).dropFirst()

private let testDataPath: String = packageRootPath + "/Tests/TestDictData/"

// MARK: - HotenkaTests

@Suite("Hotenka")
final class HotenkaTests {
  @Test
  func testGeneratingPlist() throws {
    Hotenka.consoleLog("// Start loading from: \(packageRootPath)")
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
    Hotenka.consoleLog("// Start loading plist from: \(packageRootPath)")
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
