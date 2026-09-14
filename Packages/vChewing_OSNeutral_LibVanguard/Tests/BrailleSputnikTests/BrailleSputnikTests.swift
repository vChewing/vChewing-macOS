// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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

  @Test
  func testBrailleConversionIntoBrailleASCII() throws {
    // 大丘丘病了二丘丘瞧，三丘丘採藥四丘丘熬。
    var rawReadingStr = "ㄉㄚˋ-ㄑㄧㄡ-ㄑㄧㄡ-ㄅㄧㄥˋ-ㄌㄜ˙-ㄦˋ-ㄑㄧㄡ-ㄑㄧㄡ-ㄑㄧㄠˊ-_，"
    rawReadingStr += "-ㄙㄢ-ㄑㄧㄡ-ㄑㄧㄡ-ㄘㄞˇ-ㄧㄠˋ-ㄙˋ-ㄑㄧㄡ-ㄑㄧㄡ-ㄠˊ-_。"
    let rawReadingArray: [(key: String, value: String)] = rawReadingStr.split(separator: "-").map {
      let value: String = $0.first == "_" ? $0.last?.description ?? "" : ""
      return (key: $0.description, value: value)
    }
    let processor = BrailleSputnik(standard: .of1947)
    let result1947 = processor.convertToASCIIBraille(smashedPairs: rawReadingArray)
    #expect(result1947 == "D>\"JS'JS'OY\"C!A:\"JS'JS'J[12EV'JS'JS'JW@[\"E\"JS'JS'%1- ")
    processor.standard = .of2018
    let result2018 = processor.convertToASCIIBraille(smashedPairs: rawReadingArray)
    #expect(result2018 == "D92K\\AK\\AB*2L5R2K\\AK\\AK>1\"SVAK\\AK\\AC['>2S2K\\AK\\A61\"2")
  }

  @Test
  func testBrailleASCIIConversionSpecialCells() throws {
    // 逐個驗證 Braille ASCII 對映中容易出錯的特殊字元：ASCII 引號、反斜槓、空格。
    let processor = BrailleSputnik(standard: .of1947)
    // 1947 四聲（⠐ = U+2810）→ ASCII 引號。
    #expect(processor.convertToASCIIBraille(smashedPairs: [(key: "ㄉㄚˋ", value: "大")]) == "D>\"")
    // 1947 介音 ㄩ（⠳ = U+2833）→ ASCII 反斜槓（後隨陰平 ⠄ → ASCII 撇號）。
    #expect(processor.convertToASCIIBraille(smashedPairs: [(key: "ㄩ", value: "淤")]) == "\\'")
    // 1947 句號「。」（⠤⠀）→ ASCII "-" 加空格。
    #expect(processor.convertToASCIIBraille(smashedPairs: [(key: "_。", value: "。")]) == "- ")
    // Unicode 輸出不受影響：同一輸入仍應產出原 Unicode 點字字元。
    #expect(processor.convertToBraille(smashedPairs: [(key: "ㄩ", value: "淤")]) == "⠳⠄")
  }
}
