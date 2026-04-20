// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing
@testable import TrieKit

@Suite(.serialized)
struct TrieKitTextMapTests {
  @Test("[TrieKit] TYPING TextMap 3-column numeric value disambiguation")
  func testTypingTextMapThreeColumnNumericValueDisambiguation() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t1
    KEY_COUNT\t1
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    1\t-13\t8
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    foo\t0\t1
    """

    let trie = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let entries = trie.nodes.values.first(where: { $0.readingKey == "foo" })?.entries ?? []
    let entry = try #require(entries.first)

    #expect(entries.count == 1)
    #expect(entry.value == "1")
    #expect(entry.typeID.rawValue == 8)
    #expect(entry.probability == -13)
  }

  @Test("[TrieKit] TextMap round-trip preserves escaped grouped values")
  func testTextMapRoundTripPreservesEscapedGroupedValues() throws {
    let trie = VanguardTrie.Trie(separator: "-")
    trie.insert(
      entry: .init(value: "A B", typeID: .init(rawValue: 4), probability: 0, previous: nil),
      readings: ["foo"]
    )
    trie.insert(
      entry: .init(value: "C|D", typeID: .init(rawValue: 4), probability: 0, previous: nil),
      readings: ["foo"]
    )

    let textMap = VanguardTrie.TrieIO.serializeToTextMap(trie)
    let roundTripped = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let values = roundTripped.nodes.values.first(where: { $0.readingKey == "foo" })?
      .entries.map(\.value).sorted() ?? []

    #expect(values == ["A B", "C|D"])
  }

  @Test("[TrieKit] TextMap parsing tolerates CRLF line endings")
  func testTextMapParsingToleratesCRLFLineEndings() throws {
    let textMap =
      "#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER\r\nVERSION\t1\r\nTYPE\tTYPING\r\nREADING_SEPARATOR\t-\r\nENTRY_COUNT\t1\r\nKEY_COUNT\t1\r\n#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES\r\n@-9.9\t和\t和\r\n#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP\r\nhe4\t0\t1\r\n"

    let trie = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let entries = trie.nodes.values.first(where: { $0.readingKey == "he4" })?.entries ?? []
    let values = entries.map(\.value).sorted()
    let typeIDs = entries.map { $0.typeID.rawValue }.sorted()

    #expect(entries.count == 2)
    #expect(values == ["和", "和"])
    #expect(typeIDs == [5, 6])
  }

  @Test("[TrieKit] TYPING TextMap grouped line with marker and escapes")
  func testTypingTextMapGroupedLineWithMarkerAndEscapes() throws {
    let encodedChsCell = #"A\sB|C\|D"#
    let emptyGroupedCellPlaceholder = String(UnicodeScalar(7)!)
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t1
    KEY_COUNT\t1
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    @-5.307\t\(encodedChsCell)\t\(emptyGroupedCellPlaceholder)
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    foo\t0\t1
    """

    let trie = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let entries = trie.nodes.values.first(where: { $0.readingKey == "foo" })?.entries ?? []
    let values = entries.map(\.value).sorted()

    #expect(entries.count == 2)
    #expect(values == ["A B", "C|D"])
    #expect(entries.allSatisfy { $0.typeID.rawValue == 5 })
    #expect(entries.allSatisfy { $0.probability == -5.307 })
  }

  @Test("[TrieKit] Legacy TYPING grouped line remains readable")
  func testLegacyTypingGroupedLineStillParses() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t1
    KEY_COUNT\t1
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    -9.465\t数 樹\t數
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    foo\t0\t1
    """

    let trie = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let entries = trie.nodes.values.first(where: { $0.readingKey == "foo" })?.entries ?? []
    let chsValues = entries.filter { $0.typeID.rawValue == 5 }.map(\.value).sorted()
    let chtValues = entries.filter { $0.typeID.rawValue == 6 }.map(\.value).sorted()

    #expect(chsValues == ["数", "樹"])
    #expect(chtValues == ["數"])
  }

  // MARK: - TextMapTrie Tests

  @Test("[TrieKit] TextMapTrie produces identical query results as full materialization")
  func testTextMapTrieEquivalence() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t5
    KEY_COUNT\t2
    DEFAULT_PROB_4\t0
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    @-5.28\t束\t束
    @-9.465\t数|樹\t數
    >4\t，|。
    _NORM\t0\t2
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    Su4\t0\t3
    _norm\t3\t2
    """

    let fullTrie = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let lazyTrie = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))

    // 比對 Su4 的查詢結果。
    let fullResults = fullTrie.queryGrams(
      ["Su4"], filterType: .init(rawValue: 5), partiallyMatch: false
    ).sorted { $0.value < $1.value }
    let lazyResults = lazyTrie.queryGrams(
      ["Su4"], filterType: .init(rawValue: 5), partiallyMatch: false
    ).sorted { $0.value < $1.value }

    #expect(fullResults.count == lazyResults.count)
    for (f, l) in zip(fullResults, lazyResults) {
      #expect(f.value == l.value)
      #expect(f.probability == l.probability)
    }

    // 比對 type 4（標點）的查詢結果。
    let fullType4 = fullTrie.queryGrams(
      ["Su4"], filterType: .init(rawValue: 4), partiallyMatch: false
    ).map(\.value).sorted()
    let lazyType4 = lazyTrie.queryGrams(
      ["Su4"], filterType: .init(rawValue: 4), partiallyMatch: false
    ).map(\.value).sorted()

    #expect(fullType4 == lazyType4)
  }

  @Test("[TrieKit] TextMapTrie supports TRIE_TEXTMAP type with grouped and individual entries")
  func testTextMapTrieGenericTrieTextMap() throws {
    let trie = VanguardTrie.Trie(separator: "-")
    trie.insert(
      entry: .init(value: "A B", typeID: .init(rawValue: 4), probability: 0, previous: nil),
      readings: ["foo"]
    )
    trie.insert(
      entry: .init(value: "C|D", typeID: .init(rawValue: 4), probability: 0, previous: nil),
      readings: ["foo"]
    )
    trie.insert(
      entry: .init(value: "solo", typeID: .init(rawValue: 7), probability: -3.5, previous: nil),
      readings: ["bar"]
    )

    let serialized = VanguardTrie.TrieIO.serializeToTextMap(trie)
    let lazyTrie = try VanguardTrie.TextMapTrie(data: Data(serialized.utf8))

    let fooValues = lazyTrie.queryGrams(
      ["foo"], filterType: .init(rawValue: 4), partiallyMatch: false
    ).map(\.value).sorted()
    #expect(fooValues == ["A B", "C|D"])

    let barValues = lazyTrie.queryGrams(
      ["bar"], filterType: .init(rawValue: 7), partiallyMatch: false
    )
    #expect(barValues.count == 1)
    #expect(barValues.first?.value == "solo")
    #expect(barValues.first?.probability == -3.5)
  }

  @Test("[TrieKit] TextMapTrie partial matching and longer segment")
  func testTextMapTriePartialAndLongerSegment() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1
    TYPE\tTRIE_TEXTMAP
    READING_SEPARATOR\t-
    ENTRY_COUNT\t3
    KEY_COUNT\t3
    DEFAULT_PROB_1\t-1
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    >1\tA
    >1\tB
    >1\tC
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    ab\t0\t1
    ab-cd\t1\t1
    ab-ce\t2\t1
    """

    let lazyTrie = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))

    // Partial match: "a" 應配對 "ab" 開頭的所有讀音鍵。
    let partial = lazyTrie.getNodes(
      keyArray: ["a"],
      filterType: .init(rawValue: 1),
      partiallyMatch: true,
      longerSegment: false
    )
    #expect(partial.count == 1)
    #expect(partial.first?.entries.first?.value == "A")

    // Longer segment: ["ab"] 應找到 "ab-cd" 和 "ab-ce"。
    let longer = lazyTrie.getNodes(
      keyArray: ["ab"],
      filterType: .init(rawValue: 1),
      partiallyMatch: false,
      longerSegment: true
    )
    #expect(longer.count == 2)
    let longerValues = longer.flatMap(\.entries).map(\.value).sorted()
    #expect(longerValues == ["B", "C"])
  }

  @Test("[TrieKit] TextMap auto-generated RevLookup indexes single-segment @ lines and CNS entries")
  func testTextMapAutoGeneratedRevLookupIndexesSingleSegmentGroupedLinesAndCNSEntries() throws {
    let revLookupType = VanguardTrie.Trie.EntryType(rawValue: 3)
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t3
    KEY_COUNT\t3
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    @-9.9\t宜\t宜
    @-8.8\t便宜\t便宜
    𡜅\t-11\t7
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    i2\t0\t1
    bi4-i2\t1\t1
    lv3\t2\t1
    """

    let fullTrie = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let fullRevLookup = fullTrie.queryGrams(["宜"], filterType: revLookupType).first?.value
    #expect(fullRevLookup == "i2")
    let fullCNSRevLookup = fullTrie.queryGrams(["𡜅"], filterType: revLookupType).first?.value
    #expect(fullCNSRevLookup == "lv3")

    let lazyTrie = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))
    let lazyRevLookup = lazyTrie.queryGrams(["宜"], filterType: revLookupType).first?.value
    #expect(lazyRevLookup == "i2")
    let lazyCNSRevLookup = lazyTrie.queryGrams(["𡜅"], filterType: revLookupType).first?.value
    #expect(lazyCNSRevLookup == "lv3")
  }

  @Test("[TrieKit] TextMapTrie existential query APIs preserve partial and associated phrase semantics")
  func testTextMapTrieExistentialQueryAPIs() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION	1
    TYPE	TRIE_TEXTMAP
    READING_SEPARATOR	-
    ENTRY_COUNT	4
    KEY_COUNT	3
    DEFAULT_PROB_1	-1
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    X	-1	1
    XY	-2	1
    XZ	-3	1	PREV
    XW	-4	1
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    ab	0	1
    ab-cd	1	2
    ab-ce	3	1
    """

    let trie: any VanguardTrieProtocol = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))

    let partial = trie.queryGrams(["a"], filterType: .init(rawValue: 1), partiallyMatch: true)
    #expect(partial.map(\.value) == ["X"])

    let associated = trie.queryAssociatedPhrasesAsGrams(
      (["ab"], "X"),
      filterType: .init(rawValue: 1)
    )
    #expect(associated?.map(\.value) == ["XY", "XZ", "XW"])

    let associatedFiltered = trie.queryAssociatedPhrasesAsGrams(
      (["ab"], "X"),
      anterior: "PREV",
      filterType: .init(rawValue: 1)
    )
    #expect(associatedFiltered?.map(\.value) == ["XZ"])
  }
}
