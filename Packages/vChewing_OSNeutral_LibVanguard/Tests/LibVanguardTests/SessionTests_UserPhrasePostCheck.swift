// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Shared
import SwiftExtension
import Testing

@testable import LexiconAssembly
@testable import LibVanguard

// MARK: - PhraseStoreWriteSpy

// 升權／降權之後的延後查核：成效不足時須找出真因並自救。

/// 模擬生產環境之「宿主落盤即套用」：把列寫進語言模組，並可刻意吞掉前幾次落盤。
private final class PhraseStoreWriteSpy {
  // MARK: Lifecycle

  init(lx: LXAssembly.LXFacade, failFirstCall: Bool = false) {
    self.lx = lx
    self.remainingFailures = failFirstCall ? 1 : 0
  }

  // MARK: Internal

  let lx: LXAssembly.LXFacade
  private(set) var attempts = 0
  private(set) var applied = 0

  static func row(of phrase: UserPhraseInsertable) -> String {
    var cells = [phrase.value, phrase.keyArray.joined(separator: "-")]
    if let weight = phrase.weight { cells.append(weight.description) }
    return cells.joined(separator: " ")
  }

  func write(_ phrase: UserPhraseInsertable, isFiltering: Bool) -> Bool {
    attempts += 1
    guard phrase.isValid else { return false }
    if remainingFailures > 0 {
      remainingFailures -= 1
      return true // 受理，但實際上未落盤。
    }
    applied += 1
    return lx.insertUserDataRow(Self.row(of: phrase), isFiltering: isFiltering)
  }

  // MARK: Private

  private var remainingFailures: Int
}

// MARK: - SS.UserPhrasePostCheck

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  /// 受測詞音配對（測試辭典內 ㄋㄧㄢˊ-ㄓㄨㄥ 下有「年終」−4.33、與「年中」−5.33 兩筆原廠條目）。
  private var postCheckKeyArray: [String] { ["ㄋㄧㄢˊ", "ㄓㄨㄥ"] }
  private var postCheckKeyChain: String { postCheckKeyArray.joined(separator: "-") }

  private func makePostCheckPhrase(value: String, weight: Double? = nil) -> UserPhraseInsertable {
    .init(keyArray: postCheckKeyArray, value: value, inputMode: .imeModeCHT, weight: weight)
  }

  /// 以間諜取代測試預設之純記錄，並回傳收尾用之還原閉包。
  private func adoptWriteSpy(_ spy: PhraseStoreWriteSpy) -> () -> () {
    guard let host = testEnv?.host else { return {} }
    let originalWrite = host.writeUserPhrasesAtOnce
    let originalWeight = host.updateUserPhraseWeight
    host.writeUserPhrasesAtOnce = { phrase, isFiltering in
      spy.write(phrase, isFiltering: isFiltering)
    }
    host.updateUserPhraseWeight = { phrase, action in
      var phrase = phrase
      switch action {
      case .toBoost: phrase.weight = nil
      case .toNerf: phrase.weight = -114.514
      case .toFilter: phrase.weight = nil
      }
      return phrase
    }
    return {
      host.writeUserPhrasesAtOnce = originalWrite
      host.updateUserPhraseWeight = originalWeight
    }
  }

  private func resetPhraseStore() {
    testHandler.prefs.useSCPCTypingMode = false
    testLX.clearTemporaryData(isFiltering: false)
    testLX.clearTemporaryData(isFiltering: true)
    testLX.replaceData(textData: "", for: .thePhrases, save: false)
    testLX.clearPOMData()
  }

  private func topUnigramValue() -> String? {
    testLX.lxQuerier.grams(for: postCheckKeyArray).first(where: \.isUnigram)?.current
  }

  @Test("SS-UserPhrase-002 Post check purges a gradual memory that hijacks a boosted phrase")
  func test_SS_UserPhrase_002_PostCheckPurgesPOMHijack() throws {
    resetPhraseStore()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    let spy = PhraseStoreWriteSpy(lx: testLX)
    let restore = adoptWriteSpy(spy)
    defer {
      restore()
      testLX.clearPOMData()
      LXAssembly.drainUserDataWriteQueue()
    }

    // 既有使用者列：年中 @0（＝升權後之權重），故語言模組本身已判年中居首。
    #expect(testLX.insertUserDataRow("年中 \(postCheckKeyChain) 0", isFiltering: false))
    prepareBasicComposition(sequence: "su065j/ ")
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "年中")

    // 一筆「當下既定選字為年中、使用者卻改選年終」之記憶：升權之後仍會被它拉走。
    let now = Date().timeIntervalSince1970
    testLX.memorizePerception(("()&()&(\(postCheckKeyChain),年中)", "年終"), timestamp: now)
    #expect(
      testLX.pomMemories(headReading: postCheckKeyChain, timestamp: now)
        .contains { $0.headValue == "年中" && $0.candidate == "年終" }
    )
    #expect(topUnigramValue() == "年中")

    // 經真實的標記路徑升權（此刻 POM 記憶會綁架選字，故查核必須自行清掉它）。
    press(.shiftLeftEvent)
    press(.shiftLeftEvent)
    #expect(testSession.state.type == .ofMarking)
    press(.dataEnterReturn)
    #expect(spy.applied == 1)

    testSession.runPhraseOperationPostCheck(for: makePostCheckPhrase(value: "年中"), action: .toBoost)
    #expect(
      testLX.pomMemories(headReading: postCheckKeyChain, timestamp: now).isEmpty,
      "升權查核應清掉同一讀音底下會綁架選字的漸退記憶。"
    )

    // 清詞之後，重新組字即應得到剛升權的詞。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClientProxy.clear()
    typeSentenceOrCandidates("su065j/ ")
    if testSession.state.type != .ofInputting {
      testSession.switchState(testHandler.generateStateOfInputting())
    }
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "年中")
  }

  @Test("SS-UserPhrase-003 Post check re-appends a row whose write never landed")
  func test_SS_UserPhrase_003_PostCheckRewritesMissingRow() throws {
    resetPhraseStore()
    let spy = PhraseStoreWriteSpy(lx: testLX, failFirstCall: true)
    let restore = adoptWriteSpy(spy)
    defer {
      restore()
      LXAssembly.drainUserDataWriteQueue()
    }

    // 競品先佔 0 分。
    #expect(testLX.insertUserDataRow("年終 \(postCheckKeyChain) 0", isFiltering: false))
    let phrase = makePostCheckPhrase(value: "年中")

    // 第一次落盤「受理但未套用」：使用者片語檔內沒有這一列。
    #expect(testEnv?.host.writeUserPhrasesAtOnce(phrase, false) == true)
    #expect(topUnigramValue() == "年終")

    testSession.runPhraseOperationPostCheck(for: phrase, action: .toBoost)
    #expect(spy.attempts == 2, "查核發現該列不在庫時應補寫一次。")
    #expect(topUnigramValue() == "年中", "補寫之列應成為該讀音底下最新且居首的條目。")
  }

  @Test("SS-UserPhrase-004 Post check rewrites a tied row so that the latest intent wins")
  func test_SS_UserPhrase_004_PostCheckBreaksTieByRecency() throws {
    resetPhraseStore()
    let spy = PhraseStoreWriteSpy(lx: testLX, failFirstCall: true)
    let restore = adoptWriteSpy(spy)
    defer {
      restore()
      LXAssembly.drainUserDataWriteQueue()
    }

    // 兩列同為 0 分，但競品之列較新——故語言模組此刻判競品居首。
    #expect(testLX.insertUserDataRow("年中 \(postCheckKeyChain) 0", isFiltering: false))
    #expect(testLX.insertUserDataRow("年終 \(postCheckKeyChain) 0", isFiltering: false))
    #expect(topUnigramValue() == "年終")

    // 本次升權之落盤同樣「受理但未套用」，故查核看到的仍是舊列序。
    let phrase = makePostCheckPhrase(value: "年中")
    #expect(testEnv?.host.writeUserPhrasesAtOnce(phrase, false) == true)
    #expect(topUnigramValue() == "年終")

    testSession.runPhraseOperationPostCheck(for: phrase, action: .toBoost)
    #expect(topUnigramValue() == "年中", "重寫之列即最新之列，同分時應由它勝出。")
  }

  @Test("SS-UserPhrase-005 Equal-score candidates keep the latest row first")
  func test_SS_UserPhrase_005_EqualScoreOrderIsDeterministic() throws {
    resetPhraseStore()
    defer { LXAssembly.drainUserDataWriteQueue() }

    var inserted = [String]()
    for index in 0 ..< 30 {
      let value = "年\(index)中"
      inserted.append(value)
      #expect(testLX.insertUserDataRow("\(value) \(postCheckKeyChain) 0", isFiltering: false))
    }
    let insertedSet = Set(inserted)
    let returned = testLX.lxQuerier.grams(for: postCheckKeyArray)
      .filter(\.isUnigram).map(\.current)
      .filter { insertedSet.contains($0) }
    #expect(returned == inserted.reversed(), "同分者須維持「新列在前」之次序。")
  }

  @Test("SS-UserPhrase-007 The deferred check runs by itself after the write")
  func test_SS_UserPhrase_007_DeferredCheckRunsAutomatically() async throws {
    resetPhraseStore()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    let spy = PhraseStoreWriteSpy(lx: testLX)
    let restore = adoptWriteSpy(spy)
    defer {
      restore()
      testLX.clearPOMData()
      LXAssembly.drainUserDataWriteQueue()
    }

    #expect(testLX.insertUserDataRow("年中 \(postCheckKeyChain) 0", isFiltering: false))
    prepareBasicComposition(sequence: "su065j/ ")
    let now = Date().timeIntervalSince1970
    testLX.memorizePerception(("()&()&(\(postCheckKeyChain),年中)", "年終"), timestamp: now)

    // 經真實的標記路徑升權：查核由該路徑自行排定，本測試**不**再手動叫它。
    press(.shiftLeftEvent)
    press(.shiftLeftEvent)
    press(.dataEnterReturn)
    #expect(
      testLX.pomMemories(headReading: postCheckKeyChain, timestamp: now).count == 1,
      "查核係延後執行：按下升權當下，該記憶仍應存在。"
    )

    // 排空寫入巷、並讓主佇列得以執行已排入的查核（上限約 2 秒，不依賴牆鐘精度）。
    var purged = false
    for _ in 0 ..< 40 {
      LXAssembly.drainUserDataWriteQueue()
      if testLX.pomMemories(headReading: postCheckKeyChain, timestamp: now).isEmpty {
        purged = true
        break
      }
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    #expect(purged, "查核應於落盤之後自行執行、無須呼叫端再推一把。")
  }

  @Test("SS-UserPhrase-006 Post check purges the target's own memory after a nerf")
  func test_SS_UserPhrase_006_PostCheckPurgesTargetMemoryAfterNerf() throws {
    resetPhraseStore()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    let spy = PhraseStoreWriteSpy(lx: testLX)
    let restore = adoptWriteSpy(spy)
    defer {
      restore()
      testLX.clearPOMData()
      LXAssembly.drainUserDataWriteQueue()
    }

    #expect(testLX.insertUserDataRow("年中 \(postCheckKeyChain) 0", isFiltering: false))
    let now = Date().timeIntervalSince1970
    // 一筆「既定選字為年終、使用者改選年中」之記憶：降權之後仍會把年中拉回來。
    testLX.memorizePerception(("()&()&(\(postCheckKeyChain),年終)", "年中"), timestamp: now)
    #expect(
      testLX.pomMemories(headReading: postCheckKeyChain, timestamp: now)
        .contains { $0.headValue == "年終" && $0.candidate == "年中" }
    )

    // 降權：權重極低，名次上已沉底，但記憶仍會把年中拉回來——故查核不能只看名次。
    let phrase = makePostCheckPhrase(value: "年中", weight: -114.514)
    _ = testEnv?.host.writeUserPhrasesAtOnce(phrase, false)
    testSession.runPhraseOperationPostCheck(for: phrase, action: .toNerf)
    #expect(
      testLX.pomMemories(headReading: postCheckKeyChain, timestamp: now).isEmpty,
      "降權查核應清掉會把目標拉回來的漸退記憶。"
    )
  }
}
