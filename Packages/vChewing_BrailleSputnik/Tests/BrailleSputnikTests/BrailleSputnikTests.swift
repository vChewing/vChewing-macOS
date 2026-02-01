// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

@testable import BrailleSputnik
import Testing

@Suite("BrailleSputnik")
final class BrailleSputnikTests {
  @Test
  func testBrailleConversion() throws {
    // 大丘丘病了二丘丘瞧，三丘丘採藥四丘丘熬。
    var rawReadingStr = "ㄉㄚˋ-ㄑㄧㄡ-ㄑㄧㄡ-ㄅㄧㄥˋ-ㄌㄜ˙-ㄦˋ-ㄑㄧㄡ-ㄑㄧㄡ-ㄑㄧㄠˊ-_，"
    rawReadingStr += "-ㄙㄢ-ㄑㄧㄡ-ㄑㄧㄡ-ㄘㄞˇ-ㄧㄠˋ-ㄙˋ-ㄑㄧㄡ-ㄑㄧㄡ-ㄠˊ-_。"
    let rawReadingArray: [(key: String, value: String)] = rawReadingStr.split(separator: "-").map {
      let value: String = $0.first == "_" ? $0.last?.description ?? "" : ""
      return (key: $0.description, value: value)
    }
    let processor = BrailleSputnik(standard: .of1947)
    let result1947 = processor.convertToBraille(smashedPairs: rawReadingArray)
    #expect(result1947 == "⠙⠜⠐⠚⠎⠄⠚⠎⠄⠕⠽⠐⠉⠮⠁⠱⠐⠚⠎⠄⠚⠎⠄⠚⠪⠂⠆⠑⠧⠄⠚⠎⠄⠚⠎⠄⠚⠺⠈⠪⠐⠑⠐⠚⠎⠄⠚⠎⠄⠩⠂⠤⠀")
    processor.standard = .of2018
    let result2018 = processor.convertToBraille(smashedPairs: rawReadingArray)
    #expect(result2018 == "⠙⠔⠆⠅⠳⠁⠅⠳⠁⠃⠡⠆⠇⠢⠗⠆⠅⠳⠁⠅⠳⠁⠅⠜⠂⠐⠎⠧⠁⠅⠳⠁⠅⠳⠁⠉⠪⠄⠜⠆⠎⠆⠅⠳⠁⠅⠳⠁⠖⠂⠐⠆")
  }
}
