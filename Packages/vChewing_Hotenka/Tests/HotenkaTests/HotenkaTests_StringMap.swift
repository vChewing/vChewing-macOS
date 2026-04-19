// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing

@testable import Hotenka

@Suite
struct HotenkaTests {
  // MARK: Internal

  @Test
  func generatingStringMap() throws {
    let url = try HotenkaTestSupport.ensureStringMapFixture()
    #expect(FileManager.default.fileExists(atPath: url.path))
  }

  @Test
  func generatedStringMapIsTextBased() throws {
    let data = try HotenkaTestSupport.stringMapFixtureData()
    let rendered = try #require(String(data: data, encoding: .utf8))
    #expect(rendered.hasPrefix("HTSMAPTXT\t00000001\n"))
    #expect(!data.contains(0x00))
  }

  @Test
  func generatedStringMapAcceptsCRLFInput() throws {
    let lfData = try HotenkaTestSupport.stringMapFixtureData()
    var crlfData = Data()
    crlfData.reserveCapacity(lfData.count * 2)
    for byte in lfData {
      if byte == 0x0A { crlfData.append(0x0D) }
      crlfData.append(byte)
    }
    let stringMap = try Hotenka.StringMap(data: crlfData)
    #expect(stringMap.query(dict: .zhHantTW, key: "一丝不挂") == "一絲不掛")
  }

  @Test
  func sampleConversion() throws {
    let url = try HotenkaTestSupport.ensureStringMapFixture()
    let converter = try HotenkaChineseConverter(stringMapPath: url.path)
    HotenkaTestSupport.verifySampleConversion(using: converter)
  }

  @Test
  func exactQuery() throws {
    let url = try HotenkaTestSupport.ensureStringMapFixture()
    let converter = try HotenkaChineseConverter(stringMapPath: url.path)
    #expect(converter.query(dict: .zhHantTW, key: "一丝不挂") == "一絲不掛")
  }

  @Test
  func generatedFixturesAreDeterministic() throws {
    #expect(
      try HotenkaTestSupport.stringMapFixtureData()
        == HotenkaTestSupport.stringMapFixtureData()
    )
  }

  @Test
  func canonicalEquivalentQueryAndConvert() throws {
    let decomposed = "e\u{301}"
    let composed = "\u{00E9}"

    var dictionaryStore = makeEmptyDictionaryStore()
    dictionaryStore[DictType.zhHantTW.rawKeyString] = [decomposed: "E_ACUTE"]

    let stringMap = try Hotenka.StringMap(
      data: Hotenka.StringMap.serialize(from: dictionaryStore)
    )
    let converter = HotenkaChineseConverter(stringMap: stringMap)

    #expect(converter.query(dict: .zhHantTW, key: composed) == "E_ACUTE")
    #expect(converter.convert(composed, to: .zhHantTW) == "E_ACUTE")
  }

  @Test
  func retainedIndexFootprintStaysBelowStringMapStorage() throws {
    let url = try HotenkaTestSupport.ensureStringMapFixture()
    let converter = try HotenkaChineseConverter(stringMapPath: url.path)

    HotenkaTestSupport.verifySampleConversion(using: converter)

    let profile = converter.debugProfile()

    #expect(profile.stringMapStorageBytes > 0)
    #expect(profile.retainedIndexBytes > 0)
    #expect(profile.retainedIndexBytes == profile.maximumKeyLengthTableBytes)
    #expect(profile.retainedIndexBytes < profile.stringMapStorageBytes)
  }

  // MARK: Private

  private func makeEmptyDictionaryStore() -> [String: [String: String]] {
    Dictionary(
      uniqueKeysWithValues: DictType.allCases.map { ($0.rawKeyString, [:]) }
    )
  }
}
