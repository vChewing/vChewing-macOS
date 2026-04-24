// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import HomaSharedTestComponents
import Testing

@testable import Homa

// MARK: - HomaTestsAdvanced

@Suite(.serialized)
public struct HomaTestsAdvanced: HomaTestSuite {
  /// 組字器的分詞功能測試，同時測試組字器的硬拷貝功能。
  @Test("[Homa] Assember_HardCopyAndWordSegmentation")
  func testHardCopyAndWordSegmentation() async throws {
    let regexToFilter = try Regex(".* 能留 .*\n")
    let mockLM = TestLM(
      rawData: HomaTests.strLMSampleDataHutao.replacing(regexToFilter, with: ""),
      readingSeparator: "",
      valueSegmentationOnly: true
    )
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    try "幽蝶能留一縷芳".forEach { i in
      try assembler.insertKey(i.description)
    }
    let result = assembler.assemble()
    #expect(result.joinedKeys(by: "") == ["幽蝶", "能", "留", "一縷", "芳"])
    let hardCopy = assembler.copy
    #expect(hardCopy.config == assembler.config)
  }

  /// 組字器的組字壓力測試。
  @Test("[Homa] Assember_StressBench")
  func testStressBenchOnAssemblingSentences() async throws {
    print("// Stress test preparation begins.")
    let mockLM = TestLM(rawData: HomaTests.strLMStressData)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    try (0 ..< 512).forEach { _ in
      try assembler.insertKey("sheng1")
    }
    print("// Stress test started.")
    let timeElapsed = Self.measureTime {
      assembler.assemble()
    }
    print("// Stress test elapsed: \(timeElapsed)s.")
  }

  @Test("[Homa] Assembler_UpdateUnigramDataForAllNodes")
  func testUpdateUnigramDataForAllNodes() async throws {
    let readings: [Substring] = "shu4 xin1 feng1".split(separator: " ")
    let newRawStringLM = HomaTests.strLMSampleDataEmoji + "\nshu4-xin1-feng1 樹新風 -9"
    let regexToFilter = try Regex(".*(樹|新|風) .*")
    let mockLMWithFilter = TestLM(
      rawData: newRawStringLM.replacing(regexToFilter, with: "")
    )
    let mockLM = TestLM(
      rawData: newRawStringLM
    )
    let assembler = Homa.Assembler(
      gramQuerier: { mockLMWithFilter.queryGrams($0) }, // 會回傳包含 Bigram 的結果。
    )
    try readings.forEach {
      try assembler.insertKey($0.description)
    }
    var assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["樹心", "封"])
    // 先置換語言模型 API 再更新所有節點的 Unigram 資料。
    assembler.gramQuerier = { mockLM.queryGrams($0) }
    try assembler.assignNodes(updateExisting: true)
    assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["樹新風"])
  }

  /// `fetchCandidatesDeprecated` 這個方法在極端情況下（比如兩個連續讀音，等）會有故障，現已棄用。
  /// 目前這筆測試並不能曝露這個函式的問題，但卻能用來輔助測試其**繼任者**是否能完成一致的正確工作。
  @Test("[Homa] Assembler_VerifyCandidateFetchResultsWithNewAPI")
  func testVerifyCandidateFetchResultsWithNewAPI() async throws {
    let readings = "da4 qian2 tian1 zai5 ke1 ji4 gong1 yuan2 chao1 shang1"
    let mockLM = TestLM(
      rawData: HomaTests.strLMSampleDataTechGuarden + "\n" + HomaTests.strLMSampleDataLitch
    )
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    try readings.split(separator: " ").forEach {
      try assembler.insertKey($0.description)
    }
    // 初始組句結果。
    let assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["大前天", "在", "科技", "公園", "超商"])
    var stack1A = [String]()
    var stack1B = [String]()
    var stack2A = [String]()
    var stack2B = [String]()
    for i in 0 ... assembler.keys.count {
      stack1A
        .append(
          assembler.fetchCandidates(at: i, filter: .beginAt).map(\.pair.value)
            .joined(separator: "-")
        )
      stack1B
        .append(
          assembler.fetchCandidates(at: i, filter: .endAt).map(\.pair.value)
            .joined(separator: "-")
        )
      stack2A
        .append(
          assembler.fetchCandidatesDeprecated(at: i, filter: .beginAt).map(\.pair.value)
            .joined(separator: "-")
        )
      stack2B
        .append(
          assembler.fetchCandidatesDeprecated(at: i, filter: .endAt).map(\.pair.value)
            .joined(separator: "-")
        )
    }
    stack1B.removeFirst()
    stack2B.removeLast()
    #expect(stack1A == stack2A)
    #expect(stack1B == stack2B)
  }

  /// 測試是否有效隔絕橫跨游標位置的候選字詞。
  ///
  /// 「選字窗內出現橫跨游標的候選字」的故障會破壞使用體驗，得防止發生。
  /// （微軟新注音沒有這個故障，macOS 內建的注音也沒有。）
  @Test("[Homa] Assember_FilteringOutCandidatesAcrossingTheCursor")
  func testFilteringOutCandidatesAcrossingTheCursor() async throws {
    // 一號測試。
    do {
      let readings: [Substring] = "ke1 ji4 gong1 yuan2".split(separator: " ")
      let mockLM = TestLM(rawData: HomaTests.strLMSampleDataTechGuarden)
      let assembler = Homa.Assembler(
        gramQuerier: { mockLM.queryGrams($0) }
      )
      try readings.forEach {
        try assembler.insertKey($0.description)
      }
      // 初始組句結果。
      let assembledSentence = assembler.assemble().compactMap(\.value)
      #expect(assembledSentence == ["科技", "公園"])
      // 測試候選字詞過濾。
      let gotBeginAt = assembler.fetchCandidates(at: 2, filter: .beginAt).map(\.pair.value)
      let gotEndAt = assembler.fetchCandidates(at: 2, filter: .endAt).map(\.pair.value)
      #expect(!gotBeginAt.contains("濟公"))
      #expect(gotBeginAt.contains("公園"))
      #expect(!gotEndAt.contains("公園"))
      #expect(gotEndAt.contains("科技"))
    }
    // 二號測試。
    do {
      let readings: [Substring] = "sheng1 sheng1".split(separator: " ")
      let mockLM = TestLM(
        rawData: HomaTests.strLMStressData + "\n"
          + HomaTests
          .strLMSampleDataHutao
      )
      let assembler = Homa.Assembler(
        gramQuerier: { mockLM.queryGrams($0) }
      )
      try readings.forEach {
        try assembler.insertKey($0.description)
      }
      var a =
        assembler.fetchCandidates(at: 1, filter: .beginAt)
          .map(\.pair.keyArray.count).max() ?? 0
      var b =
        assembler.fetchCandidates(at: 1, filter: .endAt)
          .map(\.pair.keyArray.count).max() ?? 0
      var c =
        assembler.fetchCandidates(at: 0, filter: .beginAt)
          .map(\.pair.keyArray.count).max() ?? 0
      var d =
        assembler.fetchCandidates(at: 2, filter: .endAt)
          .map(\.pair.keyArray.count).max() ?? 0
      #expect("\(a) \(b) \(c) \(d)" == "1 1 2 2")
      assembler.cursor = assembler.length
      try assembler.insertKey("fang1")
      a =
        assembler.fetchCandidates(at: 1, filter: .beginAt)
          .map(\.pair.keyArray.count).max() ?? 0
      b =
        assembler.fetchCandidates(at: 1, filter: .endAt)
          .map(\.pair.keyArray.count).max() ?? 0
      c =
        assembler.fetchCandidates(at: 0, filter: .beginAt)
          .map(\.pair.keyArray.count).max() ?? 0
      d =
        assembler.fetchCandidates(at: 2, filter: .endAt)
          .map(\.pair.keyArray.count).max() ?? 0
      #expect("\(a) \(b) \(c) \(d)" == "1 1 2 2")
    }
  }

  /// 組字器的組字功能測試（單元圖，完整輸入讀音與聲調，完全比對）。
  @Test("[Homa] Assember_AssembleAndOverride_WithUnigramAndCursorJump")
  func testAssembleAndOverrideWithUnigramAndCursorJump() async throws {
    let readings = "chao1 shang1 da4 qian2 tian1 wei2 zhi3 hai2 zai5 mai4 nai3 ji1"
    let mockLM = TestLM(rawData: HomaTests.strLMSampleDataLitch)
    var perceptions = [Homa.PerceptionIntel]()
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) },
      perceptor: { intel in
        perceptions.append(intel)
      }
    )
    try readings.split(separator: " ").forEach {
      try assembler.insertKey($0.description)
    }
    #expect(assembler.length == 12)
    #expect(assembler.length == assembler.cursor)
    // 初始組句結果。
    var assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["超商", "大前天", "為止", "還", "在", "賣", "荔枝"])
    // 測試 DumpDOT。
    let expectedDumpDOT = """
    digraph {\ngraph [ rankdir=TB ];\nBOS;\nBOS -> 超;\n超;\n超 -> 傷;\n\
    BOS -> 超商;\n超商;\n超商 -> 大;\n超商 -> 大錢;\n超商 -> 大前天;\n傷;\n\
    傷 -> 大;\n傷 -> 大錢;\n傷 -> 大前天;\n大;\n大 -> 前;\n大 -> 前天;\n大錢;\n\
    大錢 -> 添;\n大前天;\n大前天 -> 為;\n大前天 -> 為止;\n前;\n前 -> 添;\n前天;\n\
    前天 -> 為;\n前天 -> 為止;\n添;\n添 -> 為;\n添 -> 為止;\n為;\n為 -> 指;\n\
    為止;\n為止 -> 還;\n指;\n指 -> 還;\n還;\n還 -> 在;\n在;\n在 -> 賣;\n賣;\n\
    賣 -> 乃;\n賣 -> 荔枝;\n乃;\n乃 -> 雞;\n荔枝;\n荔枝 -> EOS;\n雞;\n雞 -> EOS;\nEOS;\n}\n
    """
    let actualDumpDOT = assembler.dumpDOT(verticalGraph: true)
    #expect(actualDumpDOT == expectedDumpDOT)
    // 單獨測試對最前方的讀音的覆寫。
    do {
      let assemblerCopy = assembler.copy
      try assemblerCopy.overrideCandidate(.init(keyArray: ["ji1"], value: "雞"), at: 11)
      assembledSentence = assemblerCopy.assemble().values
      #expect(assembledSentence == ["超商", "大前天", "為止", "還", "在", "賣", "乃", "雞"])
      #expect(perceptions.last?.contextualizedGramKey == "(mai4,賣)&(nai3,乃)&(ji1,雞)")
      #expect(perceptions.last?.candidate == "雞")
    }
    // 回到先前的測試，測試對整個詞的覆寫。
    try assembler.overrideCandidate(.init(keyArray: ["nai3", "ji1"], value: "奶雞"), at: 10)
    assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["超商", "大前天", "為止", "還", "在", "賣", "奶雞"])
    #expect(perceptions.last?.contextualizedGramKey == "(zai5,在)&(mai4,賣)&(nai3-ji1,奶雞)")
    #expect(perceptions.last?.candidate == "奶雞")
    // 測試游標跳轉。
    assembler.cursor = 10 // 向後
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .rear) })
    #expect(assembler.cursor == 9)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .rear) })
    #expect(assembler.cursor == 8)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .rear) })
    #expect(assembler.cursor == 7)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .rear) })
    #expect(assembler.cursor == 5)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .rear) })
    #expect(assembler.cursor == 2)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .rear) })
    #expect(assembler.cursor == 0)
    #expect(Self.mustFail { try assembler.jumpCursorBySegment(to: .rear) })
    #expect(assembler.cursor == 0) // 接下來準備向前
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .front) })
    #expect(assembler.cursor == 2)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .front) })
    #expect(assembler.cursor == 5)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .front) })
    #expect(assembler.cursor == 7)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .front) })
    #expect(assembler.cursor == 8)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .front) })
    #expect(assembler.cursor == 9)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .front) })
    #expect(assembler.cursor == 10)
    #expect(Self.mustDone { try assembler.jumpCursorBySegment(to: .front) })
    #expect(assembler.cursor == 12)
    #expect(Self.mustFail { try assembler.jumpCursorBySegment(to: .front) })
    #expect(assembler.cursor == 12)
  }

  /// 組字器的組字功能測試（雙元圖，完整輸入讀音與聲調，完全比對）。
  ///
  /// 這個測試包含了：
  /// - 讀音輸入處理。
  /// - 組字器的基本組句功能。
  /// - 候選字詞覆寫功能。
  /// - 在有雙元圖（Bigram）與僅有單元圖（Unigram）的情況下的組句結果對比測試。
  @Test("[Homa] Assember_AssembleAndOverride_FullMatch_WithBigram")
  func testAssembleWithBigramAndOverrideWithFullMatch() async throws {
    let readings: [Substring] = "you1 die2 neng2 liu2 yi4 lv3 fang1".split(separator: " ")
    let mockLM = TestLM(rawData: HomaTests.strLMSampleDataHutao)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }, // 會回傳包含 Bigram 的結果。
    )
    try readings.forEach {
      try assembler.insertKey($0.description)
    }
    // 初始組句結果。
    var assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["幽蝶", "能", "留意", "呂方"])
    // 測試覆寫「留」以試圖打斷「留意」。
    try assembler.overrideCandidate(
      .init(keyArray: ["liu2"], value: "留"),
      at: 3,
      type: .withSpecified
    )
    // 測試覆寫「一縷」以打斷「留意」與「呂方」。這也便於最後一個位置的 Bigram 測試。
    // （因為是有了「一縷」這個前提才會去找對應的 Bigram。）
    try assembler.overrideCandidate(
      .init(keyArray: ["yi4", "lv3"], value: "一縷"),
      at: 4,
      type: .withSpecified
    )
    let dotWithBigram = assembler.dumpDOT(verticalGraph: true)
    assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "芳"])
    // 剛才測試 Bigram 生效了。現在禁用 Bigram 試試看。先攔截掉 Bigram 結果。
    assembler.gramQuerier = { mockLM.queryGrams($0).filter { $0.previous == nil } }
    try assembler.assignNodes(updateExisting: true) // 置換掉所有節點裡面的資料。
    assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "方"])
    // 對位置 7 這個最前方的座標位置使用節點覆寫。會在此過程中自動糾正成對位置 6 的覆寫。
    try assembler.overrideCandidate(
      .init(keyArray: ["fang1"], value: "芳"),
      at: 7,
      type: .withSpecified
    )
    assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "芳"])
    let dotSansBigram = assembler.dumpDOT(verticalGraph: true)
    // 驗證兩次 dumpDOT 結果是否雷同。
    #expect(dotWithBigram == dotSansBigram)
    let expectedDOT = """
    digraph {\ngraph [ rankdir=TB ];\nBOS;\nBOS -> 優;\n優;\n優 -> 跌;\nBOS -> 幽蝶;\n\
    幽蝶;\n幽蝶 -> 能;\n幽蝶 -> 能留;\n跌;\n跌 -> 能;\n跌 -> 能留;\n能;\n能 -> 留;\n\
    能 -> 留意;\n能留;\n能留 -> 亦;\n能留 -> 一縷;\n留;\n留 -> 亦;\n留 -> 一縷;\n留意;\n\
    留意 -> 旅;\n留意 -> 呂方;\n亦;\n亦 -> 旅;\n亦 -> 呂方;\n一縷;\n一縷 -> 芳;\n旅;\n\
    旅 -> 芳;\n呂方;\n呂方 -> EOS;\n芳;\n芳 -> EOS;\nEOS;\n}\n
    """
    #expect(dotWithBigram == expectedDOT)
  }

  /// 組字器的組字功能測試（雙元圖，不完整輸入讀音與聲調，類似華碩輸入法、智能狂拼、RIME、搜狗的輸入風格）。
  ///
  /// 這個測試包含了：
  /// - 讀音輸入處理。
  /// - 組字器的基本組句功能。
  /// - 候選字詞覆寫功能。
  @Test("[Homa] Assember_AssembleAndOverride_PartialMatch_WithBigram")
  func testAssembleWithBigramAndOverrideWithPartialMatch() async throws {
    let readings: [String] = "ydnlylf".map(\.description)
    let mockLM = TestLM(rawData: HomaTests.strLMSampleDataHutao)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0, partiallyMatch: true) }, // 會回傳包含 Bigram 的結果。
    )
    try readings.forEach {
      try assembler.insertKey($0.description)
    }
    var assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["幽蝶", "能", "留意", "呂方"])
    // 測試覆寫「留」以試圖打斷「留意」。
    try assembler.overrideCandidate(
      .init(keyArray: ["liu2"], value: "留"),
      at: 3,
      type: .withSpecified
    )
    // 測試覆寫「一縷」以打斷「留意」與「呂方」。這也便於最後一個位置的 Bigram 測試。
    // （因為是有了「一縷」這個前提才會去找對應的 Bigram。）
    try assembler.overrideCandidate(
      .init(keyArray: ["yi4", "lv3"], value: "一縷"),
      at: 4,
      type: .withSpecified
    )
    assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "芳"])
    let actualkeysJoined = assembler.actualKeys.joined(separator: " ")
    #expect(actualkeysJoined == "you1 die2 neng2 liu2 yi4 lv3 fang1")
  }

  /// 針對完全覆蓋的節點的專項覆寫測試。
  @Test("[Homa] Assember_ResetFullyOverlappedNodesOnOverride")
  func testResettingFullyOverlappedNodesOnOverride() async throws {
    let readings: [Substring] = "shui3 guo3 zhi1".split(separator: " ")
    let mockLM = TestLM(rawData: HomaTests.strLMSampleDataFruitJuice)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }, // 會回傳包含 Bigram 的結果。
    )
    try readings.forEach {
      try assembler.insertKey($0.description)
    }
    var assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["水果汁"])

    // 測試針對第一個漢字的位置的操作。
    do {
      do {
        #expect(
          Self.mustDone {
            try assembler.overrideCandidate(.init(keyArray: ["shui3"], value: "💦"), at: 0)
          }
        )
        assembledSentence = assembler.assemble().values
        #expect(assembledSentence == ["💦", "果汁"])
      }
      do {
        #expect(
          Self.mustDone {
            try assembler.overrideCandidate(
              .init(keyArray: ["shui3", "guo3", "zhi1"], value: "水果汁"),
              at: 1
            )
          }
        )
        assembledSentence = assembler.assemble().values
        #expect(assembledSentence == ["水果汁"])
      }
      do {
        #expect(
          Self.mustDone {
            // 再覆寫回來。
            try assembler.overrideCandidate(.init(keyArray: ["shui3"], value: "💦"), at: 0)
          }
        )
        assembledSentence = assembler.assemble().values
        #expect(assembledSentence == ["💦", "果汁"])
      }
    }

    // 測試針對其他位置的操作。
    do {
      do {
        #expect(
          Self.mustDone {
            try assembler.overrideCandidate(.init(keyArray: ["guo3"], value: "裹"), at: 1)
          }
        )
        assembledSentence = assembler.assemble().values
        #expect(assembledSentence == ["💦", "裹", "之"])
      }
      do {
        #expect(
          Self.mustDone {
            try assembler.overrideCandidate(.init(keyArray: ["zhi1"], value: "知"), at: 2)
          }
        )
        assembledSentence = assembler.assemble().values
        #expect(assembledSentence == ["💦", "裹", "知"])
      }
      do {
        #expect(
          Self.mustDone {
            // 再覆寫回來。
            try assembler.overrideCandidate(
              .init(keyArray: ["shui3", "guo3", "zhi1"], value: "水果汁"),
              at: 3
            )
          }
        )
        assembledSentence = assembler.assemble().values
        #expect(assembledSentence == ["水果汁"])
      }
    }
  }

  /// 針對不完全覆蓋的節點的專項覆寫測試。
  @Test("[Homa] Assember_ResetPartiallyOverlappedNodesOnOverride")
  func testResettingPartiallyOverlappedNodesOnOverride() async throws {
    let readings: [Substring] = "ke1 ji4 gong1 yuan2".split(separator: " ")
    let mockLM = TestLM(rawData: HomaTests.strLMSampleDataTechGuarden + "\ngong1-yuan2 公猿 -9")
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }, // 會回傳包含 Bigram 的結果。
    )
    try readings.forEach {
      try assembler.insertKey($0.description)
    }
    var assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["科技", "公園"])
    do {
      #expect(
        Self.mustDone {
          try assembler.overrideCandidate(
            .init(keyArray: ["ji4", "gong1"], value: "濟公"),
            at: 1
          )
        }
      )
      assembledSentence = assembler.assemble().values
      #expect(assembledSentence == ["顆", "濟公", "元"])
    }
    do {
      #expect(
        Self.mustDone {
          try assembler.overrideCandidate(
            .init(keyArray: ["gong1", "yuan2"], value: "公猿"),
            at: 2
          )
        }
      )
      assembledSentence = assembler.assemble().values
      #expect(assembledSentence == ["科技", "公猿"]) // 「技工」被重設。
    }
    do {
      #expect(
        Self.mustDone {
          try assembler.overrideCandidate(
            .init(keyArray: ["ke1", "ji4"], value: "科際"),
            at: 0
          )
        }
      )
      assembledSentence = assembler.assemble().values
      #expect(assembledSentence == ["科際", "公猿"]) // 「公猿」沒有受到影響。
    }
  }

  @Test("[Homa] Assembler_CandidateDisambiguationAndCursorStepwiseMovement")
  func testCandidateDisambiguationAndCursorStepwiseMovement() async throws {
    let readings: [Substring] = "da4 shu4 xin1 de5 mi4 feng1".split(separator: " ")
    let regexToFilter = try Regex("\nshu4-xin1 .*")
    let mockLM = TestLM(
      rawData: HomaTests.strLMSampleDataEmoji.replacing(regexToFilter, with: "")
    )
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }, // 會回傳包含 Bigram 的結果。
    )
    try readings.forEach {
      try assembler.insertKey($0.description)
    }
    var assembledSentence = assembler.assemble().values
    #expect(assembledSentence == ["大樹", "新的", "蜜蜂"])
    let pos = 2
    do {
      #expect(
        Self.mustDone {
          try assembler.overrideCandidate(.init(keyArray: ["xin1"], value: "🆕"), at: pos)
        }
      )
      assembledSentence = assembler.assemble().values
      #expect(assembledSentence == ["大樹", "🆕", "的", "蜜蜂"])
    }
    do {
      #expect(
        Self.mustDone {
          try assembler.overrideCandidate(.init(keyArray: ["xin1", "de5"], value: "🆕"), at: pos)
        }
      )
      assembledSentence = assembler.assemble().values
      #expect(assembledSentence == ["大樹", "🆕", "蜜蜂"])
    }
    // 測試游標按步移動（往前方）。
    do {
      try assembler.overrideCandidate(.init(keyArray: ["mi4", "feng1"], value: "🐝"), at: 4)
      assembledSentence = assembler.assemble().values
      #expect(assembledSentence == ["大樹", "🆕", "🐝"])
      assembler.cursor = 3
      #expect(assembler.isCursorCuttingChar(isMarker: false))
      #expect(
        Self.mustDone {
          try assembler.moveCursorStepwise(to: .front)
        }
      )
      #expect(!assembler.isCursorCuttingChar(isMarker: false))
      #expect(
        Self.mustDone {
          try assembler.moveCursorStepwise(to: .front)
        }
      )
      #expect(assembler.cursor == 6)
      #expect(!assembler.isCursorCuttingChar(isMarker: false))
      #expect(assembler.isCursorAtEdge(direction: .front))
      #expect(
        Self.mustFail {
          try assembler.moveCursorStepwise(to: .front)
        }
      )
    }
    // 測試游標按步移動（往後方）。
    do {
      try assembler.overrideCandidate(.init(keyArray: ["da4", "shu4"], value: "🌳"), at: 0)
      assembledSentence = assembler.assemble().values
      #expect(assembledSentence == ["🌳", "🆕", "🐝"])
      assembler.cursor = 3
      #expect(assembler.isCursorCuttingChar(isMarker: false))
      #expect(
        Self.mustDone {
          try assembler.moveCursorStepwise(to: .rear)
        }
      )
      #expect(!assembler.isCursorCuttingChar(isMarker: false))
      #expect(
        Self.mustDone {
          try assembler.moveCursorStepwise(to: .rear)
        }
      )
      #expect(assembler.cursor == 0)
      #expect(!assembler.isCursorCuttingChar(isMarker: false))
      #expect(assembler.isCursorAtEdge(direction: .rear))
      #expect(
        Self.mustFail {
          try assembler.moveCursorStepwise(to: .rear)
        }
      )
    }
  }

  /// 組字器的候選字輪替測試。
  @Test("[Homa] Assember_TestCandidateRevolvementWithConsolidation", arguments: [false, true])
  func testCandidateRevolvementWithConsolidation(partialMatch: Bool) async throws {
    let rdSimp = "k j g y c s m n j"
    let rdFull = "ke1 ji4 gong1 yuan2 chao1 shang1 mai4 nai3 ji1"
    let readings: String = partialMatch ? rdSimp : rdFull
    let mockLM = TestLM(
      rawData: HomaTests.strLMSampleDataTechGuarden + "\n"
        + HomaTests
        .strLMSampleDataLitch
    )

    struct CandidateIdentity: Hashable {
      let pair: Homa.CandidatePair
      let gramID: FIUUID

      init(pair: Homa.CandidatePair, gram: Homa.Gram) {
        self.pair = pair
        self.gramID = gram.id
      }

      func hash(into hasher: inout Hasher) {
        hasher.combine(gramID)
      }

      static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.gramID == rhs.gramID
      }

      var debugSummary: String {
        let keys = pair.keyArray.joined(separator: "-")
        return "\(pair.value) (\(keys)) @ \(gramID.uuidString())"
      }
    }

    // 此處無須刻意組句，因為 revolveCandidate 會在發現沒組句的時候自動爬一次軌。
    // 準備正式測試。
    let cases: [Homa.Assembler.CandidateCursor] = [.placedFront, .placedRear]
    try cases.forEach { candidateCursorType in
      let assembler = Homa.Assembler(
        gramQuerier: { mockLM.queryGrams($0, partiallyMatch: partialMatch) }
      )
      try readings.split(separator: " ").forEach {
        try assembler.insertKey($0.description)
      }
      let partialText: String = partialMatch ? "PartialMatch" : "FullMatch"
      print(
        "// Testing revolvement (\(partialText)) with CandidateCursorType.\(candidateCursorType)..."
      )
      try (0 ... assembler.length).forEach { pos in
        assembler.cursor = pos
        let minimumRevolvesPerCandidate = 25
        var doRevolve = true
        var candidateRevolveCounts = [CandidateIdentity: Int]()
        var allCandidates = [(candidate: Homa.CandidatePairWeighted, identity: CandidateIdentity)]()
        var previouslyRevolvedCandidate: CandidateIdentity?
        var debugIntelBuilder = [String]()
        var hasValidatedCandidateTotal = false
        var revolvementLoopCount = 0
        let baseRevolvementLoopLimit = 200
        var revolvementLoopLimit = baseRevolvementLoopLimit
        var hasUnlockedFullLoop = false

        func resolveIdentity(for pair: Homa.CandidatePair) -> CandidateIdentity? {
          let candidateCursorPos = assembler.getLogicalCandidateCursorPosition(
            forCursor: candidateCursorType
          )
          var keyOffset = 0
          let matchedGram = assembler.assembledSentence.first { gram in
            defer { keyOffset += gram.keyArray.count }
            guard gram.keyArray == pair.keyArray, gram.value == pair.value else { return false }
            let gramRange = keyOffset ..< (keyOffset + gram.keyArray.count)
            return gramRange.contains(candidateCursorPos)
          }?.gram ?? assembler.assembledSentence.first {
            $0.keyArray == pair.keyArray && $0.value == pair.value
          }?.gram
          #expect(
            matchedGram != nil,
            Comment(stringLiteral: "未能在位置 \(pos) 找到候選 \(pair.value) 的 Gram 參考。")
          )
          guard let matchedGram else { return nil }
          return CandidateIdentity(pair: pair, gram: matchedGram)
        }
        do {
          revolvementTaskAtThisPos: while doRevolve {
            revolvementLoopCount += 1
            if revolvementLoopCount > revolvementLoopLimit {
              Issue.record(
                "Exceeded revolvement loop limit (\(revolvementLoopLimit)) at cursor position \(pos)"
              )
              break revolvementTaskAtThisPos
            }
            var fetchedCandidates: [Homa.CandidatePairWeighted] = []
            let currentRevolved = try assembler.revolveCandidate(
              cursorType: candidateCursorType,
              counterClockwise: false
            ) { debugIntel in
              debugIntelBuilder.append(debugIntel)
            } candidateArrayHandler: { candidates in
              fetchedCandidates = candidates
            }

            // 記錄這次的候選字
            let currentRevolvedPair = currentRevolved.0.pair
            guard let identity = resolveIdentity(for: currentRevolvedPair) else {
              break revolvementTaskAtThisPos
            }
            allCandidates.append((currentRevolved.0, identity))
            let newCount = candidateRevolveCounts[identity, default: 0] + 1
            candidateRevolveCounts[identity] = newCount
            let uniqueCandidateCount = candidateRevolveCounts.count

            if newCount > 1 {
              // 若發現重複，檢查詳細情況（僅於首次重複時進行詳查）
              if !hasValidatedCandidateTotal {
                if uniqueCandidateCount != currentRevolved.total {
                  print("=== 偵測到不一致: 位置 \(pos), 游標類型 \(candidateCursorType) ===")
                  print("候選識別數量: \(uniqueCandidateCount), 報告總數: \(currentRevolved.total)")
                  print("當前候選字: \(currentRevolved.0.pair.value)")

                  // 獲取該位置的所有候選字，進行對比分析
                  let filter: Homa.Assembler.CandidateFetchFilter =
                    candidateCursorType == .placedFront ? .endAt : .beginAt
                  let allAvailableCandidates = assembler.fetchCandidates(at: pos, filter: filter)
                  print("fetchCandidates 結果數量: \(allAvailableCandidates.count)")

                  // 檢查是否有重複候選字未被正確過濾
                  var seenValues = Set<String>()
                  var duplicateFound = false
                  for candidate in allAvailableCandidates {
                    let valueStr = "\(candidate.pair)"
                    if !seenValues.insert(valueStr).inserted {
                      print("發現重複候選字值: \(valueStr)")
                      duplicateFound = true
                    }
                  }
                  if !duplicateFound {
                    print("未發現重複候選字值")
                  }

                  // 比較已輪替的候選字和所有可用候選字
                  print("已輪替的候選字:")
                  for (idx, record) in allCandidates.enumerated() {
                    let candidate = record.candidate
                    print(
                      "[\(idx)] \(candidate.pair.value) (\(candidate.pair.keyArray.joined(separator: "-"))) \(candidate.weight) @ \(record.identity.debugSummary)"
                    )
                  }

                  print("選字窗的候選字：")
                  for (idx, candidate) in fetchedCandidates.enumerated() {
                    print(
                      "[\(idx)] \(candidate.pair.value) (\(candidate.pair.keyArray.joined(separator: "-"))) \(candidate.weight)"
                    )
                  }
                }
                #expect(
                  uniqueCandidateCount == currentRevolved.total,
                  Comment(
                    stringLiteral: """
                    位置:\(pos), 已輪替:\(uniqueCandidateCount), \
                    報告總數:\(currentRevolved.total), 選字游標類型：\(candidateCursorType)
                    """
                  )
                )
                hasValidatedCandidateTotal = true
                if !hasUnlockedFullLoop {
                  let expectedLoops = currentRevolved.total * minimumRevolvesPerCandidate
                  if expectedLoops > baseRevolvementLoopLimit {
                    revolvementLoopLimit = expectedLoops + currentRevolved.total
                  }
                  hasUnlockedFullLoop = true
                }
              }
            }
            #expect(
              previouslyRevolvedCandidate != identity,
              Comment(stringLiteral: "\(identity.debugSummary)")
            )
            guard previouslyRevolvedCandidate != identity else {
              break revolvementTaskAtThisPos
            }
            previouslyRevolvedCandidate = identity
            let metMinimumRevolves =
              uniqueCandidateCount == currentRevolved.total
                && candidateRevolveCounts.values.allSatisfy { $0 >= minimumRevolvesPerCandidate }
            if metMinimumRevolves {
              doRevolve = false
            }
          }
        } catch {
          print(debugIntelBuilder.joined(separator: "\n"))
          throw error
        }
      }
    }
  }

  /// 組字器的候選字輪替測試——某個罕見情形。
  @Test("[Homa] Assember_TestCandidateRevolvementRareCase1")
  func testCandidateRevolvementRareCase1() async throws {
    let mockLM = TestLM(rawData: HomaTests.strLMSampleData_JiHuQiKeng)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    let readingKeys = ["ji1", "hu1", "qi4", "keng1"]
    try readingKeys.forEach { try assembler.insertKey($0) }
    assembler.assemble()
    let assembledBefore = assembler.assembledSentence.map { $0.value }.joined(separator: " ")
    #expect(assembledBefore == "幾乎 氣 坑")
    try assembler.moveCursorStepwise(to: .rear)
    #expect(assembledBefore == "幾乎 氣 坑")
    let candidateCursorType = Homa.Assembler.CandidateCursor.placedFront
    let allCandidates = assembler.fetchCandidates(filter: .endAt).map(\ .pair.value)
    #expect(allCandidates.prefix(4) == ["呼氣", "氣", "迄", "棄"])
    guard let firstCandidate = allCandidates.first, allCandidates.count > 1 else {
      Issue.record("JiHuQiKeng rare-case test requires at least two candidates.")
      return
    }

    let expectedCycle = allCandidates + [firstCandidate]
    for expectedValue in expectedCycle {
      let currentRevolved = try assembler.revolveCandidate(
        cursorType: candidateCursorType,
        counterClockwise: false
      )
      #expect(currentRevolved.0.pair.value == expectedValue)
      let expectedNodes: [String] = expectedValue == "呼氣"
        ? ["幾", expectedValue, "坑"]
        : ["幾", "呼", expectedValue, "坑"]
      #expect(assembler.assembledSentence.map(\ .value) == expectedNodes)
    }
  }

  @Test("[Homa] Assembler_ConsolidationUsesTrueNodeAnchorsOnOverlap")
  func testConsolidationUsesTrueNodeAnchorsOnOverlap() async throws {
    let mockLM = TestLM(rawData: HomaTests.strLMSampleData_JiHuQiKeng)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    let readingKeys = ["ji1", "hu1", "qi4", "keng1"]
    try readingKeys.forEach { try assembler.insertKey($0) }
    assembler.assemble()
    #expect(assembler.assembledSentence.map(\ .value) == ["幾乎", "氣", "坑"])
    try assembler.moveCursorStepwise(to: .rear)

    let candidateCursorType = Homa.Assembler.CandidateCursor.placedFront
    let targetCandidate = Homa.CandidatePair(keyArray: ["hu1", "qi4"], value: "呼氣")
    #expect(throws: Never.self) {
      try assembler.consolidateCandidateCursorContext(
        for: targetCandidate,
        cursorType: candidateCursorType
      )
    }

    let logicalCursor = assembler.getLogicalCandidateCursorPosition(forCursor: candidateCursorType)
    #expect(throws: Never.self) {
      try assembler.overrideCandidate(
        targetCandidate,
        at: logicalCursor,
        type: .withSpecified,
        isExplicitlyOverridden: true,
        enforceRetokenization: true
      )
    }
    #expect(assembler.assembledSentence.map(\ .value) == ["幾", "呼氣", "坑"])
  }

  /// 邊緣案例測試：再創世的凱歌（再創紀の凱歌）。
  @Test("[Homa] Perception Intel API (SaisoukiNoGaika)")
  func testPerceptionIntel_SaisoukiNoGaika() async throws {
    let mockLM = TestLM(rawData: HomaTests.strLMSampleData_SaisoukiNoGaika)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    let readingKeys = ["zai4", "chuang4", "shi4", "de5", "kai3", "ge1"]
    try readingKeys.forEach { try assembler.insertKey($0) }
    assembler.assemble()
    let assembledBefore = assembler.assembledSentence.map { $0.value }.joined(separator: " ")
    #expect(assembledBefore == "再 創 是的 凱歌")

    let cursorShi = 2
    let cursorShiDe = 3

    let keyAtShiOpt = assembler.assembledSentence.generateKeyForPerception(cursor: cursorShi)
    #expect(keyAtShiOpt != nil)
    guard let keyAtShi = keyAtShiOpt else { return }
    #expect(keyAtShi.ngramKey == "(zai4,再)&(chuang4,創)&(shi4-de5,是的)")
    #expect(keyAtShi.headReading == "shi4")
    let keyAtShiDeOpt = assembler.assembledSentence.generateKeyForPerception(cursor: cursorShiDe)
    #expect(keyAtShiDeOpt != nil)
    guard let keyAtShiDe = keyAtShiDeOpt else { return }
    #expect(keyAtShiDe.ngramKey == "(zai4,再)&(chuang4,創)&(shi4-de5,是的)")
    #expect(keyAtShiDe.headReading == "de5")

    let pairsAtShiDeEnd = assembler.fetchCandidates(at: 4, filter: .endAt).map { $0.pair.value }
    #expect(pairsAtShiDeEnd.contains("是的"))
    #expect(pairsAtShiDeEnd.contains("似的"))

    var obsCaptured: Homa.PerceptionIntel?
    #expect(
      Self.mustDone {
        try assembler.overrideCandidate(
          .init(keyArray: ["shi4"], value: "世"),
          at: cursorShi,
          enforceRetokenization: true,
          perceptionHandler: { obsCaptured = $0 }
        )
      }
    )
    #expect(obsCaptured?.contextualizedGramKey == "(zai4,再)&(chuang4,創)&(shi4,世)")
    let assembledAfterReplacingShi = assembler.assembledSentence.map { $0.value }
      .joined(separator: " ")
    #expect(assembledAfterReplacingShi == "再 創 世 的 凱歌")

    let prevAssembly = assembler.assembledSentence
    obsCaptured = nil
    #expect(
      Self.mustDone {
        try assembler.overrideCandidate(
          .init(keyArray: ["shi4", "de5"], value: "是的"),
          at: cursorShiDe,
          enforceRetokenization: true,
          perceptionHandler: { obsCaptured = $0 }
        )
      }
    )
    #expect(
      obsCaptured?.contextualizedGramKey == "(chuang4,創)&(shi4,世)&(de5,的)",
      "覆寫成雙音節候選後，觀測結果目前以尾端音節作為 head。"
    )

    let currentAssembly = assembler.assembledSentence
    let afterHitOpt = currentAssembly.findGram(at: cursorShiDe)
    #expect(afterHitOpt != nil)
    guard let afterHit = afterHitOpt else { return }
    let border1 = afterHit.range.upperBound - 1
    let border2 = prevAssembly.totalKeyCount - 1
    let innerIndex = Swift.max(0, Swift.min(border1, border2))
    let prevHitOpt = prevAssembly.findGram(at: innerIndex)
    #expect(prevHitOpt != nil)
    guard let prevHit = prevHitOpt else { return }
    #expect(afterHit.gram.segLength == 2)
    #expect(prevHit.gram.segLength == 1)
    #expect(obsCaptured != nil)
    #expect(obsCaptured?.scenario == .shortToLong)
    #expect(obsCaptured?.candidate == "是的")

    assembler.clear()
    try readingKeys.prefix(4).forEach { try assembler.insertKey($0) }
    #expect(
      Self.mustDone {
        try assembler.overrideCandidate(
          .init(keyArray: ["shi4"], value: "世"),
          at: 2,
          type: .withTopGramScore,
          enforceRetokenization: true
        )
      }
    )
    assembler.assemble()
    let assembledByPOM = assembler.assembledSentence.map { $0.value }.joined(separator: " ")
    #expect(assembledByPOM == "再 創 世 的")
  }

  @Test("[Homa] Perception Intel API (BusinessEnglishSession)")
  func testPerceptionIntel_BusinessEnglishSession() async throws {
    let mockLM = TestLM(rawData: HomaTests.strLMSampleData_BusinessEnglishSession)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    let readingKeys = ["shang1", "wu4", "ying1", "yu3", "hui4", "hua4"]
    try readingKeys.forEach { try assembler.insertKey($0) }
    assembler.assemble()
    let assembledBefore = assembler.assembledSentence.map { $0.value }.joined(separator: " ")
    #expect(assembledBefore == "商務 英語 繪畫")

    let cursorHua = 5
    let keyForQueryingDataAt5Opt = assembler.assembledSentence
      .generateKeyForPerception(cursor: cursorHua)
    #expect(keyForQueryingDataAt5Opt != nil)
    guard let keyForQueryingDataAt5 = keyForQueryingDataAt5Opt else { return }
    #expect(keyForQueryingDataAt5.ngramKey == "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,繪畫)")
    #expect(keyForQueryingDataAt5.headReading == "hua4")

    let pairsAtHuiHuaEnd = assembler.fetchCandidates(at: 6, filter: .endAt)
    #expect(pairsAtHuiHuaEnd.map { $0.pair.value }.contains("繪畫"))
    #expect(pairsAtHuiHuaEnd.map { $0.pair.value }.contains("會話"))

    var obsCaptured: Homa.PerceptionIntel?
    #expect(
      Self.mustDone {
        try assembler.overrideCandidate(
          .init(keyArray: ["hui4", "hua4"], value: "會話"),
          at: cursorHua,
          enforceRetokenization: true,
          perceptionHandler: { obsCaptured = $0 }
        )
      }
    )
    #expect(
      obsCaptured?.contextualizedGramKey
        == "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,會話)"
    )
    let assembledAfter = assembler.assembledSentence.map { $0.value }.joined(separator: " ")
    #expect(assembledAfter == "商務 英語 會話")

    assembler.clear()
    try readingKeys.forEach { try assembler.insertKey($0) }

    let pomSuggestedCandidate = Homa.CandidatePair(
      keyArray: ["hui4", "hua4"],
      value: "會話"
    ).weighted(-0.074493074227700559)
    let pomSuggestedCandidateOverrideCursor = 4
    #expect(
      Self.mustDone {
        try assembler.overrideCandidate(
          pomSuggestedCandidate,
          at: pomSuggestedCandidateOverrideCursor,
          type: .withTopGramScore,
          enforceRetokenization: true
        )
      }
    )
    assembler.assemble()
    let assembledByPOM = assembler.assembledSentence.map { $0.value }.joined(separator: " ")
    #expect(assembledByPOM == "商務 英語 會話")
  }

  @Test("[Homa] Perception Intel API (DiJiaoSubmission)")
  func testPerceptionIntel_DiJiaoSubmission() async throws {
    let readingKeys = ["di4", "jiao1"]
    let mockLM = TestLM(rawData: HomaTests.strLMSampleData_DiJiaoSubmission)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    try readingKeys.forEach { try assembler.insertKey($0) }
    assembler.assemble()

    #expect(
      Self.mustDone {
        try assembler.overrideCandidate(
          .init(keyArray: ["di4"], value: "第"),
          at: 0,
          enforceRetokenization: true
        )
      }
    )
    assembler.assemble()

    let assembledAfterFirst = assembler.assembledSentence.map(\.value).joined(separator: " ")
    #expect(["第 交", "第 教"].contains(assembledAfterFirst))

    let candidatesAtEnd = assembler.fetchCandidates(
      at: readingKeys.count,
      filter: .endAt
    )
    guard let diJiaoCandidate = candidatesAtEnd.first(where: { $0.pair.value == "遞交" }) else {
      #expect(Bool(false), "遞交 should be available as a candidate ending at the current cursor.")
      return
    }

    var obsCaptured: Homa.PerceptionIntel?
    #expect(
      Self.mustDone {
        try assembler.overrideCandidate(
          diJiaoCandidate,
          at: readingKeys.count,
          enforceRetokenization: true,
          perceptionHandler: { obsCaptured = $0 }
        )
      }
    )

    guard let obsCaptured else {
      #expect(Bool(false), "Perception intel should be captured when overriding with 遞交.")
      return
    }

    #expect(obsCaptured.contextualizedGramKey == "()&(di4,第)&(di4-jiao1,遞交)")
    #expect(obsCaptured.candidate == "遞交")
    #expect(obsCaptured.scenario == .shortToLong)
    #expect(obsCaptured.forceHighScoreOverride)

    assembler.assemble()
    let assembledAfterSecond = assembler.assembledSentence.map(\.value).joined(separator: " ")
    #expect(assembledAfterSecond == "遞交")

    let validationAssembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }
    )
    try readingKeys.forEach { try validationAssembler.insertKey($0) }
    validationAssembler.assemble()

    #expect(
      Self.mustDone {
        try validationAssembler.overrideCandidate(
          .init(keyArray: ["di4"], value: "第"),
          at: 0,
          enforceRetokenization: true
        )
      }
    )
    validationAssembler.assemble()

    let baselineKey = validationAssembler.assembledSentence.generateKeyForPerception(
      cursor: max(validationAssembler.cursor - 1, 0)
    )
    #expect(baselineKey?.ngramKey == "()&(di4,第)&(jiao1,交)")

    let pomSuggestedCandidate = diJiaoCandidate.pair.weighted(diJiaoCandidate.weight)
    let overrideCursor = readingKeys.count
    let overrideType: Homa.Node.OverrideType =
      obsCaptured.forceHighScoreOverride ? .withSpecified : .withTopGramScore

    #expect(
      Self.mustDone {
        try validationAssembler.overrideCandidate(
          pomSuggestedCandidate,
          at: overrideCursor,
          type: overrideType,
          enforceRetokenization: true
        )
      }
    )
    validationAssembler.assemble()
    let assembledBySuggested = validationAssembler.assembledSentence.map(\.value)
      .joined(separator: " ")
    #expect(assembledBySuggested == "遞交")
  }
}
