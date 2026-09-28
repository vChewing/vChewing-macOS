// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
@testable import LexiconAssembly
@testable import LibVanguard
import Shared
import Testing

// MARK: - 漸退記憶（POM）之語境詞界（Phase 272）

/// 使用者報告：打「這個檔案是怎樣出現的？」時，實際輸出為「這個檔案室怎樣出現的？」；
/// 而用以糾正該句的漸退記憶（`這個 檔案 是` 之三元語境）**只在**先把游標退到「檔」後面、
/// 於選字窗選一次「檔案」，再把游標推到「是」、於選字窗選一次「是」之後才會生成。
///
/// 本 suite 以兩支互補的靶釘住該流程的兩端：
/// - **寫入側**（IH707）：單次選字（只選「是」）即應寫下**詞級**語境 `(個)&(檔案)&(是)`，
///   而非逐鍵拆散之 `(檔)&(案)&(是)`。
/// - **讀取側**（IH709）：語境加分（bigram／trigram）於**每一輪**組句皆須重算——否則該記憶
///   只影響一拍，下一個按鍵即被詞庫長詞取代。
///
/// IH708 為兩者之整合靶（單次糾正 → 重打即得正確句子）。
extension LibVanguardTestsRoot.InputHandlerTests {
  /// 測試句「這個檔案是怎樣出現的？」之按鍵流（大千排列；「出」為陰平、故以空格收聲調）。
  static let pomContextSentenceKeys = "5k4ek42;304g4yp3u;4tj vu042k7"

  /// 測試語料：**逐筆取自出貨語料庫之權重**（`vChewing-VanguardLexicon/Build/Release/tsv/data-v4.8.5.txt`
  /// 之 `讀音<TAB>詞值<TAB>權重`），各讀音只取足以左右本句組句之前幾名。關鍵三筆為
  /// `ㄉㄤˇ-ㄢˋ 檔案 -4.234`、`ㄉㄤˇ-ㄢˋ-ㄕˋ 檔案室 -5.856`、`ㄕˋ 是 -5.004`：
  /// 無記憶時「檔案室」(−5.856) 勝過「檔案」＋「是」(−9.238)；有記憶時後者得語境加分而勝。
  static let pomContextFixture: [(keyArray: [String], value: String, score: Double)] = [
    (["ㄓㄜˋ"], "這", -5.033),
    (["ㄍㄜˋ"], "個", -5.031),
    (["ㄓㄜˋ", "ㄍㄜˋ"], "這個", -6.656),
    (["ㄉㄤˇ"], "黨", -5.120),
    (["ㄉㄤˇ"], "檔", -5.185),
    (["ㄢˋ"], "案", -5.108),
    (["ㄕˋ"], "是", -5.004),
    (["ㄕˋ"], "室", -5.164),
    (["ㄗㄣˇ"], "怎", -5.244),
    (["ㄧㄤˋ"], "樣", -5.182),
    (["ㄗㄣˇ", "ㄧㄤˋ"], "怎樣", -4.224),
    (["ㄔㄨ"], "出", -5.121),
    (["ㄒㄧㄢˋ"], "現", -5.164),
    (["ㄔㄨ", "ㄒㄧㄢˋ"], "出現", -3.022),
    (["ㄉㄜ˙"], "的", -4.971),
    (["ㄉㄤˇ", "ㄢˋ"], "檔案", -4.234),
    (["ㄉㄤˇ", "ㄢˋ", "ㄕˋ"], "檔案室", -5.856),
  ]

  func installPOMContextFixture() {
    Self.pomContextFixture.forEach {
      testHandler?.currentLM.insertTemporaryData(
        unigram: .init(keyArray: $0.keyArray, value: $0.value, score: $0.score),
        isFiltering: false
      )
    }
  }

  func preparePOMContextScenario() {
    guard let testHandler, let testSession else { return }
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    installPOMContextFixture()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.consolidateContextOnCandidateSelection = true
    testSession.installMockCandidateController()
    typeSentence(Self.pomContextSentenceKeys)
  }

  func tearDownPOMContextScenario() {
    testHandler?.currentLM.clearTemporaryData(isFiltering: false)
    testSession?.mockCandidateController = nil
    testSession?.resetInputHandler(forceComposerCleanup: true)
    clearTestPOM()
  }

  /// 把游標放到指定讀音格之後，並刷新選字窗清單。
  /// - Returns: 該游標位置之候選值清單。
  @discardableResult
  func placeCaretAndRefreshCandidates(atKeyIndex index: Int) -> [String] {
    guard let testHandler, let testSession else { return [] }
    testHandler.assembler.cursor = index + 1
    testSession.switchState(testHandler.generateStateOfCandidates(dodge: false))
    return testSession.state.candidates.map(\.value)
  }

  /// 以選字窗之選字鍵選中給定值（等同使用者以選字窗選字）。
  @discardableResult
  func selectCandidateFromWindow(_ value: String) -> Bool {
    guard let testHandler, let testSession else { return false }
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == value }),
          Array(testSession.selectionKeys).indices.contains(index)
    else { return false }
    let keyChar = Array(testSession.selectionKeys)[index]
    return testHandler.triageInput(event: KBEvent.KeyEventData(chars: String(keyChar)).asEvent)
  }

  /// 已存入漸退記憶模組之語境鍵清單。
  func storedPOMKeys() -> [String] {
    testHandler?.currentLM.lxPerceptor.getSavableData().map(\.key) ?? []
  }

  /// IH707（寫入側）：於「檔案室」成詞之句中央選一次「是」，即應寫下詞級語境之記憶。
  ///
  /// 舊行為：`consolidateCandidateCursorContext` 為保全「檔案室」其餘各鍵之值，將整個節點
  /// 逐鍵拆成「檔」「案」「室」⇒ 觀察到的語境是「檔 案 是」，該記憶對「檔案 是」永不生效。
  @Test
  func test_IH707_SingleSelectionRecordsWordLevelContextMemory() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    preparePOMContextScenario()
    defer { tearDownPOMContextScenario() }
    // 詞庫之長詞「檔案室」勝出（此即使用者所報之實際輸出）。
    #expect(generateDisplayedText() == "這個檔案室怎樣出現的")
    #expect(testSession.state.type == .ofInputting)

    // 游標退到「是」那一格，於選字窗選一次「是」——不做任何多餘之游標往返。
    let candidateValues = placeCaretAndRefreshCandidates(atKeyIndex: 4)
    #expect(candidateValues.first == "檔案室")
    #expect(candidateValues.contains("是"))
    #expect(selectCandidateFromWindow("是"))
    #expect(generateDisplayedText() == "這個檔案是怎樣出現的")

    // 寫入側之判準：語境須為詞級之「檔案」，而非逐鍵之「檔 案」。
    let pomKeys = storedPOMKeys()
    #expect(pomKeys.contains("(ㄓㄜˋ-ㄍㄜˋ,這個)&(ㄉㄤˇ-ㄢˋ,檔案)&(ㄕˋ,是)"))
    #expect(!pomKeys.contains("(ㄉㄤˇ,檔)&(ㄢˋ,案)&(ㄕˋ,是)"))
    _ = testHandler
  }

  /// IH708（整合）：單次糾正之後，重打同一句即應得正確輸出。
  @Test
  func test_IH708_SingleSelectionFixSurvivesRetype() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    preparePOMContextScenario()
    defer { tearDownPOMContextScenario() }
    _ = placeCaretAndRefreshCandidates(atKeyIndex: 4)
    #expect(selectCandidateFromWindow("是"))
    #expect(generateDisplayedText() == "這個檔案是怎樣出現的")

    // 清空組字器、重打同一句：記憶應勝過詞庫之「檔案室」。
    testHandler.clear()
    typeSentence(Self.pomContextSentenceKeys)
    #expect(generateDisplayedText() == "這個檔案是怎樣出現的")
    _ = testSession
  }

  /// IH709（讀取側）：語境加分於每一輪組句皆須重算，不得只生效一拍。
  ///
  /// 舊行為：組句函式於命中語境加分時把節點記成 `withTopGramScore` 覆寫狀態，而該狀態之計分臂
  /// 逕以 unigram 基線計分 ⇒ 加分不再重算。實測：按「ㄕˋ」時得「這個檔案是」，再按「ㄗ」即
  /// 還原成「這個檔案室怎」。本靶直接注入詞級記憶、不經寫入側，故兩側之缺陷可分別歸因。
  @Test
  func test_IH709_ContextualBonusIsRecomputedOnEveryAssembly() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    installPOMContextFixture()
    defer { tearDownPOMContextScenario() }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄓㄜˋ-ㄍㄜˋ,這個)&(ㄉㄤˇ-ㄢˋ,檔案)&(ㄕˋ,是)", candidate: "是"),
      timestamp: Date().timeIntervalSince1970
    )
    typeSentence(Self.pomContextSentenceKeys)
    #expect(generateDisplayedText() == "這個檔案是怎樣出現的")
    // 組句為冪等：同一組鍵再組一次，結果與分數皆不變。
    let scoreBefore = testHandler.assembler.mostRecentPathScore
    #expect(testHandler.assembler.assemble().values.joined() == "這個檔案是怎樣出現的")
    #expect(testHandler.assembler.mostRecentPathScore == scoreBefore)
  }
}
