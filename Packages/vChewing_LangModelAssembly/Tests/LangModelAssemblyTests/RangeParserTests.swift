// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Testing

@testable import LangModelAssembly

@Suite(.serialized)
struct RangeParserTests {
  @Test
  func testParseUsesUTF8FastPathWithoutChangingLineSemantics() {
    let sample = "甲 乙\n苹 果\n最後一行"
    var fetched = [String]()

    sample.parse(splitee: "\n") { currentRange in
      fetched.append(String(sample[currentRange]))
    }

    #expect(fetched == ["甲 乙", "苹 果", "最後一行"])
  }

  @Test
  func testParseFallbackKeepsNonASCIISemantics() {
    let sample = "甲，乙，，丙，"
    var fetched = [String]()

    sample.parse(splitee: "，") { currentRange in
      fetched.append(String(sample[currentRange]))
    }

    #expect(fetched == ["甲", "乙", "丙"])
  }

  @Test
  func testParseCellsSkipsEmptySubsequencesForASCIISeparator() {
    let sample = " 甲  乙   丙 "
    var fetched = [String]()

    sample.parseCells(in: sample.startIndex ..< sample.endIndex, splitee: " ") {
      currentRange, currentIndex in
      fetched.append("\(currentIndex):\(sample[currentRange])")
      return true
    }

    #expect(fetched == ["0:甲", "1:乙", "2:丙"])
  }

  @Test
  func testParseCellsFallbackKeepsSubrangeSemantics() {
    let sample = "[甲，乙，，丙]"
    let innerRange = sample.index(after: sample.startIndex) ..< sample.index(before: sample.endIndex)
    var fetched = [String]()

    sample.parseCells(in: innerRange, splitee: "，") { currentRange, _ in
      fetched.append(String(sample[currentRange]))
      return true
    }

    #expect(fetched == ["甲", "乙", "丙"])
  }
}
