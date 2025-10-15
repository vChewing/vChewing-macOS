// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import Shared
import XCTest

class CandidateServiceCoordinatorTests: XCTestCase {
  static let testDataMap: [String] = [
    #"Unicode Metadata: %s"# + "\t" + #"@SEL:copyUnicodeMetadata:"#,
    #"HTML Ruby Zhuyin: %s"# + "\t" + #"@SEL:copyRubyHTMLZhuyinTextbookStyle:"#,
    #"HTML Ruby Pinyin: %s"# + "\t" + #"@SEL:copyRubyHTMLHanyuPinyinTextbookStyle:"#,
    #"Zhuyin Annotation: %s"# + "\t" + #"@SEL:copyInlineZhuyinAnnotationTextbookStyle:"#,
    #"Pinyin Annotation: %s"# + "\t" + #"@SEL:copyInlineHanyuPinyinAnnotationTextbookStyle:"#,
    #"Braille 1947: %s"# + "\t" + #"@SEL:copyBraille1947:"#,
    #"Braille 2018: %s"# + "\t" + #"@SEL:copyBraille2018:"#,
  ]

  func testSelector_FinalSanityCheck() throws {
    var stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "胡桃", reading: [] // 故意使用空 Reading
    )
    let count1 = stacked.count
    print("Current Count before Sanity Check ON: \(stacked.count)")
    CandidateTextService.enableFinalSanityCheck()
    stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "胡桃", reading: [] // 故意使用空 Reading
    )
    let count2 = stacked.count
    print("Current Count after Sanity Check ON: \(stacked.count)")
    XCTAssertGreaterThan(count1, count2)
  }

  func testSelector_UnicodeMetadata() throws {
    let stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "胡桃", reading: ["ㄏㄨˊ", "ㄊㄠˊ"]
    )
    let theService = stacked[0]
    switch theService.value {
    case .url: break
    case .selector:
      let response = theService.responseFromSelector
      let expectedResponse =
        "胡 U+80E1 CJK UNIFIED IDEOGRAPH-80E1\n桃 U+6843 CJK UNIFIED IDEOGRAPH-6843"
      XCTAssertEqual(response, expectedResponse)
    }
  }

  func testSelector_HTMLRubyZhuyinTextbookStyle() throws {
    let stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "甜的", reading: ["ㄊㄧㄢˊ", "ㄉㄜ˙"]
    )
    let theService = stacked[1]
    switch theService.value {
    case .url: break
    case .selector:
      let response = theService.responseFromSelector
      let expectedResponse =
        "<ruby>甜<rp>(</rp><rt>ㄊㄧㄢˊ</rt><rp>)</rp></ruby><ruby>的<rp>(</rp><rt>˙ㄉㄜ</rt><rp>)</rp></ruby>"
      XCTAssertEqual(response, expectedResponse)
    }
  }

  func testSelector_HTMLRubyPinyinTextbookStyle() throws {
    let stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "鐵嘴", reading: ["ㄊㄧㄝˇ", "ㄗㄨㄟˇ"]
    )
    let theService = stacked[2]
    switch theService.value {
    case .url: break
    case .selector:
      let response = theService.responseFromSelector
      let expectedResponse =
        "<ruby>鐵<rp>(</rp><rt>tiě</rt><rp>)</rp></ruby><ruby>嘴<rp>(</rp><rt>zuǐ</rt><rp>)</rp></ruby>"
      XCTAssertEqual(response, expectedResponse)
    }
  }

  func testSelector_InlineAnnotationZhuyinTextbookStyle() throws {
    let stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "甜的", reading: ["ㄊㄧㄢˊ", "ㄉㄜ˙"]
    )
    let theService = stacked[3]
    switch theService.value {
    case .url: break
    case .selector:
      let response = theService.responseFromSelector
      let expectedResponse = "甜(ㄊㄧㄢˊ)的(˙ㄉㄜ)"
      XCTAssertEqual(response, expectedResponse)
    }
  }

  func testSelector_InlineAnnotationTextbookStyle() throws {
    let stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "鐵嘴", reading: ["ㄊㄧㄝˇ", "ㄗㄨㄟˇ"]
    )
    let theService = stacked[4]
    switch theService.value {
    case .url: break
    case .selector:
      let response = theService.responseFromSelector
      let expectedResponse = "鐵(tiě)嘴(zuǐ)"
      XCTAssertEqual(response, expectedResponse)
    }
  }

  func testSelector_Braille1947() throws {
    let stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "幽蝶能留一縷芳",
      reading: ["ㄧㄡ", "ㄉㄧㄝˊ", "ㄋㄥˊ", "ㄌㄧㄡˊ", "ㄧˋ", "ㄌㄩˇ", "ㄈㄤ"]
    )
    let theService = stacked[5]
    switch theService.value {
    case .url: break
    case .selector:
      let response = theService.responseFromSelector
      let expectedResponse = "⠎⠄⠙⠬⠂⠝⠵⠂⠉⠎⠂⠡⠐⠉⠳⠈⠟⠭⠄"
      XCTAssertEqual(response, expectedResponse)
    }
  }

  func testSelector_Braille2018() throws {
    let stacked = Self.testDataMap.parseIntoCandidateTextServiceStack(
      candidate: "幽蝶能留一縷芳",
      reading: ["ㄧㄡ", "ㄉㄧㄝˊ", "ㄋㄥˊ", "ㄌㄧㄡˊ", "ㄧˋ", "ㄌㄩˇ", "ㄈㄤ"]
    )
    let theService = stacked[6]
    switch theService.value {
    case .url: break
    case .selector:
      let response = theService.responseFromSelector
      let expectedResponse = "⠳⠁⠙⠑⠂⠝⠼⠂⠇⠳⠂⠊⠆⠇⠬⠄⠋⠦⠁"
      XCTAssertEqual(response, expectedResponse)
    }
  }
}
