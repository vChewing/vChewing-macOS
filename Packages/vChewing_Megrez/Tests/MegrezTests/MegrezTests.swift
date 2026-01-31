// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Megrez
import MegrezTestComponents
import XCTest

private typealias SimpleLM = MegrezTestComponents.SimpleLM
private typealias MockLM = MegrezTestComponents.MockLM

// MARK: - MegrezTestsBasic

final class MegrezTestsBasic: XCTestCase {
  func test01_Segment() throws {
    let langModel = SimpleLM(input: MegrezTestComponents.strLMSampleDataLitch)
    var segment = Megrez.Segment()
    let n1 = Megrez.Node(
      keyArray: ["da4"],
      segLength: 1,
      unigrams: langModel.unigramsFor(keyArray: ["da4"])
    )
    let n3 = Megrez.Node(
      keyArray: ["da4", "qian2", "tian1"],
      segLength: 3,
      unigrams: langModel.unigramsFor(keyArray: ["da4-qian2-tian1"])
    )
    XCTAssertEqual(segment.maxLength, 0)
    segment[n1.segLength] = n1
    XCTAssertEqual(segment.maxLength, 1)
    segment[n3.segLength] = n3
    XCTAssertEqual(segment.maxLength, 3)
    XCTAssertEqual(segment[1], n1)
    XCTAssertEqual(segment[2], nil)
    XCTAssertEqual(segment[3], n3)
    segment.removeAll()
    XCTAssertEqual(segment.maxLength, 0)
    XCTAssertEqual(segment[1], nil)
    XCTAssertEqual(segment[2], nil)
    XCTAssertEqual(segment[3], nil)
  }

  func test02_Compositor_BasicSegmentNodeGramInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    XCTAssertEqual(compositor.separator, Megrez.Compositor.theSeparator)
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 0)

    compositor.insertKey("s")
    XCTAssertEqual(compositor.cursor, 1)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.segments.count, 1)
    XCTAssertEqual(compositor.segments[0].maxLength, 1)
    XCTAssertEqual(compositor.segments[0][1]?.keyArray, ["s"])
    compositor.dropKey(direction: .rear)
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 0)
    XCTAssertEqual(compositor.segments.count, 0)
  }

  func test03_Compositor_DefendingInvalidOps() throws {
    let mockLM = SimpleLM(input: "ping2 ping2 -1")
    let compositor = Megrez.Compositor(with: mockLM)
    compositor.separator = ";"
    XCTAssertFalse(compositor.insertKey("guo3"))
    XCTAssertFalse(compositor.insertKey(""))
    XCTAssertFalse(compositor.insertKey(""))
    let configAlpha = compositor.config
    XCTAssertFalse(compositor.dropKey(direction: .rear))
    XCTAssertFalse(compositor.dropKey(direction: .front))
    let configBravo = compositor.config
    XCTAssertEqual(configAlpha, configBravo)
    XCTAssertTrue(compositor.insertKey("ping2"))
    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.length, 0)
    XCTAssertTrue(compositor.insertKey("ping2"))
    compositor.cursor = 0
    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.length, 0)
  }

  /// 測試任何長度大於 1 的幅節。
  func test04_Compositor_SegmentsAcrossPositions() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("h")
    compositor.insertKey("o")
    compositor.insertKey("g")
    XCTAssertTrue((compositor.cursor, compositor.length) == (3, 3))
    XCTAssertTrue((compositor.segments.count) == 3)
    XCTAssertTrue(compositor.segments[0].maxLength == 3)
    XCTAssertTrue(compositor.segments[0][1]?.keyArray == ["h"])
    XCTAssertTrue(compositor.segments[0][2]?.keyArray == ["h", "o"])
    XCTAssertTrue(compositor.segments[0][3]?.keyArray == ["h", "o", "g"])
    XCTAssertTrue(compositor.segments[1].maxLength == 2)
    XCTAssertTrue(compositor.segments[1][1]?.keyArray == ["o"])
    XCTAssertTrue(compositor.segments[1][2]?.keyArray == ["o", "g"])
    XCTAssertTrue(compositor.segments[2].maxLength == 1)
    XCTAssertTrue(compositor.segments[2][1]?.keyArray == ["g"])
  }

  /// 測試對讀音鍵與幅節的刪除行為。
  ///
  /// 敝專案不使用石磬軟體及其成員們所使用的「前 (Before) / 後 (After)」術語體系，
  /// 而是採用「前方 (Front) / 後方 (Rear)」這種中英文表述都不產生歧義的講法。
  func test05_Compositor_KeyAndSegmentDeletionInAllDirections() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.insertKey("a")
    compositor.cursor = 0
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.segments.count, 1)
    XCTAssertFalse(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.segments.count, 1)
    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 0)
    XCTAssertEqual(compositor.segments.count, 0)

    func resetcompositorForTests() {
      compositor.clear()
      compositor.insertKey("h")
      compositor.insertKey("o")
      compositor.insertKey("g")
    }

    // 測試對幅節的刪除行為所產生的影響（從最前端開始往後方刪除）。
    do {
      resetcompositorForTests()
      XCTAssertFalse(compositor.dropKey(direction: .front))
      XCTAssertTrue(compositor.dropKey(direction: .rear))
      XCTAssertTrue((compositor.cursor, compositor.length) == (2, 2))
      XCTAssertTrue((compositor.segments.count) == 2)
      XCTAssertTrue(compositor.segments[0].maxLength == 2)
      XCTAssertTrue(compositor.segments[0][1]?.keyArray == ["h"])
      XCTAssertTrue(compositor.segments[0][2]?.keyArray == ["h", "o"])
      XCTAssertTrue(compositor.segments[1].maxLength == 1)
      XCTAssertTrue(compositor.segments[1][1]?.keyArray == ["o"])
    }

    // 測試對幅節的刪除行為所產生的影響（從最後端開始往前方刪除）。
    do {
      resetcompositorForTests()
      compositor.cursor = 0
      XCTAssertFalse(compositor.dropKey(direction: .rear))
      XCTAssertTrue(compositor.dropKey(direction: .front))
      XCTAssertTrue((compositor.cursor, compositor.length) == (0, 2))
      XCTAssertTrue((compositor.segments.count) == 2)
      XCTAssertTrue(compositor.segments[0].maxLength == 2)
      XCTAssertTrue(compositor.segments[0][1]?.keyArray == ["o"])
      XCTAssertTrue(compositor.segments[0][2]?.keyArray == ["o", "g"])
      XCTAssertTrue(compositor.segments[1].maxLength == 1)
      XCTAssertTrue(compositor.segments[1][1]?.keyArray == ["g"])
    }

    // 測試對幅節的刪除行為所產生的影響（從中間開始往後方刪除）。
    do {
      resetcompositorForTests()
      compositor.cursor = 2
      XCTAssertTrue(compositor.dropKey(direction: .rear))
      XCTAssertTrue((compositor.cursor, compositor.length) == (1, 2))
      XCTAssertTrue((compositor.segments.count) == 2)
      XCTAssertTrue(compositor.segments[0].maxLength == 2)
      XCTAssertTrue(compositor.segments[0][1]?.keyArray == ["h"])
      XCTAssertTrue(compositor.segments[0][2]?.keyArray == ["h", "g"])
      XCTAssertTrue(compositor.segments[1].maxLength == 1)
      XCTAssertTrue(compositor.segments[1][1]?.keyArray == ["g"])
    }

    // 測試對幅節的刪除行為所產生的影響（從中間開始往前方刪除）。
    do {
      let snapshot = compositor.config
      resetcompositorForTests()
      compositor.cursor = 1
      XCTAssertTrue(compositor.dropKey(direction: .front))
      XCTAssertTrue((compositor.cursor, compositor.length) == (1, 2))
      XCTAssertTrue((compositor.segments.count) == 2)
      XCTAssertTrue(compositor.segments[0].maxLength == 2)
      XCTAssertTrue(compositor.segments[0][1]?.keyArray == ["h"])
      XCTAssertTrue(compositor.segments[0][2]?.keyArray == ["h", "g"])
      XCTAssertTrue(compositor.segments[1].maxLength == 1)
      XCTAssertTrue(compositor.segments[1][1]?.keyArray == ["g"])
      XCTAssertTrue(snapshot == compositor.config)
    }
  }

  /// 測試在插入某個幅節之後、對其他幅節的影響。
  func test06_Compositor_SegmentInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.insertKey("是")
    compositor.insertKey("學")
    compositor.insertKey("生")
    compositor.cursor = 1
    compositor.insertKey("大")
    XCTAssert((compositor.cursor, compositor.length) == (2, 4))
    XCTAssert(compositor.segments.count == 4)
    XCTAssert(compositor.segments[0].maxLength == 4)
    XCTAssert(compositor.segments[0][1]?.keyArray == ["是"])
    XCTAssert(compositor.segments[0][2]?.keyArray == ["是", "大"])
    XCTAssert(compositor.segments[0][3]?.keyArray == ["是", "大", "學"])
    XCTAssert(compositor.segments[0][4]?.keyArray == ["是", "大", "學", "生"])
    XCTAssert(compositor.segments[1].maxLength == 3)
    XCTAssert(compositor.segments[1][1]?.keyArray == ["大"])
    XCTAssert(compositor.segments[1][2]?.keyArray == ["大", "學"])
    XCTAssert(compositor.segments[1][3]?.keyArray == ["大", "學", "生"])
    XCTAssert(compositor.segments[2].maxLength == 2)
    XCTAssert(compositor.segments[2][1]?.keyArray == ["學"])
    XCTAssert(compositor.segments[2][2]?.keyArray == ["學", "生"])
    XCTAssert(compositor.segments[3].maxLength == 1)
    XCTAssert(compositor.segments[3][1]?.keyArray == ["生"])
  }

  /// 測試在一個很長的組字區內在中间刪除掉或者添入某個讀音鍵之後的影響。
  func test07_Compositor_LongGridDeletionAndInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    "無可奈何花作香幽蝶能留一縷芳".forEach {
      compositor.insertKey($0.description)
    }
    do {
      compositor.cursor = 8
      XCTAssert(compositor.dropKey(direction: .rear))
      XCTAssert((compositor.cursor, compositor.length) == (7, 13))
      XCTAssert(compositor.segments.count == 13)
      XCTAssert(compositor.segments[0][5]?.keyArray.joined() == "無可奈何花")
      XCTAssert(compositor.segments[1][5]?.keyArray.joined() == "可奈何花作")
      XCTAssert(compositor.segments[2][5]?.keyArray.joined() == "奈何花作香")
      XCTAssert(compositor.segments[3][5]?.keyArray.joined() == "何花作香蝶")
      XCTAssert(compositor.segments[4][5]?.keyArray.joined() == "花作香蝶能")
      XCTAssert(compositor.segments[5][5]?.keyArray.joined() == "作香蝶能留")
      XCTAssert(compositor.segments[6][5]?.keyArray.joined() == "香蝶能留一")
      XCTAssert(compositor.segments[7][5]?.keyArray.joined() == "蝶能留一縷")
      XCTAssert(compositor.segments[8][5]?.keyArray.joined() == "能留一縷芳")
    }
    do {
      XCTAssert(compositor.insertKey("幽"))
      XCTAssert((compositor.cursor, compositor.length) == (8, 14))
      XCTAssert(compositor.segments.count == 14)
      XCTAssert(compositor.segments[0][6]?.keyArray.joined() == "無可奈何花作")
      XCTAssert(compositor.segments[1][6]?.keyArray.joined() == "可奈何花作香")
      XCTAssert(compositor.segments[2][6]?.keyArray.joined() == "奈何花作香幽")
      XCTAssert(compositor.segments[3][6]?.keyArray.joined() == "何花作香幽蝶")
      XCTAssert(compositor.segments[4][6]?.keyArray.joined() == "花作香幽蝶能")
      XCTAssert(compositor.segments[5][6]?.keyArray.joined() == "作香幽蝶能留")
      XCTAssert(compositor.segments[6][6]?.keyArray.joined() == "香幽蝶能留一")
      XCTAssert(compositor.segments[7][6]?.keyArray.joined() == "幽蝶能留一縷")
      XCTAssert(compositor.segments[8][6]?.keyArray.joined() == "蝶能留一縷芳")
    }
  }
}

// MARK: - MegrezTestsAdvanced

final class MegrezTestsAdvanced: XCTestCase {
  /// 組字器的分詞功能測試，同時測試組字器的硬拷貝功能。
  func test08_Compositor_WordSegmentation() throws {
    let regexToFilter = try Regex(".* 能留 .*\n")
    let rawData = MegrezTestComponents.strLMSampleDataHutao.replacing(regexToFilter, with: "")
    let compositor = Megrez.Compositor(
      with: SimpleLM(input: rawData, swapKeyValue: true, separator: ""),
      separator: ""
    )
    "幽蝶能留一縷芳".forEach { i in
      compositor.insertKey(i.description)
    }
    let result = compositor.assemble()
    XCTAssertEqual(result.joinedKeys(by: ""), ["幽蝶", "能", "留", "一縷", "芳"])
    let hardCopy = compositor.copy
    XCTAssertEqual(hardCopy.config, compositor.config)
  }

  /// 組字器的組字壓力測試。
  func test09_Compositor_StressBench() throws {
    NSLog("// Stress test preparation begins.")
    let compositor = Megrez.Compositor(with: SimpleLM(input: MegrezTestComponents.strLMStressData))
    (0 ..< 1_919).forEach { _ in
      compositor.insertKey("sheng1")
    }
    NSLog("// Stress test started.")
    let startTime = Date().timeIntervalSinceReferenceDate
    compositor.assemble()
    let timeElapsed = Date().timeIntervalSinceReferenceDate - startTime
    NSLog("// Stress test elapsed: \(timeElapsed)s.")
  }

  func test10_Compositor_UpdateUnigramData() throws {
    let readings: [Substring] = "shu4 xin1 feng1".split(separator: " ")
    let newRawStringLM = MegrezTestComponents.strLMSampleDataEmoji + "\nshu4-xin1-feng1 樹新風 -9\n"
    let regexToFilter = try Regex(".*(樹|新|風) .*")
    let lm = SimpleLM(input: newRawStringLM.replacing(regexToFilter, with: ""))
    let compositor = Megrez.Compositor(with: lm)
    readings.forEach { key in
      XCTAssertTrue(compositor.insertKey(key.description))
    }
    print(compositor.keys)
    let oldResult = compositor.assemble().values
    XCTAssertEqual(oldResult, ["樹心", "封"])
    lm.reinit(input: newRawStringLM)
    compositor.assignNodes(updateExisting: true)
    let newResult = compositor.assemble().values
    XCTAssertEqual(newResult, ["樹新風"])
  }

  /// `fetchCandidatesDeprecated` 這個方法在極端情況下（比如兩個連續讀音，等）會有故障，現已棄用。
  /// 目前這筆測試並不能曝露這個函式的問題，但卻能用來輔助測試其**繼任者**是否能完成一致的正確工作。
  func test11_Compositor_VerifyCandidateFetchResultsWithNewAPI() throws {
    let theLM = SimpleLM(
      input: MegrezTestComponents.strLMSampleDataTechGuarden + "\n" + MegrezTestComponents
        .strLMSampleDataLitch
    )
    let rawReadings = "da4 qian2 tian1 zai5 ke1 ji4 gong1 yuan2 chao1 shang1"
    let compositor = Megrez.Compositor(with: theLM)
    rawReadings.split(separator: " ").forEach { key in
      compositor.insertKey(key.description)
    }
    var stack1A = [String]()
    var stack1B = [String]()
    var stack2A = [String]()
    var stack2B = [String]()
    for i in 0 ... compositor.keys.count {
      stack1A
        .append(
          compositor.fetchCandidates(at: i, filter: .beginAt).map(\.value)
            .joined(separator: "-")
        )
      stack1B
        .append(
          compositor.fetchCandidates(at: i, filter: .endAt).map(\.value)
            .joined(separator: "-")
        )
      stack2A
        .append(
          compositor.fetchCandidatesDeprecated(at: i, filter: .beginAt).map(\.value)
            .joined(separator: "-")
        )
      stack2B
        .append(
          compositor.fetchCandidatesDeprecated(at: i, filter: .endAt).map(\.value)
            .joined(separator: "-")
        )
    }
    stack1B.removeFirst()
    stack2B.removeLast()
    XCTAssertEqual(stack1A, stack2A)
    XCTAssertEqual(stack1B, stack2B)
  }

  /// 測試是否有效隔絕橫跨游標位置的候選字詞。
  ///
  /// 「選字窗內出現橫跨游標的候選字」的故障會破壞使用體驗，得防止發生。
  /// （微軟新注音沒有這個故障，macOS 內建的注音也沒有。）
  func test12_Compositor_FilteringOutCandidatesAcrossingTheCursor() throws {
    // 一號測試。
    do {
      let readings: [Substring] = "ke1 ji4 gong1 yuan2".split(separator: " ")
      let mockLM = SimpleLM(input: MegrezTestComponents.strLMSampleDataTechGuarden)
      let compositor = Megrez.Compositor(with: mockLM)
      readings.forEach {
        compositor.insertKey($0.description)
      }
      // 初始組句結果。
      let assembledSentence = compositor.assemble().map(\.value)
      XCTAssertTrue(assembledSentence == ["科技", "公園"])
      // 測試候選字詞過濾。
      let gotBeginAt = compositor.fetchCandidates(at: 2, filter: .beginAt).map(\.value)
      let gotEndAt = compositor.fetchCandidates(at: 2, filter: .endAt).map(\.value)
      XCTAssertTrue(!gotBeginAt.contains("濟公"))
      XCTAssertTrue(gotBeginAt.contains("公園"))
      XCTAssertTrue(!gotEndAt.contains("公園"))
      XCTAssertTrue(gotEndAt.contains("科技"))
    }
    // 二號測試。
    do {
      let readings: [Substring] = "sheng1 sheng1".split(separator: " ")
      let mockLM = SimpleLM(
        input: MegrezTestComponents.strLMStressData + "\n" + MegrezTestComponents
          .strLMSampleDataHutao
      )
      let compositor = Megrez.Compositor(with: mockLM)
      readings.forEach {
        compositor.insertKey($0.description)
      }
      var a = compositor.fetchCandidates(at: 1, filter: .beginAt).map(\.keyArray.count).max() ?? 0
      var b = compositor.fetchCandidates(at: 1, filter: .endAt).map(\.keyArray.count).max() ?? 0
      var c = compositor.fetchCandidates(at: 0, filter: .beginAt).map(\.keyArray.count).max() ?? 0
      var d = compositor.fetchCandidates(at: 2, filter: .endAt).map(\.keyArray.count).max() ?? 0
      XCTAssertEqual("\(a) \(b) \(c) \(d)", "1 1 2 2")
      compositor.cursor = compositor.length
      compositor.insertKey("jin1")
      a = compositor.fetchCandidates(at: 1, filter: .beginAt).map(\.keyArray.count).max() ?? 0
      b = compositor.fetchCandidates(at: 1, filter: .endAt).map(\.keyArray.count).max() ?? 0
      c = compositor.fetchCandidates(at: 0, filter: .beginAt).map(\.keyArray.count).max() ?? 0
      d = compositor.fetchCandidates(at: 2, filter: .endAt).map(\.keyArray.count).max() ?? 0
      XCTAssertEqual("\(a) \(b) \(c) \(d)", "1 1 2 2")
    }
  }

  /// 組字器的組字功能測試（單元圖，完整輸入讀音與聲調，完全匹配）。
  func test13_Compositor_AssembleAndOverrideWithUnigramAndCursorJump() throws {
    let readings = "chao1 shang1 da4 qian2 tian1 wei2 zhi3 hai2 zai5 mai4 nai3 ji1"
    let mockLM = SimpleLM(input: MegrezTestComponents.strLMSampleDataLitch)
    let compositor = Megrez.Compositor(with: mockLM)
    readings.split(separator: " ").forEach {
      compositor.insertKey($0.description)
    }
    XCTAssert(compositor.length == 12)
    XCTAssert(compositor.length == compositor.cursor)
    // 初始組句結果。
    var assembledSentence = compositor.assemble().map(\.value)
    XCTAssert(assembledSentence == ["超商", "大前天", "為止", "還", "在", "賣", "荔枝"])
    // 測試 DumpDOT。
    let expectedDumpDOT = """
    digraph {\ngraph [ rankdir=LR ];\nBOS;\nBOS -> 超;\n超;\n超 -> 傷;\n\
    BOS -> 超商;\n超商;\n超商 -> 大;\n超商 -> 大錢;\n超商 -> 大前天;\n傷;\n\
    傷 -> 大;\n傷 -> 大錢;\n傷 -> 大前天;\n大;\n大 -> 前;\n大 -> 前天;\n大錢;\n\
    大錢 -> 添;\n大前天;\n大前天 -> 為;\n大前天 -> 為止;\n前;\n前 -> 添;\n前天;\n\
    前天 -> 為;\n前天 -> 為止;\n添;\n添 -> 為;\n添 -> 為止;\n為;\n為 -> 指;\n\
    為止;\n為止 -> 還;\n指;\n指 -> 還;\n還;\n還 -> 在;\n在;\n在 -> 賣;\n賣;\n\
    賣 -> 乃;\n賣 -> 荔枝;\n乃;\n乃 -> 雞;\n荔枝;\n荔枝 -> EOS;\n雞;\n雞 -> EOS;\nEOS;\n}\n
    """
    let actualDumpDOT = compositor.dumpDOT
    XCTAssert(actualDumpDOT == expectedDumpDOT)
    // 單獨測試對最前方的讀音的覆寫。
    do {
      let compositorCopy1 = compositor.copy
      XCTAssertTrue(
        compositorCopy1.overrideCandidate(.init(keyArray: ["ji1"], value: "雞"), at: 11)
      )
      assembledSentence = compositorCopy1.assemble().map(\.value)
      XCTAssert(assembledSentence == ["超商", "大前天", "為止", "還", "在", "賣", "乃", "雞"])
    }
    // 回到先前的測試，測試對整個詞的覆寫。
    XCTAssert(
      compositor.overrideCandidate(.init(keyArray: ["nai3", "ji1"], value: "奶雞"), at: 10)
    )
    assembledSentence = compositor.assemble().map(\.value)
    XCTAssert(assembledSentence == ["超商", "大前天", "為止", "還", "在", "賣", "奶雞"])
    // 測試游標跳轉。
    compositor.cursor = 10 // 向後
    XCTAssert(compositor.jumpCursorBySegment(to: .rear))
    XCTAssert(compositor.cursor == 9)
    XCTAssert(compositor.jumpCursorBySegment(to: .rear))
    XCTAssert(compositor.cursor == 8)
    XCTAssert(compositor.jumpCursorBySegment(to: .rear))
    XCTAssert(compositor.cursor == 7)
    XCTAssert(compositor.jumpCursorBySegment(to: .rear))
    XCTAssert(compositor.cursor == 5)
    XCTAssert(compositor.jumpCursorBySegment(to: .rear))
    XCTAssert(compositor.cursor == 2)
    XCTAssert(compositor.jumpCursorBySegment(to: .rear))
    XCTAssert(compositor.cursor == 0)
    XCTAssertFalse(compositor.jumpCursorBySegment(to: .rear))
    XCTAssert(compositor.cursor == 0) // 接下來準備向前
    XCTAssert(compositor.jumpCursorBySegment(to: .front))
    XCTAssert(compositor.cursor == 2)
    XCTAssert(compositor.jumpCursorBySegment(to: .front))
    XCTAssert(compositor.cursor == 5)
    XCTAssert(compositor.jumpCursorBySegment(to: .front))
    XCTAssert(compositor.cursor == 7)
    XCTAssert(compositor.jumpCursorBySegment(to: .front))
    XCTAssert(compositor.cursor == 8)
    XCTAssert(compositor.jumpCursorBySegment(to: .front))
    XCTAssert(compositor.cursor == 9)
    XCTAssert(compositor.jumpCursorBySegment(to: .front))
    XCTAssert(compositor.cursor == 10)
    XCTAssert(compositor.jumpCursorBySegment(to: .front))
    XCTAssert(compositor.cursor == 12)
    XCTAssertFalse(compositor.jumpCursorBySegment(to: .front))
    XCTAssert(compositor.cursor == 12)
  }

  /// 另一組針對組字器的組字功能測試（單元圖，完整輸入讀音與聲調，完全匹配）。
  ///
  /// 注：敝引擎（Megrez 天權星）不支援 Bigram 與 Partial Key Matching。
  /// 對此有需求者請洽其繼任者「libHoma（護摩）」。
  func test14_Compositor_AssembleAndOverride_AnotherTest() throws {
    let readings: [Substring] = "you1 die2 neng2 liu2 yi4 lv3 fang1".split(separator: " ")
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleDataHutao)
    let compositor = Megrez.Compositor(with: lm)
    readings.forEach {
      compositor.insertKey($0.description)
    }
    // 初始組句結果。
    var assembledSentence = compositor.assemble().map(\.value)
    XCTAssert(assembledSentence == ["幽蝶", "能", "留意", "呂方"])
    // 測試覆寫「留」以試圖打斷「留意」。
    compositor.overrideCandidate(
      .init((["liu2"], "留")),
      at: 3,
      overrideType: .withSpecified
    )
    // 測試覆寫「一縷」以打斷「留意」與「呂方」。
    compositor.overrideCandidate(
      .init((["yi4", "lv3"], "一縷")),
      at: 4,
      overrideType: .withSpecified
    )
    assembledSentence = compositor.assemble().map(\.value)
    XCTAssertEqual(assembledSentence, ["幽蝶", "能", "留", "一縷", "方"])
    // 對位置 7 這個最前方的座標位置使用節點覆寫。會在此過程中自動糾正成對位置 6 的覆寫。
    compositor.overrideCandidate(
      .init((["fang1"], "芳")),
      at: 7,
      overrideType: .withSpecified
    )
    assembledSentence = compositor.assemble().map(\.value)
    XCTAssert(assembledSentence == ["幽蝶", "能", "留", "一縷", "芳"])
    let expectedDOT = """
    digraph {\ngraph [ rankdir=LR ];\nBOS;\nBOS -> 優;\n優;\n優 -> 跌;\nBOS -> 幽蝶;\n\
    幽蝶;\n幽蝶 -> 能;\n幽蝶 -> 能留;\n跌;\n跌 -> 能;\n跌 -> 能留;\n能;\n能 -> 留;\n\
    能 -> 留意;\n能留;\n能留 -> 亦;\n能留 -> 一縷;\n留;\n留 -> 亦;\n留 -> 一縷;\n留意;\n\
    留意 -> 旅;\n留意 -> 呂方;\n亦;\n亦 -> 旅;\n亦 -> 呂方;\n一縷;\n一縷 -> 芳;\n旅;\n\
    旅 -> 芳;\n呂方;\n呂方 -> EOS;\n芳;\n芳 -> EOS;\nEOS;\n}\n
    """
    XCTAssertEqual(compositor.dumpDOT, expectedDOT)
  }

  /// 針對完全覆蓋的節點的專項覆寫測試。
  func test15_Compositor_ResettingFullyOverlappedNodesOnOverride() throws {
    let readings: [Substring] = "shui3 guo3 zhi1".split(separator: " ")
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleDataFruitJuice)
    let compositor = Megrez.Compositor(with: lm)
    readings.forEach {
      compositor.insertKey($0.description)
    }
    let result = compositor.assemble()
    var assembledSentence = result.map(\.value)
    XCTAssertEqual(result.values, ["水果汁"])
    // 測試針對第一個漢字的位置的操作。
    do {
      do {
        XCTAssertTrue(
          compositor.overrideCandidate(.init(keyArray: ["shui3"], value: "💦"), at: 0)
        )
        assembledSentence = compositor.assemble().map(\.value)
        XCTAssertEqual(assembledSentence, ["💦", "果汁"])
      }
      do {
        XCTAssertTrue(
          compositor.overrideCandidate(
            .init(keyArray: ["shui3", "guo3", "zhi1"], value: "水果汁"),
            at: 1
          )
        )
        assembledSentence = compositor.assemble().map(\.value)
        XCTAssertEqual(assembledSentence, ["水果汁"])
      }
      do {
        XCTAssertTrue(
          // 再覆寫回來。
          compositor.overrideCandidate(.init(keyArray: ["shui3"], value: "💦"), at: 0)
        )
        assembledSentence = compositor.assemble().map(\.value)
        XCTAssertEqual(assembledSentence, ["💦", "果汁"])
      }
    }

    // 測試針對其他位置的操作。
    do {
      do {
        XCTAssertTrue(
          compositor.overrideCandidate(.init(keyArray: ["guo3"], value: "裹"), at: 1)
        )
        assembledSentence = compositor.assemble().map(\.value)
        XCTAssertEqual(assembledSentence, ["💦", "裹", "之"])
      }
      do {
        XCTAssertTrue(
          compositor.overrideCandidate(.init(keyArray: ["zhi1"], value: "知"), at: 2)
        )
        assembledSentence = compositor.assemble().map(\.value)
        XCTAssertEqual(assembledSentence, ["💦", "裹", "知"])
      }
      do {
        XCTAssertTrue(
          // 再覆寫回來。
          compositor.overrideCandidate(
            .init(keyArray: ["shui3", "guo3", "zhi1"], value: "水果汁"),
            at: 3
          )
        )
        assembledSentence = compositor.assemble().map(\.value)
        XCTAssertEqual(assembledSentence, ["水果汁"])
      }
    }
  }

  /// 針對不完全覆蓋的節點的專項覆寫測試。
  func test16_Compositor_ResettingPartiallyOverlappedNodesOnOverride() throws {
    let readings: [Substring] = "ke1 ji4 gong1 yuan2".split(separator: " ")
    let rawData = MegrezTestComponents.strLMSampleDataTechGuarden + "\ngong1-yuan2 公猿 -9"
    let compositor = Megrez.Compositor(with: SimpleLM(input: rawData))
    readings.forEach {
      compositor.insertKey($0.description)
    }
    var result = compositor.assemble()
    XCTAssertEqual(result.values, ["科技", "公園"])

    XCTAssertTrue(
      compositor.overrideCandidate(
        .init(keyArray: ["ji4", "gong1"], value: "濟公"),
        at: 1
      )
    )
    result = compositor.assemble()
    XCTAssertEqual(result.values, ["顆", "濟公", "元"])

    XCTAssertTrue(
      compositor.overrideCandidate(
        .init(keyArray: ["gong1", "yuan2"], value: "公猿"),
        at: 2
      )
    )
    result = compositor.assemble()
    XCTAssertEqual(result.values, ["科技", "公猿"])

    XCTAssertTrue(
      compositor.overrideCandidate(
        .init(keyArray: ["ke1", "ji4"], value: "科際"),
        at: 0
      )
    )
    result = compositor.assemble()
    XCTAssertEqual(result.values, ["科際", "公猿"])
  }

  func test17_Compositor_CandidateDisambiguation() throws {
    let readings: [Substring] = "da4 shu4 xin1 de5 mi4 feng1".split(separator: " ")
    let regexToFilter = try Regex("\nshu4-xin1 .*")
    let rawData = MegrezTestComponents.strLMSampleDataEmoji.replacing(regexToFilter, with: "")
    let compositor = Megrez.Compositor(with: SimpleLM(input: rawData))
    readings.forEach {
      compositor.insertKey($0.description)
    }
    var result = compositor.assemble()
    XCTAssertEqual(result.values, ["大樹", "新的", "蜜蜂"])
    let pos = 2

    XCTAssertTrue(compositor.overrideCandidate(.init(keyArray: ["xin1"], value: "🆕"), at: pos))
    result = compositor.assemble()
    XCTAssertEqual(result.values, ["大樹", "🆕", "的", "蜜蜂"])

    XCTAssertTrue(
      compositor.overrideCandidate(.init(keyArray: ["xin1", "de5"], value: "🆕"), at: pos)
    )
    result = compositor.assemble()
    XCTAssertEqual(result.values, ["大樹", "🆕", "蜜蜂"])
  }

  func test18_Composer_PerceptionDataTest_SaisoukiNoGaika() throws {
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleData_SaisoukiNoGaika)
    let compositor = Megrez.Compositor(with: lm)
    let readingKeys = ["zai4", "chuang4", "shi4", "de5", "kai3", "ge1"]
    for key in readingKeys {
      XCTAssertTrue(compositor.insertKey(key))
    }
    compositor.assemble()
    let assembledBefore = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("再 創 是的 凱歌" == assembledBefore)
    // 測試此時生成的 keyForQueryingData 是否正確
    let cursorShi = 2
    let cursorShiDe = 3
    guard let keyForQueryingDataAt2 = compositor.assembledSentence
      .generateKeyForPerception(cursor: cursorShi)
    else {
      XCTFail("Expected key for cursor \(cursorShi)")
      return
    }
    XCTAssertEqual(keyForQueryingDataAt2.ngramKey, "(zai4,再)&(chuang4,創)&(shi4-de5,是的)")
    XCTAssertEqual(keyForQueryingDataAt2.headReading, "shi4")
    guard let keyForQueryingDataAt3 = compositor.assembledSentence
      .generateKeyForPerception(cursor: cursorShiDe)
    else {
      XCTFail("Expected key for cursor \(cursorShiDe)")
      return
    }
    XCTAssertEqual(keyForQueryingDataAt3.ngramKey, "(zai4,再)&(chuang4,創)&(shi4-de5,是的)")
    XCTAssertEqual(keyForQueryingDataAt3.headReading, "de5")
    // 應能提供『是的』『似的』『凱歌』等候選
    let pairsAtShiDeEnd = compositor.fetchCandidates(at: 4, filter: .endAt)
    XCTAssertTrue(pairsAtShiDeEnd.map(\.value).contains("是的"))
    XCTAssertTrue(pairsAtShiDeEnd.map(\.value).contains("似的"))
    // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
    var obsCaptured: Megrez.PerceptionIntel?
    let overrideSucceededFirst = compositor.overrideCandidate(
      .init(keyArray: ["shi4"], value: "世"),
      at: cursorShi,
      overrideType: .withSpecified,
      enforceRetokenization: true,
      perceptionHandler: { obsCaptured = $0 }
    )
    XCTAssertTrue(overrideSucceededFirst)
    XCTAssertEqual(obsCaptured?.contextualizedGramKey, "(zai4,再)&(chuang4,創)&(shi4,世)")
    // compositor.assemble() <- 已經組句了。
    let assembledAfter = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("再 創 世 的 凱歌" == assembledAfter)
    // ====
    let prevAssembly = compositor.assembledSentence
    obsCaptured = nil
    let overrideSucceeded = compositor.overrideCandidate(
      .init(keyArray: ["shi4", "de5"], value: "是的"),
      at: cursorShiDe,
      overrideType: .withSpecified,
      enforceRetokenization: true,
      perceptionHandler: { obsCaptured = $0 }
    )
    XCTAssertEqual(obsCaptured?.contextualizedGramKey, "(chuang4,創)&(shi4,世)&(shi4-de5,是的)")
    XCTAssertTrue(overrideSucceeded)
    let currentAssembly = compositor.assembledSentence
    guard let afterHit = currentAssembly.findGram(at: cursorShiDe) else {
      XCTFail("Expected current gram at cursor \(cursorShiDe)")
      return
    }
    let border1 = afterHit.range.upperBound - 1
    let border2 = prevAssembly.totalKeyCount - 1
    let innerIndex = Swift.max(0, Swift.min(border1, border2))
    guard let prevHit = prevAssembly.findGram(at: innerIndex) else {
      XCTFail("Expected previous gram at cursor \(innerIndex)")
      return
    }
    XCTAssertEqual(afterHit.gram.segLength, 2)
    XCTAssertEqual(prevHit.gram.segLength, 1)
    XCTAssertNotNil(obsCaptured)
    XCTAssertEqual(obsCaptured?.scenario, .shortToLong)
    XCTAssertEqual(obsCaptured?.candidate, "是的")

    // 測試 POM 建議的候選覆寫
    compositor.clear()
    for key in readingKeys.prefix(4) {
      XCTAssertTrue(compositor.insertKey(key))
    }

    let pomSuggestedCandidate = Megrez.KeyValuePaired((["shi4"], "世", -0.07449307430679043))
    let pomSuggestedCandidateOverrideCursor = 2
    // let forceHighScoreOverride = false
    // overrideType: forceHighScoreOverride ? .withHighScore : .withTopUnigramScore
    XCTAssertTrue(
      compositor.overrideCandidate(
        pomSuggestedCandidate,
        at: pomSuggestedCandidateOverrideCursor,
        overrideType: .withTopGramScore,
        enforceRetokenization: true
      )
    )
    compositor.assemble()
    let assembledByPOM = compositor.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    XCTAssertEqual("再 創 世 的", assembledByPOM)
  }

  func test19_Composer_PerceptionDataTest_BusinessEnglishSession() throws {
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleData_BusinessEnglishSession)
    let compositor = Megrez.Compositor(with: lm)
    // 測試用句「再創世的凱歌」。
    let readingKeys = ["shang1", "wu4", "ying1", "yu3", "hui4", "hua4"]
    for key in readingKeys {
      XCTAssertTrue(compositor.insertKey(key))
    }
    compositor.assemble()
    let assembledBefore = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("商務 英語 繪畫" == assembledBefore)
    // 測試此時生成的 keyForQueryingData 是否正確
    let cursorHua = 5
    guard let keyForQueryingDataAt5 = compositor.assembledSentence
      .generateKeyForPerception(cursor: cursorHua)
    else {
      XCTFail("Expected key for cursor \(cursorHua)")
      return
    }
    XCTAssertEqual(keyForQueryingDataAt5.ngramKey, "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,繪畫)")
    XCTAssertEqual(keyForQueryingDataAt5.headReading, "hua4")
    // 應能提供『是的』『似的』『凱歌』等候選
    let pairsAtHuiHuaEnd = compositor.fetchCandidates(at: 6, filter: .endAt)
    XCTAssertTrue(pairsAtHuiHuaEnd.map(\.value).contains("繪畫"))
    XCTAssertTrue(pairsAtHuiHuaEnd.map(\.value).contains("會話"))
    // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
    var obsCaptured: Megrez.PerceptionIntel?
    let overrideSucceeded = compositor.overrideCandidate(
      .init(keyArray: ["hui4", "hua4"], value: "會話"),
      at: cursorHua,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    XCTAssertTrue(overrideSucceeded)
    XCTAssertEqual(
      obsCaptured?.contextualizedGramKey,
      "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,會話)"
    )
    // compositor.assemble() <- 已經組句了。
    let assembledAfter = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("商務 英語 會話" == assembledAfter)

    // 測試 POM 建議的候選覆寫
    compositor.clear()
    for key in readingKeys {
      XCTAssertTrue(compositor.insertKey(key))
    }

    let pomSuggestedCandidate = Megrez.KeyValuePaired(
      (["hui4", "hua4"], "會話", -0.074493074227700559)
    )
    let pomSuggestedCandidateOverrideCursor = 4
    // let forceHighScoreOverride = false
    // overrideType: forceHighScoreOverride ? .withHighScore : .withTopUnigramScore
    XCTAssertTrue(
      compositor.overrideCandidate(
        pomSuggestedCandidate,
        at: pomSuggestedCandidateOverrideCursor,
        overrideType: .withTopGramScore,
        enforceRetokenization: true
      )
    )
    compositor.assemble()
    let assembledByPOM = compositor.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    XCTAssertEqual("商務 英語 會話", assembledByPOM)
  }

  func test20_Composer_PerceptionDataTest_DiJiaoSubmission() throws {
    let readingKeys = ["di4", "jiao1"]
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleData_DiJiaoSubmission)
    let compositor = Megrez.Compositor(with: lm)
    for key in readingKeys {
      XCTAssertTrue(compositor.insertKey(key))
    }
    compositor.assemble()

    XCTAssertTrue(
      compositor.overrideCandidate(
        .init(keyArray: ["di4"], value: "第"),
        at: 0,
        enforceRetokenization: true
      )
    )
    compositor.assemble()
    let assembledAfterFirst = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue(["第 交", "第 教"].contains(assembledAfterFirst))

    let candidatesAtEnd = compositor.fetchCandidates(at: readingKeys.count, filter: .endAt)
    guard let diJiaoCandidate = candidatesAtEnd.first(where: { $0.value == "遞交" }) else {
      XCTFail("遞交 should be available as a candidate ending at the current cursor.")
      return
    }

    var obsCaptured: Megrez.PerceptionIntel?
    XCTAssertTrue(
      compositor.overrideCandidate(
        diJiaoCandidate,
        at: readingKeys.count,
        enforceRetokenization: true
      ) {
        obsCaptured = $0
      }
    )
    guard let obsCaptured else {
      XCTFail("Perception intel should be captured when overriding with 遞交.")
      return
    }

    XCTAssertEqual(obsCaptured.contextualizedGramKey, "()&(di4,第)&(di4-jiao1,遞交)")
    XCTAssertEqual(obsCaptured.candidate, "遞交")
    XCTAssertEqual(obsCaptured.scenario, .shortToLong)
    XCTAssertTrue(obsCaptured.forceHighScoreOverride)

    compositor.assemble()
    let assembledAfterSecond = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("遞交", assembledAfterSecond)

    let validationCompositor = Megrez.Compositor(with: lm)
    for key in readingKeys {
      XCTAssertTrue(validationCompositor.insertKey(key))
    }
    validationCompositor.assemble()
    XCTAssertTrue(
      validationCompositor.overrideCandidate(
        .init(keyArray: ["di4"], value: "第"),
        at: 0,
        enforceRetokenization: true
      )
    )
    validationCompositor.assemble()

    let baselineKey = validationCompositor.assembledSentence
      .generateKeyForPerception(cursor: max(validationCompositor.cursor - 1, 0))
    XCTAssertEqual(baselineKey?.ngramKey, "()&(di4,第)&(jiao1,交)")

    let pomSuggestedCandidate = Megrez.KeyValuePaired(
      keyArray: diJiaoCandidate.keyArray,
      value: diJiaoCandidate.value,
      score: diJiaoCandidate.score
    )
    let overrideCursor = readingKeys.count
    let overrideType: Megrez.Node.OverrideType =
      obsCaptured.forceHighScoreOverride ? .withSpecified : .withTopGramScore
    XCTAssertTrue(
      validationCompositor.overrideCandidate(
        pomSuggestedCandidate,
        at: overrideCursor,
        overrideType: overrideType,
        enforceRetokenization: true
      )
    )
    validationCompositor.assemble()
    let assembledBySuggested = validationCompositor.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    XCTAssertEqual("遞交", assembledBySuggested)
  }
}
