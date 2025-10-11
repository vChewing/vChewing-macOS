// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import Tekkon
import XCTest

// MARK: - Something Else

extension StringProtocol {
  /// 分析傳入的原始辭典檔案（UTF-8 TXT）的資料。
  /// - Parameters:
  ///   - separator: 行內單元分隔符。
  ///   - task: 要執行的外包任務。
  func parse(
    splitee separator: Element,
    task: @escaping (_ theRange: Range<String.Index>) -> ()
  ) {
    var startIndex = startIndex
    split(separator: separator).forEach { substring in
      let theRange = range(of: substring, range: startIndex ..< endIndex)
      guard let theRange else { return }
      task(theRange)
      startIndex = theRange.upperBound
    }
  }
}

extension Tekkon.MandarinParser {
  public init?(nameTag: String) {
    let matched = Self.allCases.first { $0.nameTag == nameTag }
    guard let matched else { return nil }
    self = matched
  }
}

// MARK: - SubTestCase

final class SubTestCase: Sendable {
  // MARK: Lifecycle

  init?(
    parser: Tekkon.MandarinParser,
    typing: any StringProtocol,
    expected: any StringProtocol
  ) {
    guard typing.first != "`" else { return nil }
    self.typing = typing.replacingOccurrences(of: "_", with: " ")
    self.expected = expected.replacingOccurrences(of: "_", with: " ")
    self.parser = parser
  }

  // MARK: Internal

  let parser: Tekkon.MandarinParser
  let typing: String
  let expected: String

  func verify() -> Bool {
    var composer = Tekkon.Composer(arrange: parser)
    let strResult = composer.receiveSequence(typing)
    guard strResult != expected else { return true }
    let parserTag = composer.parser.nameTag
    let strError =
      "MISMATCH (\(parserTag)): \"\(typing)\" -> \"\(strResult)\" != \"\(expected)\""
    print(strError)
    return false
  }
}

// MARK: - TekkonTestsKeyboardArrangmentsStatic

class TekkonTestsKeyboardArrangmentsStatic: XCTestCase {
  static func checkEq(
    _ counter: inout Int,
    _ composer: inout Tekkon.Composer,
    _ strGivenSeq: some StringProtocol,
    _ strExpected: some StringProtocol
  ) {
    let strResult = composer.receiveSequence(strGivenSeq.description)
    guard strResult != strExpected else { return }
    let parserTag = composer.parser.nameTag
    let strError =
      "MISMATCH (\(parserTag)): \"\(strGivenSeq)\" -> \"\(strResult)\" != \"\(strExpected)\""
    print(strError)
    counter += 1
  }

  func testQwertyDachenKeys() {
    // Testing Dachen Traditional Mapping (QWERTY)
    var c = Tekkon.Composer(arrange: .ofDachen)
    var counter = 0
    Self.checkEq(&counter, &c, " ", " ")
    Self.checkEq(&counter, &c, "18 ", "ㄅㄚ ")
    Self.checkEq(&counter, &c, "m,4", "ㄩㄝˋ")
    Self.checkEq(&counter, &c, "5j/ ", "ㄓㄨㄥ ")
    Self.checkEq(&counter, &c, "fu.", "ㄑㄧㄡ")
    Self.checkEq(&counter, &c, "g0 ", "ㄕㄢ ")
    Self.checkEq(&counter, &c, "xup6", "ㄌㄧㄣˊ")
    Self.checkEq(&counter, &c, "xu;6", "ㄌㄧㄤˊ")
    Self.checkEq(&counter, &c, "z/", "ㄈㄥ")
    Self.checkEq(&counter, &c, "tjo ", "ㄔㄨㄟ ")
    Self.checkEq(&counter, &c, "284", "ㄉㄚˋ")
    Self.checkEq(&counter, &c, "2u4", "ㄉㄧˋ")
    Self.checkEq(&counter, &c, "hl3", "ㄘㄠˇ")
    Self.checkEq(&counter, &c, "5 ", "ㄓ ")
    Self.checkEq(&counter, &c, "193", "ㄅㄞˇ")
    XCTAssertEqual(counter, 0)
  }
}

// MARK: - TekkonTestsKeyboardArrangmentsDynamic

class TekkonTestsKeyboardArrangmentsDynamic: XCTestCase {
  typealias Parser = Tekkon.MandarinParser

  func testDynamicKeyLayouts() {
    // 遍歷所有動態鍵盤配置
    for (idxRaw, parser) in Parser.allCases.filter(\.isDynamic).enumerated() {
      var cases = [SubTestCase?]()
      print(" -> [Tekkon] Preparing tests for dynamic keyboard handling...")
      var isTitleLine = true
      testTable4DynamicLayouts.parse(splitee: "\n") { theRange in
        guard !isTitleLine else {
          isTitleLine = false
          return
        }
        let cells = testTable4DynamicLayouts[theRange].split(separator: " ")
        let expected = cells[0]
        let idx = idxRaw + 1
        let typing = cells[idx]
        let newTestCase = SubTestCase(
          parser: parser,
          typing: typing.description,
          expected: expected.description
        )
        cases.append(newTestCase)
      }
      let timeTag = Date.now
      print(" -> [Tekkon][(\(parser.nameTag))] Starting dynamic keyboard handling test ...")
      let results = cases.compactMap { testCase in
        (testCase?.verify() ?? true) ? 0 : 1
      }.reduce(0, +)
      XCTAssertEqual(
        results, 0,
        "[Failure] \(parser.nameTag) failed from being handled correctly with \(results) bad results."
      )
      let timeDelta = Date.now.timeIntervalSince1970 - timeTag.timeIntervalSince1970
      let timeDeltaStr = String(format: "%.4f", timeDelta)
      print(
        " -> [Tekkon][(\(parser.nameTag))] Finished within \(timeDeltaStr) seconds."
      )
    }
  }
}
