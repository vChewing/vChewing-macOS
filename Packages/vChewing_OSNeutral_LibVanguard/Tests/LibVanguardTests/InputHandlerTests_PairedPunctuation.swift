// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Shared
import Testing

@testable import LexiconAssembly
@testable import LibVanguard

// MARK: - IH.PairedPunctuation

extension LibVanguardTestsRoot.InputHandlerTests {
  @Test("IH-PairedPunctuation-001 Split a full pair when selected")
  func test_IH_PairedPunctuation_001_SplitFullPairOnSelection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    typeSentence("\\")
    let candidates = testHandler.generateArrayOfCandidates()
    guard candidates.contains(where: { $0.value == "【】" }) else {
      Issue.record("Missing 【】 candidate. Candidates: \(candidates.map(\.value))")
      return
    }
    testSession.switchState(testHandler.generateStateOfCandidates())
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == "【】" }) else {
      Issue.record("Candidate state is missing 【】. Candidates: \(testSession.state.candidates.map(\.value))")
      return
    }
    testSession.candidatePairSelectionConfirmed(at: index)

    #expect(
      testHandler.assembler.actualKeys == ["_punct_[", "_punct_]"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["【", "】"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    #expect(testHandler.assembler.cursor == 1, "實得：\(testHandler.assembler.cursor)")
  }
}

extension LibVanguardTestsRoot.InputHandlerTests {
  @Test("IH-PairedPunctuation-002 Revolving the right component synchronizes the left")
  func test_IH_PairedPunctuation_002_RevolveRightSynchronizesLeft() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("【】") else { return }

    testHandler.assembler.cursor = 2 // 右元件之後。
    #expect(testHandler.revolveCandidate(reverseOrder: false))
    let values = testHandler.assembler.assembledSentence.map(\.value)
    #expect(values.count == 2, "實得：\(values)")
    guard values.count == 2 else { return }
    #expect(
      values[0] == PairedPunctuation.counterpart(of: values[1]),
      "左邊未隨右邊同步：\(values)"
    )
  }

  @Test("IH-PairedPunctuation-003 Revolving the left component synchronizes the right")
  func test_IH_PairedPunctuation_003_RevolveLeftSynchronizesRight() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("【】") else { return }

    testHandler.assembler.cursor = 1 // 左元件之後、右元件之前。
    #expect(testHandler.revolveCandidate(reverseOrder: false))
    let values = testHandler.assembler.assembledSentence.map(\.value)
    #expect(values.count == 2, "實得：\(values)")
    guard values.count == 2 else { return }
    #expect(
      values[1] == PairedPunctuation.counterpart(of: values[0]),
      "右邊未隨左邊同步：\(values)"
    )
  }

  @Test("IH-PairedPunctuation-004 Re-selecting the right component synchronizes the left")
  func test_IH_PairedPunctuation_004_ReselectRightSynchronizesLeft() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("【】") else { return }

    testHandler.assembler.cursor = 2 // 右元件之後。
    testSession.switchState(testHandler.generateStateOfCandidates())
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == "》" }) else {
      Issue.record("Missing 》 candidate. Candidates: \(testSession.state.candidates.map(\.value))")
      return
    }
    testSession.candidatePairSelectionConfirmed(at: index)
    let values = testHandler.assembler.assembledSentence.map(\.value)
    #expect(values == ["《", "》"], "實得：\(values)")
  }

  @Test("IH-PairedPunctuation-005 Non-pair component does not synchronize")
  func test_IH_PairedPunctuation_005_NonPairDoesNotSynchronize() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("【】") else { return }

    // 把左元件換成非成對的「、」：游標置於左元件之後，刪左元件，再插入 `\` 鍵（首候選為「、」）。
    testHandler.assembler.cursor = 1
    #expect((try? testHandler.assembler.dropKey(direction: .rear)) != nil)
    #expect((try? testHandler.assembler.insertKey("_punct_\\")) != nil)
    let before = testHandler.assembler.assembledSentence.map(\.value)
    #expect(before.count == 2, "實得：\(before)")
    guard before.count == 2 else { return }
    #expect(before[1] == "】", "實得：\(before)")

    testHandler.synchronizePairedPunctuationIfNeeded(at: 0)
    let values = testHandler.assembler.assembledSentence.map(\.value)
    #expect(values == before, "非成對元件不應觸發同步：\(values)")
  }

  @Test("IH-PairedPunctuation-006 Non-adjacent components do not synchronize")
  func test_IH_PairedPunctuation_006_NonAdjacentDoesNotSynchronize() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("【】") else { return }

    testHandler.assembler.cursor = 1 // 左元件之後、右元件之前。
    #expect((try? testHandler.assembler.insertKey("_punct_\\")) != nil)
    let inserted = testHandler.assembler.assembledSentence.map(\.value)
    #expect(inserted.count == 3, "實得：\(inserted)")
    guard inserted.count == 3 else { return }
    #expect(inserted[1] != "】", "實得：\(inserted)")

    #expect((try? testHandler.assembler.overrideCandidate(
      .init(keyArray: ["_punct_["], value: "《"),
      at: 0,
      type: .withSpecified,
      isExplicitlyOverridden: false
    )) != nil)
    testHandler.synchronizePairedPunctuationIfNeeded(at: 0)
    let values = testHandler.assembler.assembledSentence.map(\.value)
    #expect(values == ["《", "、", "】"], "實得：\(values)")
  }

  @Test("IH-PairedPunctuation-007 Selecting a non-pair candidate does not split")
  func test_IH_PairedPunctuation_007_NonPairSelectionDoesNotSplit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectCandidate("、") else { return }

    #expect(
      testHandler.assembler.actualKeys == ["_punct_\\"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["、"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
  }

  @Test("IH-PairedPunctuation-008 Re-selecting the left component synchronizes the right")
  func test_IH_PairedPunctuation_008_ReselectLeftSynchronizesRight() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("【】") else { return }

    testHandler.assembler.cursor = 1 // 左元件之後。
    testSession.switchState(testHandler.generateStateOfCandidates())
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == "《" }) else {
      Issue.record("Missing 《 candidate. Candidates: \(testSession.state.candidates.map(\.value))")
      return
    }
    testSession.candidatePairSelectionConfirmed(at: index)
    let values = testHandler.assembler.assembledSentence.map(\.value)
    #expect(values == ["《", "》"], "實得：\(values)")
  }

  @Test("IH-PairedPunctuation-010 Split a brace pair into brace keys")
  func test_IH_PairedPunctuation_010_SplitBracePair() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("〈〉", trigger: "|") else { return }

    #expect(
      testHandler.assembler.actualKeys == ["_punct_{", "_punct_}"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["〈", "〉"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    #expect(testHandler.assembler.cursor == 1, "實得：\(testHandler.assembler.cursor)")
  }

  @Test("IH-PairedPunctuation-009 Table matches the test lexicon")
  func test_IH_PairedPunctuation_009_TableMatchesLexicon() throws {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    func lexiconValues(for key: String) -> Set<String> {
      Set(
        testHandler.currentLM.unigramsFor(keyArray: [key])
          .map(\.current)
          .filter { !$0.unicodeScalars.allSatisfy(\.isASCII) }
      )
    }
    func tableValues(for key: String, in map: [String: String]) -> Set<String> {
      Set(map.compactMap { $0.value == key ? $0.key : nil })
    }
    #expect(
      lexiconValues(for: "_punct_[") ==
        tableValues(for: "_punct_[", in: PairedPunctuation.leftKeyMap)
    )
    #expect(
      lexiconValues(for: "_punct_]") ==
        tableValues(for: "_punct_]", in: PairedPunctuation.rightKeyMap)
    )
    #expect(
      lexiconValues(for: "_punct_{") ==
        tableValues(for: "_punct_{", in: PairedPunctuation.leftKeyMap)
    )
    #expect(
      lexiconValues(for: "_punct_}") ==
        tableValues(for: "_punct_}", in: PairedPunctuation.rightKeyMap)
    )
    #expect(
      lexiconValues(for: "_punct_(") ==
        tableValues(for: "_punct_(", in: PairedPunctuation.leftKeyMap)
    )
    #expect(
      lexiconValues(for: "_punct_)") ==
        tableValues(for: "_punct_)", in: PairedPunctuation.rightKeyMap)
    )
  }

  @Test("IH-PairedPunctuation-011 Revolving to a full pair keeps one gram")
  func test_IH_PairedPunctuation_011_RevolvingToPairDoesNotSplit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    typeSentence("\\")
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["、"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    var reached = false
    for _ in 0 ..< 12 {
      if testHandler.assembler.assembledSentence.map(\.value) == ["【】"] {
        reached = true
        break
      }
      _ = testHandler.revolveCandidate(reverseOrder: false)
    }
    #expect(reached, "未輪替到【】")
    #expect(
      testHandler.assembler.actualKeys == ["_punct_\\"],
      "輪替到 pair 不應拆對：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["【】"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
  }

  @Test("IH-PairedPunctuation-012 Plain left splits a whole pair and centers")
  func test_IH_PairedPunctuation_012_PlainLeftSplitsAndCenters() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard prepareWholePair("【】") else { return }

    testHandler.assembler.cursor = 1 // 整對之後。
    #expect(testHandler.handleBackward(input: KBEvent.KeyEventData.dataArrowLeft.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["_punct_[", "_punct_]"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["【", "】"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    #expect(testHandler.assembler.cursor == 1, "實得：\(testHandler.assembler.cursor)")
  }

  @Test("IH-PairedPunctuation-013 Plain right splits a whole pair and centers")
  func test_IH_PairedPunctuation_013_PlainRightSplitsAndCenters() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard prepareWholePair("【】") else { return }

    testHandler.assembler.cursor = 0 // 整對之前。
    #expect(testHandler.handleForward(input: KBEvent.KeyEventData.dataArrowRight.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["_punct_[", "_punct_]"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["【", "】"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    #expect(testHandler.assembler.cursor == 1, "實得：\(testHandler.assembler.cursor)")
  }

  @Test("IH-PairedPunctuation-014 Shift-left does not split a whole pair")
  func test_IH_PairedPunctuation_014_ShiftLeftDoesNotSplit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard prepareWholePair("【】") else { return }

    testHandler.assembler.cursor = 1 // 整對之後。
    #expect(testHandler.handleBackward(input: KBEvent.KeyEventData.shiftLeftEvent.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["_punct_\\"],
      "標記游標不應拆對：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["【】"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    #expect(testSession.state.type == .ofMarking, "實得：\(testSession.state.type)")
  }

  @Test("IH-PairedPunctuation-015 Plain arrow does not split a non-pair")
  func test_IH_PairedPunctuation_015_PlainArrowDoesNotSplitNonPair() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    typeSentence("\\")
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["、"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    testHandler.assembler.cursor = 0
    #expect(testHandler.handleForward(input: KBEvent.KeyEventData.dataArrowRight.asEvent))
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["、"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    #expect(testHandler.assembler.cursor == 1, "實得：\(testHandler.assembler.cursor)")
  }

  @Test("IH-PairedPunctuation-016 Plain arrow over an already split pair does not resplit")
  func test_IH_PairedPunctuation_016_PlainArrowOnSplitPairDoesNotResplit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("【】") else { return }
    #expect(testHandler.assembler.cursor == 1, "實得：\(testHandler.assembler.cursor)")

    #expect(testHandler.handleBackward(input: KBEvent.KeyEventData.dataArrowLeft.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["_punct_[", "_punct_]"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(testHandler.assembler.cursor == 0, "實得：\(testHandler.assembler.cursor)")
  }

  @Test("IH-PairedPunctuation-017 Half-width pair candidates split and center")
  func test_IH_PairedPunctuation_017_HalfWidthPairCandidatesSplitAndCenter() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let originalHalfWidth = testHandler.prefs.halfWidthPunctuationEnabled
    defer {
      testHandler.prefs.halfWidthPunctuationEnabled = originalHalfWidth
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    let cases: [(pair: String, keys: [String], values: [String])] = [
      ("[]", ["_half_punct_[", "_half_punct_]"], ["[", "]"]),
      ("{}", ["_half_punct_{", "_half_punct_}"], ["{", "}"]),
      ("()", ["_half_punct_(", "_half_punct_)"], ["(", ")"]),
      ("<>", ["_half_punct_<", "_half_punct_>"], ["<", ">"]),
    ]
    for item in cases {
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.prefs.halfWidthPunctuationEnabled = true
      guard selectSplitPair(item.pair) else { return }
      #expect(
        testHandler.assembler.actualKeys == item.keys,
        "\(item.pair) 實得：\(testHandler.assembler.actualKeys)"
      )
      #expect(
        testHandler.assembler.assembledSentence.map(\.value) == item.values,
        "\(item.pair) 實得：\(testHandler.assembler.assembledSentence.map(\.value))"
      )
      #expect(
        testHandler.assembler.cursor == 1,
        "\(item.pair) 實得：\(testHandler.assembler.cursor)"
      )
    }
  }

  @Test("IH-PairedPunctuation-018 Half-width components synchronize")
  func test_IH_PairedPunctuation_018_HalfWidthComponentsSynchronize() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let originalHalfWidth = testHandler.prefs.halfWidthPunctuationEnabled
    defer {
      testHandler.prefs.halfWidthPunctuationEnabled = originalHalfWidth
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    testHandler.prefs.halfWidthPunctuationEnabled = true
    guard selectSplitPair("[]") else { return }

    // 測試辭典只收 `[`／`]`；真實辭典另有 `｢`／`｣`。此處補上後者以驗同步。
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["_half_punct_["], value: "｢", score: 0),
      isFiltering: false
    )
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["_half_punct_]"], value: "｣", score: 0),
      isFiltering: false
    )
    testHandler.assembler.cursor = 1 // 左元件之後、右元件之前。
    #expect(testHandler.revolveCandidate(reverseOrder: false))
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["｢", "｣"],
      "半形同步失敗：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
  }

  @Test("IH-PairedPunctuation-019 Vertical pair splits and centers")
  func test_IH_PairedPunctuation_019_VerticalPairSplitsAndCenters() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    typeSentence("\\")
    let didOverride = testHandler.assembler.overrideCandidate(
      .init(keyArray: ["_punct_\\"], value: "︻︼"),
      at: 0,
      overrideType: .withSpecified,
      isExplicitlyOverridden: false
    )
    #expect(didOverride, "無法把【】覆寫成︻︼")
    testHandler.assembler.cursor = 1
    #expect(testHandler.handleBackward(input: KBEvent.KeyEventData.dataArrowLeft.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["_punct_[", "_punct_]"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["︻", "︼"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    #expect(testHandler.assembler.cursor == 1, "實得：\(testHandler.assembler.cursor)")
  }

  @Test("IH-PairedPunctuation-020 Vertical components synchronize")
  func test_IH_PairedPunctuation_020_VerticalComponentsSynchronize() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    guard selectSplitPair("【】") else { return }
    let didOverride = testHandler.assembler.overrideCandidate(
      .init(keyArray: ["_punct_]"], value: "﹈"),
      at: 1,
      overrideType: .withSpecified,
      isExplicitlyOverridden: false
    )
    #expect(didOverride, "無法把右元件覆寫成﹈")
    testHandler.synchronizePairedPunctuationIfNeeded(at: 1)
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["﹇", "﹈"],
      "縱排同步失敗：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
  }

  @Test("IH-PairedPunctuation-021 Vertical hardening is one-to-one")
  func test_IH_PairedPunctuation_021_VerticalHardeningIsOneToOne() throws {
    var horizontal = "【】"
    ChineseConverter.hardenVerticalPunctuations(target: &horizontal, convert: true)
    #expect(horizontal == "︻︼", "實得：\(horizontal)")
    #expect(horizontal.count == 2, "縱排硬化不得改變字元數：\(horizontal)")
    var alreadyVertical = "︻︼"
    ChineseConverter.hardenVerticalPunctuations(target: &alreadyVertical, convert: true)
    #expect(alreadyVertical == "︻︼", "實得：\(alreadyVertical)")
  }

  @Test("IH-PairedPunctuation-022 Half-width Shift+backslash pair splits and centers")
  func test_IH_PairedPunctuation_022_HalfWidthShiftBackslashPairSplitsAndCenters() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let originalHalfWidth = testHandler.prefs.halfWidthPunctuationEnabled
    defer {
      testHandler.prefs.halfWidthPunctuationEnabled = originalHalfWidth
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    testHandler.prefs.halfWidthPunctuationEnabled = true
    guard selectSplitPair("<>", trigger: "|") else { return }
    #expect(
      testHandler.assembler.actualKeys == ["_half_punct_<", "_half_punct_>"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["<", ">"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
    #expect(testHandler.assembler.cursor == 1, "實得：\(testHandler.assembler.cursor)")
  }

  @Test("IH-PairedPunctuation-023 Mismatched partner keys do not beep")
  func test_IH_PairedPunctuation_023_MismatchedPartnerKeysDoNotBeep() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    #expect((try? testHandler.assembler.insertKey("_punct_[")) != nil)
    #expect((try? testHandler.assembler.insertKey("_punct_}")) != nil)
    let didLeft = testHandler.assembler.overrideCandidate(
      .init(keyArray: ["_punct_["], value: "「"),
      at: 0,
      overrideType: .withSpecified,
      isExplicitlyOverridden: false
    )
    let didRight = testHandler.assembler.overrideCandidate(
      .init(keyArray: ["_punct_}"], value: "』"),
      at: 1,
      overrideType: .withSpecified,
      isExplicitlyOverridden: false
    )
    #expect(didLeft && didRight, "測試前提：兩側必須各自成為「」與』」。")
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["「", "』"],
      "實得：\(testHandler.assembler.assembledSentence.map(\.value))"
    )

    var errors = [String]()
    testHandler.errorCallback = { errors.append($0) }
    testHandler.synchronizePairedPunctuationIfNeeded(at: 0)

    #expect(errors.isEmpty, "索引鍵不匹配的同步失敗不應蜂鳴／回報錯誤：\(errors)")
    #expect(
      testHandler.assembler.assembledSentence.map(\.value) == ["「", "』"],
      "同步失敗時應保持原狀：\(testHandler.assembler.assembledSentence.map(\.value))"
    )
  }

  /// 將單一標點 gram 直接覆寫成完整成對值（不經拆對）。
  private func prepareWholePair(
    _ pairValue: String = "【】",
    trigger: String = "\\",
    key: String = "_punct_\\"
  )
    -> Bool {
    guard let testHandler else { return false }
    typeSentence(trigger)
    guard testHandler.assembler.actualKeys == [key] else {
      Issue.record("Unexpected keys: \(testHandler.assembler.actualKeys)")
      return false
    }
    let didOverride = testHandler.assembler.overrideCandidate(
      .init(keyArray: [key], value: pairValue),
      at: 0,
      overrideType: .withSpecified,
      isExplicitlyOverridden: false
    )
    guard didOverride, testHandler.assembler.assembledSentence.map(\.value) == [pairValue] else {
      Issue.record("Failed to prepare \(pairValue). Values: \(testHandler.assembler.assembledSentence.map(\.value))")
      return false
    }
    return true
  }

  /// 鍵入 `trigger`，選中指定的候選。
  private func selectCandidate(_ value: String, trigger: String = "\\") -> Bool {
    guard let testHandler, let testSession else { return false }
    typeSentence(trigger)
    let candidates = testHandler.generateArrayOfCandidates()
    guard candidates.contains(where: { $0.value == value }) else {
      Issue.record("Missing \(value) candidate. Candidates: \(candidates.map(\.value))")
      return false
    }
    testSession.switchState(testHandler.generateStateOfCandidates())
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == value }) else {
      Issue.record("Candidate state is missing \(value). Candidates: \(testSession.state.candidates.map(\.value))")
      return false
    }
    testSession.candidatePairSelectionConfirmed(at: index)
    return true
  }

  /// 鍵入 `trigger`，選中指定的完整成對候選，讓其走完拆對流程。
  private func selectSplitPair(_ pairValue: String, trigger: String = "\\") -> Bool {
    guard selectCandidate(pairValue, trigger: trigger) else { return false }
    guard let testHandler else { return false }
    let keys = testHandler.assembler.actualKeys
    guard keys.count == 2 else {
      Issue.record("Split did not happen. Keys: \(keys)")
      return false
    }
    return true
  }
}
