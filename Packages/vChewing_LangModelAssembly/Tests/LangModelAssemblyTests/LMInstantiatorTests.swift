// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import XCTest

@testable import LangModelAssembly

final class LMInstantiatorTests: XCTestCase {
  func testReplaceDataSavesToCorrectStore() {
    let lmi = LMAssembly.LMInstantiator()
    let sample = "foo bar\n"

    lmi.replaceData(textData: sample, for: .thePhrases, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .thePhrases).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theFilter, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .theFilter).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theReplacements, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .theReplacements).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theAssociates, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .theAssociates).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theSymbols, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .theSymbols).contains("foo bar"))
  }

  func testCleanupInputTokenHashMapRemovesToTargetSize() {
    let instance = LMAssembly.LMInstantiator()
    // Create 3500 dummy hashes
    instance.inputTokenHashesArray = ContiguousArray((0 ..< 3_500).map { $0 })
    // Trigger cleanup via a simple unigram query
    _ = instance.unigramsFor(keyArray: ["ㄎㄜ"])
    XCTAssertEqual(instance.inputTokenHashesArray.count, 1_000)
  }
}
