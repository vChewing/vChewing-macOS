// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import Testing

@testable import LangModelAssembly

// MARK: - POMTestSuite

@Suite(.serialized)
struct POMTestSuite {}

// 更新時間常數，使用天為單位，與 Perceptor 保持一致
private let nowTimeStamp: Double = 114_514 * 10_000
private let capacity = 5
private let dayInSeconds: Double = 24 * 3_600 // 一天的秒數
private let nullURL = URL(fileURLWithPath: "/dev/null")

// MARK: POMTestSuite.POMBasicTests

extension POMTestSuite {
  // MARK: - POMBasicTests

  @Suite(.serialized)
  struct POMBasicTests {
    @Test
    func testPOM_BS01_BasicPerceptionOps() throws {
      let pom = LMAssembly.LMPerceptionOverride(
        capacity: capacity,
        dataURL: nullURL
      )
      let key1 = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
      let expectedSuggestion = "狗"
      pom.memorizePerception((key1, expectedSuggestion), timestamp: nowTimeStamp)

      // 即時查詢應該能找到結果
      var suggested = pom.getSuggestion(key: key1, timestamp: nowTimeStamp)
      #expect((suggested?.first?.value ?? "") == expectedSuggestion)
      #expect((suggested?.first?.previous ?? "") == "的")

      // 測試 2 天和 8 天的記憶衰退
      // 2 天內應該保留，8 天應該消失
      suggested = pom.getSuggestion(
        key: key1,
        timestamp: nowTimeStamp + (dayInSeconds * 2)
      )
      #expect((suggested?.first?.value ?? "") == expectedSuggestion)

      suggested = pom.getSuggestion(
        key: key1,
        timestamp: nowTimeStamp + (dayInSeconds * 8)
      )
      #expect(suggested == nil)
      // -----------

      // 測試基本功能 - 使用簡單的 key 格式
      let key2 = "(test,測試)&(key,鍵)&(target,目標)"
      let candidate = "目標"
      let timestamp = Date.now.timeIntervalSince1970

      // 記憶一個候選詞
      pom.memorizePerception((ngramKey: key2, candidate: candidate), timestamp: timestamp)
      print("記憶候選詞: \(key2) -> \(candidate)")

      // 檢索建議
      let suggestions = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
      if let suggestions = suggestions {
        print("找到 \(suggestions.count) 個建議")
        for suggestion in suggestions {
          print("建議: \(suggestion.value), 權重: \(suggestion.probability)")
        }
        #expect(!suggestions.isEmpty)
        #expect(suggestions.first?.value == candidate)
        #expect((suggestions.first?.probability ?? 0) < 0)
      } else {
        Issue.record("沒有找到建議")
      }

      // 測試清理功能
      pom.clearData()
      let emptySuggestions = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
      #expect(emptySuggestions == nil)

      print("基本 API 測試完成")
    }

    func testPOM_BS02_NewestAgainstRepeatedlyUsed() throws {
      let pom = LMAssembly.LMPerceptionOverride(
        capacity: capacity,
        dataURL: nullURL
      )
      let key = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
      let valRepeatedlyUsed = "狗" // 更常用
      let valNewest = "苟" // 最近偶爾用了一次

      // 使用天數作為單位
      let stamps: [Double] = [0, 0.1, 0.2].map { nowTimeStamp + dayInSeconds * $0 }
      stamps.forEach { stamp in
        pom.memorizePerception((key, valRepeatedlyUsed), timestamp: stamp)
      }

      // 即時查詢應該能找到結果
      var suggested = pom.getSuggestion(key: key, timestamp: nowTimeStamp)
      #expect((suggested?.first?.value ?? "") == valRepeatedlyUsed)

      // 在 1 天後選擇了另一個候選字
      pom.memorizePerception((key, valNewest), timestamp: nowTimeStamp + dayInSeconds * 1)

      // 在 1.1 天檢查最新使用的候選字是否被建議
      suggested = pom.getSuggestion(
        key: key,
        timestamp: nowTimeStamp + dayInSeconds * 1.1
      )
      #expect((suggested?.first?.value ?? "") == valNewest)

      // 在 10 天時，記憶應該已經衰減到閾值以下
      suggested = pom.getSuggestion(
        key: key,
        timestamp: nowTimeStamp + dayInSeconds * 10
      )
      #expect(suggested == nil)
    }

    func testPOM_BS03_LRUTable() throws {
      let a = (key: "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)", value: "狗", head: "ㄍㄡˇ")
      let b = (key: "(ㄆㄞˋ-ㄇㄥˊ,派蒙)&(ㄉㄜ˙,的)&(ㄐㄧㄤˇ-ㄐㄧㄣ,獎金)", value: "伙食費", head: "ㄏㄨㄛˇ-ㄕˊ-ㄈㄟˋ")
      let c = (key: "(ㄍㄨㄛˊ-ㄅㄥ,國崩)&(ㄉㄜ˙,的)&(ㄇㄠˋ-ㄗ˙,帽子)", value: "帽子", head: "ㄇㄠˋ-ㄗ˙")
      let d = (key: "(ㄌㄟˊ-ㄉㄧㄢˋ-ㄐㄧㄤ-ㄐㄩㄣ,雷電將軍)&(ㄉㄜ˙,的)&(ㄐㄧㄠˇ-ㄔㄡˋ,腳臭)", value: "腳臭", head: "ㄐㄧㄠˇ-ㄔㄡˋ")

      // 容量為2的LRU測試
      let pom = LMAssembly.LMPerceptionOverride(
        capacity: 2,
        dataURL: nullURL
      )

      // 緊接著記錄三個項目，只保留最後兩個
      pom.memorizePerception((a.key, a.value), timestamp: nowTimeStamp)
      pom.memorizePerception((b.key, b.value), timestamp: nowTimeStamp + 1)
      pom.memorizePerception((c.key, c.value), timestamp: nowTimeStamp + 2)

      // C是最新的，應該在清單中
      var suggested = pom.getSuggestion(
        key: c.key,
        timestamp: nowTimeStamp + 3
      )
      #expect((suggested?.first?.value ?? "") == c.value)

      // B是第二新的，應該在清單中
      suggested = pom.getSuggestion(
        key: b.key,
        timestamp: nowTimeStamp + 4
      )
      #expect((suggested?.first?.value ?? "") == b.value)

      // A最舊，應該被移除
      suggested = pom.getSuggestion(
        key: a.key,
        timestamp: nowTimeStamp + 5
      )
      #expect(suggested == nil)

      // 添加D, B應該被移除
      pom.memorizePerception((d.key, d.value), timestamp: nowTimeStamp + 6)

      suggested = pom.getSuggestion(
        key: d.key,
        timestamp: nowTimeStamp + 7
      )
      #expect((suggested?.first?.value ?? "") == d.value)

      suggested = pom.getSuggestion(
        key: c.key,
        timestamp: nowTimeStamp + 8
      )
      #expect((suggested?.first?.value ?? "") == c.value)

      suggested = pom.getSuggestion(
        key: b.key,
        timestamp: nowTimeStamp + 9
      )
      #expect(suggested == nil)
    }

    // 添加一個專門測試長期記憶衰減的測試
    func testPOM_BS04_LongTermMemoryDecay() throws {
      let pom = LMAssembly.LMPerceptionOverride(
        capacity: capacity,
        dataURL: nullURL
      )
      let unigramKey = "()&()&(ㄐㄧㄠˇ-ㄔㄡˋ,腳臭)"
      let unigramCandidate = "腳臭"

      pom.memorizePerception((unigramKey, unigramCandidate), timestamp: nowTimeStamp)

      let shortWindowTimestamp = nowTimeStamp + (dayInSeconds * 5.0)
      let shortWindowSuggestions = pom.getSuggestion(key: unigramKey, timestamp: shortWindowTimestamp)
      #expect(shortWindowSuggestions != nil)
      #expect(shortWindowSuggestions?.first?.value == unigramCandidate)
      if let score = shortWindowSuggestions?.first?.probability {
        #expect(score > LMAssembly.LMPerceptionOverride.kDecayThreshold)
      }

      let pastShortWindowTimestamp = nowTimeStamp + (dayInSeconds * 7.0)
      #expect(pom.getSuggestion(key: unigramKey, timestamp: pastShortWindowTimestamp) == nil)

      // 給腳臭來點上下文。
      let contextualKey = "(ㄌㄟˊ-ㄉㄧㄢˋ-ㄐㄧㄤ-ㄐㄩㄣ,雷電將軍)&(ㄉㄜ˙,的)&(ㄐㄧㄠˇ-ㄔㄡˋ,腳臭)"
      let contextualCandidate = "腳臭"

      pom.memorizePerception((contextualKey, contextualCandidate), timestamp: nowTimeStamp)

      let longWindowTimestamp = nowTimeStamp + (dayInSeconds * 7.5)
      let longWindowSuggestions = pom.getSuggestion(key: contextualKey, timestamp: longWindowTimestamp)
      #expect(longWindowSuggestions != nil)
      #expect(longWindowSuggestions?.first?.value == contextualCandidate)

      let pastLongWindowTimestamp = nowTimeStamp + (dayInSeconds * 8.0)
      #expect(pom.getSuggestion(key: contextualKey, timestamp: pastLongWindowTimestamp) == nil)
    }

    func testPOM_BS05_BleachUnigramsRemovesDelimitedUnigrams() throws {
      let json = """
      [
        {
          "p": { "ovr": { "流溢": { "ts": 1760430443.677927, "cnt": 1 } } },
          "k": "()&()&(ㄌㄧㄡˊ-ㄧˋ,流溢)"
        },
        {
          "p": { "ovr": { "【】": { "ts": 1760420369.484758, "cnt": 2 } } },
          "k": "()&()&(_punctuation_|,【】)"
        },
        {
          "k": "()&()&(ㄧˋ-ㄧˋ,意譯)",
          "p": { "ovr": { "意譯": { "cnt": 1, "ts": 1760420293.741153 } } }
        },
        {
          "p": { "ovr": { "《》": { "ts": 1760365764.630261, "cnt": 1 } } },
          "k": "()&()&(_punctuation_|,《》)"
        },
        {
          "k": "(ㄧ,一)&(ㄎㄞ-ㄕˇ,開始)&(ㄓ,隻)",
          "p": { "ovr": { "隻": { "cnt": 1, "ts": 1760361739.6757479 } } }
        },
        {
          "p": { "ovr": { "煸": { "ts": 1760358515.301589, "cnt": 1 } } },
          "k": "()&()&(ㄅㄧㄢ,煸)"
        },
        {
          "k": "()&()&(ㄓㄜˋ-ㄧㄤˋ-ㄗ˙,這樣子)",
          "p": { "ovr": { "這樣子": { "cnt": 1, "ts": 1760327246.0910969 } } }
        },
        {
          "p": { "ovr": { "→": { "ts": 1760275750.28729, "cnt": 1 } } },
          "k": "()&()&(_punctuation_+,→)"
        }
      ]
      """
      let data = Data(json.utf8)
      let decoder = JSONDecoder()
      let pairs = try decoder.decode([LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self, from: data)
      let pom = LMAssembly.LMPerceptionOverride(dataURL: nullURL)
      pom.loadData(from: pairs)

      #expect(pom.mutLRUMap.count == 5)
      #expect(!pom.mutLRUMap.keys.contains(where: { $0.contains("_punctuation_") }))

      pom.bleachUnigrams()

      #expect(pom.mutLRUMap.count == 1)
      #expect(pom.mutLRUMap.keys.contains("(ㄧ,一)&(ㄎㄞ-ㄕˇ,開始)&(ㄓ,隻)"))
      #expect(pom.mutLRUKeySeqList == ["(ㄧ,一)&(ㄎㄞ-ㄕˇ,開始)&(ㄓ,隻)"])
    }

    func testPOM_BS06_PerceptionKeyGeneration() throws {
      let nonInterruptionSuffix: [Megrez.GramInPath] = [
        ("neng2", "能", -5.36),
        ("liu2", "留", -5.245),
        ("yi4-lv3", "一縷", -8.496),
      ].map(Megrez.GramInPath.fromTuplet)

      guard let nonInterruptionResult = nonInterruptionSuffix.generateKeyForPerception() else {
        Issue.record("Failed to generate perception key for non-interruption suffix.")
        return
      }

      #expect(nonInterruptionResult.ngramKey == "(neng2,能)&(liu2,留)&(yi4-lv3,一縷)")
      #expect(nonInterruptionResult.candidate == "一縷")
      #expect(nonInterruptionResult.headReading == "lv3")

      let interruptionSuffix: [Megrez.GramInPath] = [
        ("you1-die2", "幽蝶", -8.496),
        ("neng2", "能", -5.36),
        ("liu2", "留", -5.245),
      ].map(Megrez.GramInPath.fromTuplet)

      guard let interruptionResult = interruptionSuffix.generateKeyForPerception() else {
        Issue.record("Failed to generate perception key for interruption suffix.")
        return
      }

      #expect(interruptionResult.ngramKey == "(you1-die2,幽蝶)&(neng2,能)&(liu2,留)")
      #expect(interruptionResult.candidate == "留")
      #expect(interruptionResult.headReading == "liu2")
    }

    func testPOM_BS07_ParsePerceptionKeyUnigramHasNoContext() throws {
      let pom = LMAssembly.LMPerceptionOverride(dataURL: nullURL)
      guard let parsed = pom.parsePerceptionKey("()&()&(ㄧˋ-ㄧˋ,意譯)") else {
        Issue.record("Failed to parse unigram perception key.")
        return
      }
      #expect(parsed.headReading == "ㄧˋ-ㄧˋ")
      #expect(parsed.headValue == "意譯")
      #expect(parsed.previous == nil)
      #expect(parsed.anterior == nil)
    }

    func testPOM_BS08_ParsePerceptionKeyContextualParts() throws {
      let pom = LMAssembly.LMPerceptionOverride(dataURL: nullURL)
      let key = "(ㄧ,一)&(ㄎㄞ-ㄕˇ,開始)&(ㄓ,隻)"
      guard let parsed = pom.parsePerceptionKey(key) else {
        Issue.record("Failed to parse contextual perception key.")
        return
      }
      #expect(parsed.headReading == "ㄓ")
      #expect(parsed.headValue == "隻")
      #expect(parsed.previous?.reading == "ㄎㄞ-ㄕˇ")
      #expect(parsed.previous?.value == "開始")
      #expect(parsed.anterior?.reading == "ㄧ")
      #expect(parsed.anterior?.value == "一")
    }

    func testPOM_BS09_IgnoresUnderscorePrefixedReadings() throws {
      let pom = LMAssembly.LMPerceptionOverride(dataURL: nullURL)
      let punctuationKey = "()&()&(_punctuation_|,《》)"
      pom.memorizePerception((punctuationKey, "《》"), timestamp: nowTimeStamp)
      #expect(pom.mutLRUMap.isEmpty)
      #expect(pom.getSuggestion(key: punctuationKey, timestamp: nowTimeStamp + 1) == nil)

      let dashedKey = "()&()&(ㄍㄡˇ-_punctuation_|,狗，)"
      pom.memorizePerception((dashedKey, "狗，"), timestamp: nowTimeStamp)
      #expect(pom.mutLRUMap.isEmpty)
      #expect(pom.getSuggestion(key: dashedKey, timestamp: nowTimeStamp + 1) == nil)
    }

    func testPOM_BS10_AlternateKeysDoesNotMatchShortSegments() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let now = Date.now.timeIntervalSince1970

      // 多段 head: BC
      let originalKey = "()&()&(BC,BC)"
      // 切成兩段的候選： previous=B head=C
      let splitCandidate = "()&(B,B)&(C,C)"

      pom.memorizePerception((ngramKey: splitCandidate, candidate: "split"), timestamp: now)
      pom.memorizePerception((ngramKey: originalKey, candidate: "orig"), timestamp: now)

      let fallbacks = pom.alternateKeysForTesting(originalKey)
      #expect(
        fallbacks.contains(splitCandidate)
      )
    }

    func testPOM_BS11_AlternateKeysAllowsPrimaryMatchForSingleSegmentOriginal() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let now = Date.now.timeIntervalSince1970

      // 原始為單段 head: B
      let originalKey = "()&()&(B,orig)"
      // 另一個以相同 head B（但 value 不同）的候選
      let candidate = "()&()&(B,b2)"

      pom.memorizePerception((ngramKey: candidate, candidate: "c2"), timestamp: now)
      pom.memorizePerception((ngramKey: originalKey, candidate: "orig"), timestamp: now)

      let fallbacks = pom.alternateKeysForTesting(originalKey)
      #expect(
        fallbacks.contains(candidate)
      )
    }

    func testPOM_BS12_AlternateKeysRejectsSingleSegmentPrimaryMatchForMultiSegmentOriginal() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let now = Date.now.timeIntervalSince1970

      // 原始為多段 head: B-C（使用 Compositor.theSeparator = "-"）
      let originalKey = "()&()&(B-C,orig)"
      // 單段候選僅匹配 primary segment B
      let candidate = "()&()&(B,cand)"

      pom.memorizePerception((ngramKey: candidate, candidate: "c1"), timestamp: now)
      pom.memorizePerception((ngramKey: originalKey, candidate: "orig"), timestamp: now)

      let fallbacks = pom.alternateKeysForTesting(originalKey)
      #expect(!fallbacks.contains(candidate))
    }

    func testPOM_BS13_AlternateKeysAllowsSingleSegmentPrimaryWhenPreviousMatches() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let now = Date.now.timeIntervalSince1970

      // 原始為多段 head 且有 previous: A & (B-C)
      let originalKey = "()&(A,A)&(B-C,orig)"
      // 單段候選匹配 primary B，但帶有相同的 previous A
      let candidate = "()&(A,A)&(B,cand)"

      pom.memorizePerception((ngramKey: candidate, candidate: "c1"), timestamp: now)
      pom.memorizePerception((ngramKey: originalKey, candidate: "orig"), timestamp: now)

      let fallbacks = pom.alternateKeysForTesting(originalKey)
      #expect(
        fallbacks.contains(candidate)
      )
    }

    func testPOM_BS14_GetSuggestionIncludesPreviousField() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let now = Date.now.timeIntervalSince1970

      // Bigram 候選字詞（帶有 `previous`）
      let candidateKey = "()&(A,A)&(B,cand)"
      pom.memorizePerception((ngramKey: candidateKey, candidate: "cand"), timestamp: now)

      guard let suggestions = pom.getSuggestion(key: candidateKey, timestamp: now + 1) else {
        Issue.record("Failed to get suggestions for candidate key.")
        return
      }
      // getSuggestion 應回傳 previous 欄位為先前值的 tuple
      #expect(suggestions.contains { $0.value == "cand" && $0.previous == "A" })
    }

    @Test
    func testPOM_BS15_SplitCandidateCombinedHeadAccepted() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let now = Date.now.timeIntervalSince1970

      // 原始的多段頭部：BC
      let originalKey = "()&()&(BC,BC)"
      // 拆分候選：previous=B head=C
      let splitCandidate = "()&(B,B)&(C,cand)"

      pom.memorizePerception((ngramKey: splitCandidate, candidate: "split"), timestamp: now)

      // 對 splitCandidate 直接呼叫 getSuggestion 應成功取得建議
      guard let suggestions = pom.getSuggestion(key: splitCandidate, timestamp: now + 1) else {
        Issue.record("Failed to get suggestions for split candidate.")
        return
      }
      #expect(suggestions.contains { $0.value == "split" })

      // 對 original 呼叫 alternateKeysForTesting 應包含 splitCandidate
      let fallbacks = pom.alternateKeysForTesting(originalKey)
      #expect(fallbacks.contains(splitCandidate))
    }
  }
}

extension Megrez.Node {
  fileprivate static func fromTuplet(
    _ tuplet4Test: (keyChain: String, value: String, score: Double)
  )
    -> Megrez.Node {
    let keyCells = tuplet4Test.keyChain.split(separator: "-").map(\.description)
    return Megrez.Node(
      keyArray: keyCells,
      segLength: keyCells.count,
      unigrams: [
        .init(value: tuplet4Test.value, score: tuplet4Test.score),
      ]
    )
  }
}

extension Megrez.GramInPath {
  fileprivate static func fromTuplet(
    _ tuplet4Test: (keyChain: String, value: String, score: Double)
  )
    -> Megrez.GramInPath {
    let keyCells = tuplet4Test.keyChain.split(separator: "-").map(\.description)
    return Megrez.GramInPath(
      gram: .init(keyArray: keyCells, value: tuplet4Test.value, score: tuplet4Test.score),
      isExplicit: false
    )
  }
}
