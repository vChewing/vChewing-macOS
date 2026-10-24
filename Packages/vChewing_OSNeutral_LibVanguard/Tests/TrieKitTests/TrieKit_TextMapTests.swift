// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing
@testable import TrieKit

@Suite
struct TrieKitTextMapTests {
  // MARK: Internal

  @Test("[TrieKit] TYPING TextMap 3-column numeric value disambiguation")
  func testTypingTextMapThreeColumnNumericValueDisambiguation() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t2.0
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

    let textMap = try VanguardTrie.TrieIO.serializeToTextMap(trie)
    #expect(textMap.contains("VERSION\t2.0"))
    let roundTripped = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let values = roundTripped.nodes.values.first(where: { $0.readingKey == "foo" })?
      .entries.map(\.value).sorted() ?? []

    #expect(values == ["A B", "C|D"])
  }

  @Test("[TrieKit] ZWJ emoji and ideographic space survive grouped and contextual round trips")
  func testZWJEmojiAndIdeographicSpaceRoundTrips() throws {
    let trie = VanguardTrie.Trie(separator: "-")
    let emoji = "🙅‍♀️"
    let ideographicSpace = "\u{3000}"
    let combiningMarkEmoticon = "( ͒˃⌂˂ ͒)"
    for value in [emoji, ideographicSpace, combiningMarkEmoticon] {
      trie.insert(
        entry: .init(value: value, typeID: .init(rawValue: 4), probability: 0, previous: nil),
        readings: ["foo"]
      )
    }
    for (index, context) in ["要", emoji, ideographicSpace].enumerated() {
      trie.insert(
        entry: .init(
          value: emoji,
          typeID: .init(rawValue: 6),
          probability: -Double(index + 1),
          previous: context
        ),
        readings: ["foo"]
      )
    }

    let serialized = try VanguardTrie.TrieIO.serializeToTextMap(trie)
    #expect(serialized.contains(#"(\s͒˃⌂˂\s͒)"#))
    for trie in try [
      VanguardTrie.TrieIO.deserializeFromTextMap(serialized) as any VanguardTrieProtocol,
      VanguardTrie.TextMapTrie(data: Data(serialized.utf8)) as any VanguardTrieProtocol,
    ] {
      #expect(trie.queryGrams(["foo"], filterType: .init(rawValue: 4)).map(\.value) == [
        emoji, ideographicSpace, combiningMarkEmoticon,
      ])
      let contextual = trie.queryGrams(["foo"], filterType: .init(rawValue: 6))
      #expect(contextual.map(\.value) == Array(repeating: emoji, count: 3))
      #expect(contextual.compactMap(\.previous) == ["要", emoji, ideographicSpace])
    }
  }

  @Test("[TrieKit] Type C bare values may begin with reserved markers")
  func testTypeCBareValuesWithReservedMarkers() throws {
    let values = ["!詞", "@詞", ">詞"]
    let contexts = ["甲", "乙", "丙"]
    let trie = VanguardTrie.Trie(separator: "-")
    for (value, context) in zip(values, contexts) {
      trie.insert(
        entry: .init(value: value, typeID: .init(rawValue: 6), probability: -1, previous: context),
        readings: ["foo"]
      )
    }

    let serialized = try VanguardTrie.TrieIO.serializeToTextMap(trie)
    let typing = serialized.replacingOccurrences(of: "TYPE\tTRIE_TEXTMAP", with: "TYPE\tTYPING")
    for content in [serialized, typing] {
      for trie in try [
        VanguardTrie.TrieIO.deserializeFromTextMap(content) as any VanguardTrieProtocol,
        VanguardTrie.TextMapTrie(data: Data(content.utf8)) as any VanguardTrieProtocol,
      ] {
        let grams = trie.queryGrams(["foo"], filterType: .init(rawValue: 6))
        #expect(grams.map(\.value) == values)
        #expect(grams.compactMap(\.previous) == contexts)
      }
    }
  }

  @Test("[TrieKit] TextMap parsing tolerates CRLF line endings")
  func testTextMapParsingToleratesCRLFLineEndings() throws {
    let textMap =
      "#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER\r\nVERSION\t2.0\r\nTYPE\tTYPING\r\nREADING_SEPARATOR\t-\r\nENTRY_COUNT\t1\r\nKEY_COUNT\t1\r\n#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES\r\n@-9.9\t和\t和\r\n#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP\r\nhe4\t0\t1\r\n"

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
    VERSION\t2.0
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

  @Test("[TrieKit] Legacy bare VERSION 1 TextMap is rejected")
  func testLegacyBareVersionOneTextMapIsRejected() {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t1
    KEY_COUNT\t1
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    @-9.9\t和\t和
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    he4\t0\t1
    """

    #expect(throws: (any Error).self) {
      try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    }
    #expect(throws: (any Error).self) {
      try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))
    }
  }

  @Test("[TrieKit] Legacy TYPING grouped line remains readable")
  func testLegacyTypingGroupedLineStillParses() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t2.0
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
    VERSION\t2.0
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
    ㄕㄨˋ\t0\t3
    _norm\t3\t2
    """

    let fullTrie = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
    let lazyTrie = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))

    // 比對 ㄕㄨˋ 的查詢結果。
    let fullResults = fullTrie.queryGrams(
      ["ㄕㄨˋ"], filterType: .init(rawValue: 5), partiallyMatch: false
    ).sorted { $0.value < $1.value }
    let lazyResults = lazyTrie.queryGrams(
      ["ㄕㄨˋ"], filterType: .init(rawValue: 5), partiallyMatch: false
    ).sorted { $0.value < $1.value }

    #expect(fullResults.count == lazyResults.count)
    for (f, l) in zip(fullResults, lazyResults) {
      #expect(f.value == l.value)
      #expect(f.probability == l.probability)
    }

    // 比對 type 4（標點）的查詢結果。
    let fullType4 = fullTrie.queryGrams(
      ["ㄕㄨˋ"], filterType: .init(rawValue: 4), partiallyMatch: false
    ).map(\.value).sorted()
    let lazyType4 = lazyTrie.queryGrams(
      ["ㄕㄨˋ"], filterType: .init(rawValue: 4), partiallyMatch: false
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

    let serialized = try VanguardTrie.TrieIO.serializeToTextMap(trie)
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
    VERSION\t2.0
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
    VERSION\t2.0
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
    VERSION	2.0
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

  @Test("[TrieKit] TextMapTrie flushReverseLookupIndex releases index and rebuilds on demand")
  func testTextMapTrieFlushReverseLookupIndexRebuildsOnDemand() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t2.0
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

    let trie = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))
    #expect(trie.reverseLookup(for: "宜") == ["i2"])
    #expect(trie.reverseLookup(for: "𡜅") == ["lv3"])
    trie.flushReverseLookupIndex()
    #expect(trie.reverseLookup(for: "宜") == ["i2"])
    #expect(trie.reverseLookup(for: "𡜅") == ["lv3"])
  }

  @Test("[TrieKit] TextMap 型別 C 的第 4 欄承載至多兩層前驗詞鏈")
  func testTextMapTypeCContextCellCarriesMultigramChain() throws {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t2.0
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t2
    KEY_COUNT\t2
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    再\t-8.386\t6\t不要
    樣\t-8.562\t6\t不要|再
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    ㄗㄞˋ\t0\t1
    ㄧㄤˋ\t1\t1
    """

    let trie: any VanguardTrieProtocol = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))

    let bigrams = trie.queryGrams(["ㄗㄞˋ"], filterType: .init(rawValue: 6))
    #expect(bigrams.map(\.value) == ["再"])
    #expect(bigrams.first?.previous == "不要")
    #expect(bigrams.first?.anterior == nil)

    let trigrams = trie.queryGrams(["ㄧㄤˋ"], filterType: .init(rawValue: 6))
    #expect(trigrams.map(\.value) == ["樣"])
    #expect(trigrams.first?.previous == "再")
    #expect(trigrams.first?.anterior == "不要")
  }

  @Test("[TrieKit] Type D groups by value and type while preserving expansion order")
  func testTypeDGroupingAndRoundTripOrder() throws {
    let trie = VanguardTrie.Trie(separator: "-")
    let entries = [
      VanguardTrie.Trie.Entry(value: "再", typeID: .init(rawValue: 6), probability: -3.405, previous: "要"),
      VanguardTrie.Trie.Entry(
        value: "再",
        typeID: .init(rawValue: 6),
        probability: -3.502,
        previous: "要",
        anterior: "不"
      ),
      VanguardTrie.Trie.Entry(value: "再", typeID: .init(rawValue: 5), probability: -2, previous: "要"),
      VanguardTrie.Trie.Entry(value: "樣", typeID: .init(rawValue: 6), probability: -4, previous: "再"),
      VanguardTrie.Trie.Entry(value: "再", typeID: .init(rawValue: 6), probability: -1, previous: "呢"),
    ]
    for entry in entries { trie.insert(entry: entry, readings: ["foo"]) }

    let serialized = try VanguardTrie.TrieIO.serializeToTextMap(trie)
    #expect(valueLines(from: serialized) == [
      "!再\t6\t-3.405\t要\t-3.502\t不|要\t-1\t呢",
      "再\t-2\t5\t要",
      "樣\t-4\t6\t再",
    ])

    let full = try VanguardTrie.TrieIO.deserializeFromTextMap(serialized)
    let lazy = try VanguardTrie.TextMapTrie(data: Data(serialized.utf8))
    for typeID in [Int32(5), 6] {
      let filter = VanguardTrie.Trie.EntryType(rawValue: typeID)
      #expect(signatures(full.queryGrams(["foo"], filterType: filter)) == signatures(
        lazy.queryGrams(["foo"], filterType: filter)
      ))
    }
    let contextual = lazy.queryGrams(["foo"], filterType: .init(rawValue: 6))
    #expect(contextual.map(\.value) == ["再", "再", "再", "樣"])
    #expect(contextual.map(\.previous) == ["要", "要", "呢", "再"])
    #expect(contextual.map(\.anterior) == [nil, "不", nil, nil])
  }

  @Test("[TrieKit] Type D is identical in TYPING and TRIE_TEXTMAP modes")
  func testTypeDWorksInBothTextMapModes() throws {
    let line = "!再\t6\t-3.405\t要\t-3.502\t不|要"
    for type in ["TYPING", "TRIE_TEXTMAP"] {
      let textMap = makeTextMap(values: [line], type: type, keyMap: ["foo\t0\t1"])
      let full = try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
      let lazy = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))
      let fullGrams = full.queryGrams(["foo"], filterType: .init(rawValue: 6))
      let lazyGrams = lazy.queryGrams(["foo"], filterType: .init(rawValue: 6))
      #expect(signatures(fullGrams) == signatures(lazyGrams))
      #expect(lazyGrams.map(\.previous) == ["要", "要"])
      #expect(lazyGrams.map(\.anterior) == [nil, "不"])
      #expect(lazyGrams.map(\.probability) == [-3.405, -3.502])
    }
  }

  @Test("[TrieKit] Type D preserves bare values and all grouped-cell escapes")
  func testTypeDEscapesRoundTrip() throws {
    let trie = VanguardTrie.Trie(separator: "-")
    let value = "!詞|\\"
    let contexts = ["A B", "C|D", "E\\F", "G\u{7}H"]
    for (index, context) in contexts.enumerated() {
      trie.insert(
        entry: .init(
          value: value,
          typeID: .init(rawValue: 6),
          probability: -Double(index + 1),
          context: [context]
        ),
        readings: ["foo"]
      )
    }

    let serialized = try VanguardTrie.TrieIO.serializeToTextMap(trie)
    let line = try #require(valueLines(from: serialized).first)
    #expect(line.hasPrefix("!!詞|\\"))
    #expect(line.contains("A\\sB"))
    #expect(line.contains("C\\|D"))
    #expect(line.contains("E\\\\F"))
    #expect(line.contains("G\\aH"))

    for trie in try [
      VanguardTrie.TrieIO.deserializeFromTextMap(serialized) as any VanguardTrieProtocol,
      VanguardTrie.TextMapTrie(data: Data(serialized.utf8)) as any VanguardTrieProtocol,
    ] {
      let grams = trie.queryGrams(["foo"], filterType: .init(rawValue: 6))
      #expect(grams.map(\.value) == Array(repeating: value, count: 4))
      #expect(grams.compactMap(\.previous) == contexts)
    }
  }

  @Test("[TrieKit] Type D chunks 17 and 33 entries without a singleton tail")
  func testTypeDChunking() throws {
    for count in [17, 33] {
      let trie = VanguardTrie.Trie(separator: "-")
      for index in 0 ..< count {
        trie.insert(
          entry: .init(
            value: "再",
            typeID: .init(rawValue: 6),
            probability: -1,
            previous: "P\(index)"
          ),
          readings: ["foo"]
        )
      }
      let serialized = try VanguardTrie.TrieIO.serializeToTextMap(trie)
      let lines = valueLines(from: serialized)
      #expect(lines.map { ($0.components(separatedBy: "\t").count - 2) / 2 } == (
        count == 17 ? [15, 2] : [16, 15, 2]
      ))
      let full = try VanguardTrie.TrieIO.deserializeFromTextMap(serialized)
      let lazy = try VanguardTrie.TextMapTrie(data: Data(serialized.utf8))
      let expected = (0 ..< count).map { "P\($0)" }
      #expect(full.queryGrams(["foo"], filterType: .init(rawValue: 6)).compactMap(\.previous) == expected)
      #expect(lazy.queryGrams(["foo"], filterType: .init(rawValue: 6)).compactMap(\.previous) == expected)
    }
  }

  @Test("[TrieKit] Contextual entries do not suppress default probabilities")
  func testDefaultProbabilityExcludesContextualEntries() throws {
    let trie = VanguardTrie.Trie(separator: "-")
    for value in ["A", "B"] {
      trie.insert(
        entry: .init(value: value, typeID: .init(rawValue: 6), probability: -5, previous: nil),
        readings: ["foo"]
      )
    }
    trie.insert(
      entry: .init(value: "A", typeID: .init(rawValue: 6), probability: -9, previous: "P"),
      readings: ["foo"]
    )

    let serialized = try VanguardTrie.TrieIO.serializeToTextMap(trie)
    #expect(serialized.contains("DEFAULT_PROB_6\t-5\n"))
    #expect(serialized.contains(">6\tA|B"))
    let full = try VanguardTrie.TrieIO.deserializeFromTextMap(serialized)
    let unigrams = full.queryGrams(["foo"], filterType: .init(rawValue: 6)).filter {
      $0.previous == nil && $0.anterior == nil
    }
    #expect(unigrams.map(\.value) == ["A", "B"])
    #expect(unigrams.allSatisfy { $0.probability == -5 })
  }

  @Test("[TrieKit] Full and lazy loaders reject every malformed VALUES line")
  func testMalformedValueLinesAreRejectedEagerly() throws {
    let d17 = "!A\t6\t" + (0 ..< 17).map { "-1\tP\($0)" }.joined(separator: "\t")
    let malformed = [
      ">4\tA\textra",
      "@-1\tA\tB\textra",
      "A\t-1",
      "A\t-1\t6\tP\textra",
      "!A\t6\t-1\tP\t-2",
      d17,
      "A\tnan\t6",
      "A\tinf\t6",
      "A\t-1\t6\t",
      "A\t-1\t6\tP|Q|R",
      "A\t-1\t6\tP\\q",
      "A\t-1\t6\tP\\",
      "A\t-1\t6\tP||Q",
      "A\t-1\t6\tP Q",
      "A\t-1\t6\tP\u{1}",
    ]
    for line in malformed {
      let textMap = makeTextMap(values: [line])
      #expect(throws: (any Error).self) {
        try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
      }
      #expect(throws: (any Error).self) {
        try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))
      }
    }
  }

  @Test("[TrieKit] Version gate requires explicit 2.0 and empty B sides stay valid")
  func testVersionGateAndEmptyTypingCells() throws {
    for version in [nil, "VERSION\t2.1", "VERSION\t2.0.1"] {
      let textMap = makeTextMap(values: ["A\t-1\t6"], version: version)
      #expect(throws: (any Error).self) {
        try VanguardTrie.TrieIO.deserializeFromTextMap(textMap)
      }
      #expect(throws: (any Error).self) {
        try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))
      }
    }

    let valid = makeTextMap(
      values: ["@-1\t\t\u{7}"],
      keyMap: ["foo\t0\t1"]
    )
    let full = try VanguardTrie.TrieIO.deserializeFromTextMap(valid)
    let lazy = try VanguardTrie.TextMapTrie(data: Data(valid.utf8))
    #expect(full.queryGrams(["foo"], filterType: .init(rawValue: 5)).isEmpty)
    #expect(lazy.queryGrams(["foo"], filterType: .init(rawValue: 5)).isEmpty)
  }

  @Test("[TrieKit] Serializer rejects long contexts, controls, and non-finite probabilities")
  func testSerializerRejectsUnrepresentableEntries() {
    let entries = [
      VanguardTrie.Trie.Entry(
        value: "A", typeID: .init(rawValue: 6), probability: -1, context: ["P", "Q", "R"]
      ),
      VanguardTrie.Trie.Entry(
        value: "A\nB", typeID: .init(rawValue: 6), probability: -1, previous: "P"
      ),
      VanguardTrie.Trie.Entry(
        value: "A", typeID: .init(rawValue: 6), probability: -1, context: ["P\tQ"]
      ),
      VanguardTrie.Trie.Entry(
        value: "A", typeID: .init(rawValue: 6), probability: .nan, previous: "P"
      ),
    ]
    for entry in entries {
      let trie = VanguardTrie.Trie(separator: "-")
      trie.insert(entry: entry, readings: ["foo"])
      #expect(throws: (any Error).self) {
        try VanguardTrie.TrieIO.serializeToTextMap(trie)
      }
    }
  }

  // MARK: Private

  private func makeTextMap(
    values: [String],
    version: String? = "VERSION\t2.0",
    type: String = "TYPING",
    keyMap: [String] = []
  )
    -> String {
    var lines = ["#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER"]
    if let version { lines.append(version) }
    lines.append("TYPE\t\(type)")
    lines.append("READING_SEPARATOR\t-")
    lines.append("ENTRY_COUNT\t\(values.count)")
    lines.append("KEY_COUNT\t\(keyMap.count)")
    lines.append("#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES")
    lines.append(contentsOf: values)
    lines.append("#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP")
    lines.append(contentsOf: keyMap)
    return lines.joined(separator: "\n")
  }

  private func valueLines(from textMap: String) -> [String] {
    guard let values = textMap.range(of: "#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES\n"),
          let keyMap = textMap.range(of: "#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP")
    else { return [] }
    return textMap[values.upperBound ..< keyMap.lowerBound].split(whereSeparator: \.isNewline).map(String.init)
  }

  private func signatures(_ grams: [VanguardTrie.TrieGram]) -> [String] {
    grams.map {
      [$0.value, $0.previous ?? "nil", $0.anterior ?? "nil", $0.probability.description]
        .joined(separator: "|")
    }
  }
}
